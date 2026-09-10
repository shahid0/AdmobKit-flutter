import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/models/ad_placement.dart';
import '../flutter_ads_facade.dart';

/// Zero-CLS (Cumulative Layout Shift) banner container.
///
/// Automatically collapses to [SizedBox.shrink] if the user is premium.
/// Pre-reserves layout bounds to prevent visual jumping when the ad renders.
class AdBannerView extends StatefulWidget {
  /// Type-safe banner placement descriptor.
  final BannerPlacement placement;

  /// Reserved height for the banner ad (defaults to 50.0 for standard banner).
  final double height;

  /// Reserved width for the banner ad (defaults to 320.0).
  final double width;

  /// Optional placeholder rendered while the ad buffer is filling.
  final Widget? placeholder;

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

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (FlutterAds.isUserPremium) {
      setState(() => _isLoading = false);
      return;
    }

    final cached = FlutterAds.leaseInlineAd(widget.placement);
    if (cached is BannerAd) {
      setState(() {
        _bannerAd = cached;
        _isLoading = false;
      });
    } else {
      FlutterAds.pool?.preload(widget.placement).then((_) {
        if (!mounted) return;
        final newlyLoaded = FlutterAds.leaseInlineAd(widget.placement);
        if (newlyLoaded is BannerAd) {
          setState(() {
            _bannerAd = newlyLoaded;
            _isLoading = false;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FlutterAds.isUserPremium) {
      return const SizedBox.shrink();
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
