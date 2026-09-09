import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';
import '../../widgets/task_tile.dart';
import '../sub_screens/create_task_screen.dart';
import '../sub_screens/task_detail_screen.dart';

class TasksListTab extends StatefulWidget {
  const TasksListTab({super.key});

  @override
  State<TasksListTab> createState() => _TasksListTabState();
}

class _TasksListTabState extends State<TasksListTab> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final allTasks = store.tasks;
        final filteredTasks = allTasks.where((t) {
          if (_filter == 'PENDING') return !t.isCompleted;
          if (_filter == 'COMPLETED') return t.isCompleted;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F14),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Task', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              );
            },
          ),
          body: CustomScrollView(
            slivers: [
              // Header with stats & filter chips
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF14141A),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Tasks',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${store.pendingTasksCount} pending · ${store.completedTasksCount} done',
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (store.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'PRO ACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildFilterChip('ALL', 'All (${allTasks.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('PENDING', 'Pending (${store.pendingTasksCount})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('COMPLETED', 'Done (${store.completedTasksCount})'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Task List with Embedded Native Ads
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Insert Medium Native Ad at index 1
                      if (index == 1 && !store.isPremium) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF191922),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const AdNativeView(
                              placement: SampleAds.mediumNative,
                              height: 130,
                            ),
                          ),
                        );
                      }

                      // Insert Big Native Ad at index 4
                      if (index == 4 && !store.isPremium) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF191922),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const AdNativeView(
                              placement: SampleAds.bigNative,
                              height: 300,
                            ),
                          ),
                        );
                      }

                      // Adjust item index accounting for injected ads
                      int taskIndex = index;
                      if (!store.isPremium) {
                        if (index > 4) {
                          taskIndex -= 2;
                        } else if (index > 1) {
                          taskIndex -= 1;
                        }
                      }

                      if (taskIndex >= filteredTasks.length) {
                        return const SizedBox.shrink();
                      }

                      final task = filteredTasks[taskIndex];
                      return TaskTile(
                        task: task,
                        onToggle: () {
                          store.toggleTaskCompletion(task.id);
                          // Interval-based ad trigger: every 3 completions
                          if (store.incrementActionAndCheckInterval(interval: 3)) {
                            store.appendLog('⏱️ [Interval] Task completion threshold reached. Triggering Interstitial...');
                            FlutterAds.show(
                              SampleAds.mainInterstitial,
                              onDismissed: () {
                                store.appendLog('✅ [Interval] Interstitial dismissed. User flow uninterrupted.');
                              },
                            );
                          }
                        },
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: task.id),
                            ),
                          );
                        },
                        onDelete: () => store.deleteTask(task.id),
                      );
                    },
                    childCount: filteredTasks.length + (store.isPremium ? 0 : (filteredTasks.length > 3 ? 2 : 1)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white60)),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF20202A),
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}
