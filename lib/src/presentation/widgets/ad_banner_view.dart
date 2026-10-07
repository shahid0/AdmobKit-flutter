import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../domain/models/ad_initialization_state.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/banner_layout.dart';
import '../../infrastructure/drivers/adaptive_banner_ad.dart';
import '../../infrastructure/pool/ad_cache_entry.dart';
import '../ad_runtime.dart';
import '../admob_kit_facade.dart';

/// Adaptive banner sized to its parent's available logical width.
///
/// Anchored banners use the SDK-selected height. Inline banners reserve their
/// configured maximum height, with the creative centered at its actual size.
/// Loading and rendering honor Visibility, TickerMode, and [active].
class AdBannerView extends StatelessWidget {
  final BannerPlacement placement;

  /// Optional logical width. Required only when the parent width is unbounded.
  final double? width;
  final Widget? placeholder;

  /// Additional gate for retained-page hosts without Flutter visibility signals.
  final bool active;

  const AdBannerView({super.key, required this.placement, this.width, this.placeholder, this.active = true});

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) return const SizedBox.shrink();
    final orientation = MediaQuery.orientationOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = width == null ? constraints.maxWidth : constraints.constrainWidth(width!);
        if (!available.isFinite || available < 1 || (width != null && (!width!.isFinite || width! <= 0))) {
          throw FlutterError('AdBannerView requires a positive bounded width. Supply width in an unbounded parent.');
        }
        return _BannerHost(
          placement: placement,
          layout: BannerLayout(
            width: available.floor(),
            orientation: orientation == Orientation.portrait ? BannerOrientation.portrait : BannerOrientation.landscape,
          ),
          active: active,
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
  final Widget? placeholder;

  const _BannerHost({required this.placement, required this.layout, required this.active, this.placeholder});

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
    if (oldWidget.placement.id != widget.placement.id || oldWidget.layout != widget.layout) _resetLease();
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
      final ad = await session?.leaseInlineAd(widget.placement, bannerLayout: widget.layout);
      if (!mounted || generation != _generation) {
        await AdCacheEntry.disposeAdInstance(ad);
        return;
      }
      if (ad != null && ad is! AdaptiveBannerAd) {
        await AdCacheEntry.disposeAdInstance(ad);
        throw StateError('Banner driver returned a non-adaptive ad.');
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
    final height = widget.placement.sizing.maxHeight?.toDouble() ?? size?.height.toDouble() ?? 0;
    return SizedBox(
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
          : (_pending ? widget.placeholder : null),
    );
  }
}
