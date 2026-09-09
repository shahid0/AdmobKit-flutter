import 'package:flutter/material.dart';

enum TaskPriority {
  high('High', Color(0xFFEF4444)),
  medium('Medium', Color(0xFFF59E0B)),
  low('Low', Color(0xFF10B981));

  final String label;
  final Color color;
  const TaskPriority(this.label, this.color);
}

class TaskItem {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final bool isCompleted;
  final TaskPriority priority;
  final DateTime dueDate;

  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    required this.dueDate,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? dueDate,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
