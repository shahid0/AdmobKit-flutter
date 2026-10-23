/// Google AdMob ads for Flutter with consent-aware loading, adaptive and fixed banners,
/// optional banner space reservation, native templates, fullscreen presentation
/// and live native styling.
library;

export 'src/domain/ad_placements.dart' hide AdRequestKey;
export 'src/domain/ad_telemetry.dart'
    show
        AdLogLevel,
        AdRevenuePrecision,
        AdRevenueValue,
        AdDiagnosticEventType,
        AdDiagnosticReport,
        AdAnalyticsTracker,
        AdDiagnosticsTracker;
export 'src/domain/ad_network.dart'
    show AdNetworkType, AdTimeoutPolicy, AdTimeoutConfig;

export 'src/presentation/admob_kit_facade.dart' show AdmobKit;
export 'src/presentation/widgets/ad_banner_view.dart' show AdBannerView;
export 'src/presentation/widgets/ad_native_view.dart' show AdNativeView;
export 'src/presentation/widgets/ad_paywall_guard.dart' show AdPaywallGuard;
export 'src/presentation/config/admob_kit_config.dart';

export 'src/infrastructure/consent/consent_coordinator.dart'
    show ConsentTestConfig;
export 'package:google_mobile_ads/google_mobile_ads.dart' show DebugGeography;
