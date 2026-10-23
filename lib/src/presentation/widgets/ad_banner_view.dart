import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../domain/ad_placements.dart';
import '../../infrastructure/drivers/adaptive_banner_ad.dart';
import '../../infrastructure/engine/ad_cache_entry.dart';
import '../ad_session.dart';
import '../admob_kit_facade.dart';
import 'ad_loading_shimmer.dart';

/// Adaptive or fixed banner centered within its parent's available logical width.
///
/// Inline and fixed banners reserve their configured height by default. Set
/// [reserveSpace] to false to collapse while loading and use the actual loaded
/// height. Anchored banners always use the SDK-selected height when available.
/// The first request waits for Visibility and TickerMode. Once
/// delivered, the banner stays mounted for the host's lifetime; the SDK only
/// refreshes it while it is on screen.
/// Fixed banners use an ad preloaded by [AdmobKit.registerPlacements] when one is
/// ready, and render nothing in a host narrower than their fixed width.
class AdBannerView extends StatelessWidget {
  final BannerPlacement placement;

  /// Host width. Defaults to the parent's width, or the fixed banner width in an
  /// unbounded parent. Adaptive banners require a width in unbounded parents.
  final double? width;

  /// Overrides [BannerSizing.reserveSpace]. Null uses the placement's policy.
  /// When true, reserves maxHeight or fixedHeight, including while loading.
  /// When false, collapses until render dimensions are available.
  final bool? reserveSpace;

  /// Displayed while loading only when space is reserved. Defaults to a
  /// shimmering "Loading ad" placeholder.
  final Widget? placeholder;

  const AdBannerView({
    super.key,
    required this.placement,
    this.width,
    this.reserveSpace,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) return const SizedBox.shrink();
    final orientation = MediaQuery.orientationOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wait for a renderable width during cold-start and collapse frames.
        if (constraints.maxWidth <= 0) return const SizedBox.shrink();
        final available = width != null
            ? constraints.constrainWidth(width!)
            : constraints.hasBoundedWidth
            ? constraints.maxWidth
            : placement.sizing.fixedWidth?.toDouble() ?? double.infinity;
        if (!available.isFinite ||
            available < 1 ||
            (width != null && (!width!.isFinite || width! <= 0))) {
          throw FlutterError(
            'AdBannerView requires a positive bounded width. Supply width in an unbounded parent.',
          );
        }
        final sizing = placement.sizing;
        // A fixed creative cannot shrink, so a narrower host never requests it.
        if (sizing.isFixed && available < sizing.fixedWidth!) return const SizedBox.shrink();
        return _BannerHost(
          placement: placement,
          width: available.floor().toDouble(),
          layout: sizing.isFixed
              ? null
              : BannerLayout(
                  width: available.floor(),
                  orientation: orientation == Orientation.portrait ? BannerOrientation.portrait : BannerOrientation.landscape,
                ),
          reserveSpace: reserveSpace ?? sizing.reserveSpace,
          placeholder: placeholder,
        );
      },
    );
  }
}

class _BannerHost extends StatefulWidget {
  final BannerPlacement placement;
  final double width;

  /// Request layout for adaptive banners; null for fixed banners.
  final BannerLayout? layout;
  final bool reserveSpace;
  final Widget? placeholder;

  const _BannerHost({
    required this.placement,
    required this.width,
    required this.layout,
    required this.reserveSpace,
    this.placeholder,
  });

  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  AdaptiveBannerAd? _ad;
  // The layout [_ad] was requested for; differs from the widget's while a resize reloads.
  BannerLayout? _adLayout;
  bool _pending = false;
  bool _attempted = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdmobKit.initializationStateListenable.addListener(_onInitializationChanged);
  }

  // An empty slot (no fill, retries exhausted) tries again when the app returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || _ad != null || _pending) return;
    setState(() {
      _attempted = false;
      _checkAndActivate();
    });
  }

  // Lazy lists and page views would otherwise dispose a scrolled-away host and
  // request a new banner when it scrolls back.
  @override
  bool get wantKeepAlive => _ad != null;

  void _resetLease() {
    _generation++;
    _ad?.renderSize.removeListener(_sizeChanged);
    _ad?.dispose();
    _ad = null;
    _adLayout = null;
    _pending = false;
    _attempted = false;
    updateKeepAlive();
  }

  void _sizeChanged() {
    if (mounted) setState(() {});
  }

  void _onInitializationChanged() {
    if (!mounted) return;
    final state = AdmobKit.initializationState;
    if (state == AdInitializationState.disposed ||
        state == AdInitializationState.updatingConsent ||
        state == AdInitializationState.consentDenied ||
        state == AdInitializationState.failed) {
      setState(_resetLease);
    } else if (state == AdInitializationState.ready) {
      setState(_checkAndActivate);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndActivate();
  }

  @override
  void didUpdateWidget(_BannerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _resetLease();
    } else if (oldWidget.layout != widget.layout) {
      // Keep the current banner on screen until the new size arrives.
      _generation++;
      _pending = false;
      _attempted = false;
    }
    _checkAndActivate();
  }

  // Decides when to request and which host receives an ad; a delivered banner stays mounted.
  bool get _active => TickerMode.valuesOf(context).enabled && Visibility.of(context);

  void _checkAndActivate() {
    if (!_active) {
      if (_ad == null && !_pending) _attempted = false;
      return;
    }
    final ad = _ad;
    final ttl = activeAdSession?.config.adTtl;
    if (ad != null && !ad.hasImpression && ad.loadedAt != null && ttl != null && DateTime.now().difference(ad.loadedAt!) > ttl) {
      _resetLease();
    }
    if ((_ad == null || _adLayout != widget.layout) && !_attempted && !AdmobKit.isUserPremium) _load();
  }

  Future<void> _load() async {
    _attempted = true;
    _pending = true;
    final generation = _generation;
    final session = activeAdSession;
    try {
      final ad = await session?.leaseInlineAd(
        widget.placement,
        bannerLayout: widget.layout,
        // A hidden waiter is skipped; the engine buffers the ad for the visible host.
        isMounted: () => mounted && generation == _generation && _active,
      );
      if (!mounted || generation != _generation) {
        await AdCacheEntry.disposeAdInstance(ad);
        return;
      }
      if (ad != null && ad is! AdaptiveBannerAd) {
        await AdCacheEntry.disposeAdInstance(ad);
        throw StateError('Banner driver returned an unmanaged banner ad.');
      }
      _pending = false;
      setState(() {
        if (ad is AdaptiveBannerAd) {
          _ad?.renderSize.removeListener(_sizeChanged);
          _ad?.dispose();
          _ad = ad..renderSize.addListener(_sizeChanged);
          _adLayout = widget.layout;
          updateKeepAlive();
        } else if (_ad == null && !_active) {
          _attempted = false;
        }
      });
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      session?.logger.error('[Banner] Lease failed for "${widget.placement.id}".', error, stack);
      setState(() {
        _pending = false;
        if (!_active) _attempted = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdmobKit.initializationStateListenable.removeListener(_onInitializationChanged);
    final waiting = _pending;
    _resetLease();
    if (waiting) activeAdSession?.abandonLease(widget.placement, bannerLayout: widget.layout);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (AdmobKit.isUserPremium) return const SizedBox.shrink();
    final ad = _ad;
    final rendered = ad?.renderSize.value;
    // A banner kept through a resize is hidden if it no longer fits.
    final size = rendered != null && rendered.width <= widget.width ? rendered : null;
    final sizing = widget.placement.sizing;
    final reservedHeight = widget.reserveSpace ? (sizing.maxHeight ?? sizing.fixedHeight)?.toDouble() : null;
    final height = reservedHeight ?? size?.height.toDouble() ?? 0;
    return AnimatedContainer(
      duration: widget.placement.isCollapsible ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.fastOutSlowIn,
      width: widget.width,
      height: height,
      child: ad != null && size != null
          ? Center(
              child: SizedBox(
                width: size.width.toDouble(),
                height: size.height.toDouble(),
                child: AdWidget(key: ObjectKey(ad), ad: ad),
              ),
            )
          : (_pending && widget.reserveSpace ? widget.placeholder ?? const AdLoadingShimmer() : null),
    );
  }
}
