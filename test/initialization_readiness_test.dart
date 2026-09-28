import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Driver extends GoogleMobileAdsDriver {
  int initializations = 0;
  final loads = <String>[];
  final shows = <String>[];
  final sdk = Completer<InitializationStatus>();
  Completer<dynamic>? ad;

  @override
  Future<InitializationStatus> initialize({List<String>? testDeviceIds}) {
    initializations++;
    return sdk.future;
  }

  @override
  Future<dynamic> loadAd(AdPlacement placement) async {
    loads.add(placement.id);
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
    AdmobKit.driverForTesting = driver;
    AdmobKit.networkInfoForTesting = _Network();
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
    AdmobKit.driverForTesting = null;
    AdmobKit.networkInfoForTesting = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_ump, null);
    messenger.setMockMethodCallHandler(_plugin, null);
  });

  testWidgets('session show forwards callbacks through the current pool after privacy update', (tester) async {
    arrange();
    await AdmobKit.initialize(
      config: const AdmobKitConfig(requestConsent: false, initializeNativeGma: false, logLevel: AdLogLevel.none),
    );
    const placement = RewardedPlacement(id: 'reward', androidId: '3', iosId: '3', loadOnce: true);
    await AdmobKit.pool!.preload(placement);
    final oldPool = AdmobKit.pool;
    final privacy = AdmobKit.showPrivacyOptionsForm();
    form.complete();
    await tester.pump();
    expect(await privacy, isTrue);
    expect(AdmobKit.pool, isNot(same(oldPool)));
    await AdmobKit.pool!.preload(placement);
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

  testWidgets('unobserved initialization failure stays observable to a late awaiter', (tester) async {
    arrange();
    final error = StateError('SDK initialization failed');
    final stack = StackTrace.current;
    final init = AdmobKit.initialize(config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    AdmobKit.registerPlacements([_native], placementCapacities: {_native.id: 2});
    AdmobKit.preload(_placement);
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    bool? eligibility;
    Object? leased;
    var leaseSettled = false;
    AdmobKit.waitUntilCanRequestAds().then((value) => eligibility = value);
    AdmobKit.leaseInlineAd(_native).then((value) {
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
    final first = AdmobKit.initialize(config: config);
    final second = AdmobKit.initialize(config: config);
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
    await AdmobKit.initialize(config: config);
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    final eligible = AdmobKit.waitUntilCanRequestAds();
    final ready = AdmobKit.waitFor(_placement);
    final leased = AdmobKit.leaseInlineAd(_native);
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    consent.failure(FormError(errorCode: 1, message: 'offline'));
    driver.sdk.complete(InitializationStatus({}));
    factories.complete(true);
    await tester.pump();
    await init;
    expect(await AdmobKit.waitUntilCanRequestAds(), isTrue);
  });

  testWidgets('failed factory registration is a real initialization failure', (tester) async {
    arrange();
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final old = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    expect(AdmobKit.pool, isNull);
  });

  testWidgets('old SDK completion cannot overwrite a newer session', (tester) async {
    arrange();
    final old = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    consent.success();
    form.complete();
    await tester.pump();
    AdmobKit.dispose();
    final oldDriver = driver;
    driver = _Driver();
    AdmobKit.driverForTesting = driver;
    final current = AdmobKit.initialize(
      config: const AdmobKitConfig(requestConsent: false, initializeNativeGma: false, logLevel: AdLogLevel.none),
    );
    await tester.pump();
    await current;
    final currentPool = AdmobKit.pool;
    oldDriver.sdk.complete(InitializationStatus({}));
    await tester.pump();
    await old;
    expect(identical(AdmobKit.pool, currentPool), isTrue);
    expect(AdmobKit.canRequestAds, isTrue);
    expect(oldDriver.loads, isEmpty);
  });

  testWidgets('premium is checked after initialization, not guessed during consent', (tester) async {
    arrange();
    var premium = false;
    final init = AdmobKit.initialize(
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final lease = AdmobKit.leaseInlineAd(_native);
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
      final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    expect(AdmobKit.pool, isNull);
  });

  testWidgets('readiness observer can dispose without starting a stale SDK request', (tester) async {
    arrange();
    void disposeDuringSdk() {
      if (AdmobKit.initializationState == AdInitializationState.initializingSdk) AdmobKit.dispose();
    }

    AdmobKit.initializationStateListenable.addListener(disposeDuringSdk);
    addTearDown(() => AdmobKit.initializationStateListenable.removeListener(disposeDuringSdk));
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    AdmobKit.preload(_native);
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
    final init = AdmobKit.initialize(
      config: const AdmobKitConfig(requestConsent: false, initializeNativeGma: false, logLevel: AdLogLevel.none),
    );
    await tester.pump();
    await init;
    expect(AdmobKit.pool!.mutex.tryAcquire(_placement.id), isTrue);
    expect(await AdmobKit.showPrivacyOptionsForm(), isFalse);
    expect(AdmobKit.isShowingAd, isTrue);
    expect(AdmobKit.initializationState, AdInitializationState.ready);
  });

  testWidgets('disposal also releases a privacy update waiting for the final UMP decision', (tester) async {
    arrange();
    final init = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
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
    final first = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    final failed = expectLater(first, throwsA(isA<StateError>()));
    consent.success();
    form.complete();
    await tester.pump();
    driver.sdk.completeError(StateError('failed'));
    await tester.pump();
    await failed;
    expect(await AdmobKit.waitUntilCanRequestAds(), isFalse);
    driver = _Driver();
    AdmobKit.driverForTesting = driver;
    final retry = AdmobKit.initialize(config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none));
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
    final init = AdmobKit.initialize(
      config: AdmobKitConfig(
        requestConsent: false,
        initializeNativeGma: false,
        logLevel: AdLogLevel.none,
        isPremium: () => premium,
      ),
    );
    await tester.pump();
    await init;
    var settled = false;
    Object? leased;
    AdmobKit.leaseInlineAd(_native).then((value) {
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
