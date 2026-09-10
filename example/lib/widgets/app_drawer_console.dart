import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import '../state/task_store.dart';
import '../theme/task_theme.dart';

class AppDrawerConsole extends StatefulWidget {
  const AppDrawerConsole({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaskColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AppDrawerConsole(),
    );
  }

  @override
  State<AppDrawerConsole> createState() => _AppDrawerConsoleState();
}

class _AppDrawerConsoleState extends State<AppDrawerConsole> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TaskColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: TaskColors.accentPrimary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Live Diagnostic HUD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: TaskColors.textInkPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bug_report_outlined, size: 20, color: TaskColors.amberText),
                    tooltip: 'Open AdMob Inspector',
                    onPressed: () {
                      FlutterAds.openAdInspector((error) {
                        if (error != null) {
                          store.appendLog('❌ Inspector error: $error');
                        } else {
                          store.appendLog('🔍 AdMob Inspector opened successfully.');
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: TaskColors.textMutedCaption),
                    tooltip: 'Clear Logs',
                    onPressed: () {
                      store.liveLogs.value = [];
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ANALYTICS'),
                    const SizedBox(width: 8),
                    _buildFilterChip('DIAGNOSTICS'),
                  ],
                ),
              ),
            ),

            const Divider(color: TaskColors.borderSubtle, height: 1),

            Expanded(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: store.liveLogs,
                builder: (context, logs, _) {
                  final filtered = logs.where((l) {
                    if (_filter == 'ANALYTICS') return l.contains('[Analytics]');
                    if (_filter == 'DIAGNOSTICS') return l.contains('[Diagnostics]');
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No events recorded yet.\nInteract with the app to test ads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: TaskColors.textMutedCaption, fontSize: 13),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final line = filtered[index];
                      Color textColor = TaskColors.textSlateMedium;
                      Color bgColor = TaskColors.surfaceSubtle;
                      Color borderColor = TaskColors.borderSubtle;

                      if (line.contains('Paid Event') || line.contains('Granted')) {
                        textColor = TaskColors.emeraldText;
                        bgColor = TaskColors.emeraldSurface;
                        borderColor = TaskColors.emeraldBorder;
                      } else if (line.contains('Failed') || line.contains('Error') || line.contains('❌')) {
                        textColor = TaskColors.roseText;
                        bgColor = TaskColors.roseSurface;
                        borderColor = TaskColors.roseBorder;
                      } else if (line.contains('[Diagnostics]') || line.contains('Inspector')) {
                        textColor = TaskColors.amberText;
                        bgColor = TaskColors.amberSurface;
                        borderColor = TaskColors.amberBorder;
                      } else if (line.contains('[Analytics]')) {
                        textColor = TaskColors.accentPrimary;
                      }

                      return InkWell(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: line));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Log line copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : TaskColors.textSlateMedium,
        ),
      ),
      selected: isSelected,
      selectedColor: TaskColors.accentPrimary,
      backgroundColor: TaskColors.surfaceSubtle,
      side: BorderSide(
        color: isSelected ? TaskColors.accentPrimary : TaskColors.borderSubtle,
      ),
      onSelected: (_) => setState(() => _filter = label),
    );
  }
}
