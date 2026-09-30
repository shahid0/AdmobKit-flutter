import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';
import '../theme/task_theme.dart';
import 'adaptive_banner_screen.dart';
import 'native_template_screen.dart';

/// Catalog of 25 Native ad templates and 2 Adaptive banner configurations.
/// Browsing does not register or preload inventory; selecting a preview requests
/// only that placement on-demand with loadOnce semantics.
class AdGalleryScreen extends StatelessWidget {
  const AdGalleryScreen({super.key});

  IconData _iconForTemplate(NativeAdTemplate template) {
    if (template.isFullscreen) return Icons.fullscreen_rounded;
    if (template.name.startsWith('large')) return Icons.view_quilt_rounded;
    if (template.name.startsWith('medium')) return Icons.space_dashboard_rounded;
    return Icons.view_compact_rounded;
  }

  String _descriptionForTemplate(NativeAdTemplate template) {
    if (template.isFullscreen) {
      return 'Bounded fullscreen · live colors · video safe';
    }
    return '${template.height.toInt()} px · ${template.name.startsWith("large") ? "content & media" : template.name.startsWith("medium") ? "compact card" : "inline strip"}';
  }

  @override
  Widget build(BuildContext context) {
    final totalTemplates = NativeAdTemplate.values.length;

    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      appBar: AppBar(
        title: const Text('Ad gallery'),
        leading: const BackButton(),
      ),
      body: ListView.builder(
        itemCount: totalTemplates + 3,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TaskCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge.emerald('$totalTemplates TEMPLATES', icon: const Icon(Icons.auto_awesome_rounded, size: 12, color: TaskColors.emeraldText)),
                        const SizedBox(width: 8),
                        const StatusBadge(
                          label: 'ON-DEMAND PREVIEWS',
                          textColor: TaskColors.accentPrimary,
                          surfaceColor: TaskColors.accentSubtle,
                          borderColor: TaskColors.borderSubtle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Browse all native layouts and adaptive banners. Tap any template to inspect live asset bindings, dynamic palette switches, and layout constraints.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TaskColors.textSlateMedium,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index == 1 || index == 2) {
            final inline = index == 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: TaskColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TaskColors.borderSubtle),
              ),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: TaskColors.accentSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.view_agenda_outlined, color: TaskColors.accentPrimary, size: 18),
                ),
                title: Text(
                  inline ? 'Inline adaptive banner' : 'Anchored adaptive banner',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TaskColors.textInkPrimary,
                  ),
                ),
                subtitle: Text(
                  inline ? 'Inline maxHeight: 250 · Parent-derived width' : 'Anchored SDK height · Parent-derived width',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TaskColors.textSlateMedium,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: TaskColors.textMutedCaption),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => AdaptiveBannerScreen(inline: inline)),
                ),
              ),
            );
          }

          final templateIndex = index - 3;
          final template = NativeAdTemplate.values[templateIndex];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: TaskColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TaskColors.borderSubtle),
            ),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: template.isFullscreen
                      ? TaskColors.amberSurface
                      : template.height == 360
                          ? TaskColors.emeraldSurface
                          : template.height == 180
                              ? TaskColors.accentSubtle
                              : TaskColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForTemplate(template),
                  color: template.isFullscreen
                      ? TaskColors.amberText
                      : template.height == 360
                          ? TaskColors.emeraldText
                          : template.height == 180
                              ? TaskColors.accentPrimary
                              : TaskColors.slateText,
                  size: 18,
                ),
              ),
              title: Text(
                template.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TaskColors.textInkPrimary,
                  fontFamily: 'monospace',
                ),
              ),
              subtitle: Text(
                _descriptionForTemplate(template),
                style: const TextStyle(
                  fontSize: 12,
                  color: TaskColors.textSlateMedium,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: TaskColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      template.isFullscreen ? 'FULL' : '${template.height.toInt()}px',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: TaskColors.textMutedCaption,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: TaskColors.textMutedCaption),
                ],
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => NativeTemplateScreen(template: template)),
              ),
            ),
          );
        },
      ),
    );
  }
}
