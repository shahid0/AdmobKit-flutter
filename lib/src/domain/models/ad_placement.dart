import 'package:flutter/foundation.dart';
import 'ad_format.dart';
import 'ad_native_template.dart';
import 'ad_priority.dart';

/// Base class representing a type-safe ad placement configuration.
@immutable
sealed class AdPlacement {
  /// The unique placement identifier.
  final String id;

  /// The AdMob Ad Unit ID for Android.
  final String androidId;

  /// The AdMob Ad Unit ID for iOS.
  final String iosId;

  /// The ad format (interstitial, rewarded, banner, native, app open).
  final AdFormat format;

  /// The initial priority tier for queue dispatching.
  final AdPriority priority;

  /// Whether this ad is only loaded once and never replenished post-dismissal.
  final bool loadOnce;

  /// Whether this placement is part of the splash screen loading sequence.
  final bool isSplash;

  /// Creates a base [AdPlacement] configuration.
  const AdPlacement({
    required this.id,
    required this.androidId,
    required this.iosId,
    required this.format,
    required this.priority,
    this.loadOnce = false,
    this.isSplash = false,
  });

  /// Resolves the unit ID for the target platform.
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
  /// Creates a [FullscreenPlacement] configuration.
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
  /// Creates an [InlinePlacement] configuration.
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
  /// Creates an [InterstitialPlacement] with the specified unit IDs and options.
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
          priority: priority ?? (isSplash ? AdPriority.splash : AdPriority.high),
        );
}

/// Type-safe placement descriptor for Rewarded ads.
class RewardedPlacement extends FullscreenPlacement {
  /// Creates a [RewardedPlacement] with the specified unit IDs and options.
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
  /// Creates a [RewardedInterstitialPlacement] with the specified unit IDs and options.
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
  /// Creates an [AppOpenPlacement] with the specified unit IDs and options.
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
          priority: priority ?? (isSplash ? AdPriority.splash : AdPriority.high),
        );
}

/// Type-safe placement descriptor for Banner ads.
class BannerPlacement extends InlinePlacement {
  /// Creates a [BannerPlacement] with the specified unit IDs and options.
  const BannerPlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    AdPriority? priority,
    super.isSplash = false,
    super.loadOnce = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.banner,
          priority: priority ?? (isSplash ? AdPriority.splash : AdPriority.medium),
        );
}

/// Type-safe placement descriptor for Native ads.
class NativePlacement extends InlinePlacement {
  /// The optional native ad factory ID registered on Android / iOS.
  final String? factoryId;

  /// The associated template type if using standard templates.
  final NativeAdTemplate? template;

  /// Creates a [NativePlacement] with the specified unit IDs, template, or custom factory.
  const NativePlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    this.factoryId,
    this.template,
    AdPriority? priority,
    super.isSplash = false,
    super.loadOnce = false,
  }) : super(
          id: id ?? androidId,
          format: AdFormat.native,
          priority: priority ?? (isSplash ? AdPriority.splash : AdPriority.medium),
        );

  /// Convenience constructor for the Big Native Ad template (`bigNativeAd`).
  const NativePlacement.big({
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool isSplash = false,
    bool loadOnce = false,
  }) : this(
          id: id,
          androidId: androidId,
          iosId: iosId,
          factoryId: 'bigNativeAd',
          template: NativeAdTemplate.big,
          priority: priority,
          isSplash: isSplash,
          loadOnce: loadOnce,
        );

  /// Convenience constructor for the Medium Native Ad template (`listTileMedium`).
  const NativePlacement.medium({
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool isSplash = false,
    bool loadOnce = false,
  }) : this(
          id: id,
          androidId: androidId,
          iosId: iosId,
          factoryId: 'listTileMedium',
          template: NativeAdTemplate.medium,
          priority: priority,
          isSplash: isSplash,
          loadOnce: loadOnce,
        );

  /// Convenience constructor for the Small Native Ad template (`smallNativeAd`).
  const NativePlacement.small({
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool isSplash = false,
    bool loadOnce = false,
  }) : this(
          id: id,
          androidId: androidId,
          iosId: iosId,
          factoryId: 'smallNativeAd',
          template: NativeAdTemplate.small,
          priority: priority,
          isSplash: isSplash,
          loadOnce: loadOnce,
        );
}
