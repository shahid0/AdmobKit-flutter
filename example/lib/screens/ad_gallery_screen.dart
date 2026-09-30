import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';

import 'adaptive_banner_screen.dart';
import 'native_template_screen.dart';

/// Browsing the catalog does not register or preload its inventory.
class AdGalleryScreen extends StatelessWidget {
  const AdGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ad gallery')),
    body: ListView.builder(
      itemCount: NativeAdTemplate.values.length + 2,
      itemBuilder: (context, index) {
        if (index < 2) {
          final inline = index == 1;
          return ListTile(
            title: Text(inline ? 'Inline adaptive banner' : 'Anchored adaptive banner'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => AdaptiveBannerScreen(inline: inline))),
          );
        }
        final template = NativeAdTemplate.values[index - 2];
        return ListTile(
          title: Text(template.name),
          subtitle: Text(
            template.isFullscreen ? 'Bounded fullscreen · live colors' : '${template.height.toInt()} px · live colors',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => NativeTemplateScreen(template: template))),
        );
      },
    ),
  );
}
