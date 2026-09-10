import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/category_item.dart';
import '../../models/task_item.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';

/// Architectural Light Theme task creation screen.
///
/// Implements `.uispec/specs/create_task_screen.spec.md` and
/// `.uispec/content/create_task_screen.slots.md`.
class CreateTaskScreen extends StatefulWidget {
  static const String routeName = '/create-task';

  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategoryId = 'work';
  TaskPriority _selectedPriority = TaskPriority.medium;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter a task title',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: TaskColors.textInkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final newTask = TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: _descController.text.trim(),
      categoryId: _selectedCategoryId,
      priority: _selectedPriority,
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );

    TaskStore.instance.addTask(newTask);
    if (TaskStore.instance.checkInterval('task_create', interval: 2)) {
      TaskStore.instance.appendLog('📝 [Action] Task creation threshold reached. Triggering Interstitial...');
      FlutterAds.show(
        SampleAds.mainInterstitial,
        onDismissed: () {
          if (mounted) Navigator.of(context).pop();
        },
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  int _getTierLevel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      appBar: AppBar(
        backgroundColor: TaskColors.canvasGround,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TaskColors.textInkPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create New Task',
          style: TextStyle(
            color: TaskColors.textInkPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TASK TITLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TaskColors.textMutedCaption,
                        letterSpacing: 0.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      autofocus: true,
                      style: const TextStyle(
                        color: TaskColors.textInkPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: TaskColors.surfaceCard,
                        hintText: 'e.g. Implement Paywall Close Guard',
                        hintMaxLines: 2,
                        hintStyle: const TextStyle(
                          color: TaskColors.textMutedCaption,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TaskColors.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TaskColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TaskColors.accentPrimary, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'DESCRIPTION & NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TaskColors.textMutedCaption,
                        letterSpacing: 0.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      style: const TextStyle(
                        color: TaskColors.textInkPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: TaskColors.surfaceCard,
                        hintText: 'Add technical specifications, acceptance criteria, or reminders...',
                        hintMaxLines: 2,
                        hintStyle: const TextStyle(
                          color: TaskColors.textMutedCaption,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TaskColors.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TaskColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TaskColors.accentPrimary, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TaskColors.textMutedCaption,
                        letterSpacing: 0.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: CategoryItem.defaultCategories.map((c) {
                        final isSelected = _selectedCategoryId == c.id;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedCategoryId = c.id),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected ? TaskColors.accentSubtle : TaskColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? TaskColors.accentPrimary : TaskColors.borderSubtle,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected ? null : TaskColors.cardShadow,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  c.icon,
                                  size: 20,
                                  color: isSelected ? TaskColors.accentPrimary : c.color,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'PRIORITY LEVEL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TaskColors.textMutedCaption,
                        letterSpacing: 0.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: TaskPriority.values.map((p) {
                        final isSelected = _selectedPriority == p;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedPriority = p),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected ? TaskColors.accentSubtle : TaskColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? TaskColors.accentPrimary : TaskColors.borderSubtle,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected ? null : TaskColors.cardShadow,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      p == TaskPriority.high
                                          ? Icons.priority_high_rounded
                                          : (p == TaskPriority.medium
                                              ? Icons.drag_handle_rounded
                                              : Icons.arrow_downward_rounded),
                                      size: 16,
                                      color: isSelected ? TaskColors.accentPrimary : p.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(3, (dotIndex) {
                                        final isActiveTier = dotIndex < _getTierLevel(p);
                                        return Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isActiveTier
                                                ? (isSelected ? TaskColors.accentPrimary : p.color)
                                                : TaskColors.borderSubtle,
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: TaskColors.canvasGround,
                border: Border(
                  top: BorderSide(color: TaskColors.borderSubtle, width: 1),
                ),
              ),
              child: TactileButton(
                onTap: _saveTask,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TaskColors.accentPrimary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: TaskColors.accentPrimary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Save Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
