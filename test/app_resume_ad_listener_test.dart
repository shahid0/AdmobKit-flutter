import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/src/domain/contracts/ad_network_info.dart';
import 'package:flutter_ads/src/domain/models/ad_placement.dart';
import 'package:flutter_ads/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:flutter_ads/src/infrastructure/mutex/presentation_mutex.dart';
import 'package:flutter_ads/src/infrastructure/pool/eager_ad_pool.dart';
import 'package:flutter_ads/src/presentation/lifecycle/app_resume_ad_listener.dart';

class FakeNetworkInfo implements AdNetworkInfo {
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();

  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppResumeAdListener True State Machine Tests', () {
    late PresentationMutex mutex;
    late EagerAdPool pool;
    late AppResumeAdListener listener;
    const placement = AppOpenPlacement(androidId: 'ao_1', iosId: 'ao_1');

    setUp(() {
      mutex = PresentationMutex();
      pool = EagerAdPool(
        driver: GoogleMobileAdsDriver(),
        mutex: mutex,
        networkInfo: FakeNetworkInfo(),
      );
      listener = AppResumeAdListener(
        placement: placement,
        pool: pool,
      );
    });

    tearDown(() {
      listener.detach();
      pool.dispose();
    });

    test('Arms background flag when app transitions to paused without an active ad', () {
      expect(listener.isBackgroundArmed, false);

      // Transition to paused while mutex is free
      listener.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(listener.isBackgroundArmed, true);
    });

    test('Arms background flag when app transitions to hidden without an active ad', () {
      expect(listener.isBackgroundArmed, false);

      // Transition to hidden while mutex is free
      listener.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(listener.isBackgroundArmed, true);
    });

    test('Does NOT arm background flag when app transitions to paused while fullscreen ad is active', () {
      expect(listener.isBackgroundArmed, false);

      // Acquire mutex for an interstitial
      final acquired = mutex.tryAcquire('interstitial_1');
      expect(acquired, true);
      expect(mutex.isLocked, true);

      // Native fullscreen ad launches, Flutter activity pauses
      listener.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Background flag must NOT be armed
      expect(listener.isBackgroundArmed, false);

      // Ad is dismissed
      mutex.release('interstitial_1');
      expect(mutex.isLocked, false);

      // Flutter resumes
      listener.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Still false, no resume ad fired
      expect(listener.isBackgroundArmed, false);
    });

    test('Consumes armed background flag on resume and disarms immediately (1-to-1 consumption)', () {
      // User backgrounds app
      listener.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(listener.isBackgroundArmed, true);

      // User resumes app (no matter how long or short)
      listener.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(listener.isBackgroundArmed, false);

      // Subsequent resume event without backgrounding does nothing
      listener.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(listener.isBackgroundArmed, false);
    });
  });
}
