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
///
/// Deferred loading: ad loads are gated on [TickerMode] (route coverage via
/// Overlay) **and** [Visibility] (e.g. hidden `IndexedStack` tabs). A tab
/// inside an `IndexedStack` defers its ad request until switched to. Custom
/// tab containers that neither gate must be wrapped in `TickerMode` or
/// `Visibility` explicitly to opt into deferral.
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
  bool _hasAttemptedLoad = false;
  bool _leasePending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndActivate();
  }

  @override
  void didUpdateWidget(AdNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement.id != widget.placement.id) {
      _nativeAd?.dispose();
      _nativeAd = null;
      _isLoading = true;
      _hasAttemptedLoad = false;
      _checkAndActivate();
    }
  }

  void _checkAndActivate() {
    if (!_isSubtreeActive && _nativeAd == null && !_leasePending) {
      // Deactivated with nothing loaded or settled (e.g. prior offline
      // failure): reset so reactivating this tab retries the lease instead of
      // staying blank. Skipped while a lease is still in-flight.
      _hasAttemptedLoad = false;
    } else if (_isSubtreeActive && _nativeAd == null && !_hasAttemptedLoad) {
      _loadNative();
    }
  }

  void _loadNative() {
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
        if (ad is NativeAd) ad.dispose();
        return;
      }
      setState(() {
        _nativeAd = ad is NativeAd ? ad : null;
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
    _nativeAd?.dispose();
    super.dispose();
  }

  /// Deferred-loading gate: active only when the subtree both animates
  /// (TickerMode, e.g. route coverage) and is visible (Visibility, e.g.
  /// IndexedStack hidden tabs). Plain screens satisfy both by default.
  bool get _isSubtreeActive =>
      TickerMode.valuesOf(context).enabled && Visibility.of(context);

  NativeAdTemplate get _effectiveTemplate =>
      widget.template ?? widget.placement.template ?? NativeAdTemplate.medium;

  @override
  Widget build(BuildContext context) {
    if (AdmobKit.isUserPremium) {
      return const SizedBox.shrink();
    }

    final isSubtreeActive = _isSubtreeActive;

    // Preserves zero CLS layout bounds while offstage without mounting native platform view
    if (!isSubtreeActive && _nativeAd == null) {
      return SizedBox(
        height: widget.height ?? _effectiveTemplate.height,
        width: widget.width ?? _effectiveTemplate.width,
        child: widget.placeholder ?? const SizedBox.shrink(),
      );
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
