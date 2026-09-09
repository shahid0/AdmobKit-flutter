import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads/src/infrastructure/pool/tiered_ad_queue.dart';

class FakeNetworkInfo implements AdNetworkInfo {
  AdNetworkType current = AdNetworkType.wifi;
  final _controller = StreamController<AdNetworkType>.broadcast();

  @override
  Future<AdNetworkType> getNetworkType() async => current;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => _controller.stream;

  void emit(AdNetworkType type) {
    current = type;
    _controller.add(type);
  }
}

class FakeDiagnosticsTracker implements AdDiagnosticsTracker {
  final List<AdDiagnosticReport> reports = [];

  @override
  void onDiagnosticReport(AdDiagnosticReport report) {
    reports.add(report);
  }
}

void main() {
  group('TieredAdQueue Tests', () {
    late FakeNetworkInfo networkInfo;
    late FakeDiagnosticsTracker diagnostics;

    setUp(() {
      networkInfo = FakeNetworkInfo();
      diagnostics = FakeDiagnosticsTracker();
    });

    test('Strict Concurrency = 1: Only 1 task executes at a time', () async {
      int activeCount = 0;
      int maxConcurrent = 0;

      final queue = TieredAdQueue(
        executor: (placement) async {
          activeCount++;
          if (activeCount > maxConcurrent) maxConcurrent = activeCount;
          await Future.delayed(const Duration(milliseconds: 20));
          activeCount--;
          return Object();
        },
        networkInfo: networkInfo,
        diagnostics: diagnostics,
      );

      const p1 = BannerPlacement(androidId: '1', iosId: '1');
      const p2 = BannerPlacement(androidId: '2', iosId: '2');
      const p3 = BannerPlacement(androidId: '3', iosId: '3');

      final futures = [
        queue.enqueue(p1),
        queue.enqueue(p2),
        queue.enqueue(p3),
      ];

      await Future.wait(futures);

      expect(maxConcurrent, 1, reason: 'Strict single concurrency must never exceed 1');
      queue.dispose();
    });

    test('Queue drain order: Immediate drains before Medium and Low', () async {
      final executionOrder = <String>[];

      final queue = TieredAdQueue(
        executor: (placement) async {
          executionOrder.add(placement.id);
          return Object();
        },
        networkInfo: networkInfo,
        diagnostics: diagnostics,
      );

      const low = BannerPlacement(id: 'low', androidId: '3', iosId: '3', priority: AdPriority.low);
      const medium = BannerPlacement(id: 'medium', androidId: '2', iosId: '2', priority: AdPriority.medium);
      const immediate = BannerPlacement(id: 'immediate', androidId: '1', iosId: '1', priority: AdPriority.immediate);

      // Enqueue in reverse priority
      final f1 = queue.enqueue(low);
      final f2 = queue.enqueue(medium);
      final f3 = queue.enqueue(immediate);

      await Future.wait([f1, f2, f3]);

      // Immediate drains first, then medium, then low
      expect(executionOrder, ['immediate', 'medium', 'low']);

      queue.dispose();
    });

    test('Splash Handshake Gate: Splash Fullscreen waits until Splash Inline resolves', () async {
      final executionOrder = <String>[];
      final completerMap = <String, Completer<void>>{};

      final queue = TieredAdQueue(
        executor: (placement) async {
          executionOrder.add(placement.id);
          final c = Completer<void>();
          completerMap[placement.id] = c;
          await c.future;
          return Object();
        },
        networkInfo: networkInfo,
        diagnostics: diagnostics,
      );

      const splashInline = BannerPlacement(
        id: 'splash_inline',
        androidId: '1',
        iosId: '1',
        isSplash: true,
      );
      const splashFullscreen = InterstitialPlacement(
        id: 'splash_fullscreen',
        androidId: '2',
        iosId: '2',
        isSplash: true,
      );

      // Enqueue splash fullscreen first, then splash inline
      queue.enqueue(splashFullscreen);
      queue.enqueue(splashInline);

      // Give event loop a tick
      await Future.delayed(const Duration(milliseconds: 10));

      // Handshake gate check: splash_inline should execute first!
      expect(executionOrder, contains('splash_inline'));
      expect(executionOrder, isNot(contains('splash_fullscreen')));

      // Now resolve splash_inline
      completerMap['splash_inline']!.complete();
      await Future.delayed(const Duration(milliseconds: 10));

      // Now splash_fullscreen should unlock and execute!
      expect(executionOrder, contains('splash_fullscreen'));

      completerMap['splash_fullscreen']!.complete();
      queue.dispose();
    });

    test('Black Hole Detection: Consecutive cellular timeouts trigger blackHoleSuspected', () async {
      networkInfo.current = AdNetworkType.cellular;

      final queue = TieredAdQueue(
        executor: (placement) async {
          await Future.delayed(const Duration(milliseconds: 80));
          return Object();
        },
        networkInfo: networkInfo,
        diagnostics: diagnostics,
        timeoutConfig: const AdTimeoutConfig(
          fullscreen: AdTimeoutPolicy(cellularTimeout: Duration(milliseconds: 15)),
          inline: AdTimeoutPolicy(cellularTimeout: Duration(milliseconds: 15)),
        ),
      );

      const p1 = BannerPlacement(id: 'p1', androidId: '1', iosId: '1');
      const p2 = BannerPlacement(id: 'p2', androidId: '2', iosId: '2');

      queue.enqueue(p1).catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 50));

      queue.enqueue(p2).catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final blackHoleReports = diagnostics.reports.where(
        (r) => r.eventType == AdDiagnosticEventType.blackHoleSuspected,
      );
      expect(blackHoleReports.isNotEmpty, true);

      queue.dispose();
    });
  });
}
