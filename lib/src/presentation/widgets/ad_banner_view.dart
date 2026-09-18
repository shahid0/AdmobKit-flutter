import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/models/ad_placement.dart';
import '../admob_kit_facade.dart';

/// Zero-CLS (Cumulative Layout Shift) banner container.
///
/// Automatically collapses to [SizedBox.shrink] if the user is premium.
/// Pre-reserves layout bounds to prevent visual jumping when the ad renders.
///
/// Deferred loading: ad loads are gated on [TickerMode] (route coverage via
/// Overlay) **and** [Visibility] (e.g. hidden `IndexedStack` tabs). A tab
/// inside an `IndexedStack` defers its ad request until switched to. Custom
/// tab containers that neither gate must be wrapped in `TickerMode` or
/// `Visibility` explicitly to opt into deferral.
class AdBannerView extends StatefulWidget {
  /// The type-safe banner placement descriptor.
  final BannerPlacement placement;

  /// The reserved height for the banner ad (defaults to 50.0 for standard banner).
  final double height;

  /// The reserved width for the banner ad (defaults to 320.0).
  final double width;

  /// The optional placeholder rendered while the ad buffer is filling.
  final Widget? placeholder;

  /// Creates an [AdBannerView] for a given [placement].
  const AdBannerView({
    super.key,
    required this.placement,
    this.height = 50.0,
    this.width = 320.0,
    this.placeholder,
  });

  @override
  State<AdBannerView> createState() => _AdBannerViewState();
}

class _AdBannerViewState extends State<AdBannerView> {
  BannerAd? _bannerAd;
  bool _isLoading = true;
  bool _hasAttemptedLoad = false;
  bool _leasePending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndActivate();
  }

  @override
  void didUpdateWidget(AdBannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement.id != widget.placement.id) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoading = true;
      _hasAttemptedLoad = false;
      _checkAndActivate();
    }
  }

  void _checkAndActivate() {
    if (!_isSubtreeActive && _bannerAd == null && !_leasePending) {
      // Deactivated with nothing loaded or settled (e.g. prior offline
      // failure): reset so reactivating this tab retries the lease instead of
      // staying blank. Skipped while a lease is still in-flight.
      _hasAttemptedLoad = false;
    } else if (_isSubtreeActive && _bannerAd == null && !_hasAttemptedLoad) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (AdmobKit.isUserPremium) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _hasAttemptedLoad = true;
    _leasePending = true;

    // Demand-based lease: the pool delivers a distinct ad instance when one is
    // buffered or replenished. Settles instantly on terminal load failure.
    AdmobKit.leaseInlineAd(widget.placement).then((ad) {
      _leasePending = false;
      if (!mounted) {
        // Never rendered — release the platform resource immediately.
        if (ad is BannerAd) ad.dispose();
        return;
      }
      setState(() {
        _bannerAd = ad is BannerAd ? ad : null;
        _isLoading = false;
      });
    }).catchError((_) {
      // AdMob no-fill / network failure / timeout: render the empty state
      // instead of hanging on the placeholder.
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  /// Deferred-loading gate: active only when the subtree both animates
  /// (TickerMode, e.g. route coverage) and is visible (Visibility, e.g.
  /// IndexedStack hidden tabs). Plain screens satisfy both by default.
  bool get _isSubtreeActive =>
      TickerMode.valuesOf(context).enabled && Visibility.of(context);

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) {
      return const SizedBox.shrink();
    }

    final isSubtreeActive = _isSubtreeActive;

    // Preserves zero CLS layout bounds while offstage without mounting native platform view
    if (!isSubtreeActive && _bannerAd == null) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: widget.placeholder ?? const SizedBox.shrink(),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : (_isLoading ? (widget.placeholder ?? const SizedBox.shrink()) : const SizedBox.shrink()),
    );
  }
}
