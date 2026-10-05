import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import '../../theme/task_theme.dart';

/// Demonstrates an immersive full-screen native ad with PresentationMutex locking.
/// App dismissal controls remain strictly outside the SDK ad assets.
class FullscreenNativeShowcaseScreen extends StatefulWidget {
  const FullscreenNativeShowcaseScreen({super.key});

  @override
  State<FullscreenNativeShowcaseScreen> createState() => _FullscreenNativeShowcaseScreenState();
}

class _FullscreenNativeShowcaseScreenState extends State<FullscreenNativeShowcaseScreen> {
  NativeAdTemplate _selectedTemplate = NativeAdTemplate.fullscreenMediaFirst;
  bool _updatingColors = false;

  late NativePlacement _placement = _createPlacement(_selectedTemplate);

  NativePlacement _createPlacement(NativeAdTemplate template) {
    return NativePlacement(
      id: 'fullscreen_native_${template.name}',
      androidId: AdMobTestIds.nativeAndroid,
      iosId: AdMobTestIds.nativeIos,
      template: template,
      loadOnce: true,
    );
  }

  void _onTemplateChanged(NativeAdTemplate template) {
    if (_selectedTemplate == template) return;
    setState(() {
      _selectedTemplate = template;
      _placement = _createPlacement(template);
    });
  }

  Future<void> _applyStyle(NativeAdStyle colors) async {
    setState(() => _updatingColors = true);
    try {
      await AdmobKit.setNativeStyle(colors, placement: _placement);
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
    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildTemplateSelector(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < _selectedTemplate.minWidth ||
                      constraints.maxHeight < _selectedTemplate.height) {
                    return Center(
                      child: Text(
                        'Requires at least ${_selectedTemplate.minWidth.toInt()} × ${_selectedTemplate.height.toInt()} px.',
                        style: const TextStyle(fontSize: 13, color: TaskColors.textSlateMedium),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: TaskColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TaskColors.borderSubtle),
                      boxShadow: TaskColors.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AdNativeView(
                      placement: _placement,
                      placeholder: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2, color: TaskColors.accentPrimary),
                            SizedBox(height: 12),
                            Text(
                              'Priming Fullscreen Native Ad...',
                              style: TextStyle(fontSize: 13, color: TaskColors.textSlateMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fullscreen Native Ad',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: TaskColors.textInkPrimary,
                ),
              ),
              Text(
                'PresentationMutex Protected',
                style: TextStyle(fontSize: 11, color: TaskColors.emeraldText, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Spacer(),
          PopupMenuButton<NativeAdStyle>(
            tooltip: 'Apply native colors',
            enabled: !_updatingColors,
            icon: const Icon(Icons.palette_outlined, color: TaskColors.accentPrimary),
            onSelected: _applyStyle,
            itemBuilder: (_) => const [
              PopupMenuItem(value: NativeAdStyle(), child: Text('Reset to inherited colors')),
              PopupMenuItem(
                value: NativeAdStyle(
                  background: 0xFF14213D,
                  headline: 0xFFFFFFFF,
                  body: 0xFFE5E5E5,
                  callToActionBackground: 0xFFFCA311,
                  callToActionText: 0xFF14213D,
                ),
                child: Text('Midnight / gold'),
              ),
              PopupMenuItem(
                value: NativeAdStyle(
                  background: 0xFFF0FDF4,
                  headline: 0xFF14532D,
                  body: 0xFF166534,
                  callToActionBackground: 0xFF166534,
                  callToActionText: 0xFFFFFFFF,
                ),
                child: Text('Forest / light'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    final templates = NativeAdTemplate.values.where((template) => template.isFullscreen);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: templates.map((tmpl) {
          final isSelected = tmpl == _selectedTemplate;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tmpl.name),
              selected: isSelected,
              onSelected: (_) => _onTemplateChanged(tmpl),
              selectedColor: TaskColors.accentSubtle,
              checkmarkColor: TaskColors.accentPrimary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? TaskColors.accentPrimary : TaskColors.textSlateMedium,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continue')),
          StatusBadge.emerald(
            'MUTEX: ${AdmobKit.isShowingAd ? "LOCKED" : "IDLE"}',
            icon: const Icon(Icons.lock_outline_rounded, size: 12, color: TaskColors.emeraldText),
          ),
          const SizedBox(width: 8),
          const StatusBadge(
            label: 'DISMISS OUTSIDE ASSETS',
            textColor: TaskColors.textSlateMedium,
            surfaceColor: TaskColors.surfaceSubtle,
            borderColor: TaskColors.borderSubtle,
          ),
        ],
      ),
    );
  }
}
