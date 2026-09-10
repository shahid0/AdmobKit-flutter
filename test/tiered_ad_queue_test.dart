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

    test('Concurrency Limit <= 2: Up to 2 tasks execute concurrently, never exceeding 2', () async {
      int activeCount = 0;
      int maxConcurrent = 0;

      final queue = TieredAdQueue(
        executor: (placement) async {
          activeCount++;
          if (activeCount > maxConcurrent) {
            maxConcurrent = activeCount;
          }
          await Future.delayed(const Duration(milliseconds: 30));
          activeCount--;
          return Object();
        },
        networkInfo: networkInfo,
        diagnostics: diagnostics,
      );

      const p1 = BannerPlacement(androidId: '1', iosId: '1');
      const p2 = BannerPlacement(androidId: '2', iosId: '2');
      const p3 = BannerPlacement(androidId: '3', iosId: '3');
      const p4 = BannerPlacement(androidId: '4', iosId: '4');

      final futures = [
        queue.enqueue(p1),
        queue.enqueue(p2),
        queue.enqueue(p3),
        queue.enqueue(p4),
      ];

      await Future.wait(futures);

      expect(maxConcurrent, 2, reason: 'Concurrency limit must cap at 2');
      queue.dispose();
    });

    test('Queue drain order: Splash drains before Immediate, Medium, and Low', () async {
      final executionOrder = <String>[];

      final queue = TieredAdQueue(
        executor: (placement) async {
          executionOrder.add(placement.id);
          return Object();
        },
        networkInfo: networkInfo,
        diagnostics: diagnostics,
      );

      const low = BannerPlacement(id: 'low', androidId: '4', iosId: '4', priority: AdPriority.low);
      const medium = BannerPlacement(id: 'medium', androidId: '3', iosId: '3', priority: AdPriority.medium);
      const immediate = BannerPlacement(id: 'immediate', androidId: '2', iosId: '2', priority: AdPriority.immediate);
      const splash = BannerPlacement(id: 'splash', androidId: '1', iosId: '1', priority: AdPriority.splash);

      // Enqueue in reverse priority
      final f1 = queue.enqueue(low);
      final f2 = queue.enqueue(medium);
      final f3 = queue.enqueue(immediate);
      final f4 = queue.enqueue(splash);

      await Future.wait([f1, f2, f3, f4]);

      // Splash drains first, then immediate, then medium, then low
      expect(executionOrder, ['splash', 'immediate', 'medium', 'low']);

      queue.dispose();
    });

    test('Concurrent Priority 0 Dispatch: Splash Inline and Splash Fullscreen load concurrently', () async {
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

      // Enqueue both Priority 1 placements
      queue.enqueue(splashFullscreen);
      queue.enqueue(splashInline);

      // Give event loop a tick
      await Future.delayed(const Duration(milliseconds: 10));

      // Under concurrency = 2, both Priority 1 placements start concurrently!
      expect(executionOrder, contains('splash_inline'));
      expect(executionOrder, contains('splash_fullscreen'));

      completerMap['splash_inline']!.complete();
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
