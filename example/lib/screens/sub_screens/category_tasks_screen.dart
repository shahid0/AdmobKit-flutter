import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/category_item.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';
import '../../widgets/task_tile.dart';
import 'task_detail_screen.dart';

/// Architectural Light Theme screen displaying tasks filtered by category.
///
/// Implements `.uispec/specs/category_tasks_screen.spec.md` and
/// `.uispec/content/category_tasks_screen.slots.md`.
class CategoryTasksScreen extends StatelessWidget {
  final CategoryItem category;

  const CategoryTasksScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tasks = store.tasks.where((t) => t.categoryId == category.id).toList();

        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          appBar: AppBar(
            backgroundColor: TaskColors.canvasGround,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: TaskColors.textInkPrimary),
            title: Row(
              children: [
                Icon(category.icon, color: category.color, size: 20),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: const TextStyle(
                    color: TaskColors.textInkPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: TaskCard(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                            borderRadius: 16,
                            backgroundColor: TaskColors.surfaceCard,
                            border: Border.all(color: TaskColors.borderSubtle),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: category.color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: category.color.withValues(alpha: 0.2)),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: category.color,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No tasks in this workspace',
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
                                  'All objectives clear. Tap the floating action button to create objectives under this category.',
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
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return TaskTile(
                            task: task,
                            onToggle: () => store.toggleTaskCompletion(task.id),
                            onTap: () {
                              void navigate() {
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TaskDetailScreen(taskId: task.id),
                                    ),
                                  );
                                }
                              }

                              if (FlutterAds.recordActionAndCheckInterval('task_detail_navigation', interval: 4)) {
                                TaskStore.instance.appendLog('🔍 [Action] Task detail navigation threshold reached. Triggering Interstitial...');
                                FlutterAds.show(
                                  SampleAds.mainInterstitial,
                                  onDismissed: navigate,
                                );
                              } else {
                                navigate();
                              }
                            },
                            onDelete: () {
                              store.deleteTask(task.id);
                              if (FlutterAds.recordActionAndCheckInterval('task_delete', interval: 3)) {
                                TaskStore.instance.appendLog('🗑️ [Action] Task deletion threshold reached. Triggering Interstitial...');
                                FlutterAds.show(
                                  SampleAds.mainInterstitial,
                                  onDismissed: () {},
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
              if (!store.isPremium)
                _buildNativeAdCard()
              else
                const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNativeAdCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: TaskColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TaskColors.borderSubtle),
          boxShadow: TaskColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TaskColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TaskColors.borderSubtle),
                ),
                child: const Text(
                  'SPONSORED RECOMMENDATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: TaskColors.textMutedCaption,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            AdNativeView(
              placement: SampleAds.mediumNative,
              height: 130,
              placeholder: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: TaskColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaskColors.borderSubtle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
