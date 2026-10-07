import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

abstract final class AppAds {
  static const transition = InterstitialPlacement(
    id: 'transition',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
  );
  static const native = NativePlacement(
    id: 'feed',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    template: NativeAdTemplate.feedMediaFirst,
  );
  static const banner = BannerPlacement(
    id: 'footer',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = AdmobKit.initialize();
  AdmobKit.registerPlacements([AppAds.transition, AppAds.native, AppAds.banner]);
  runApp(const ExampleApp());
  try {
    await boot;
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: ExampleScreen());
}

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AdmobKit example')),
    body: ListView(
      children: [
        const Text('App content'),
        LayoutBuilder(
          builder: (context, bounds) => bounds.maxWidth >= AppAds.native.template.minWidth
              ? const AdNativeView(placement: AppAds.native)
              : const SizedBox.shrink(),
        ),
        TextButton(
          onPressed: () => AdmobKit.show(
            AppAds.transition,
            onDismissed: () {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action completed')));
            },
          ),
          child: const Text('Continue'),
        ),
      ],
    ),
    bottomNavigationBar: const SafeArea(child: AdBannerView(placement: AppAds.banner)),
  );
}
