import 'package:flutter/foundation.dart';

/// Supported Google AdMob formats.
enum AdFormat {
  interstitial,
  rewarded,
  rewardedInterstitial,
  banner,
  native,
  appOpen;

  /// Whether this format is presented as a full-screen modal overlay.
  bool get isFullscreen =>
      this == interstitial ||
      this == rewarded ||
      this == rewardedInterstitial ||
      this == appOpen;

  /// Whether this format is embedded directly within the Flutter widget tree.
  bool get isInline => this == banner || this == native;
}

/// Priority tier determining queue dispatch order.
enum AdPriority {
  /// Highest priority. Dispatched immediately, preempting all other pending requests.
  immediate(0),

  /// Reserved for splash screen ads. Preempts standard background preloading.
  splash(1),

  /// High priority. Dispatched before medium and low priority requests.
  high(2),

  /// Default priority for most preloaded ads.
  medium(3),

  /// Low priority background replenishment tasks.
  low(4);

  final int _rank;
  const AdPriority(this._rank);

  /// Returns true if this priority tier is higher than or equal to [other].
  bool operator <=(AdPriority other) => _rank <= other._rank;

  /// Numerical rank of this tier (0 = highest, 4 = lowest).
  int get rank => _rank;
}

/// Lifecycle state of an ad placement within the eager preloading pool.
enum AdPlacementState {
  /// The placement has not yet been enqueued or requested.
  unloaded,

  /// The placement is currently in-flight downloading in the priority queue.
  loading,

  /// The placement is primed in memory and ready for instant 0ms presentation.
  ready,

  /// The placement failed to load (network error, timeout, or no-fill)
  /// and is awaiting autonomous exponential backoff retry.
  error,
}

/// Overall initialization and consent status of AdmobKit.
enum AdInitializationState {
  /// Neither consent nor SDK initialization has started.
  uninitialized,

  /// Currently requesting consent via Google UMP and/or Apple ATT.
  gatheringConsent,

  /// Consent resolved; currently initializing Google Mobile Ads native SDK.
  initializingSdk,

  /// Consent and SDK are ready; ads may be requested.
  ready,

  /// Actively updating consent via privacy options form.
  updatingConsent,

  /// Consent was denied by the user or is unavailable.
  consentDenied,

  /// Initialization failed due to a fatal error.
  failed,

  /// AdmobKit has been disposed.
  disposed;

  /// Whether ads can potentially be loaded in this state.
  bool get isReady => this == ready;
}

/// Device orientation used when resolving an adaptive banner layout.
enum BannerOrientation { portrait, landscape }

/// Edge where an expanded collapsible banner aligns with its collapsed banner.
enum CollapsibleAnchor {
  top('top'),
  bottom('bottom');

  final String value;
  const CollapsibleAnchor(this.value);
}

/// Available logical width and device orientation for a banner host.
final class BannerLayout {
  final int width;
  final BannerOrientation orientation;

  const BannerLayout({required this.width, required this.orientation})
    : assert(width > 0);

  void validate() {
    if (width <= 0) {
      throw ArgumentError.value(
        width,
        'width',
        'Must be positive logical pixels',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BannerLayout &&
      width == other.width &&
      orientation == other.orientation;

  @override
  int get hashCode => Object.hash(width, orientation);

  @override
  String toString() => '${width}dp/${orientation.name}';
}

/// SDK sizing policy for adaptive or fixed banners, in logical pixels.
///
/// Inline adaptive and fixed banners reserve their configured height by default.
/// Set [reserveSpace] to false to collapse the host until an ad size is available.
@immutable
final class BannerSizing {
  /// Maximum SDK creative height for inline adaptive banners; otherwise null.
  final int? maxHeight;

  /// Requested fixed dimensions; null for adaptive banners.
  final int? fixedWidth;
  final int? fixedHeight;

  /// Whether the host reserves the configured height before and after loading.
  final bool reserveSpace;

  /// Resolves width and height through the SDK without reserving loading space.
  const factory BannerSizing.anchoredAdaptive() = _AnchoredAdaptiveBannerSizing;

  const BannerSizing._anchoredAdaptive()
    : maxHeight = null,
      fixedWidth = null,
      fixedHeight = null,
      reserveSpace = false;

  /// Resolves an adaptive creative up to [maxHeight] (at least 32 pixels).
  // The argument is non-nullable; null is reserved for other sizing modes.
  // ignore: prefer_initializing_formals
  const BannerSizing.inlineAdaptive({
    required int maxHeight,
    this.reserveSpace = true,
  }) : assert(maxHeight >= 32),
       maxHeight = maxHeight,
       fixedWidth = null,
       fixedHeight = null;

  /// Requests exact positive [width] and [height] without adaptive calculation.
  const BannerSizing.fixed({
    required int width,
    required int height,
    this.reserveSpace = true,
  }) : assert(width > 0),
       assert(height > 0),
       fixedWidth = width,
       fixedHeight = height,
       maxHeight = null;

  /// Standard 320×50 banner.
  const BannerSizing.standard({bool reserveSpace = true})
    : this.fixed(width: 320, height: 50, reserveSpace: reserveSpace);

  /// Medium rectangle, 300×250.
  const BannerSizing.mediumRectangle({bool reserveSpace = true})
    : this.fixed(width: 300, height: 250, reserveSpace: reserveSpace);

  /// Alias for [BannerSizing.mediumRectangle].
  const BannerSizing.mrec({bool reserveSpace = true})
    : this.mediumRectangle(reserveSpace: reserveSpace);

  /// Large 320×100 banner.
  const BannerSizing.large({bool reserveSpace = true})
    : this.fixed(width: 320, height: 100, reserveSpace: reserveSpace);

  /// Alias for [BannerSizing.large].
  const BannerSizing.largeBanner({bool reserveSpace = true})
    : this.large(reserveSpace: reserveSpace);

  /// Leaderboard, 728×90. The host must be wide enough to display it.
  const BannerSizing.leaderboard({bool reserveSpace = true})
    : this.fixed(width: 728, height: 90, reserveSpace: reserveSpace);

  bool get isFixed => fixedWidth != null;
  bool get isAdaptive => !isFixed;
  bool get isInline => maxHeight != null;

  /// Validates dimensions without relying on debug-only assertions.
  void validate() {
    if (maxHeight != null && maxHeight! < 32) {
      throw ArgumentError.value(
        maxHeight,
        'maxHeight',
        'Must be at least 32 logical pixels',
      );
    }
    if (fixedWidth != null && fixedWidth! <= 0) {
      throw ArgumentError.value(
        fixedWidth,
        'width',
        'Must be positive logical pixels',
      );
    }
    if (fixedHeight != null && fixedHeight! <= 0) {
      throw ArgumentError.value(
        fixedHeight,
        'height',
        'Must be positive logical pixels',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BannerSizing &&
      maxHeight == other.maxHeight &&
      fixedWidth == other.fixedWidth &&
      fixedHeight == other.fixedHeight &&
      reserveSpace == other.reserveSpace;

  @override
  int get hashCode =>
      Object.hash(maxHeight, fixedWidth, fixedHeight, reserveSpace);

  @override
  String toString() {
    if (isFixed) {
      return 'BannerSizing.fixed(width: $fixedWidth, height: $fixedHeight, reserveSpace: $reserveSpace)';
    }
    if (isInline) {
      return 'BannerSizing.inlineAdaptive(maxHeight: $maxHeight, reserveSpace: $reserveSpace)';
    }
    return 'BannerSizing.anchoredAdaptive()';
  }
}

// A type check is const-safe; reading sizing getters in a const placement's
// assertion is not. Keep the anchored mode identifiable without exposing a type.
final class _AnchoredAdaptiveBannerSizing extends BannerSizing {
  const _AnchoredAdaptiveBannerSizing() : super._anchoredAdaptive();
}

/// Request compatibility key; policy and analytics remain placement-scoped.
typedef AdRequestKey = ({
  String placementId,
  BannerLayout? bannerLayout,
  CollapsibleAnchor? collapsible,
});

/// Built-in native compositions, shared by Android and iOS.
enum NativeAdTemplate {
  /// Leading icon, identity, and trailing CTA on the same row.
  rowWithLeadingIcon(height: 80),

  /// Identity, trailing icon, and trailing CTA on the same row.
  rowWithTrailingIcon(height: 80),

  /// Leading CTA, icon, and identity on the same row.
  rowLeadingCta(height: 80),

  /// Compact media on the left, beside identity, metadata and action.
  splitMediaLeft(height: 160),

  /// Compact identity, metadata and action beside media on the right.
  splitMediaRight(height: 160),

  /// Identity above a full-width action.
  cardContentTop(height: 132),

  /// Full-width action above identity.
  cardActionTop(height: 132),

  /// Identity with a trailing icon, above a full-width action.
  cardContentTopTrailingIcon(height: 132),

  /// Hero media, identity, then a full-width action.
  feedMediaFirst(height: 340),

  /// Identity, hero media, then a full-width action.
  feedContentFirst(height: 340),

  /// Identity, full-width action, then hero media.
  feedActionMiddle(height: 340),

  /// Trailing-icon identity, hero media, then a full-width action.
  feedTrailingIcon(height: 340),

  /// Hero media above a leading-icon identity row with a trailing CTA.
  feedMediaTopSideCta(height: 280),

  /// Leading-icon identity row with a trailing CTA above hero media.
  feedContentTopSideCta(height: 280),

  /// Bounded hero media, identity, then a full-width action.
  fullscreenMediaFirst(height: 320, isFullscreen: true),

  /// Identity, bounded hero media, then a full-width action.
  fullscreenContentFirst(height: 320, isFullscreen: true),

  /// Identity, full-width action, then bounded hero media.
  fullscreenActionMiddle(height: 320, isFullscreen: true),

  /// Bounded hero media, trailing-icon identity, then a full-width action.
  fullscreenTrailingIcon(height: 320, isFullscreen: true),

  /// Bounded hero media above a leading-icon identity row with a trailing CTA.
  fullscreenMediaSideCta(height: 320, isFullscreen: true);

  static const compactRow = rowWithLeadingIcon;
  static const smartMedia = splitMediaLeft;
  static const stackedCard = cardContentTop;
  static const feedCard = feedMediaFirst;
  static const fullscreen = fullscreenMediaFirst;

  /// Initial loading estimate for inline hosts, not a fixed content height.
  final double height;

  /// Fills bounded host height and participates in exclusive presentation.
  final bool isFullscreen;

  /// Minimum supported logical width. Smaller hosts must choose another location.
  double get minWidth => 320;

  /// Factory identifier shared with the native catalog.
  String get factoryId => 'admobKit.$name';

  const NativeAdTemplate({required this.height, this.isFullscreen = false});
}

/// Optional appearance overrides for the built-in native templates.
///
/// Use 0xAARRGGBB values (or Flutter Color.toARGB32()). Null inherits the next
/// level: placement overrides → global style → the template's own defaults.
final class NativeAdStyle {
  final int? background;
  final int? headline;
  final int? body;
  final int? callToActionBackground;
  final int? callToActionText;
  final double? callToActionCornerRadius;

  const NativeAdStyle({
    this.background,
    this.headline,
    this.body,
    this.callToActionBackground,
    this.callToActionText,
    this.callToActionCornerRadius,
  });

  @override
  bool operator ==(Object other) =>
      other is NativeAdStyle &&
      background == other.background &&
      headline == other.headline &&
      body == other.body &&
      callToActionBackground == other.callToActionBackground &&
      callToActionText == other.callToActionText &&
      callToActionCornerRadius == other.callToActionCornerRadius;

  @override
  int get hashCode => Object.hash(
    background,
    headline,
    body,
    callToActionBackground,
    callToActionText,
    callToActionCornerRadius,
  );

  /// Validates without relying on debug-only assertions.
  void validate() {
    for (final value in [
      background,
      headline,
      body,
      callToActionBackground,
      callToActionText,
    ]) {
      if (value != null && (value < 0 || value > 0xffffffff)) {
        throw ArgumentError.value(
          value,
          'color',
          'Expected an unsigned 32-bit ARGB value.',
        );
      }
    }
    final radius = callToActionCornerRadius;
    if (radius != null && (!radius.isFinite || radius < 0)) {
      throw ArgumentError.value(
        radius,
        'callToActionCornerRadius',
        'Expected a finite non-negative radius.',
      );
    }
  }

  /// Resolves this level over inherited style; null still means template default.
  NativeAdStyle over(NativeAdStyle inherited) => NativeAdStyle(
    background: background ?? inherited.background,
    headline: headline ?? inherited.headline,
    body: body ?? inherited.body,
    callToActionBackground:
        callToActionBackground ?? inherited.callToActionBackground,
    callToActionText: callToActionText ?? inherited.callToActionText,
    callToActionCornerRadius:
        callToActionCornerRadius ?? inherited.callToActionCornerRadius,
  );
}

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

  /// Disables background replenishment after consumption.
  final bool loadOnce;

  /// Whether this placement is part of the splash screen loading sequence.
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
  String toString() =>
      '$runtimeType(id: $id, format: ${format.name}, priority: ${priority.name})';
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
         priority: priority ?? (isSplash ? AdPriority.splash : AdPriority.high),
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
  }) : super(id: id ?? androidId, format: AdFormat.rewarded, isSplash: false);
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
         priority: priority ?? (isSplash ? AdPriority.splash : AdPriority.high),
       );
}

/// Type-safe placement descriptor for Banner ads.
class BannerPlacement extends InlinePlacement {
  final BannerSizing sizing;

  /// Requests a collapsible overlay for an anchored adaptive banner.
  final CollapsibleAnchor? collapsible;

  bool get isCollapsible => collapsible != null;

  const BannerPlacement({
    this.sizing = const BannerSizing.anchoredAdaptive(),
    this.collapsible,
    String? id,
    required super.androidId,
    required super.iosId,
    AdPriority? priority,
    super.isSplash = false,
    super.loadOnce = false,
  }) : assert(
         collapsible == null || sizing is _AnchoredAdaptiveBannerSizing,
         'Collapsible banners require anchored adaptive sizing.',
       ),
       super(
         id: id ?? androidId,
         format: AdFormat.banner,
         priority:
             priority ?? (isSplash ? AdPriority.splash : AdPriority.medium),
       );

  const BannerPlacement.collapsible({
    CollapsibleAnchor anchor = CollapsibleAnchor.bottom,
    String? id,
    required String androidId,
    required String iosId,
    AdPriority? priority,
    bool loadOnce = false,
  }) : this(
         id: id,
         androidId: androidId,
         iosId: iosId,
         sizing: const BannerSizing.anchoredAdaptive(),
         collapsible: anchor,
         priority: priority,
         loadOnce: loadOnce,
       );

  /// Validates banner configuration without relying on debug-only assertions.
  void validate() {
    sizing.validate();
    if (isCollapsible && (sizing.isFixed || sizing.isInline)) {
      throw ArgumentError(
        'Collapsible banners require anchored adaptive sizing.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BannerPlacement &&
      super == other &&
      sizing == other.sizing &&
      collapsible == other.collapsible;

  @override
  int get hashCode => Object.hash(super.hashCode, sizing, collapsible);
}

/// Type-safe placement for one built-in native template, mounted with AdNativeView.
class NativePlacement extends InlinePlacement {
  final NativeAdStyle style;
  final NativeAdTemplate template;

  const NativePlacement({
    String? id,
    required super.androidId,
    required super.iosId,
    this.template = NativeAdTemplate.cardContentTop,
    this.style = const NativeAdStyle(),
    AdPriority? priority,
    super.isSplash = false,
    super.loadOnce = false,
  }) : super(
         id: id ?? androidId,
         format: AdFormat.native,
         priority:
             priority ?? (isSplash ? AdPriority.splash : AdPriority.medium),
       );
}

/// Official Google AdMob sample test ad unit IDs.
abstract final class AdMobTestIds {
  static const bannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const bannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const interstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const interstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const rewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const rewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const rewardedInterstitialAndroid =
      'ca-app-pub-3940256099942544/5354046379';
  static const rewardedInterstitialIos =
      'ca-app-pub-3940256099942544/6978759866';
  static const nativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const nativeIos = 'ca-app-pub-3940256099942544/3986624511';
  static const appOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const appOpenIos = 'ca-app-pub-3940256099942544/5575463023';
}
