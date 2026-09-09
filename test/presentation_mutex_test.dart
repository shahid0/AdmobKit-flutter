import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/src/infrastructure/mutex/presentation_mutex.dart';

void main() {
  group('PresentationMutex Tests', () {
    test('Allows first caller to acquire and blocks subsequent callers', () {
      final mutex = PresentationMutex();

      expect(mutex.isLocked, false);
      expect(mutex.currentHolderId, isNull);

      final acquired1 = mutex.tryAcquire('interstitial_1');
      expect(acquired1, true);
      expect(mutex.isLocked, true);
      expect(mutex.currentHolderId, 'interstitial_1');

      // Collision attempt by another ad
      final acquired2 = mutex.tryAcquire('app_open_resume');
      expect(acquired2, false);
      expect(mutex.currentHolderId, 'interstitial_1');

      // Release
      mutex.release('interstitial_1');
      expect(mutex.isLocked, false);
      expect(mutex.currentHolderId, isNull);

      // Now the second ad can acquire
      final acquired3 = mutex.tryAcquire('app_open_resume');
      expect(acquired3, true);
      expect(mutex.currentHolderId, 'app_open_resume');
    });

    test('Force release clears active holder', () {
      final mutex = PresentationMutex();
      mutex.tryAcquire('stuck_ad');
      expect(mutex.isLocked, true);

      mutex.forceRelease();
      expect(mutex.isLocked, false);
      expect(mutex.lastAdDismissedAt, isNotNull);
    });

    test('Tracks isResumingFromAd and post-ad cooldown', () {
      final mutex = PresentationMutex();
      expect(mutex.isResumingFromAd, false);

      mutex.tryAcquire('interstitial_flow');
      expect(mutex.isResumingFromAd, true);

      mutex.release('interstitial_flow');
      expect(mutex.isResumingFromAd, true);
      expect(mutex.isWithinCooldown(const Duration(seconds: 2)), true);

      // Consume resume flag
      mutex.consumeResumeFromAd();
      expect(mutex.isResumingFromAd, false);
    });
  });
}
