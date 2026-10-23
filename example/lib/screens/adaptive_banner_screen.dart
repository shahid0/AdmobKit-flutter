import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';
import '../config/sample_ads.dart';
import '../theme/task_theme.dart';

enum BannerDemoType {
  inlineAdaptive('Adaptive', 'Inline adaptive up to 250dp'),
  standard('Standard', 'Fixed 320×50'),
  mrec('MREC', 'Fixed 300×250');

  final String title;
  final String subtitle;
  const BannerDemoType(this.title, this.subtitle);
}

class AdaptiveBannerScreen extends StatefulWidget {
  final bool inline;
  const AdaptiveBannerScreen({super.key, required this.inline});

  @override
  State<AdaptiveBannerScreen> createState() => _AdaptiveBannerScreenState();
}

class _AdaptiveBannerScreenState extends State<AdaptiveBannerScreen> {
  late final _adaptivePlacement = BannerPlacement(
    id: widget.inline ? 'gallery_inline_banner' : 'gallery_anchored_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    sizing: widget.inline
        ? const BannerSizing.inlineAdaptive(maxHeight: 250)
        : const BannerSizing.anchoredAdaptive(),
    loadOnce: true,
  );

  bool _inset = false;
  bool _reserveSpace = true;
  BannerDemoType _selectedType = BannerDemoType.inlineAdaptive;

  BannerPlacement get _currentPlacement => switch (_selectedType) {
    BannerDemoType.inlineAdaptive => _adaptivePlacement,
    BannerDemoType.standard => SampleAds.standardBanner,
    BannerDemoType.mrec => SampleAds.mrecBanner,
  };

  Widget _banner() => Padding(
    padding: EdgeInsets.symmetric(horizontal: _inset ? 24 : 0),
    child: AdBannerView(
      key: ValueKey('${_currentPlacement.id}_$_reserveSpace'),
      placement: _currentPlacement,
      reserveSpace: widget.inline ? _reserveSpace : null,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TaskColors.canvasGround,
    appBar: AppBar(
      title: Text(widget.inline ? 'Banner gallery' : 'Anchored adaptive'),
      leading: const BackButton(),
    ),
    body: SafeArea(
      child: ListView(
        children: [
          SwitchListTile(
            title: const Text('Inset banner width'),
            subtitle: const Text(
              'Change available width or rotate the device. The SDK resolves the ad height.',
            ),
            value: _inset,
            onChanged: (value) => setState(() => _inset = value),
          ),
          if (widget.inline) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<BannerDemoType>(
                segments: [
                  for (final type in BannerDemoType.values)
                    ButtonSegment(
                      value: type,
                      label: Text(type.title, style: const TextStyle(fontSize: 12)),
                    ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) => setState(() => _selectedType = set.first),
              ),
            ),
            CheckboxListTile(
              title: const Text('Reserve banner space'),
              subtitle: const Text(
                'Turn off to collapse height until loaded, then adapt to actual ad height.',
              ),
              value: _reserveSpace,
              onChanged: (value) => setState(() => _reserveSpace = value ?? true),
            ),
            const SizedBox(height: 12),
            _banner(),
          ],
        ],
      ),
    ),
    bottomNavigationBar: widget.inline ? null : SafeArea(child: _banner()),
  );
}
