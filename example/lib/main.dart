import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'config/sample_ads.dart';
import 'screens/splash_screen.dart';
import 'state/task_store.dart';

export 'config/sample_ads.dart';

// ============================================================================
// 1. Production Analytics DI Implementation (Console + Live UI Stream)
// ============================================================================

class PrintingAnalyticsTracker implements AdAnalyticsTracker {
  final void Function(String log)? onLog;

  const PrintingAnalyticsTracker({this.onLog});

  void _record(String message) {
    debugPrint(message);
    onLog?.call(message);
  }

  @override
  void onAdRequested(AdPlacement placement) {
    _record('📊 [Analytics] Ad Requested -> ${placement.id} (${placement.format.name})');
  }

  @override
  void onAdLoaded(AdPlacement placement, Duration loadTime) {
    _record('📊 [Analytics] Ad Loaded -> ${placement.id} in ${loadTime.inMilliseconds}ms');
  }

  @override
  void onAdFailedToLoad(AdPlacement placement, String error, int? errorCode) {
    _record('📊 [Analytics] Ad Load Failed -> ${placement.id} (Code: $errorCode) | $error');
  }

  @override
  void onAdDisplayed(AdPlacement placement) {
    _record('📊 [Analytics] Ad Impression Displayed -> ${placement.id} (${placement.format.name})');
  }

  @override
  void onAdDismissed(AdPlacement placement) {
    _record('📊 [Analytics] Ad Dismissed by User -> ${placement.id}');
  }

  @override
  void onAdClicked(AdPlacement placement) {
    _record('📊 [Analytics] Ad Click Tracked -> ${placement.id}');
  }

  @override
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue) {
    _record('💰 [Analytics] Revenue Paid Event -> ${placement.id} | '
        '${revenue.value.toStringAsFixed(6)} ${revenue.currencyCode} (${revenue.micros} micros)');
  }
}

// ============================================================================
// 2. Production Diagnostics DI Implementation (Console + Live UI Stream)
// ============================================================================

class PrintingDiagnosticsTracker implements AdDiagnosticsTracker {
  final void Function(String log)? onLog;

  const PrintingDiagnosticsTracker({this.onLog});

  @override
  void onDiagnosticReport(AdDiagnosticReport report) {
    final msg = '🔍 [Diagnostics] [${report.eventType.name.toUpperCase()}] '
        'Placement: ${report.placementId} | Network: ${report.networkType} | '
        'Elapsed: ${report.elapsed.inMilliseconds}ms'
        '${report.admobErrorCode != null ? " | Code: ${report.admobErrorCode}" : ""}'
        '${report.admobErrorMessage != null ? " | Error: ${report.admobErrorMessage}" : ""}';
    debugPrint(msg);
    onLog?.call(msg);
  }
}

// ============================================================================
// 3. App Entry Point & SDK Initialization
// ============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FlutterAds at boot with full DI utilization
  await FlutterAds.initialize(
    config: FlutterAdsConfig(
      placements: SampleAds.allPlacements,
      requestConsent: false, // Set to true for GDPR/UMP in production
      timeouts: AdTimeoutConfig.standard,
      isPremium: () => TaskStore.instance.isPremium,
      analytics: PrintingAnalyticsTracker(onLog: TaskStore.instance.appendLog),
      diagnostics: PrintingDiagnosticsTracker(onLog: TaskStore.instance.appendLog),
      testDeviceIds: const ['5836268AE16674B51B1B19E62E1B3401'],
    ),
  );

  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFEC4899),
          surface: Color(0xFF14141A),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF14141A),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
