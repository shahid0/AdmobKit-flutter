import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/task_item.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';
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
        final filteredTasks = _getFilteredTasks(allTasks);

        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          floatingActionButton: _buildFloatingActionButton(context),
          body: Column(
            children: [
              _buildStickyHeader(store),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      sliver: filteredTasks.isEmpty
                          ? SliverToBoxAdapter(
                              child: _buildEmptyState(),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final adCount = filteredTasks.length >= 3
                                      ? 2
                                      : (filteredTasks.isNotEmpty ? 1 : 0);

                                  if (index == 1) {
                                    if (store.isPremium) {
                                      return const SizedBox.shrink();
                                    }
                                    return _buildNativeAdCard(
                                      placement: SampleAds.mediumNative,
                                      height: NativeAdTemplate.medium.height,
                                    );
                                  }

                                  if (index == 4 && adCount == 2) {
                                    if (store.isPremium) {
                                      return const SizedBox.shrink();
                                    }
                                    return _buildNativeAdCard(
                                      placement: SampleAds.bigNative,
                                      height: NativeAdTemplate.big.height,
                                    );
                                  }

                                  int taskIndex = index;
                                  if (index > 4 && adCount == 2) {
                                    taskIndex -= 2;
                                  } else if (index > 1) {
                                    taskIndex -= 1;
                                  }

                                  if (taskIndex < 0 || taskIndex >= filteredTasks.length) {
                                    return const SizedBox.shrink();
                                  }

                                  final task = filteredTasks[taskIndex];
                                  return TaskTile(
                                    task: task,
                                    onToggle: () {
                                      store.toggleTaskCompletion(task.id);
                                      if (store.incrementActionAndCheckInterval(interval: 3)) {
                                        store.appendLog(
                                          '⏱️ [Interval] Task completion threshold reached. Triggering Interstitial...',
                                        );
                                        FlutterAds.show(
                                          SampleAds.mainInterstitial,
                                          onDismissed: () {
                                            store.appendLog(
                                              '✅ [Interval] Interstitial dismissed. User flow uninterrupted.',
                                            );
                                          },
                                        );
                                      }
                                    },
                                    onTap: () {
                                      if (store.checkInterval('task_detail_navigation', interval: 4)) {
                                        FlutterAds.show(
                                          SampleAds.mainInterstitial,
                                          onDismissed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => TaskDetailScreen(taskId: task.id),
                                              ),
                                            );
                                          },
                                        );
                                      } else {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => TaskDetailScreen(taskId: task.id),
                                          ),
                                        );
                                      }
                                    },
                                    onDelete: () {
                                      store.deleteTask(task.id);
                                      if (store.checkInterval('task_delete', interval: 3)) {
                                        store.appendLog(
                                          '🗑️ [Action] Task deletion threshold reached. Triggering Interstitial...',
                                        );
                                        FlutterAds.show(
                                          SampleAds.mainInterstitial,
                                          onDismissed: () {},
                                        );
                                      }
                                    },
                                  );
                                },
                                childCount: filteredTasks.length +
                                    (filteredTasks.length >= 3
                                        ? 2
                                        : (filteredTasks.isNotEmpty ? 1 : 0)),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<TaskItem> _getFilteredTasks(List<TaskItem> allTasks) {
    switch (_filter) {
      case 'PENDING':
        return allTasks.where((t) => !t.isCompleted).toList();
      case 'DONE':
        return allTasks.where((t) => t.isCompleted).toList();
      case 'ALL':
      default:
        return allTasks;
    }
  }

  Widget _buildStickyHeader(TaskStore store) {
    return Container(
      decoration: const BoxDecoration(
        color: TaskColors.surfaceCard,
        border: Border(
          bottom: BorderSide(color: TaskColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Tasks',
                      style: TextStyle(
                        color: TaskColors.textInkPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${store.pendingTasksCount} pending • ${store.completedTasksCount} done',
                      style: const TextStyle(
                        color: TaskColors.textSlateMedium,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (store.isPremium) ...[
                const SizedBox(width: 8),
                StatusBadge.emerald(
                  'PRO ACTIVE',
                  icon: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: TaskColors.emeraldText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFilterChip(
                label: 'All',
                isSelected: _filter == 'ALL',
                onTap: () => setState(() => _filter = 'ALL'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Pending',
                isSelected: _filter == 'PENDING',
                onTap: () => setState(() => _filter = 'PENDING'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Done',
                isSelected: _filter == 'DONE',
                onTap: () => setState(() => _filter = 'DONE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? TaskColors.accentPrimary : TaskColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? TaskColors.accentPrimary : TaskColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: isSelected ? Colors.white : TaskColors.textSlateMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNativeAdCard({
    required NativePlacement placement,
    required double height,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TaskCard(
        padding: const EdgeInsets.all(10),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: TaskColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: TaskColors.borderSubtle),
                  ),
                  child: const Text(
                    'SPONSORED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: TaskColors.textMutedCaption,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdNativeView(
                placement: placement,
                height: height,
                placeholder: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: TaskColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TaskColors.borderSubtle),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: TaskColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TaskColors.borderSubtle),
          boxShadow: TaskColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: TaskColors.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: TaskColors.borderSubtle),
              ),
              child: const Icon(
                Icons.checklist_rounded,
                color: TaskColors.textSlateMedium,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Tasks Found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TaskColors.textInkPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All objectives clear. Tap New Task to architect your next goal.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: TaskColors.textSlateMedium,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return TactileButton(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: TaskColors.accentPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: TaskColors.accentPrimary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'New Task',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
