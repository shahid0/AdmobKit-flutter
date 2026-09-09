import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/models/ad_placement.dart';
import '../flutter_ads_facade.dart';

/// Zero-CLS (Cumulative Layout Shift) container for Native ads.
///
/// Automatically collapses to [SizedBox.shrink] if the user is premium.
/// Pre-reserves layout bounds based on the specified [NativePlacement.template]
/// or custom [height] to prevent visual jumping when the ad loads.
class AdNativeView extends StatefulWidget {
  /// Type-safe native placement descriptor.
  final NativePlacement placement;

  /// Reserved height for the native ad layout.
  /// If null, resolves automatically from [NativePlacement.template]
  /// (e.g. 300.0 for Big, 130.0 for Medium, 74.0 for Small).
  final double? height;

  /// Reserved width for the native ad layout (defaults to double.infinity).
  final double width;

  /// Optional custom placeholder rendered while the ad buffer is filling.
  final Widget? placeholder;

  /// Whether to render a styled dark placeholder while the ad is loading.
  /// Defaults to true.
  final bool showPlaceholder;

  const AdNativeView({
    super.key,
    required this.placement,
    this.height,
    this.width = double.infinity,
    this.placeholder,
    this.showPlaceholder = true,
  });

  @override
  State<AdNativeView> createState() => _AdNativeViewState();
}

class _AdNativeViewState extends State<AdNativeView> {
  NativeAd? _nativeAd;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNative();
  }

  void _loadNative() {
    if (FlutterAds.isUserPremium) {
      setState(() => _isLoading = false);
      return;
    }

    final cached = FlutterAds.leaseInlineAd(widget.placement);
    if (cached is NativeAd) {
      setState(() {
        _nativeAd = cached;
        _isLoading = false;
      });
    } else {
      FlutterAds.pool?.preload(widget.placement).then((_) {
        if (!mounted) return;
        final newlyLoaded = FlutterAds.leaseInlineAd(widget.placement);
        if (newlyLoaded is NativeAd) {
          setState(() {
            _nativeAd = newlyLoaded;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }).catchError((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  double get _effectiveHeight =>
      widget.height ?? widget.placement.template?.defaultHeight ?? 300.0;

  @override
  Widget build(BuildContext context) {
    if (FlutterAds.isUserPremium) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _effectiveHeight,
      width: widget.width,
      child: _nativeAd != null
          ? AdWidget(ad: _nativeAd!)
          : (_isLoading && widget.showPlaceholder
              ? (widget.placeholder ?? _buildDefaultPlaceholder())
              : const SizedBox.shrink()),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x28FFFFFF)),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9185E9)),
        ),
      ),
    );
  }
}
