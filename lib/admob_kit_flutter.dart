/// Production-grade Google AdMob plugin for Flutter with instant 0ms display,
/// UMP GDPR consent, zero-CLS native ad templates, banners, interstitials,
/// and rewarded ads.
library;

export 'src/presentation/admob_kit_facade.dart';
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

export 'src/domain/contracts/ad_analytics_tracker.dart';
export 'src/domain/contracts/ad_diagnostics_tracker.dart';
export 'src/domain/contracts/ad_logger.dart';
export 'src/domain/contracts/ad_network_info.dart';

export 'src/infrastructure/consent/consent_coordinator.dart' show ConsentTestConfig;

export 'src/presentation/widgets/ad_banner_view.dart';
export 'src/presentation/widgets/ad_native_view.dart';
export 'src/presentation/widgets/ad_paywall_guard.dart';
