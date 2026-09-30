import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../infrastructure/drivers/managed_native_ad.dart';
import '../../infrastructure/mutex/presentation_mutex.dart';
import '../../domain/models/ad_native_template.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_initialization_state.dart';
import '../admob_kit_facade.dart';

/// Zero-CLS (Cumulative Layout Shift) container for Native ads.
///
/// Automatically collapses to [SizedBox.shrink] if the user is premium.
/// Layout dimensions and native view factory bindings are governed by the
/// [NativeAdTemplate] enum on the placement.
/// Fullscreen templates fill bounded height and own exclusive presentation only
/// while a loaded ad is active. Keep app dismissal controls outside this host.
///
/// Deferred loading: ad loads are gated on [TickerMode] (route coverage via
/// Overlay) **and** [Visibility] (e.g. hidden `IndexedStack` tabs). Custom lazy
/// containers that do not expose these gates must provide [active] from their
/// selection state. Viewport visibility is not inferred from widget mounting.
class AdNativeView extends StatelessWidget {
  /// The type-safe native placement descriptor.
  final NativePlacement placement;

  /// The optional custom placeholder rendered while the ad buffer is filling.
  final Widget? placeholder;

  /// Whether to render a styled placeholder while the ad is loading.
  ///
  /// Defaults to `true`.
  final bool showPlaceholder;

  /// Additional activity gate for hosts that do not expose Visibility/TickerMode.
  /// Cannot override an inactive ancestor.
  final bool active;

  /// Creates a host bound to the placement's template and dimensions.
  const AdNativeView({
    super.key,
    required this.placement,
    this.active = true,
    this.placeholder,
    this.showPlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final template = placement.template;
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth < template.minWidth ||
            (template.isFullscreen && !constraints.hasBoundedHeight) ||
            constraints.maxHeight < template.height) {
          throw FlutterError(
            'AdNativeView ${template.name} requires a bounded width of at least '
            '${template.minWidth} and ${template.isFullscreen ? "bounded " : ""}height of at least ${template.height}.',
          );
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: template.isFullscreen ? constraints.maxHeight : template.height,
          child: _AdNativeHost(config: this),
        );
      },
    );
  }
}

/// Owns the lease only after the outer host has established valid layout bounds.
class _AdNativeHost extends StatefulWidget {
  final AdNativeView config;
  const _AdNativeHost({required this.config});
  @override
  State<_AdNativeHost> createState() => _AdNativeViewState();
}

class _AdNativeViewState extends State<_AdNativeHost> with WidgetsBindingObserver {
  NativeAd? _nativeAd;
  bool _isLoading = true;
  bool _hasAttemptedLoad = false;
  bool _leasePending = false;
  bool _wasActive = false;
  bool _templateConflict = false;
  int _generation = 0;
  bool _attached = true;
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
    _nativeAd?.dispose();
    _nativeAd = null;
    _isLoading = true;
    _leasePending = false;
    _hasAttemptedLoad = false;
  }

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
    final reactivating = active && !_wasActive;
    _wasActive = active;
    if (_nativeAd == null && !AdmobKit.canRequestAds) {
      final state = AdmobKit.initializationState;
      _isLoading =
          state == AdInitializationState.gatheringConsent ||
          state == AdInitializationState.initializingSdk ||
          state == AdInitializationState.updatingConsent;
    }
    final ad = _nativeAd;
    if ((reactivating || (_effectiveTemplate.isFullscreen && _token == null)) &&
        ad is ManagedNativeAd &&
        ad.loadedAt != null &&
        DateTime.now().difference(ad.loadedAt!) > AdmobKit.inlineAdTtl) {
      _resetLease();
    }
    if (!_isSubtreeActive && _nativeAd == null && !_leasePending) {
      // Deactivated with nothing loaded or settled (e.g. prior offline
      // failure): reset so reactivating this tab retries the lease instead of
      // staying blank. Skipped while a lease is still in-flight.
      _hasAttemptedLoad = false;
    } else if (_isSubtreeActive && _nativeAd == null && !_hasAttemptedLoad && AdmobKit.canRequestAds) {
      _loadNative();
    }
    _syncPresentation();
  }

  void _bindPresentation() {
    final next = _effectiveTemplate.isFullscreen ? AdmobKit.presentationMutex : null;
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
        AdmobKit.isUserPremium ||
        AdmobKit.initializationState != AdInitializationState.ready) {
      _releasePresentation();
    } else if (_effectiveTemplate.isFullscreen && _token == null) {
      _token = _mutex?.tryAcquire(widget.config.placement.id);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && _attached && _effectiveTemplate.isFullscreen) setState(_checkAndActivate);
  }

  @override
  void deactivate() {
    _attached = false;
    _wasActive = false;
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
    AdmobKit.leaseInlineAd(widget.config.placement)
        .then((ad) {
          if (!mounted || generation != _generation) {
            // Never rendered — release the platform resource immediately.
            if (ad is Ad) ad.dispose();
            return;
          }
          _leasePending = false;
          setState(() {
            _nativeAd = ad is NativeAd ? ad : null;
            _isLoading = false;
            _checkAndActivate();
            if (_nativeAd == null && !_isSubtreeActive) _hasAttemptedLoad = false;
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
    _nativeAd?.dispose();
    super.dispose();
  }

  /// Deferred-loading gate: active only when the subtree both animates
  /// (TickerMode, e.g. route coverage) and is visible (Visibility, e.g.
  /// IndexedStack hidden tabs). Plain screens satisfy both by default.
  bool get _isSubtreeActive =>
      _attached &&
      widget.config.active &&
      (!_effectiveTemplate.isFullscreen ||
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) &&
      TickerMode.valuesOf(context).enabled &&
      Visibility.of(context);

  NativeAdTemplate get _effectiveTemplate => widget.config.placement.template;

  @override
  Widget build(BuildContext context) {
    if (_templateConflict) {
      throw ArgumentError('Changing a native template requires a distinct placement ID.');
    }
    if (AdmobKit.isUserPremium) {
      return const SizedBox.shrink();
    }

    final isSubtreeActive = _isSubtreeActive;

    // Preserves zero CLS layout bounds while offstage without mounting native platform view
    if (!isSubtreeActive) {
      return SizedBox(width: double.infinity, child: widget.config.placeholder ?? const SizedBox.shrink());
    }

    return SizedBox(
      width: double.infinity,
      child: _nativeAd != null && (!_effectiveTemplate.isFullscreen || _token != null)
          ? AdWidget(key: ObjectKey(_nativeAd), ad: _nativeAd!)
          : ((_isLoading || _nativeAd != null) && widget.config.showPlaceholder
                ? (widget.config.placeholder ?? _buildDefaultPlaceholder(context))
                : const SizedBox.shrink()),
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0x28FFFFFF) : const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF9185E9) : const Color(0xFF4338CA)),
        ),
      ),
    );
  }
}
