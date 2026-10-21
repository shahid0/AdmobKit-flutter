import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../domain/ad_placements.dart';
import '../../infrastructure/drivers/adaptive_banner_ad.dart';
import '../../infrastructure/engine/ad_cache_entry.dart';
import '../ad_session.dart';
import '../admob_kit_facade.dart';

/// Adaptive or fixed banner centered within its parent's available logical width.
///
/// Inline and fixed banners reserve their configured height by default. Set
/// [reserveSpace] to false to collapse while loading and use the actual loaded
/// height. Anchored banners always use the SDK-selected height when available.
/// Loading and rendering honor Visibility, TickerMode, and [active].
class AdBannerView extends StatelessWidget {
  final BannerPlacement placement;

  /// Host width. Defaults to the parent's width, or the fixed banner width in an
  /// unbounded parent. Adaptive banners require a width in unbounded parents.
  final double? width;

  /// Overrides [BannerSizing.reserveSpace]. Null uses the placement's policy.
  /// When true, reserves maxHeight or fixedHeight, including while loading.
  /// When false, collapses until render dimensions are available.
  final bool? reserveSpace;

  /// Displayed while loading only when space is reserved.
  final Widget? placeholder;

  /// Additional gate for retained-page hosts without Flutter visibility signals.
  final bool active;

  const AdBannerView({
    super.key,
    required this.placement,
    this.width,
    this.reserveSpace,
    this.placeholder,
    this.active = true,
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
        return _BannerHost(
          placement: placement,
          layout: BannerLayout(
            width: available.floor(),
            orientation: orientation == Orientation.portrait ? BannerOrientation.portrait : BannerOrientation.landscape,
          ),
          active: active,
          reserveSpace: reserveSpace ?? placement.sizing.reserveSpace,
          placeholder: placeholder,
        );
      },
    );
  }
}

class _BannerHost extends StatefulWidget {
  final BannerPlacement placement;
  final BannerLayout layout;
  final bool active;
  final bool reserveSpace;
  final Widget? placeholder;

  const _BannerHost({
    required this.placement,
    required this.layout,
    required this.active,
    required this.reserveSpace,
    this.placeholder,
  });

  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost> {
  AdaptiveBannerAd? _ad;
  bool _pending = false;
  bool _attempted = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    AdmobKit.initializationStateListenable.addListener(_onInitializationChanged);
  }

  void _resetLease() {
    _generation++;
    _ad?.renderSize.removeListener(_sizeChanged);
    _ad?.dispose();
    _ad = null;
    _pending = false;
    _attempted = false;
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
    if (oldWidget.placement != widget.placement || oldWidget.layout != widget.layout) _resetLease();
    _checkAndActivate();
  }

  bool get _active => widget.active && TickerMode.valuesOf(context).enabled && Visibility.of(context);

  void _checkAndActivate() {
    if (!_active) {
      if (_ad == null && !_pending) _attempted = false;
      return;
    }
    final loadedAt = _ad?.loadedAt;
    final ttl = activeAdSession?.config.adTtl;
    if (loadedAt != null && ttl != null && DateTime.now().difference(loadedAt) > ttl) _resetLease();
    if (_ad == null && !_attempted && !AdmobKit.isUserPremium) _load();
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
        isMounted: () => mounted && _active,
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
        _ad = ad as AdaptiveBannerAd?;
        _ad?.renderSize.addListener(_sizeChanged);
        if (_ad == null && !_active) _attempted = false;
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
    AdmobKit.initializationStateListenable.removeListener(_onInitializationChanged);
    _resetLease();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) return const SizedBox.shrink();
    final ad = _ad;
    final size = ad?.renderSize.value;
    final sizing = widget.placement.sizing;
    final reservedHeight = widget.reserveSpace ? (sizing.maxHeight ?? sizing.fixedHeight)?.toDouble() : null;
    final height = reservedHeight ?? size?.height.toDouble() ?? 0;
    return AnimatedContainer(
      duration: widget.placement.isCollapsible ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.fastOutSlowIn,
      width: widget.layout.width.toDouble(),
      height: height,
      child: _active && ad != null && size != null
          ? Center(
              child: SizedBox(
                width: size.width.toDouble(),
                height: size.height.toDouble(),
                child: AdWidget(key: ObjectKey(ad), ad: ad),
              ),
            )
          : (_pending && widget.reserveSpace ? widget.placeholder : null),
    );
  }
}
