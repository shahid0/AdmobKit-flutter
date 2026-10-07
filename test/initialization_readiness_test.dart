import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/contracts/ad_network_info.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart' show AdmobKitTestHarness;
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const _placement = InterstitialPlacement(id: 'boot', androidId: '1', iosId: '1', loadOnce: true);
const _native = NativePlacement(id: 'native', androidId: '2', iosId: '2', loadOnce: true);
const _ump = MethodChannel('plugins.flutter.io/google_mobile_ads/ump');
const _plugin = MethodChannel('flutter_ads');

class _Consent extends ConsentInformation {
  int updates = 0;
  bool allowed = true;
  Completer<bool>? decision;
  bool privacyRequired = true;
  PrivacyOptionsRequirementStatus? privacyStatus;
  Object? privacyError;
  Completer<PrivacyOptionsRequirementStatus>? privacyDecision;
  int privacyQueries = 0;
  late void Function() success;
  late void Function(FormError) failure;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener onSuccess,
    OnConsentInfoUpdateFailureListener onFailure,
  ) {
    updates++;
    success = onSuccess;
    failure = onFailure;
  }

  @override
  Future<bool> canRequestAds() async => decision == null ? allowed : decision!.future;

  @override
  Future<PrivacyOptionsRequirementStatus> getPrivacyOptionsRequirementStatus() async {
    privacyQueries++;
    if (privacyError != null) throw privacyError!;
    if (privacyDecision != null) return privacyDecision!.future;
    return privacyStatus ??
        (privacyRequired ? PrivacyOptionsRequirementStatus.required : PrivacyOptionsRequirementStatus.notRequired);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Driver extends GoogleMobileAdsDriver {
  int initializations = 0;
  final loads = <String>[];
  final shows = <String>[];
  final sdk = Completer<InitializationStatus>();
  Completer<dynamic>? ad;
  Future<dynamic> Function(AdPlacement)? onLoad;

  @override
  Future<InitializationStatus> initialize({List<String>? testDeviceIds}) {
    initializations++;
    return sdk.future;
  }

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) async {
    loads.add(placement.id);
    if (onLoad != null) return onLoad!(placement);
    return ad == null ? Object() : ad!.future;
  }

  @override
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required void Function() onDisplayed,
    required void Function() onDismissed,
    void Function(num amount, String type)? onRewardGranted,
  }) {
    shows.add(placement.id);
    onDisplayed();
    onRewardGranted?.call(3, 'coins');
    onDismissed();
  }
}

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ConsentInformation previous;
  late _Consent consent;
  late _Driver driver;
  late Completer<void> form;
  late Completer<bool> factories;

  setUp(() {
    AdmobKit.dispose();
    previous = ConsentInformation.instance;
  });

  void arrange() {
    consent = _Consent();
    driver = _Driver();
    form = Completer<void>();
    factories = Completer<bool>();
    ConsentInformation.instance = consent;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_ump, (_) async {
      await form.future;
      return null;
    });
    messenger.setMockMethodCallHandler(_plugin, (_) => factories.future);
  }

  tearDown(() {
    AdmobKit.dispose();
    ConsentInformation.instance = previous;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_ump, null);
    messenger.setMockMethodCallHandler(_plugin, null);
  });

  testWidgets('session show forwards callbacks through the current pool after privacy update', (tester) async {
    arrange();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    const placement = RewardedPlacement(id: 'reward', androidId: '3', iosId: '3', loadOnce: true);
    await AdmobKitTestHarness.pool!.preload(placement);
    final oldPool = AdmobKitTestHarness.pool;
    final privacy = AdmobKit.showPrivacyOptionsForm();
    form.complete();
    await tester.pump();
    expect(await privacy, isTrue);
    expect(AdmobKitTestHarness.pool, isNot(same(oldPool)));
    await AdmobKitTestHarness.pool!.preload(placement);
    final events = <String>[];

    AdmobKit.show(
      placement,
      onDisplayed: () => events.add('displayed'),
      onRewardGranted: (amount, type) => events.add('$amount $type'),
      onDismissed: () => events.add('dismissed'),
    );

    expect(driver.shows, [placement.id]);
    expect(events, ['displayed', '3 coins', 'dismissed']);
    expect(AdmobKit.isShowingAd, isFalse);
  });

  testWidgets('privacy settings requirement waits for consent even when ads are denied', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    bool? required;
    AdmobKit.isPrivacyOptionsRequired().then((value) => required = value);
    await tester.pump();
    expect(required, isNull);
    consent.allowed = false;
    consent.success();
    form.complete();
    await tester.pump();
    await init;
    expect(required, isTrue);
    expect(AdmobKit.canRequestAds, isFalse);
    consent.privacyRequired = false;
    expect(await AdmobKit.isPrivacyOptionsRequired(), isFalse);
    consent.privacyStatus = PrivacyOptionsRequirementStatus.unknown;
    await expectLater(AdmobKit.isPrivacyOptionsRequired(), throwsStateError);
    consent.privacyStatus = null;
    consent.privacyError = StateError('UMP query unavailable');
    await expectLater(AdmobKit.isPrivacyOptionsRequired(), throwsStateError);
  });

  testWidgets('a concurrent privacy update invalidates an older settings requirement query', (tester) async {
    arrange();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    final oldQuery = Completer<PrivacyOptionsRequirementStatus>();
    consent.privacyDecision = oldQuery;
    bool? result;
    AdmobKit.isPrivacyOptionsRequired().then((value) => result = value);
    await tester.pump();
    expect(consent.privacyQueries, 1);
    final update = AdmobKit.showPrivacyOptionsForm();
    form.complete();
    await tester.pump();
    await update;
    consent.privacyDecision = null;
    oldQuery.complete(PrivacyOptionsRequirementStatus.notRequired);
    await tester.pump();
    expect(result, isTrue);
    expect(consent.privacyQueries, 2);
  });

  testWidgets('disposal releases a pending settings requirement query', (tester) async {
    arrange();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    final query = Completer<PrivacyOptionsRequirementStatus>();
    consent.privacyDecision = query;
    final requirement = AdmobKit.isPrivacyOptionsRequired();
    await tester.pump();
    AdmobKit.dispose();
    expect(await requirement, isFalse);
    query.complete(PrivacyOptionsRequirementStatus.required);
    await tester.pump();
    expect(AdmobKit.initializationState, AdInitializationState.disposed);
  });

  testWidgets('privacy updates preserve loadOnce consumption but permit new inline demand', (tester) async {
    arrange();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, subsequentConcurrency: 2, logLevel: AdLogLevel.none),
    );
    AdmobKit.registerPlacements([_placement, _native]);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pump();
    AdmobKit.show(_placement);
    expect(await AdmobKitTestHarness.leaseInlineAd(_native), isNotNull);
    final loadsBeforePrivacy = driver.loads.length;
    final update = AdmobKit.showPrivacyOptionsForm();
    form.complete();
    await tester.pump();
    await update;
    await tester.runAsync(() async {});
    await tester.pump();
    expect(
      driver.loads.length,
      loadsBeforePrivacy,
      reason: 'Consent refresh must not restart consumed background work',
    );
    expect(await AdmobKit.waitFor(_placement), isFalse);
    final pending = <Completer<dynamic>>[];
    driver.onLoad = (_) {
      final load = Completer<dynamic>();
      pending.add(load);
      return load.future;
    };
    final first = AdmobKitTestHarness.leaseInlineAd(_native);
    final second = AdmobKitTestHarness.leaseInlineAd(_native);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pump();
    expect(pending, hasLength(2), reason: 'Consumed startup work must not leave the initial batch open');
    for (final load in pending) {
      load.complete(Object());
    }
    expect(await first, isNotNull);
    expect(await second, isNotNull);
    driver.onLoad = null;
    expect(driver.loads.length, loadsBeforePrivacy + 2);
    expect(driver.loads.where((id) => id == _placement.id), hasLength(1));
    AdmobKit.dispose();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    AdmobKit.registerPlacements([_placement]);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pump();
    expect(driver.loads.where((id) => id == _placement.id), hasLength(2), reason: 'A new session resets consumption');
  });

  testWidgets('an obsolete privacy query error cannot replace the new requirement', (tester) async {
    arrange();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    final oldQuery = Completer<PrivacyOptionsRequirementStatus>();
    consent.privacyDecision = oldQuery;
    bool? result;
    AdmobKit.isPrivacyOptionsRequired().then((value) => result = value);
    await tester.pump();
    final update = AdmobKit.showPrivacyOptionsForm();
    form.complete();
    await tester.pump();
    await update;
    consent.privacyDecision = null;
    oldQuery.completeError(StateError('Old requirement query failed'));
    await tester.pump();
    expect(result, isTrue);
    expect(consent.privacyQueries, 2);
  });

  testWidgets('unobserved initialization failure stays observable to a late awaiter', (tester) async {
    arrange();
    final error = StateError('SDK initialization failed');
    final stack = StackTrace.current;
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    driver.sdk.completeError(error, stack);
    // No caller observes the future until after the error has been delivered.
    await tester.pump();
    expect(AdmobKit.initializationState, AdInitializationState.failed);
    expect(await AdmobKit.waitUntilCanRequestAds(), isFalse);
    await init.then<void>(
      (_) => fail('Initialization must retain its error'),
      onError: (Object received, StackTrace receivedStack) {
        expect(received, same(error));
        expect(receivedStack, same(stack));
      },
    );
  });

  testWidgets('waitFor stays pending through consent, SDK and native factory registration', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    bool? result;
    AdmobKit.waitFor(_placement).then((value) => result = value);
    await tester.pump();
    expect(result, isNull, reason: 'Pending initialization is not a denial');
    expect(driver.loads, isEmpty);

    consent.success();
    await tester.pump();
    expect(driver.initializations, 0);
    form.complete();
    await tester.pump();
    expect(AdmobKit.canRequestAds, isFalse, reason: 'SDK is still initializing');
    expect(result, isNull);
    driver.sdk.complete(InitializationStatus({}));
    await tester.pump();
    expect(AdmobKit.canRequestAds, isFalse, reason: 'Native factories are not ready');
    factories.complete(true);
    await tester.pump();
    await init;
    await tester.runAsync(() async {});
    await tester.pump();
    expect(result, isTrue);
    expect(driver.loads, [_placement.id]);
  });

  testWidgets('early registration and preload are retained while consent resolves', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    AdmobKit.registerPlacements([_native], placementCapacities: {_native.id: 2});
    AdmobKitTestHarness.preload(_placement);
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    expect(driver.loads.where((id) => id == _native.id).length, 2);
    expect(driver.loads.where((id) => id == _placement.id).length, 1);
  });

  testWidgets('slow consent form does not become readiness after a guessed delay', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    expect(driver.initializations, 0, reason: 'The user has not dismissed the consent form');
    expect(AdmobKit.canRequestAds, isFalse);
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
  });

  testWidgets('SDK failure cannot leave canRequestAds true', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    final failed = expectLater(init, throwsA(isA<StateError>()));
    consent.success();
    form.complete();
    await tester.pump();
    driver.sdk.completeError(StateError('SDK unavailable'));
    await tester.pump();
    await failed;
    expect(AdmobKit.canRequestAds, isFalse);
    expect(driver.loads, isEmpty);
  });

  testWidgets('eligibility and inline leases wait for the same initialization', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    bool? eligibility;
    Object? leased;
    var leaseSettled = false;
    AdmobKit.waitUntilCanRequestAds().then((value) => eligibility = value);
    AdmobKitTestHarness.leaseInlineAd(_native).then((value) {
      leased = value;
      leaseSettled = true;
    });
    await tester.pump();
    expect(eligibility, isNull);
    expect(leaseSettled, isFalse);
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    expect(eligibility, isTrue);
    expect(leased, isNotNull);
    expect(driver.loads, [_native.id]);
  });

  testWidgets('concurrent initialization is single-flight and reports each stage', (tester) async {
    arrange();
    final states = <AdInitializationState>[];
    void listen() => states.add(AdmobKit.initializationState);
    AdmobKit.initializationStateListenable.addListener(listen);
    addTearDown(() => AdmobKit.initializationStateListenable.removeListener(listen));
    const config = AdmobKitConfig(logLevel: AdLogLevel.none, placements: [_placement]);
    final first = AdmobKitTestHarness.initialize(driver: driver, networkInfo: _Network(), config: config);
    final second = AdmobKitTestHarness.initialize(driver: driver, networkInfo: _Network(), config: config);
    expect(identical(first, second), isTrue);
    expect(consent.updates, 1);
    consent.success();
    form.complete();
    await tester.pump();
    expect(AdmobKit.initializationState, AdInitializationState.initializingSdk);
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await first;
    await AdmobKitTestHarness.initialize(driver: driver, networkInfo: _Network(), config: config);
    expect(consent.updates, 1);
    expect(driver.initializations, 1);
    expect(driver.loads, [_placement.id]);
    expect(
      states,
      containsAllInOrder([
        AdInitializationState.gatheringConsent,
        AdInitializationState.initializingSdk,
        AdInitializationState.ready,
      ]),
    );
  });

  testWidgets('actual consent denial settles all early callers without ad traffic', (tester) async {
    arrange();
    consent.allowed = false;
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    final eligible = AdmobKit.waitUntilCanRequestAds();
    final ready = AdmobKit.waitFor(_placement);
    final leased = AdmobKitTestHarness.leaseInlineAd(_native);
    consent.success();
    form.complete();
    await tester.pump();
    await init;
    expect(await eligible, isFalse);
    expect(await ready, isFalse);
    expect(await leased, isNull);
    expect(AdmobKit.initializationState, AdInitializationState.consentDenied);
    expect(driver.initializations, 0);
    expect(driver.loads, isEmpty);
  });

  testWidgets('failed UMP update uses its authoritative existing permission', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.failure(FormError(errorCode: 1, message: 'offline'));
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    expect(await AdmobKit.waitUntilCanRequestAds(), isTrue);
  });

  testWidgets('failed factory registration is a real initialization failure', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    final failed = expectLater(init, throwsA(isA<StateError>()));
    final eligible = AdmobKit.waitUntilCanRequestAds();
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(false);
    await tester.pump();
    await failed;
    expect(await eligible, isFalse);
    expect(AdmobKit.initializationState, AdInitializationState.failed);
    expect(driver.loads, isEmpty);
  });

  testWidgets('dispose releases waiters and ignores stale consent callbacks', (tester) async {
    arrange();
    final old = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    final eligible = AdmobKit.waitUntilCanRequestAds();
    final ready = AdmobKit.waitFor(_placement);
    AdmobKit.dispose();
    await tester.pump();
    await old;
    expect(await eligible, isFalse);
    expect(await ready, isFalse);
    consent.success();
    await tester.pump();
    expect(driver.initializations, 0);
    expect(AdmobKit.initializationState, AdInitializationState.disposed);
    expect(AdmobKitTestHarness.pool, isNull);
  });

  testWidgets('old SDK completion cannot overwrite a newer session', (tester) async {
    arrange();
    final old = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    form.complete();
    await tester.pump();
    AdmobKit.dispose();
    final oldDriver = driver;
    driver = _Driver();
    final current = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    await tester.pump();
    await current;
    final currentPool = AdmobKitTestHarness.pool;
    oldDriver.sdk.complete(InitializationStatus({}));
    await tester.pump();
    await old;
    expect(identical(AdmobKitTestHarness.pool, currentPool), isTrue);
    expect(AdmobKit.canRequestAds, isTrue);
    expect(oldDriver.loads, isEmpty);
  });

  testWidgets('premium is checked after initialization, not guessed during consent', (tester) async {
    arrange();
    var premium = false;
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: AdmobKitConfig(logLevel: AdLogLevel.none, placements: const [_placement], isPremium: () => premium),
    );
    final eligibility = AdmobKit.waitUntilCanRequestAds();
    premium = true;
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    expect(await eligibility, isFalse);
    expect(driver.loads, isEmpty);
    premium = false;
    expect(await AdmobKit.waitUntilCanRequestAds(), isTrue);
  });

  testWidgets('ATT must settle, but denial of tracking alone does not deny ads', (tester) async {
    arrange();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final att = Completer<int>();
    var attPrompts = 0;
    const channel = MethodChannel('app_tracking_transparency');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) {
      if (call.method == 'getTrackingAuthorizationStatus') return Future.value(0);
      attPrompts++;
      return att.future;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    await tester.pump();
    expect(attPrompts, 0);
    form.complete();
    await tester.pump();
    expect(attPrompts, 1);
    expect(driver.initializations, 0);
    expect(AdmobKit.initializationState, AdInitializationState.gatheringConsent);
    att.complete(2); // TrackingStatus.denied
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    expect(await AdmobKit.waitUntilCanRequestAds(), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('privacy updates hold new requests then recheck UMP permission', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    form = Completer<void>();
    final privacy = AdmobKit.showPrivacyOptionsForm();
    expect(AdmobKit.canRequestAds, isFalse, reason: 'Privacy gate closes synchronously');
    await tester.pump();
    bool? eligible;
    bool? ready;
    AdmobKit.waitUntilCanRequestAds().then((value) => eligible = value);
    AdmobKit.waitFor(_placement).then((value) => ready = value);
    await tester.pump();
    expect(AdmobKit.initializationState, AdInitializationState.updatingConsent);
    expect(eligible, isNull);
    expect(ready, isNull);
    expect(driver.loads, isEmpty);
    consent.allowed = false;
    form.complete();
    await tester.pump();
    expect(await privacy, isTrue);
    expect(eligible, isFalse);
    expect(ready, isFalse);
    expect(AdmobKit.initializationState, AdInitializationState.consentDenied);

    form = Completer<void>();
    final allowedAgain = AdmobKit.showPrivacyOptionsForm();
    await tester.pump();
    final lease = AdmobKitTestHarness.leaseInlineAd(_native);
    consent.allowed = true;
    form.complete();
    await tester.pump();
    expect(await allowedAgain, isTrue);
    expect(await lease, isNotNull);
    expect(driver.initializations, 1, reason: 'SDK is already initialized');
  });

  for (final allowed in [false, true]) {
    testWidgets('UMP eligibility itself is awaited (result: $allowed)', (tester) async {
      arrange();
      consent.decision = Completer<bool>();
      final init = AdmobKitTestHarness.initialize(
        driver: driver,
        networkInfo: _Network(),
        config: const AdmobKitConfig(logLevel: AdLogLevel.none),
      );
      bool? eligible;
      AdmobKit.waitUntilCanRequestAds().then((value) => eligible = value);
      consent.success();
      form.complete();
      await tester.pump();
      expect(eligible, isNull);
      expect(driver.initializations, 0);
      consent.decision!.complete(allowed);
      driver.sdk.complete(InitializationStatus({}));
      factories.complete(true);
      await tester.pump();
      await init;
      expect(eligible, allowed);
      expect(driver.initializations, allowed ? 1 : 0);
    });
  }

  testWidgets('privacy grant after initial denial initializes SDK before releasing requests', (tester) async {
    arrange();
    consent.allowed = false;
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    AdmobKit.registerPlacements([_placement]);
    consent.success();
    form.complete();
    await tester.pump();
    await init;
    expect(driver.initializations, 0);
    form = Completer<void>();
    final update = AdmobKit.showPrivacyOptionsForm();
    bool? eligible;
    AdmobKit.waitUntilCanRequestAds().then((value) => eligible = value);
    consent.allowed = true;
    form.complete();
    await tester.pump();
    expect(driver.initializations, 1);
    expect(eligible, isNull);
    expect(driver.loads, isEmpty);
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    expect(await update, isTrue);
    expect(eligible, isTrue);
    expect(driver.loads, [_placement.id]);
  });

  testWidgets('privacy interrupts an existing ad wait without returning premature false', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    final oldLoad = Completer<dynamic>();
    driver.ad = oldLoad;
    bool? ready;
    AdmobKit.waitFor(_placement).then((value) => ready = value);
    await tester.pump();
    expect(driver.loads.length, 1);
    form = Completer<void>();
    final privacy = AdmobKit.showPrivacyOptionsForm();
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pump();
    expect(ready, isNull);
    driver.ad = null;
    form.complete();
    await tester.pump();
    await privacy;
    await tester.runAsync(() async {});
    await tester.pump();
    expect(ready, isTrue);
    expect(driver.loads.length, 2);
    oldLoad.complete(Object());
    await tester.pump();
  });

  testWidgets('disposal during factory registration settles callers and cannot resurrect readiness', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    final eligible = AdmobKit.waitUntilCanRequestAds();
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    await tester.pump();
    AdmobKit.dispose();
    await tester.pump();
    await init;
    expect(await eligible, isFalse);
    factories.complete(true);
    await tester.pump();
    expect(AdmobKit.canRequestAds, isFalse);
    expect(AdmobKitTestHarness.pool, isNull);
  });

  testWidgets('readiness observer can dispose without starting a stale SDK request', (tester) async {
    arrange();
    void disposeDuringSdk() {
      if (AdmobKit.initializationState == AdInitializationState.initializingSdk) AdmobKit.dispose();
    }

    AdmobKit.initializationStateListenable.addListener(disposeDuringSdk);
    addTearDown(() => AdmobKit.initializationStateListenable.removeListener(disposeDuringSdk));
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    form.complete();
    await tester.pump();
    await init;
    expect(driver.initializations, 0);
    expect(AdmobKit.initializationState, AdInitializationState.disposed);
  });

  testWidgets('ad timeout does not run while startup prerequisites are unresolved', (tester) async {
    arrange();
    driver.ad = Completer<dynamic>();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    bool? ready;
    AdmobKit.waitFor(_placement, timeout: const Duration(milliseconds: 50)).then((value) => ready = value);
    await tester.pump(const Duration(seconds: 30));
    expect(ready, isNull);
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    await tester.pump(const Duration(milliseconds: 49));
    expect(ready, isNull);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.runAsync(() async {});
    await tester.pump();
    expect(ready, isFalse, reason: 'This is a real ad-load timeout after startup settled');
    driver.ad!.complete(Object());
    await tester.pump();
  });

  testWidgets('privacy change between eligibility and loading keeps demand pending', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    form = Completer<void>();
    Future<bool>? privacy;
    AdmobKit.waitUntilCanRequestAds().then((_) => privacy = AdmobKit.showPrivacyOptionsForm());
    bool? ready;
    AdmobKit.waitFor(_placement).then((value) => ready = value);
    AdmobKitTestHarness.preload(_native);
    await tester.pump();
    expect(ready, isNull);
    expect(driver.loads, isEmpty);
    form.complete();
    await tester.pump();
    await privacy;
    await tester.runAsync(() async {});
    await tester.pump();
    expect(ready, isTrue);
    expect(driver.loads, containsAll([_placement.id, _native.id]));
  });

  testWidgets('privacy cannot cover a fullscreen ad or unlock its presentation mutex', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    await tester.pump();
    await init;
    expect(AdmobKitTestHarness.pool!.mutex.tryAcquire(_placement.id), isNotNull);
    expect(await AdmobKit.showPrivacyOptionsForm(), isFalse);
    expect(AdmobKit.isShowingAd, isTrue);
    expect(AdmobKit.initializationState, AdInitializationState.ready);
  });

  testWidgets('disposal also releases a privacy update waiting for the final UMP decision', (tester) async {
    arrange();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    consent.success();
    form.complete();
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    form = Completer<void>();
    consent.decision = Completer<bool>();
    final update = AdmobKit.showPrivacyOptionsForm();
    form.complete();
    await tester.pump();
    expect(AdmobKit.initializationState, AdInitializationState.updatingConsent);
    AdmobKit.dispose();
    await tester.pump();
    expect(await update, isFalse);
    consent.decision!.complete(true);
    await tester.pump();
    expect(AdmobKit.canRequestAds, isFalse);
  });

  testWidgets('failed initialization can be retried without reusing a denied readiness result', (tester) async {
    arrange();
    final first = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(logLevel: AdLogLevel.none),
    );
    final failed = expectLater(first, throwsA(isA<StateError>()));
    consent.success();
    form.complete();
    await tester.pump();
    driver.sdk.completeError(StateError('failed'));
    await tester.pump();
    await failed;
    expect(await AdmobKit.waitUntilCanRequestAds(), isFalse);
    driver = _Driver();
    final retry = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    bool? eligible;
    AdmobKit.waitUntilCanRequestAds().then((value) => eligible = value);
    await tester.pump();
    expect(eligible, isNull);
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await retry;
    expect(eligible, isTrue);
  });

  testWidgets('premium change during loading settles inline demand without waiting for its timeout', (tester) async {
    arrange();
    var premium = false;
    driver.ad = Completer<dynamic>();
    final init = AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none, isPremium: () => premium),
    );
    await tester.pump();
    await init;
    var settled = false;
    Object? leased;
    AdmobKitTestHarness.leaseInlineAd(_native).then((value) {
      leased = value;
      settled = true;
    });
    await tester.pump();
    premium = true;
    driver.ad!.complete(Object());
    await tester.pump();
    expect(settled, isTrue);
    expect(leased, isNull);
    expect(AdmobKit.canRequestAds, isFalse);
  });
}
