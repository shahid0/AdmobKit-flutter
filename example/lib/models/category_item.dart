import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<CategoryItem> defaultCategories = [
    CategoryItem(
      id: 'work',
      name: 'Work & Projects',
      icon: Icons.work_rounded,
      color: Color(0xFF6366F1),
    ),
    CategoryItem(
      id: 'personal',
      name: 'Personal Life',
      icon: Icons.person_rounded,
      color: Color(0xFFEC4899),
    ),
    CategoryItem(
      id: 'fitness',
      name: 'Health & Fitness',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFF10B981),
    ),
    CategoryItem(
      id: 'finance',
      name: 'Bills & Finance',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFF59E0B),
    ),
    CategoryItem(
      id: 'study',
      name: 'Learning & Study',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF8B5CF6),
    ),
  ];
}
