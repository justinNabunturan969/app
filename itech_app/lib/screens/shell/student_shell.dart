import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';

import '../student/student_borrowings_screen.dart';
import '../student/student_home_screen.dart';
import '../student/student_notifications_screen.dart';
import '../student/student_profile_screen.dart';
import '../../features/analytics/analytics_page.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;

  static const tabs = [
    _TabSpec('Home', Icons.home_rounded, 0),
    _TabSpec('Analytics', Icons.analytics_rounded, 1),
    _TabSpec('Borrowings', Icons.history_rounded, 2),
    _TabSpec('Profile', Icons.person_rounded, 3),
    _TabSpec('Notifications', Icons.notifications_rounded, 4),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StudentDashboardController(),
      builder: (context, _) {
        final ctrl = context.watch<StudentDashboardController>();
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _pageForIndex(index),
          ),
          bottomNavigationBar: _BottomStudentNav(
            currentIndex: index,
            tabs: tabs,
            unreadCount: ctrl.unreadCount,
            onTap: (i) {
              if (i == index) return;
              // Light vibration/haptic on tab switch (safe prototype)
              // On some platforms the haptic API may not be available, so keep it optional.
              try {
                // ignore: deprecated_member_use
                // ignore: invalid_use_of_protected_member
                // ignore: unnecessary_statements
                // Haptic feedback not used in this repo build yet.
                // (Call your preferred haptics plugin here once configured.)
              } catch (_) {
                // no-op
              }

              setState(() => index = i);
            },
          ),
        );
      },
    );
  }

  Widget _pageForIndex(int i) {
    switch (i) {
      case 0:
        return const StudentHomeScreen();
      case 1:
        return const AnalyticsPage();

      case 2:
        return const StudentBorrowingsScreen();
      case 3:
        return const StudentProfileScreen();
      case 4:
        return const StudentNotificationsScreen();
      default:
        return const StudentHomeScreen();
    }
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.index);

  final String label;
  final IconData icon;
  final int index;
}

class _BottomStudentNav extends StatelessWidget {
  const _BottomStudentNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    required this.unreadCount,
  });

  final int currentIndex;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark
        ? PupColors.deepMahogany.withValues(alpha: 0.78)
        : PupColors.lightCardAlt.withValues(alpha: 0.92);

    // Light mode → red active item; dark mode → amber (unchanged).
    final activeColor =
        isDark ? PupColors.cyberAmber : PupColors.signalRed;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
      ),
      child: BottomNavigationBarTheme(
        data: Theme.of(context).bottomNavigationBarTheme,
        child: Container(
          color: navBg,
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: currentIndex,
              onTap: onTap,
              backgroundColor: Colors.transparent,
              elevation: 8,
              items: tabs.map((t) {
                final selected = t.index == currentIndex;
                final color = selected
                    ? activeColor
                    : (isDark
                          ? PupColors.ashGray
                          : PupColors.ashGray.withValues(alpha: 0.75));

                Widget icon = _AnimatedNavIcon(
                  icon: t.icon,
                  color: color,
                  selected: selected,
                  activeColor: activeColor,
                );

                if (t.label == 'Notifications' && unreadCount > 0) {
                  icon = Stack(
                    clipBehavior: Clip.none,
                    children: [
                      icon,
                      Positioned(
                        top: -6,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PupColors.signalRed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return BottomNavigationBarItem(icon: icon, label: t.label);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedNavIcon extends StatelessWidget {
  const _AnimatedNavIcon({
    required this.icon,
    required this.color,
    required this.selected,
    required this.activeColor,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, selected ? -5.0 : 0.0, 0.0, 1.0)
        ..scaleByDouble(selected ? 1.1 : 1.0, selected ? 1.1 : 1.0, 1.0, 1.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected)
            Positioned(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: PupColors.cyberAmber.withValues(alpha: 0.30),
                            blurRadius: 24,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: PupColors.cyberAmber.withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          // Light mode glow follows the (red) active color.
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.12),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.06),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                ),
              ),
            ),
          Icon(icon, color: color, size: 26),
        ],
      ),
    );
  }
}
