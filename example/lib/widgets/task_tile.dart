import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../theme/task_theme.dart';

class TaskTile extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = CategoryItem.defaultCategories.firstWhere(
      (c) => c.id == task.categoryId,
      orElse: () => CategoryItem.defaultCategories.first,
    );

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: TaskColors.roseSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TaskColors.roseBorder),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: TaskColors.roseText),
      ),
      onDismissed: (_) => onDelete(),
      child: TactileButton(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TaskColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: task.isCompleted ? TaskColors.borderSubtle : TaskColors.borderStrong,
              width: 1,
            ),
            boxShadow: TaskColors.cardShadow,
          ),
          child: Row(
            children: [
              // Tactile Architectural Checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
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
              ),
              const SizedBox(width: 12),

              // Task Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: task.isCompleted ? TaskColors.textMutedCaption : TaskColors.textInkPrimary,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isCompleted ? TaskColors.textMutedCaption : TaskColors.textSlateMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Category tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: category.color.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(category.icon, size: 11, color: category.color),
                              const SizedBox(width: 4),
                              Text(
                                category.name.split(' ').first,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: category.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Priority indicator
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: task.priority.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.priority.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: task.priority.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: TaskColors.textMutedCaption,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
