import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../state/task_store.dart';

class AppDrawerConsole extends StatefulWidget {
  const AppDrawerConsole({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141418),
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
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ads Console',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bug_report_outlined, size: 20, color: Color(0xFFF59E0B)),
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
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.white54),
                    tooltip: 'Clear Logs',
                    onPressed: () {
                      store.liveLogs.value = [];
                    },
                  ),
                ],
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

            const Divider(color: Colors.white12, height: 1),

            // Log List
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
                        style: TextStyle(color: Colors.white38, fontSize: 13),
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
                      Color textColor = const Color(0xFFB0B0C0);
                      if (line.contains('[Analytics]')) {
                        textColor = const Color(0xFF67E8F9); // cyan
                      } else if (line.contains('Paid Event')) {
                        textColor = const Color(0xFF4ADE80); // green
                      } else if (line.contains('[Diagnostics]')) {
                        textColor = const Color(0xFFFDE047); // yellow
                      } else if (line.contains('Failed') || line.contains('Error') || line.contains('❌')) {
                        textColor = const Color(0xFFF87171); // red
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E26),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
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
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white60)),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF242430),
      onSelected: (_) => setState(() => _filter = label),
    );
  }
}
