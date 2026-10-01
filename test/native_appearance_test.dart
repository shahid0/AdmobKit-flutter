import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/appearance/native_appearance.dart';
import 'package:admob_kit_flutter/src/infrastructure/appearance/native_appearance.g.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/managed_native_ad.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/ad_cache_entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;

const placement = NativePlacement(
  template: NativeAdTemplate.rowWithLeadingIcon,
  id: 'native',
  androidId: 'test',
  iosId: 'test',
  style: NativeAdStyle(headline: 0xff123456),
);

class _Host extends NativeAppearanceHost {
  final snapshots = <Map<String, NativeStyleData>>[];
  final revisions = <int>[];
  final starts = <String>[];
  String? session;
  bool fail = false;
  bool failStart = false;
  Completer<void>? barrier;

  @override
  Future<void> startSession(String sessionId) async {
    starts.add(sessionId);
    if (failStart) throw PlatformException(code: 'start-failed');
    session = sessionId;
  }

  @override
  Future<void> applyStyle(String sessionId, int revision, Map<String, NativeStyleData> renders) async {
    await barrier?.future;
    if (fail) throw PlatformException(code: 'test-failure');
    if (session != sessionId) throw StateError('stale session');
    snapshots.add(renders);
    revisions.add(revision);
  }

  @override
  Future<void> endSession(String sessionId) async {
    if (session == sessionId) session = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed host startup can be retried without discarding desired colors', () async {
    final host = _Host()..failStart = true;
    final appearance = NativeAppearance(host: host);
    await expectLater(appearance.setStyle(const NativeAdStyle(body: 77)), throwsA(isA<PlatformException>()));
    host.failStart = false;
    final id = await appearance.reserve(placement);
    expect(host.snapshots.last[id]!.body, 77);
    expect(host.starts, hasLength(2));
    await appearance.dispose();
  });

  test('color validation is runtime checked and inheritance is field-by-field', () {
    expect(() => const NativeAdStyle(body: -1).validate(), throwsArgumentError);
    expect(() => const NativeAdStyle(background: 0x100000000).validate(), throwsArgumentError);
    const NativeAdStyle(background: 0xffffffff).validate();
    final colors = const NativeAdStyle(headline: 3).over(const NativeAdStyle(background: 1, headline: 2));
    expect(colors.background, 1);
    expect(colors.headline, 3);
  });

  test('CTA radius validates at runtime, inherits per field, and participates in equality', () {
    for (final radius in [-1.0, double.nan, double.infinity, double.negativeInfinity]) {
      expect(() => NativeAdStyle(callToActionCornerRadius: radius).validate(), throwsArgumentError);
    }
    const NativeAdStyle(callToActionCornerRadius: 0).validate();
    const NativeAdStyle(callToActionCornerRadius: 6.5).validate();
    expect(const NativeAdStyle().over(const NativeAdStyle(callToActionCornerRadius: 12)).callToActionCornerRadius, 12);
    expect(
      const NativeAdStyle(
        callToActionCornerRadius: 0,
      ).over(const NativeAdStyle(callToActionCornerRadius: 12)).callToActionCornerRadius,
      0,
    );
    expect(const NativeAdStyle(callToActionCornerRadius: 4), const NativeAdStyle(callToActionCornerRadius: 4));
    final styles = <NativeAdStyle>{};
    styles.add(const NativeAdStyle(callToActionCornerRadius: 4));
    styles.add(const NativeAdStyle(callToActionCornerRadius: 4));
    expect(styles, hasLength(1));
    expect(const NativeAdStyle(callToActionCornerRadius: 4), isNot(const NativeAdStyle(callToActionCornerRadius: 5)));
  });

  test(
    'radius applies to existing and future renders; reset inherits, invalid intent does not replace state',
    () async {
      final host = _Host();
      final appearance = NativeAppearance(host: host, defaults: const NativeAdStyle(callToActionCornerRadius: 12));
      final first = await appearance.reserve(placement);
      expect(host.snapshots.last[first]!.callToActionCornerRadius, 12);
      await appearance.setStyle(const NativeAdStyle(callToActionCornerRadius: 0), placement: placement);
      final second = await appearance.reserve(placement);
      expect(host.snapshots.last[first]!.callToActionCornerRadius, 0);
      expect(host.snapshots.last[second]!.callToActionCornerRadius, 0);
      await expectLater(
        appearance.setStyle(const NativeAdStyle(callToActionCornerRadius: -1), placement: placement),
        throwsArgumentError,
      );
      await appearance.setStyle(const NativeAdStyle(background: 1, callToActionCornerRadius: 6.5));
      expect(host.snapshots.last[first]!.callToActionCornerRadius, 0);
      await appearance.setStyle(const NativeAdStyle(), placement: placement);
      expect(host.snapshots.last[first]!.callToActionCornerRadius, 6.5);
      await appearance.setStyle(const NativeAdStyle());
      expect(host.snapshots.last[first]!.callToActionCornerRadius, isNull);
      await appearance.dispose();
    },
  );

  test('global, placement, live overrides, and reset work for existing and future renders', () async {
    final host = _Host();
    final appearance = NativeAppearance(host: host, defaults: const NativeAdStyle(background: 0xff000000, headline: 1));
    final first = await appearance.reserve(placement);
    expect(host.snapshots.last[first]!.background, 0xff000000);
    expect(host.snapshots.last[first]!.headline, 0xff123456);
    await appearance.setStyle(const NativeAdStyle(body: 4), placement: placement);
    expect(host.snapshots.last[first]!.headline, 1);
    expect(host.snapshots.last[first]!.body, 4);
    await appearance.setStyle(const NativeAdStyle(headline: 5));
    final second = await appearance.reserve(placement);
    expect(host.snapshots.last[first], host.snapshots.last[second]);
    expect(host.snapshots.last[first]!.background, isNull);
    await appearance.setStyle(const NativeAdStyle(), placement: placement);
    expect(host.snapshots.last[first]!.body, isNull);
    expect(host.snapshots.last[first]!.headline, 5);
    await appearance.setStyle(const NativeAdStyle());
    expect(host.snapshots.last[first], NativeStyleData());
    await appearance.release(first);
    expect(host.snapshots.last.keys, [second]);
    await appearance.dispose();
    expect(host.session, isNull);
  });

  test('concurrent updates serialize and retain the latest complete intent', () async {
    final host = _Host();
    final appearance = NativeAppearance(host: host);
    final id = await appearance.reserve(placement);
    host.barrier = Completer<void>();
    final first = appearance.setStyle(const NativeAdStyle(background: 1));
    final second = appearance.setStyle(const NativeAdStyle(background: 2));
    final third = appearance.setStyle(const NativeAdStyle(body: 3), placement: placement);
    host.barrier!.complete();
    await Future.wait([first, second, third]);
    expect(host.snapshots.last[id]!.background, 2);
    expect(host.snapshots.last[id]!.body, 3);
    expect(host.revisions, orderedEquals([...host.revisions]..sort()));
    expect(host.starts, hasLength(1));
    await appearance.dispose();
  });

  test('failed updates propagate and a later snapshot recovers all desired colors', () async {
    final host = _Host();
    final appearance = NativeAppearance(host: host);
    final id = await appearance.reserve(placement);
    host.fail = true;
    await expectLater(appearance.setStyle(const NativeAdStyle(background: 8)), throwsA(isA<PlatformException>()));
    await expectLater(appearance.reserve(placement), throwsA(isA<PlatformException>()));
    host.fail = false;
    await appearance.setStyle(const NativeAdStyle(body: 9), placement: placement);
    expect(host.snapshots.last.keys, [id]);
    expect(host.snapshots.last[id]!.background, 8);
    expect(host.snapshots.last[id]!.body, 9);
    await appearance.dispose();
  });

  test('disposed pending start cannot replace a new session', () async {
    final host = _Host();
    final old = NativeAppearance(host: host);
    final pending = old.reserve(placement);
    final rejected = expectLater(pending, throwsStateError);
    final disposal = old.dispose();
    final current = NativeAppearance(host: host);
    await current.reserve(placement);
    await disposal;
    await rejected;
    expect(host.session, current.sessionId);
    expect(host.starts, [current.sessionId]);
    await expectLater(old.setStyle(const NativeAdStyle()), throwsStateError);
    await current.dispose();
  });

  test('generated channel preserves unsigned ARGB, nulls, map identity, and errors', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.admob_kit_flutter.NativeAppearanceHost.applyStyle',
      NativeAppearanceHost.pigeonChannelCodec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      final args = message! as List<Object?>;
      expect(args[0], 'session');
      expect(args[1], 42);
      final colors = (args[2]! as Map)['render'] as NativeStyleData;
      expect(colors.background, 0xffffffff);
      expect(colors.headline, isNull);
      expect(colors.callToActionCornerRadius, 6.5);
      return <Object?>[];
    });
    addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
    await NativeAppearanceHost().applyStyle('session', 42, {
      'render': NativeStyleData(background: 0xffffffff, callToActionCornerRadius: 6.5),
    });
    messenger.setMockDecodedMessageHandler<Object?>(channel, (_) async => ['paint-failed', 'failure', null]);
    await expectLater(NativeAppearanceHost().applyStyle('session', 43, {}), throwsA(isA<PlatformException>()));
  });

  group('SDK native ownership', () {
    late _Host host;
    late NativeAppearance appearance;
    late GoogleMobileAdsDriver driver;
    late List<MethodCall> calls;
    late List<ManagedNativeAd> loaded;
    setUp(() {
      host = _Host();
      appearance = NativeAppearance(host: host);
      driver = GoogleMobileAdsDriver(appearance: appearance);
      calls = [];
      loaded = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        (call) async {
          calls.add(call);
          if (call.method == 'loadNativeAd') {
            final ad = instanceManager.adFor((call.arguments as Map)['adId'] as int)! as ManagedNativeAd;
            loaded.add(ad);
          }
          return null;
        },
      );
    });
    tearDown(() async {
      for (final ad in loaded) {
        await ad.dispose();
      }
      await appearance.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        null,
      );
    });

    test('live colors cover pending/loaded ad without another SDK load; disposal releases identity once', () async {
      final pending = driver.loadAd(placement);
      await Future<void>.delayed(Duration.zero);
      final ad = loaded.single;
      final render = ad.customOptions!['renderId'] as String;
      expect(ad.customOptions!['sessionId'], appearance.sessionId);
      await appearance.setStyle(const NativeAdStyle(background: 7));
      expect(host.snapshots.last[render]!.background, 7);
      ad.listener.onAdLoaded!(ad);
      expect(await pending, same(ad));
      expect(ad.loadedAt, isNotNull);
      await appearance.setStyle(const NativeAdStyle(background: 8));
      expect(calls.where((c) => c.method == 'loadNativeAd'), hasLength(1));
      expect(host.snapshots.last[render]!.background, 8);
      ad.loadedAt = DateTime.now().subtract(const Duration(hours: 1));
      expect(AdCacheEntry(placement: placement, adInstance: ad).isStale, isTrue);
      await Future.wait([ad.dispose(), ad.dispose()]);
      expect(host.snapshots.last, isEmpty);
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    });

    test('SDK disposal is not blocked by a delayed appearance acknowledgement', () async {
      final release = Completer<void>();
      final ad = ManagedNativeAd(
        adUnitId: 'test',
        factoryId: 'admobKit.rowWithLeadingIcon',
        request: const AdRequest(),
        listener: NativeAdListener(),
        releaseAppearance: () => release.future,
      );
      await ad.load();
      final disposing = ad.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
      release.complete();
      await disposing;
    });

    test('eligibility is rechecked after asynchronous appearance setup', () async {
      await expectLater(driver.loadAd(placement, validateRequest: () => throw StateError('revoked')), throwsStateError);
      expect(calls.where((c) => c.method == 'loadNativeAd'), isEmpty);
      expect(host.snapshots.last, isEmpty);
    });

    test('SDK failure releases the pending render', () async {
      final pending = driver.loadAd(placement);
      final assertion = expectLater(pending, throwsA(isA<LoadAdError>()));
      await Future<void>.delayed(Duration.zero);
      final ad = loaded.single;
      ad.listener.onAdFailedToLoad!(ad, LoadAdError(1, 'test', 'no fill', null));
      await assertion;
      await ad.dispose();
      expect(host.snapshots.last, isEmpty);
    });
  });
}
