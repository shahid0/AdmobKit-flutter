import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/category_item.dart';
import '../../state/task_store.dart';

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
          orElse: () => store.tasks.first,
        );

        final category = CategoryItem.defaultCategories.firstWhere(
          (c) => c.id == task.categoryId,
          orElse: () => CategoryItem.defaultCategories.first,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14141A),
            title: const Text('Task Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                tooltip: 'Delete Task',
                onPressed: () {
                  store.deleteTask(task.id);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(category.icon, size: 14, color: category.color),
                                const SizedBox(width: 4),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: category.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: task.priority.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${task.priority.label} Priority',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.description.isEmpty ? 'No additional description provided.' : task.description,
                        style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: task.isCompleted ? const Color(0xFF333340) : const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(task.isCompleted ? Icons.undo_rounded : Icons.check_circle_rounded),
                        label: Text(task.isCompleted ? 'Mark Incomplete' : 'Mark Completed'),
                        onPressed: () {
                          store.toggleTaskCompletion(task.id);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Deep Sub-Screen Embedded Big Native Ad
                if (!store.isPremium) ...[
                  const Text(
                    'SPONSORED RECOMMENDATION',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const AdNativeView(
                      placement: SampleAds.bigNative,
                      height: 300,
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
