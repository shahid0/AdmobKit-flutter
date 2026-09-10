import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/category_item.dart';
import '../../models/task_item.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final task = store.tasks.firstWhere(
          (t) => t.id == taskId,
          orElse: () => store.tasks.isNotEmpty
              ? store.tasks.first
              : TaskItem(
                  id: taskId,
                  title: 'Task Details',
                  description: '',
                  categoryId: 'work',
                  priority: TaskPriority.medium,
                  dueDate: DateTime.now(),
                ),
        );

        final category = CategoryItem.defaultCategories.firstWhere(
          (c) => c.id == task.categoryId,
          orElse: () => CategoryItem.defaultCategories.first,
        );

        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          appBar: AppBar(
            backgroundColor: TaskColors.canvasGround,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Task Details',
              style: TextStyle(
                color: TaskColors.textInkPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: TaskColors.roseText),
                tooltip: 'Delete Task',
                onPressed: () {
                  store.deleteTask(task.id);
                  if (TaskStore.instance.checkInterval('task_delete', interval: 3)) {
                    TaskStore.instance.appendLog('🗑️ [Action] Task deletion threshold reached. Triggering Interstitial...');
                    FlutterAds.show(
                      SampleAds.mainInterstitial,
                      onDismissed: () {
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    );
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: category.color.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(category.icon, size: 14, color: category.color),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      category.name.split(' ').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: category.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: '${task.priority.label} Priority',
                            textColor: task.priority.color,
                            surfaceColor: task.priority.color.withValues(alpha: 0.1),
                            borderColor: task.priority.color.withValues(alpha: 0.25),
                            icon: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.priority.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: task.isCompleted ? TaskColors.textMutedCaption : TaskColors.textInkPrimary,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.description.isEmpty
                            ? 'No additional description provided.'
                            : task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: TaskColors.textSlateMedium,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TactileButton(
                        onTap: () {
                          store.toggleTaskCompletion(task.id);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? TaskColors.surfaceSubtle
                                : TaskColors.accentPrimary,
                            borderRadius: BorderRadius.circular(10),
                            border: task.isCompleted
                                ? Border.all(color: TaskColors.borderSubtle)
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                task.isCompleted ? Icons.undo_rounded : Icons.check_circle_rounded,
                                color: task.isCompleted ? TaskColors.textInkPrimary : Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                task.isCompleted ? 'Mark Incomplete' : 'Mark Completed',
                                style: TextStyle(
                                  color: task.isCompleted ? TaskColors.textInkPrimary : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'EXECUTION CHECKLIST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: TaskColors.textMutedCaption,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                TaskCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  borderRadius: 16,
                  onTap: () => store.toggleTaskCompletion(task.id),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.isCompleted ? TaskColors.accentPrimary : Colors.transparent,
                          border: Border.all(
                            color: task.isCompleted ? TaskColors.accentPrimary : TaskColors.borderStrong,
                            width: 1.5,
                          ),
                        ),
                        child: task.isCompleted
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: TaskColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: task.isCompleted ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: TaskColors.accentPrimary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!store.isPremium) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'SPONSORED RECOMMENDATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: TaskColors.textMutedCaption,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: TaskColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TaskColors.borderSubtle),
                      boxShadow: TaskColors.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AdNativeView(
                      placement: SampleAds.bigNative,
                      template: NativeAdTemplate.big,
                      placeholder: Container(
                        height: NativeAdTemplate.big.height,
                        width: NativeAdTemplate.big.width,
                        decoration: BoxDecoration(
                          color: TaskColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TaskColors.borderSubtle),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
