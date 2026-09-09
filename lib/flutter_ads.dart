library;

// Facade & Configuration
export 'src/presentation/flutter_ads_facade.dart';
export 'src/presentation/config/flutter_ads_config.dart';

// Domain Models & Placements
export 'src/domain/models/ad_format.dart';
export 'src/domain/models/ad_priority.dart';
export 'src/domain/models/ad_revenue_value.dart';
export 'src/domain/models/ad_placement.dart';
export 'src/domain/models/ad_native_template.dart';
export 'src/domain/models/admob_test_ids.dart';
export 'src/domain/models/ad_timeout_config.dart';
export 'src/domain/models/diagnostic_report.dart';

// Domain Contracts
export 'src/domain/contracts/ad_analytics_tracker.dart';
export 'src/domain/contracts/ad_diagnostics_tracker.dart';
export 'src/domain/contracts/ad_logger.dart';
export 'src/domain/contracts/ad_network_info.dart';

// Consent Infrastructure
export 'src/infrastructure/consent/consent_coordinator.dart' show ConsentTestConfig;

// Presentation Widgets & Lifecycle
export 'src/presentation/widgets/ad_banner_view.dart';
export 'src/presentation/widgets/ad_native_view.dart';
export 'src/presentation/widgets/ad_paywall_guard.dart';
export 'src/presentation/lifecycle/flutter_ads_route_observer.dart';
