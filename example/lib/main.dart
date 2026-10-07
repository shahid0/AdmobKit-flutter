import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'config/sample_ads.dart';
import 'screens/splash_screen.dart';
import 'state/task_store.dart';
import 'theme/task_theme.dart';

export 'config/sample_ads.dart';

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
    _record(
      '💰 [Analytics] Revenue Paid Event -> ${placement.id} | '
      '${revenue.value.toStringAsFixed(6)} ${revenue.currencyCode} (${revenue.micros} micros)',
    );
  }
}

class PrintingDiagnosticsTracker implements AdDiagnosticsTracker {
  final void Function(String log)? onLog;

  const PrintingDiagnosticsTracker({this.onLog});

  @override
  void onDiagnosticReport(AdDiagnosticReport report) {
    final msg =
        '🔍 [Diagnostics] [${report.eventType.name.toUpperCase()}] '
        'Placement: ${report.placementId} | Network: ${report.networkType} | '
        'Elapsed: ${report.elapsed.inMilliseconds}ms'
        '${report.admobErrorCode != null ? " | Code: ${report.admobErrorCode}" : ""}'
        '${report.admobErrorMessage != null ? " | Error: ${report.admobErrorMessage}" : ""}';
    debugPrint(msg);
    onLog?.call(msg);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final boot = AdmobKit.initialize(
    config: AdmobKitConfig(
      timeouts: AdTimeoutConfig.standard,
      isPremium: () => TaskStore.instance.isPremium,
      analytics: PrintingAnalyticsTracker(onLog: TaskStore.instance.appendLog),
      diagnostics: PrintingDiagnosticsTracker(onLog: TaskStore.instance.appendLog),
      testDeviceIds: const ['5836268AE16674B51B1B19E62E1B3401'],
      nativeStyle: const NativeAdStyle(
        background: 0xFFFFFFFF,
        headline: 0xFF0F172A,
        body: 0xFF475569,
        callToActionBackground: 0xFF4338CA,
        callToActionText: 0xFFFFFFFF,
        callToActionCornerRadius: 8,
      ),
    ),
  );

  AdmobKit.registerPlacements(SampleAds.allPlacements, placementCapacities: {'multi_widget_showcase': 2});

  runApp(const TaskFlowApp());
  try {
    await boot;
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    TaskStore.instance.appendLog('Ad initialization failed: $error');
  }
}

class TaskFlowApp extends StatefulWidget {
  const TaskFlowApp({super.key});

  @override
  State<TaskFlowApp> createState() => _TaskFlowAppState();
}

class _TaskFlowAppState extends State<TaskFlowApp> with WidgetsBindingObserver {
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!AdmobKit.isShowingAd) {
        _wasInBackground = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_wasInBackground) return;
      _wasInBackground = false;

      if (SplashScreen.isSplashActive) return;
      if (AdmobKit.isShowingAd) return;

      TaskStore.instance.appendLog('📱 [Lifecycle] App resumed from background. Showing App Open ad...');
      AdmobKit.show(SampleAds.appOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow Pro',
      debugShowCheckedModeBanner: false,
      theme: TaskTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
