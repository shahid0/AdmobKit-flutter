import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';
import '../theme/task_theme.dart';

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

  void _showInfoSheet() {
    final template = widget.template;
    showModalBottomSheet(
      context: context,
      backgroundColor: TaskColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge.emerald(
                  template.isFullscreen ? 'FULLSCREEN' : '${template.height.toInt()} PX HEIGHT',
                  icon: const Icon(Icons.info_outline_rounded, size: 12, color: TaskColors.emeraldText),
                ),
                const Spacer(),
                Text(
                  template.factoryId,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: TaskColors.textMutedCaption),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Template: ${template.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: TaskColors.textInkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Minimum constraints: ${template.minWidth.toInt()} × ${template.height.toInt()} logical pixels.\n'
              'Placement owns template identity. Colors apply over native Android/iOS views via Pigeon without ad reloads.',
              style: const TextStyle(fontSize: 13, color: TaskColors.textSlateMedium, height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(template.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Template Specs',
            onPressed: _showInfoSheet,
          ),
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
              PopupMenuItem(
                value: NativeAdColors(
                  background: 0xff0f172a,
                  headline: 0xfff8fafc,
                  body: 0xff94a3b8,
                  callToActionBackground: 0xff4338ca,
                  callToActionText: 0xffffffff,
                ),
                child: Text('Indigo / dark'),
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
