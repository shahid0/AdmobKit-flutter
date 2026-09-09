import 'package:flutter/foundation.dart';
import 'ad_format.dart';
import 'ad_native_template.dart';
import 'ad_priority.dart';

/// Base class representing a type-safe ad placement configuration.
@immutable
sealed class AdPlacement {
  /// Unique placement identifier.
  final String id;

  /// AdMob Ad Unit ID for Android.
  final String androidId;

  /// AdMob Ad Unit ID for iOS.
  final String iosId;

  /// Ad format (interstitial, rewarded, banner, native, app open).
  final AdFormat format;

  /// Initial priority tier for queue dispatching.
  final AdPriority priority;

  /// If true, this ad is only loaded once and never replenished post-dismissal.
  final bool loadOnce;

  /// If true, this placement is part of the splash screen loading sequence.
  final bool isSplash;

  const AdPlacement({
    required this.id,
    required this.androidId,
    required this.iosId,
    required this.format,
    required this.priority,
    this.loadOnce = false,
    this.isSplash = false,
  });

  /// Resolves unit ID for the target platform.
  String getUnitId({required bool isAndroid}) => isAndroid ? androidId : iosId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdPlacement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$runtimeType(id: $id, format: ${format.name}, priority: ${priority.name})';
}

/// Base sealed class for full-screen placements (Interstitial, Rewarded, AppOpen).
sealed class FullscreenPlacement extends AdPlacement {
  const FullscreenPlacement({
    required super.id,
    required super.androidId,
    required super.iosId,
    required super.format,
    required super.priority,
    super.loadOnce,
    super.isSplash,
  });
}

/// Base sealed class for inline layout placements (Banner, Native).
sealed class InlinePlacement extends AdPlacement {
  const InlinePlacement({
    required super.id,
    required super.androidId,
    required super.iosId,
    required super.format,
    required super.priority,
    super.loadOnce,
    super.isSplash,
  });
}

/// Type-safe placement descriptor for Interstitial ads.
class InterstitialPlacement extends FullscreenPlacement {
  const InterstitialPlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    AdPriority? priority,
    super.loadOnce = false,
    super.isSplash = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.interstitial,
          priority: priority ?? (isSplash ? AdPriority.splashFullscreen : AdPriority.high),
        );
}

/// Type-safe placement descriptor for Rewarded ads.
class RewardedPlacement extends FullscreenPlacement {
  const RewardedPlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    super.priority = AdPriority.medium,
    super.loadOnce = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.rewarded,
          isSplash: false,
        );
}

/// Type-safe placement descriptor for Rewarded Interstitial ads.
class RewardedInterstitialPlacement extends FullscreenPlacement {
  const RewardedInterstitialPlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    super.priority = AdPriority.medium,
    super.loadOnce = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.rewardedInterstitial,
          isSplash: false,
        );
}

/// Type-safe placement descriptor for App Open ads.
class AppOpenPlacement extends FullscreenPlacement {
  const AppOpenPlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    AdPriority? priority,
    super.loadOnce = false,
    super.isSplash = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.appOpen,
          priority: priority ?? (isSplash ? AdPriority.splashFullscreen : AdPriority.high),
        );
}

/// Type-safe placement descriptor for Banner ads.
class BannerPlacement extends InlinePlacement {
  const BannerPlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    AdPriority? priority,
    super.isSplash = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.banner,
          priority: priority ?? (isSplash ? AdPriority.immediate : AdPriority.medium),
          loadOnce: false,
        );
}

/// Type-safe placement descriptor for Native ads.
class NativePlacement extends InlinePlacement {
  /// Optional native ad factory ID registered on Android / iOS.
  final String? factoryId;

  /// Associated template type if using standard templates.
  final NativeAdTemplate? template;

  const NativePlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    this.factoryId,
    this.template,
    AdPriority? priority,
    super.isSplash = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.native,
          priority: priority ?? (isSplash ? AdPriority.immediate : AdPriority.medium),
          loadOnce: false,
        );

  /// Convenience constructor for the Big Native Ad template (`bigNativeAd`).
  const NativePlacement.big({
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool isSplash = false,
  }) : this(
          id: id,
          androidId: androidId,
          iosId: iosId,
          factoryId: 'bigNativeAd',
          template: NativeAdTemplate.big,
          priority: priority,
          isSplash: isSplash,
        );

  /// Convenience constructor for the Medium Native Ad template (`listTileMedium`).
  const NativePlacement.medium({
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool isSplash = false,
  }) : this(
          id: id,
          androidId: androidId,
          iosId: iosId,
          factoryId: 'listTileMedium',
          template: NativeAdTemplate.medium,
          priority: priority,
          isSplash: isSplash,
        );

  /// Convenience constructor for the Small Native Ad template (`smallNativeAd`).
  const NativePlacement.small({
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool isSplash = false,
  }) : this(
          id: id,
          androidId: androidId,
          iosId: iosId,
          factoryId: 'smallNativeAd',
          template: NativeAdTemplate.small,
          priority: priority,
          isSplash: isSplash,
        );
}
