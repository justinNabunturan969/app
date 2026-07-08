import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;

  static const tabs = [
    _TabSpec('Home', Icons.home_rounded),
    _TabSpec('Search', Icons.search_rounded),
    _TabSpec('Borrowings', Icons.history_rounded),
    _TabSpec('Profile', Icons.person_rounded),
    _TabSpec('Notifications', Icons.notifications_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Student Dashboard (tab: ${tabs[index].label})\nPrototype shell',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBar: _BottomGlassNav(
        currentIndex: index,
        items: tabs
            .map(
              (t) =>
                  BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
        onTap: (i) => setState(() => index = i),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _BottomGlassNav extends StatelessWidget {
  const _BottomGlassNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: PupColors.deepMahogany.withValues(alpha: 0.78),
        elevation: 8,
        selectedItemColor: PupColors.cyberAmber,
        unselectedItemColor: Colors.white.withValues(alpha: 0.7),
        items: items,
      ),
    );
  }
}
