import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class TopBorrowedItem {
  const TopBorrowedItem({required this.name, required this.count});

  final String name;
  final int count;
}

class CategoryStat {
  const CategoryStat({
    required this.name,
    required this.pct,
    required this.color,
  });

  final String name;
  final double pct;
  final Color color;
}

class Achievement {
  const Achievement({required this.title, required this.unlocked});

  final String title;
  final bool unlocked;
}

class AnalyticsMockData {
  static const int totalBorrowed = 24;
  static const int activeBorrowings = 3;
  static const double onTimeRate = 0.92;

  static const List<int> weeklyData = [2, 4, 3, 5, 4, 6, 3];

  static const List<TopBorrowedItem> topItems = [
    TopBorrowedItem(name: 'Fluke 87V Multimeter', count: 8),
    TopBorrowedItem(name: 'Arduino UNO R3', count: 6),
    TopBorrowedItem(name: 'Oscilloscope Kit (DSO)', count: 5),
    TopBorrowedItem(name: 'Power Supply 0-30V', count: 3),
    TopBorrowedItem(name: 'Digital Caliper (150mm)', count: 2),
  ];

  static const List<CategoryStat> categories = [
    CategoryStat(
      name: 'Electrical',
      pct: 0.42,
      color: PupColors.techCyan,
    ),
    CategoryStat(
      name: 'Mechanical',
      pct: 0.25,
      color: PupColors.cyberAmber,
    ),
    CategoryStat(
      name: 'Testers',
      pct: 0.20,
      color: PupColors.mintGreen,
    ),
    CategoryStat(
      name: 'Tools',
      pct: 0.13,
      color: PupColors.pupMaroon,
    ),
  ];

  static const List<Achievement> achievements = [
    Achievement(title: 'First Borrow — completed your first checkout', unlocked: true),
    Achievement(title: 'On-Time Hero — 5 consecutive on-time returns', unlocked: true),
    Achievement(title: 'Lab Regular — borrowed 10+ items', unlocked: true),
    Achievement(title: 'Category Explorer — used all equipment categories', unlocked: false),
    Achievement(title: 'Perfect Semester — 100% on-time rate', unlocked: false),
  ];
}
