import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../domain/ad_placements.dart';
import '../../infrastructure/appearance/native_appearance.g.dart';
import '../../infrastructure/drivers/managed_native_ad.dart';
import '../../infrastructure/mutex/presentation_mutex.dart';
import '../ad_session.dart';
import '../admob_kit_facade.dart';

/// Native ad host measured from SDK assets and the available width.
///
/// Automatically collapses to [SizedBox.shrink] if the user is premium.
/// The template reserves an initial height while loading. Loaded inline ads
/// use their native measured height; do not constrain them to that estimate.
/// Fullscreen templates fill bounded height and own exclusive presentation only
/// while a loaded ad is active. Keep app dismissal controls outside this host.
///
/// Deferred loading: the first request waits until [TickerMode] (route coverage
/// via Overlay) and [Visibility] (e.g. hidden `IndexedStack` tabs) allow it.
/// Once delivered, the ad stays mounted for the host's lifetime, so covering
/// routes and tab switches never reload it. Unshown ads older than the
/// configured TTL are replaced when the host becomes visible again.
class AdNativeView extends StatelessWidget {
  /// The type-safe native placement descriptor.
  final NativePlacement placement;

  /// The optional custom placeholder rendered while the ad buffer is filling.
  final Widget? placeholder;

  /// Whether to render a styled placeholder while the ad is loading.
  ///
  /// Defaults to `true`.
  final bool showPlaceholder;

  /// Creates a host bound to the placement's template and dimensions.
  const AdNativeView({
    super.key,
    required this.placement,
    this.placeholder,
    this.showPlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cold-start and collapse frames can temporarily have no render area.
        if (constraints.maxWidth <= 0 || (constraints.hasBoundedHeight && constraints.maxHeight <= 0)) {
          return const SizedBox.shrink();
        }
        final template = placement.template;
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth < template.minWidth ||
            (template.isFullscreen && (!constraints.hasBoundedHeight || constraints.maxHeight < template.height))) {
          throw FlutterError(
            'AdNativeView ${template.name} requires a bounded width of at least '
            '${template.minWidth}${template.isFullscreen ? " and bounded height of at least ${template.height}" : " with room for its measured content"}.',
          );
        }
        return _AdNativeHost(
          config: this,
          width: constraints.maxWidth,
          minHeight: constraints.minHeight,
          maxHeight: constraints.maxHeight,
        );
      },
    );
  }
}

/// Owns the lease only after the outer host has established valid layout bounds.
class _AdNativeHost extends StatefulWidget {
  final AdNativeView config;
  final double width;
  final double minHeight;
  final double maxHeight;
  const _AdNativeHost({required this.config, required this.width, required this.minHeight, required this.maxHeight});
  @override
  State<_AdNativeHost> createState() => _AdNativeViewState();
}

class _AdNativeViewState extends State<_AdNativeHost> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  bool _isLoading = true;
  bool _hasAttemptedLoad = false;
  bool _leasePending = false;
  bool _templateConflict = false;
  int _generation = 0;
  bool _attached = true;
  double? _layoutHeight;
  Object? _layoutError;
  int _layoutGeneration = 0;
  ({double width, double? height, double headline, double body, double metadata, double action})?
  _layoutKey;
  PresentationMutex? _mutex;
  PresentationToken? _token;
  StreamSubscription<void>? _presentationChanges;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdmobKit.initializationStateListenable.addListener(_onInitializationChanged);
  }

  void _resetLease() {
    _releasePresentation();
    _generation++;
    _layoutGeneration++;
    _layoutHeight = null;
    _layoutKey = null;
    _layoutError = null;
    _nativeAd?.dispose();
    _nativeAd = null;
    _isLoading = true;
    _leasePending = false;
    _hasAttemptedLoad = false;
    updateKeepAlive();
  }

  // Lazy lists and page views would otherwise dispose a scrolled-away host and
  // request a new ad when it scrolls back.
  @override
  bool get wantKeepAlive => _nativeAd != null;

  void _onInitializationChanged() {
    if (!mounted) return;
    final state = AdmobKit.initializationState;
    if (state == AdInitializationState.disposed ||
        state == AdInitializationState.updatingConsent ||
        state == AdInitializationState.consentDenied ||
        state == AdInitializationState.failed) {
      setState(() {
        _resetLease();
        _isLoading = state == AdInitializationState.updatingConsent;
      });
    } else {
      setState(_checkAndActivate);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndActivate();
  }

  @override
  void didUpdateWidget(_AdNativeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _templateConflict =
        oldWidget.config.placement.id == widget.config.placement.id &&
        (_templateConflict || oldWidget.config.placement.template != widget.config.placement.template);
    if (_templateConflict) {
      _resetLease();
      return;
    }
    if (oldWidget.config.placement.id != widget.config.placement.id) {
      _resetLease();
    }
    _checkAndActivate();
  }

  void _checkAndActivate() {
    if (_templateConflict || !_attached) return;
    _bindPresentation();
    final active = _isSubtreeActive;
    if (_nativeAd == null && !AdmobKit.canRequestAds) {
      final state = AdmobKit.initializationState;
      _isLoading =
          state == AdInitializationState.gatheringConsent ||
          state == AdInitializationState.initializingSdk ||
          state == AdInitializationState.updatingConsent;
    }
    final ad = _nativeAd;
    final ttl = activeAdSession?.config.adTtl;
    if (active &&
        ad is ManagedNativeAd &&
        !ad.hasImpression &&
        ad.loadedAt != null &&
        ttl != null &&
        DateTime.now().difference(ad.loadedAt!) > ttl) {
      _resetLease();
    }
    if (!active && _nativeAd == null && !_leasePending) {
      // Deactivated with nothing loaded or settled (e.g. prior offline
      // failure): reset so reactivating this tab retries the lease instead of
      // staying blank. Skipped while a lease is still in-flight.
      _hasAttemptedLoad = false;
    } else if (active && _nativeAd == null && !_hasAttemptedLoad && !_leasePending && AdmobKit.canRequestAds) {
      _loadNative();
    }
    if (_nativeAd != null) _configureLayout();
    _syncPresentation();
  }

  void _configureLayout() {
    final scaler = MediaQuery.textScalerOf(context);
    final key = (
      width: widget.width,
      height: _effectiveTemplate.isFullscreen ? widget.maxHeight : null,
      headline: scaler.scale(15),
      body: scaler.scale(12),
      metadata: scaler.scale(11),
      action: scaler.scale(13),
    );
    if (_layoutKey == key) return;
    _layoutKey = key;
    _layoutHeight = null;
    _layoutError = null;
    _releasePresentation();
    final version = ++_layoutGeneration;
    final ad = _nativeAd;
    final measure = ad is ManagedNativeAd ? ad.measureLayout : null;
    final result = measure == null
        ? Future<double>.error(StateError('Native render has no layout measurement.'))
        : measure(
            NativeLayoutRequest(
              width: key.width,
              height: key.height,
              headlineSize: key.headline,
              bodySize: key.body,
              metadataSize: key.metadata,
              actionSize: key.action,
            ),
          );
    result.then<void>(
      (height) {
        if (!mounted || version != _layoutGeneration || !identical(ad, _nativeAd)) {
          return;
        }
        setState(() {
          if (!height.isFinite || height <= 0 || height > widget.maxHeight + 1) {
            _layoutError = FlutterError(
              'Native ad assets require $height logical pixels of height; '
              'the host provides ${widget.maxHeight}. Allow inline ads to size themselves.',
            );
          } else {
            _layoutHeight = height;
          }
          _syncPresentation();
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || version != _layoutGeneration || !identical(ad, _nativeAd)) {
          return;
        }
        setState(() => _layoutError = error);
      },
    );
  }

  void _bindPresentation() {
    final next = _effectiveTemplate.isFullscreen ? activeAdSession?.mutex : null;
    if (identical(next, _mutex)) return;
    _releasePresentation();
    _presentationChanges?.cancel();
    _mutex = next;
    _presentationChanges = next?.changes.listen((_) {
      if (!mounted || !_attached) return;
      setState(_checkAndActivate);
    });
  }

  void _releasePresentation() {
    final token = _token;
    _token = null;
    if (token != null) _mutex?.release(token);
  }

  void _syncPresentation() {
    if (_token != null && !(_mutex?.owns(_token!) ?? false)) _token = null;
    if (!_isSubtreeActive ||
        _nativeAd == null ||
        _layoutHeight == null ||
        AdmobKit.isUserPremium ||
        AdmobKit.initializationState != AdInitializationState.ready) {
      _releasePresentation();
    } else if (_effectiveTemplate.isFullscreen && _token == null) {
      _token = _mutex?.tryAcquire(widget.config.placement.id);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_attached) return;
    // An empty slot (no fill, retries exhausted) tries again when the app returns.
    final retry = state == AppLifecycleState.resumed && _nativeAd == null && !_leasePending;
    if (retry) _hasAttemptedLoad = false;
    if (retry || _effectiveTemplate.isFullscreen) setState(_checkAndActivate);
  }

  @override
  void deactivate() {
    _attached = false;
    _releasePresentation();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _attached = true;
    // didChangeDependencies follows activation and revalidates freshness/gates.
  }

  void _loadNative() {
    if (AdmobKit.isUserPremium) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _hasAttemptedLoad = true;
    _leasePending = true;
    _isLoading = true;
    final generation = _generation;

    // Demand-based lease: the pool delivers a distinct ad instance when one is
    // buffered or replenished. Settles instantly on terminal load failure.
    (activeAdSession?.leaseInlineAd(
          widget.config.placement,
          // A hidden waiter is skipped; the engine buffers the ad for the visible host.
          isMounted: () => mounted && _attached && generation == _generation && _isSubtreeActive,
        ) ??
        Future<dynamic>.value(null))
        .then((ad) {
          if (!mounted || generation != _generation) {
            // Never rendered — release the platform resource immediately.
            if (ad is Ad) ad.dispose();
            return;
          }
          _leasePending = false;
          setState(() {
            _nativeAd = ad is NativeAd ? ad : null;
            updateKeepAlive();
            _isLoading = false;
            _checkAndActivate();
            if (_nativeAd == null && !_isSubtreeActive) {
              _hasAttemptedLoad = false;
            }
          });
        })
        .catchError((_) {
          // AdMob no-fill / network failure / timeout: render the empty state
          // instead of hanging on the placeholder.
          if (!mounted || generation != _generation) return;
          _leasePending = false;
          setState(() {
            _isLoading = false;
            if (!_isSubtreeActive) _hasAttemptedLoad = false;
          });
        });
  }

  @override
  void dispose() {
    _releasePresentation();
    _presentationChanges?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AdmobKit.initializationStateListenable.removeListener(_onInitializationChanged);
    _generation++;
    _layoutGeneration++;
    if (_leasePending) activeAdSession?.abandonLease(widget.config.placement);
    _nativeAd?.dispose();
    super.dispose();
  }

  /// Deferred-loading gate: active only when the subtree both animates
  /// (TickerMode, e.g. route coverage) and is visible (Visibility, e.g.
  /// IndexedStack hidden tabs). Plain screens satisfy both by default.
  bool get _isSubtreeActive =>
      _attached &&
      (!_effectiveTemplate.isFullscreen ||
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) &&
      TickerMode.valuesOf(context).enabled &&
      Visibility.of(context);

  NativeAdTemplate get _effectiveTemplate => widget.config.placement.template;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_templateConflict) {
      throw ArgumentError('Changing a native template requires a distinct placement ID.');
    }
    if (AdmobKit.isUserPremium) {
      return const SizedBox.shrink();
    }
    if (_layoutError != null) {
      throw FlutterError('Native layout failed: $_layoutError');
    }

    final layoutHeight = _layoutHeight;
    if (layoutHeight != null && layoutHeight > widget.maxHeight + 1) {
      throw FlutterError(
        'Native ad assets require $layoutHeight logical pixels of height; '
        'the host provides ${widget.maxHeight}. Allow inline ads to size themselves.',
      );
    }
    final height = _effectiveTemplate.isFullscreen
        ? widget.maxHeight
        : (layoutHeight ?? _effectiveTemplate.height).clamp(widget.minHeight, widget.maxHeight);

    // Hosts that have not requested yet stay quiet instead of showing a spinner.
    if (_nativeAd == null && !_isSubtreeActive) {
      return SizedBox(width: widget.width, height: height, child: widget.config.placeholder);
    }

    return SizedBox(
      width: widget.width,
      height: height,
      child: _nativeAd != null && _layoutHeight != null && (!_effectiveTemplate.isFullscreen || _token != null)
          ? AdWidget(key: ObjectKey(_nativeAd), ad: _nativeAd!)
          : ((_isLoading || _nativeAd != null) && widget.config.showPlaceholder
                ? (widget.config.placeholder ?? _buildDefaultPlaceholder(context))
                : const SizedBox.shrink()),
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      ),
    );
  }
}
