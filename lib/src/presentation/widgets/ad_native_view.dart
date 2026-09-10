import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/models/ad_native_template.dart';
import '../../domain/models/ad_placement.dart';
import '../admob_kit_facade.dart';

/// Zero-CLS (Cumulative Layout Shift) container for Native ads.
///
/// Automatically collapses to [SizedBox.shrink] if the user is premium.
/// Layout dimensions and native view factory bindings are governed by the
/// [NativeAdTemplate] enum ([NativeAdTemplate.big], [NativeAdTemplate.medium], [NativeAdTemplate.small]).
class AdNativeView extends StatefulWidget {
  /// The type-safe native placement descriptor.
  final NativePlacement placement;

  /// The optional template override ([NativeAdTemplate.big], [NativeAdTemplate.medium], [NativeAdTemplate.small]).
  ///
  /// Defaults to the placement template or [NativeAdTemplate.medium].
  final NativeAdTemplate? template;

  /// The optional height override.
  ///
  /// Defaults to [NativeAdTemplate.height].
  final double? height;

  /// The optional width override.
  ///
  /// Defaults to [NativeAdTemplate.width].
  final double? width;

  /// The optional custom placeholder rendered while the ad buffer is filling.
  final Widget? placeholder;

  /// Whether to render a styled placeholder while the ad is loading.
  ///
  /// Defaults to `true`.
  final bool showPlaceholder;

  /// Creates an [AdNativeView] with optional size and template overrides.
  const AdNativeView({
    super.key,
    required this.placement,
    this.template,
    this.height,
    this.width,
    this.placeholder,
    this.showPlaceholder = true,
  });

  /// Creates an [AdNativeView] explicitly bound to a [NativeAdTemplate].
  AdNativeView.templated({
    super.key,
    required this.placement,
    required NativeAdTemplate this.template,
    this.placeholder,
    this.showPlaceholder = true,
  })  : height = template.height,
        width = template.width;

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
    if (AdmobKit.isUserPremium) {
      setState(() => _isLoading = false);
      return;
    }

    final cached = AdmobKit.leaseInlineAd(widget.placement);
    if (cached is NativeAd) {
      setState(() {
        _nativeAd = cached;
        _isLoading = false;
      });
    } else {
      AdmobKit.pool?.preload(widget.placement).then((_) {
        if (!mounted) return;
        final newlyLoaded = AdmobKit.leaseInlineAd(widget.placement);
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

  NativeAdTemplate get _effectiveTemplate =>
      widget.template ?? widget.placement.template ?? NativeAdTemplate.medium;

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height ?? _effectiveTemplate.height,
      width: widget.width ?? _effectiveTemplate.width,
      child: _nativeAd != null
          ? AdWidget(ad: _nativeAd!)
          : (_isLoading && widget.showPlaceholder
              ? (widget.placeholder ?? _buildDefaultPlaceholder(context))
              : const SizedBox.shrink()),
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0x28FFFFFF) : const Color(0xFFE2E8F0),
        ),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDark ? const Color(0xFF9185E9) : const Color(0xFF4338CA),
          ),
        ),
      ),
    );
  }
}
