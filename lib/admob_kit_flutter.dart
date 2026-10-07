/// Google AdMob ads for Flutter with consent-aware loading, adaptive banners,
/// native templates, fullscreen presentation and live native styling.
library;

export 'src/domain/models/native_ad_style.dart';

export 'src/domain/models/banner_layout.dart';
export 'src/domain/models/banner_sizing.dart';

export 'src/presentation/admob_kit_facade.dart' show AdmobKit;
export 'src/presentation/widgets/ad_banner_view.dart' show AdBannerView;
export 'src/presentation/widgets/ad_native_view.dart' show AdNativeView;
export 'src/presentation/widgets/ad_paywall_guard.dart' show AdPaywallGuard;
export 'src/presentation/config/admob_kit_config.dart';

export 'src/domain/models/ad_format.dart';
export 'src/domain/models/ad_priority.dart';
export 'src/domain/models/ad_revenue_value.dart';
export 'src/domain/models/ad_placement.dart';
export 'src/domain/models/ad_native_template.dart';
export 'src/domain/models/admob_test_ids.dart';
export 'src/domain/models/ad_timeout_config.dart';
export 'src/domain/models/diagnostic_report.dart';
export 'src/domain/models/ad_placement_state.dart';
export 'src/domain/models/ad_initialization_state.dart';

export 'src/domain/contracts/ad_analytics_tracker.dart';
export 'src/domain/contracts/ad_diagnostics_tracker.dart';
export 'src/domain/contracts/ad_logger.dart' show AdLogLevel;
export 'src/domain/contracts/ad_network_info.dart' show AdNetworkType;

export 'src/infrastructure/consent/consent_coordinator.dart' show ConsentTestConfig;
export 'package:google_mobile_ads/google_mobile_ads.dart' show DebugGeography;
