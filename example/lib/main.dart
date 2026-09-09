import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';

// ============================================================================
// 1. Production Analytics DI Implementation (Print + Live UI Stream)
// ============================================================================

/// Analytics Dependency Injection implementation.
///
/// In production, route these methods to Firebase Analytics, AppsFlyer,
/// Mixpanel, or BigQuery. Here, we format and print every event to stdout
/// and optionally broadcast to the in-app live terminal.
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
// 2. Production Diagnostics DI Implementation (Print + Live UI Stream)
// ============================================================================

/// Diagnostics Dependency Injection implementation.
///
/// In production, route these to Crashlytics, Sentry, or Datadog to capture
/// telco TCP black-holes, slow network timeouts, and queue lifecycle anomalies.
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
// 3. Self-Contained Typed Placement Definitions Using Official Test IDs
// ============================================================================

abstract final class SampleAds {
  // --- Splash Placements (demonstrates splash priority handshake) ---
  static const splashBanner = BannerPlacement(
    id: 'splash_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    isSplash: true,
  );

  static const splashInterstitial = InterstitialPlacement(
    id: 'splash_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
    isSplash: true,
    loadOnce: true,
  );

  // --- Fullscreen Placements ---
  static const mainInterstitial = InterstitialPlacement(
    id: 'main_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
  );

  static const rewardedBonus = RewardedPlacement(
    id: 'rewarded_bonus',
    androidId: AdMobTestIds.rewardedAndroid,
    iosId: AdMobTestIds.rewardedIos,
  );

  static const appOpen = AppOpenPlacement(
    id: 'app_open',
    androidId: AdMobTestIds.appOpenAndroid,
    iosId: AdMobTestIds.appOpenIos,
  );

  // --- Custom Native Ad Templates ---
  static const bigNative = NativePlacement.big(
    id: 'native_big_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const mediumNative = NativePlacement.medium(
    id: 'native_medium_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const smallNative = NativePlacement.small(
    id: 'native_small_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const allPlacements = [
    splashBanner,
    splashInterstitial,
    mainInterstitial,
    rewardedBonus,
    appOpen,
    bigNative,
    mediumNative,
    smallNative,
  ];
}

// ============================================================================
// 4. App Entry Point & Initialization
// ============================================================================

final ValueNotifier<List<String>> _liveLogNotifier = ValueNotifier<List<String>>([]);
bool _isUserPremiumGlobal = false;

void _appendLog(String line) {
  final time = DateTime.now().toIso8601String().substring(11, 19);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _liveLogNotifier.value = [
      '[$time] $line',
      ..._liveLogNotifier.value.take(49),
    ];
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FlutterAds at boot with full DI utilization
  await FlutterAds.initialize(
    config: FlutterAdsConfig(
      placements: SampleAds.allPlacements,
      requestConsent: false, // Set to true in EU/EEA production builds
      timeouts: AdTimeoutConfig.standard,
      isPremium: () => _isUserPremiumGlobal,
      analytics: PrintingAnalyticsTracker(onLog: _appendLog),
      diagnostics: PrintingDiagnosticsTracker(onLog: _appendLog),
    ),
  );

  runApp(const FlutterAdsExampleApp());
}

// ============================================================================
// 5. Example Application UI
// ============================================================================

class FlutterAdsExampleApp extends StatefulWidget {
  const FlutterAdsExampleApp({super.key});

  @override
  State<FlutterAdsExampleApp> createState() => _FlutterAdsExampleAppState();
}

class _FlutterAdsExampleAppState extends State<FlutterAdsExampleApp> {
  int _userCoins = 100;
  int _selectedNativeIndex = 0; // 0: Big, 1: Medium, 2: Small, 3: Banner

  void _togglePremium(bool value) {
    setState(() {
      _isUserPremiumGlobal = value;
    });
    _appendLog('💎 [User] Premium VIP toggled: ${value ? "ACTIVE (No Ads)" : "INACTIVE (Show Ads)"}');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0C0E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9185E9),
          surface: Color(0xFF141416),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FlutterAds Showcase', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF141416),
          elevation: 0,
          actions: [
            // Coin Counter Badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF222228),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Row(
                children: [
                  const Text('🪙 ', style: TextStyle(fontSize: 14)),
                  Text(
                    '$_userCoins',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFD54F)),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Premium Toggle Card
            _buildPremiumHeader(),

            // Scrollable Feature Demos
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Fullscreen Ad Triggers
                  _buildSectionHeader('Fullscreen Placements (0ms Latency)'),
                  const SizedBox(height: 8),
                  _buildFullscreenButtons(),

                  const SizedBox(height: 20),

                  // Paywall Interceptor Demo
                  _buildSectionHeader('Paywall Hardware Back Guard'),
                  const SizedBox(height: 8),
                  _buildPaywallCard(context),

                  const SizedBox(height: 20),

                  // Native Templates Selector & Showcase
                  _buildSectionHeader('Native Ads Templates (Extracted)'),
                  const SizedBox(height: 8),
                  _buildNativeTemplateSelector(),
                  const SizedBox(height: 12),
                  _buildActiveNativeTemplateView(),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Live Analytics & Diagnostics Event Log Console
            _buildLiveConsole(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      color: const Color(0xFF18181C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isUserPremiumGlobal ? Icons.verified : Icons.lock_open,
                color: _isUserPremiumGlobal ? const Color(0xFF66BB6A) : const Color(0xFF9E9E9E),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _isUserPremiumGlobal ? 'VIP Member (Ads Suppressed)' : 'Free User (Ads Enabled)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _isUserPremiumGlobal ? const Color(0xFF66BB6A) : Colors.white,
                ),
              ),
            ],
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _isUserPremiumGlobal,
              activeThumbColor: const Color(0xFF66BB6A),
              onChanged: _togglePremium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFFB0B0B8),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFullscreenButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Show Interstitial',
                icon: Icons.fullscreen,
                onTap: () {
                  FlutterAds.show(
                    SampleAds.mainInterstitial,
                    onDismissed: () {
                      _appendLog('🎯 [UI] Interstitial dismissed. Resuming navigation flow.');
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                label: 'Show Rewarded (+50)',
                icon: Icons.card_giftcard,
                onTap: () {
                  FlutterAds.show(
                    SampleAds.rewardedBonus,
                    onRewardGranted: (amount, type) {
                      setState(() => _userCoins += 50);
                      _appendLog('🎁 [UI] User granted reward: +50 coins! New balance: $_userCoins');
                    },
                    onDismissed: () {
                      _appendLog('🎯 [UI] Rewarded dialog closed.');
                    },
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Show App Open Ad',
                icon: Icons.launch,
                onTap: () {
                  FlutterAds.show(
                    SampleAds.appOpen,
                    onDismissed: () {
                      _appendLog('🎯 [UI] App Open ad completed.');
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                label: 'Simulate Splash Launch',
                icon: Icons.flash_on,
                onTap: () {
                  _appendLog('⚡ [Splash] Triggering splash priority handshake...');
                  FlutterAds.show(
                    SampleAds.splashInterstitial,
                    onDismissed: () {
                      _appendLog('⚡ [Splash] Splash interstitial dismissed. Screen loaded.');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF9185E9)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaywallCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF9185E9).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF9185E9), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AdPaywallGuard Interceptor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Intercepts Back & Close buttons with an ad guard',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888892)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9185E9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SamplePaywallScreen()),
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeTemplateSelector() {
    final labels = ['Big (300dp)', 'Medium (130dp)', 'Small (74dp)', 'Banner (50dp)'];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = _selectedNativeIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedNativeIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF9185E9) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveNativeTemplateView() {
    switch (_selectedNativeIndex) {
      case 0:
        return const AdNativeView(
          key: ValueKey('big_native_view'),
          placement: SampleAds.bigNative,
        );
      case 1:
        return const AdNativeView(
          key: ValueKey('medium_native_view'),
          placement: SampleAds.mediumNative,
        );
      case 2:
        return const AdNativeView(
          key: ValueKey('small_native_view'),
          placement: SampleAds.smallNative,
        );
      case 3:
      default:
        return const AdBannerView(
          key: ValueKey('banner_view'),
          placement: SampleAds.splashBanner,
          height: 50,
        );
    }
  }

  Widget _buildLiveConsole() {
    return Container(
      height: 170,
      width: double.infinity,
      color: const Color(0xFF08080A),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF101014),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 14, color: Color(0xFF9185E9)),
                    SizedBox(width: 6),
                    Text(
                      'Live Analytics & Diagnostics Stream',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB0B0B8)),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _liveLogNotifier.value = [],
                  child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFF9185E9))),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _liveLogNotifier,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Interacting with ads streams live telemetry here...',
                      style: TextStyle(color: Color(0xFF55555F), fontSize: 11),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    Color textColor = const Color(0xFFCCCCCC);
                    if (log.contains('[Analytics]')) {
                      textColor = const Color(0xFF81D4FA);
                    } else if (log.contains('Revenue')) {
                      textColor = const Color(0xFFA5D6A7);
                    } else if (log.contains('[Diagnostics]')) {
                      textColor = const Color(0xFFFFCC80);
                    } else if (log.contains('Load Failed')) {
                      textColor = const Color(0xFFEF9A9A);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. Sample Paywall Screen with AdPaywallGuard Interceptor
// ============================================================================

class SamplePaywallScreen extends StatelessWidget {
  const SamplePaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdPaywallGuard(
      placement: SampleAds.mainInterstitial,
      onDismiss: () {
        _appendLog('🛡️ [AdPaywallGuard] Interstitial guard passed. Dismissing Paywall screen.');
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0E12),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Trigger dismissal which will be guarded by AdPaywallGuard
              Navigator.of(context).maybePop();
            },
          ),
          title: const Text('Unlock Unlimited Access', style: TextStyle(fontSize: 16)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.star, size: 72, color: Color(0xFFFFD54F)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upgrade to Pro VIP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Remove all advertisements, enable instant generation, and unlock cloud sync.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9185E9)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Annual Access', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$39.99 / year', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9185E9))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9185E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _appendLog('💳 [Paywall] User initiated checkout flow.');
                    Navigator.of(context).pop();
                  },
                  child: const Text('Start 7-Day Free Trial', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Press Close (X) or Android Hardware Back to see the AdPaywallGuard trigger!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF757575), fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
