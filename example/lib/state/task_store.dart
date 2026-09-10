import 'package:flutter/material.dart';
import '../models/task_item.dart';

class TaskStore extends ChangeNotifier {
  static final TaskStore instance = TaskStore._internal();
  TaskStore._internal() {
    _initSampleTasks();
  }

  // --- State Variables ---
  bool _isPremium = false;
  bool _isProThemeUnlocked = false;

  final List<TaskItem> _tasks = [];
  final ValueNotifier<List<String>> liveLogs = ValueNotifier<List<String>>([]);

  // --- Getters ---
  bool get isPremium => _isPremium;
  bool get isProThemeUnlocked => _isProThemeUnlocked;
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  int get totalTasksCount => _tasks.length;
  int get completedTasksCount => _tasks.where((t) => t.isCompleted).length;
  int get pendingTasksCount => _tasks.where((t) => !t.isCompleted).length;

  void togglePremium(bool value) {
    _isPremium = value;
    appendLog('👑 VIP Status changed: ${_isPremium ? "PRO ACTIVATED" : "FREE TIER"}');
    notifyListeners();
  }

  void unlockProTheme() {
    _isProThemeUnlocked = true;
    appendLog('🎨 Pro theme unlocked via Rewarded Ad!');
    notifyListeners();
  }

  void addTask(TaskItem task) {
    _tasks.insert(0, task);
    appendLog('📝 Task added: "${task.title}"');
    notifyListeners();
  }

  void updateTask(TaskItem updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _tasks[index] = updated;
      appendLog('✏️ Task updated: "${updated.title}"');
      notifyListeners();
    }
  }

  void toggleTaskCompletion(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _tasks[index];
      _tasks[index] = t.copyWith(isCompleted: !t.isCompleted);
      appendLog('✅ Task status toggled: "${t.title}" -> ${_tasks[index].isCompleted ? "DONE" : "PENDING"}');
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _tasks.removeAt(index);
      appendLog('🗑️ Task deleted: "${t.title}"');
      notifyListeners();
    }
  }

  final Map<String, int> _actionCounters = {};

  /// Checks and increments a named counter (e.g. 'task_clicks', 'navigation').
  /// Returns true when [interval] is reached and resets that counter.
  bool checkInterval(String key, {int interval = 3}) {
    if (_isPremium) return false;
    final current = (_actionCounters[key] ?? 0) + 1;
    if (current >= interval) {
      _actionCounters[key] = 0;
      return true;
    }
    _actionCounters[key] = current;
    return false;
  }

  /// Increments default action counter and returns true if threshold is reached.
  bool incrementActionAndCheckInterval({int interval = 3}) {
    return checkInterval('default', interval: interval);
  }

  void appendLog(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final time = DateTime.now().toIso8601String().substring(11, 19);
      liveLogs.value = [
        '[$time] $message',
        ...liveLogs.value.take(49),
      ];
    });
  }

  void _initSampleTasks() {
    final now = DateTime.now();
    _tasks.addAll([
      TaskItem(
        id: '1',
        title: 'Review Q3 monetization metrics',
        description: 'Analyze AdMob eCPM, interstitial fill rates, and paywall conversions.',
        categoryId: 'work',
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(hours: 4)),
      ),
      TaskItem(
        id: '2',
        title: 'Prepare design brief for logo maker',
        description: 'Incorporate new atomic design specs and responsive reflow constraints.',
        categoryId: 'work',
        priority: TaskPriority.medium,
        dueDate: now.add(const Duration(days: 1)),
      ),
      TaskItem(
        id: '3',
        title: 'Evening 5km run & stretching',
        description: 'Maintain cardio routine for upcoming weekend marathon.',
        categoryId: 'fitness',
        priority: TaskPriority.low,
        dueDate: now.add(const Duration(hours: 6)),
      ),
      TaskItem(
        id: '4',
        title: 'Review monthly cloud server invoice',
        description: 'Verify database autoscaling compute costs and storage backups.',
        categoryId: 'finance',
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 2)),
      ),
      TaskItem(
        id: '5',
        title: 'Read 2 chapters of System Design Interview',
        description: 'Focus on distributed cache invalidation and database sharding.',
        categoryId: 'study',
        priority: TaskPriority.medium,
        dueDate: now.add(const Duration(days: 3)),
      ),
      TaskItem(
        id: '6',
        title: 'Call family & schedule weekend dinner',
        description: 'Confirm restaurant reservations for Saturday evening.',
        categoryId: 'personal',
        priority: TaskPriority.low,
        isCompleted: true,
        dueDate: now.subtract(const Duration(hours: 2)),
      ),
    ]);
  }
}
