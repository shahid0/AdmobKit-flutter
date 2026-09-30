import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';

/// App navigation and dismissal stay outside the SDK's clickable ad assets.
class NativeTemplateScreen extends StatefulWidget {
  final NativeAdTemplate template;
  const NativeTemplateScreen({super.key, required this.template});

  @override
  State<NativeTemplateScreen> createState() => _NativeTemplateScreenState();
}

class _NativeTemplateScreenState extends State<NativeTemplateScreen> {
  late final _placement = NativePlacement(
    id: 'gallery_${widget.template.name}',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    template: widget.template,
    loadOnce: true,
  );
  bool _updatingColors = false;

  Future<void> _applyColors(NativeAdColors colors) async {
    setState(() => _updatingColors = true);
    try {
      await AdmobKit.setNativeColors(colors, placement: _placement);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Color update failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _updatingColors = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(template.name),
        actions: [
          PopupMenuButton<NativeAdColors>(
            tooltip: 'Apply native colors',
            enabled: !_updatingColors,
            icon: const Icon(Icons.palette_outlined),
            onSelected: _applyColors,
            itemBuilder: (_) => const [
              PopupMenuItem(value: NativeAdColors(), child: Text('Reset to inherited colors')),
              PopupMenuItem(
                value: NativeAdColors(
                  background: 0xff14213d,
                  headline: 0xffffffff,
                  body: 0xffe5e5e5,
                  callToActionBackground: 0xfffca311,
                  callToActionText: 0xff14213d,
                ),
                child: Text('Midnight / gold'),
              ),
              PopupMenuItem(
                value: NativeAdColors(
                  background: 0xfff0fdf4,
                  headline: 0xff14532d,
                  body: 0xff166534,
                  callToActionBackground: 0xff166534,
                  callToActionText: 0xffffffff,
                ),
                child: Text('Forest / light'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < template.minWidth || constraints.maxHeight < template.height) {
              return Center(
                child: Text('This template needs at least 320 × ${template.height.toInt()} logical pixels.'),
              );
            }
            final ad = AdNativeView(placement: _placement);
            return template.isFullscreen ? ad : Center(child: ad);
          },
        ),
      ),
    );
  }
}
