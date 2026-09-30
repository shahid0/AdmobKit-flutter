import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';

void main() {
  group('PresentationMutex Tests', () {
    test('changes are asynchronous, stale release is silent, disposal prevents reacquisition', () async {
      final mutex = PresentationMutex();
      var notifications = 0;
      final subscription = mutex.changes.listen((_) => notifications++);
      final first = mutex.tryAcquire('first')!;
      expect(notifications, 0);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      mutex.release(first);
      final second = mutex.tryAcquire('second')!;
      mutex.release(first);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 3);
      expect(mutex.owns(second), isTrue);
      mutex.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 4);
      expect(mutex.isLocked, isFalse);
      expect(mutex.tryAcquire('late'), isNull);
      mutex.release(second);
      mutex.dispose();
      await subscription.cancel();
    });
    test('Allows first caller to acquire and blocks subsequent callers', () {
      final mutex = PresentationMutex();

      expect(mutex.isLocked, false);
      expect(mutex.currentHolderId, isNull);

      final acquired1 = mutex.tryAcquire('interstitial_1');
      expect(acquired1, isNotNull);
      expect(mutex.isLocked, true);
      expect(mutex.currentHolderId, 'interstitial_1');

      // Collision attempt by another ad
      final acquired2 = mutex.tryAcquire('app_open_resume');
      expect(acquired2, isNull);
      expect(mutex.currentHolderId, 'interstitial_1');

      // Release
      mutex.release(acquired1!);
      expect(mutex.isLocked, false);
      expect(mutex.currentHolderId, isNull);

      // Now the second ad can acquire
      final acquired3 = mutex.tryAcquire('app_open_resume');
      expect(acquired3, isNotNull);
      expect(mutex.currentHolderId, 'app_open_resume');
    });

    test('Force release clears active holder', () {
      final mutex = PresentationMutex();
      mutex.tryAcquire('stuck_ad');
      expect(mutex.isLocked, true);

      mutex.forceRelease();
      expect(mutex.isLocked, false);
    });

    test('stale token cannot release a newer presentation of the same placement', () {
      final mutex = PresentationMutex();
      final old = mutex.tryAcquire('same')!;
      mutex.forceRelease();
      final current = mutex.tryAcquire('same')!;
      mutex.release(old);
      expect(mutex.isLocked, isTrue);
      mutex.release(current);
      expect(mutex.isLocked, isFalse);
    });

    test('token from another mutex cannot release this mutex', () {
      final first = PresentationMutex();
      final second = PresentationMutex();
      final foreign = first.tryAcquire('same')!;
      second.tryAcquire('same');
      second.release(foreign);
      expect(second.isLocked, isTrue);
    });
  });
}
