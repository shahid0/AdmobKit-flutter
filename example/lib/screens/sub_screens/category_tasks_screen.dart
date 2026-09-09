import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/category_item.dart';
import '../../state/task_store.dart';
import '../../widgets/task_tile.dart';
import 'task_detail_screen.dart';

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
          backgroundColor: const Color(0xFF0F0F14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14141A),
            title: Row(
              children: [
                Icon(category.icon, color: category.color, size: 20),
                const SizedBox(width: 8),
                Text(category.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(category.icon, size: 48, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text('No tasks in ${category.name}', style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return TaskTile(
                            task: task,
                            onToggle: () => store.toggleTaskCompletion(task.id),
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
                      ),
              ),

              // Embedded Medium Native Ad in category detail
              if (!store.isPremium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const AdNativeView(
                      placement: SampleAds.mediumNative,
                      height: 130,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
