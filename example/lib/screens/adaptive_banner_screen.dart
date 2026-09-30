import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';
import '../theme/task_theme.dart';

class AdaptiveBannerScreen extends StatefulWidget {
  final bool inline;
  const AdaptiveBannerScreen({super.key, required this.inline});

  @override
  State<AdaptiveBannerScreen> createState() => _AdaptiveBannerScreenState();
}

class _AdaptiveBannerScreenState extends State<AdaptiveBannerScreen> {
  late final _placement = BannerPlacement(
    id: widget.inline ? 'gallery_inline_banner' : 'gallery_anchored_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    sizing: widget.inline ? const BannerSizing.inlineAdaptive(maxHeight: 250) : const BannerSizing.anchoredAdaptive(),
    loadOnce: true,
  );
  bool _inset = false;

  Widget _banner() => Padding(
    padding: EdgeInsets.symmetric(horizontal: _inset ? 24 : 0),
    child: AdBannerView(placement: _placement),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TaskColors.canvasGround,
    appBar: AppBar(
      title: Text(widget.inline ? 'Inline adaptive' : 'Anchored adaptive'),
      leading: const BackButton(),
    ),
    body: SafeArea(
      child: ListView(
        children: [
          SwitchListTile(
            title: const Text('Inset banner width'),
            subtitle: const Text('Change available width or rotate the device. The SDK resolves the ad height.'),
            value: _inset,
            onChanged: (value) => setState(() => _inset = value),
          ),
          if (widget.inline) _banner(),
        ],
      ),
    ),
    bottomNavigationBar: widget.inline ? null : SafeArea(child: _banner()),
  );
}
