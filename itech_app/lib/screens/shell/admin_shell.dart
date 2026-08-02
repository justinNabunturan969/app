import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_inventory_screen.dart';
import '../admin/admin_occupancy_screen.dart';
import '../admin/admin_pending_requests_screen.dart';
import '../admin/admin_scan_screen.dart';

/// Admin shell — hosts the 5 admin tabs (Dashboard, Inventory, Pending,
/// Scan, Live) behind a glass bottom-nav. Each tab renders its own
/// header, so the shell intentionally has no AppBar.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec('Dashboard', Icons.dashboard_customize_rounded, 0),
    _TabSpec('Live', Icons.podcasts_rounded, 1),
    _TabSpec('Inventory', Icons.inventory_2_rounded, 2),
    _TabSpec('Pending', Icons.pending_actions_rounded, 3),
    _TabSpec('Scan', Icons.qr_code_scanner_rounded, 4),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StudentDashboardController>(
      create: (_) => StudentDashboardController(),
      builder: (context, _) {
        return Scaffold(
          // No AppBar — each tab provides its own header.
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: _pageForIndex(_index),
            ),
          ),
          bottomNavigationBar: _BottomGlassNav(
            currentIndex: _index,
            tabs: _tabs,
            onTap: (i) {
              if (i == _index) return;
              HapticFeedback.selectionClick();
              setState(() => _index = i);
            },
          ),
        );
      },
    );
  }

  Widget _pageForIndex(int i) {
    void switchTo(int j) {
      if (!mounted || j == _index) return;
      HapticFeedback.selectionClick();
      setState(() => _index = j);
    }

    switch (i) {
      case 1:
        return AdminOccupancyScreen(onSwitchTab: switchTo);
      case 2:
        return const AdminInventoryScreen();
      case 3:
        return const AdminPendingRequestsScreen();
      case 4:
        return const AdminScanScreen();
      case 0:
      default:
        return AdminDashboardScreen(onSwitchTab: switchTo);
    }
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.index);
  final String label;
  final IconData icon;
  final int index;
}

// ─────────────────────────────────────────────────────────────────────────
// Glass bottom nav — mirrors the student shell's pattern, including the
// red-in-light-mode active color introduced in the light-mode pass.
// ─────────────────────────────────────────────────────────────────────────

class _BottomGlassNav extends StatelessWidget {
  const _BottomGlassNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark
        ? PupColors.deepMahogany.withValues(alpha: 0.78)
        : PupColors.lightCardAlt.withValues(alpha: 0.95);
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : PupColors.ashGray.withValues(alpha: 0.75);

    // Light mode → red active item; dark mode → amber (unchanged).
    final activeColor =
        isDark ? PupColors.cyberAmber : PupColors.signalRed;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
      ),
      child: Container(
        color: navBg,
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 8,
            selectedItemColor: activeColor,
            unselectedItemColor: unselectedColor,
            items: tabs
                .map(
                  (t) => BottomNavigationBarItem(
                    icon: _AdminNavIcon(
                      icon: Icon(t.icon),
                      selected: t.index == currentIndex,
                      activeColor: activeColor,
                    ),
                    label: t.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _AdminNavIcon extends StatelessWidget {
  const _AdminNavIcon({
    required this.icon,
    required this.selected,
    required this.activeColor,
  });

  final Icon icon;
  final bool selected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, selected ? -4.0 : 0.0, 0.0, 1.0)
        ..scaleByDouble(selected ? 1.08 : 1.0, selected ? 1.08 : 1.0, 1.0, 1.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected)
            Positioned(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.30),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          // Light mode glow follows the (red) active color.
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.20),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.10),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                ),
              ),
            ),
          IconTheme(
            data: IconThemeData(
              color: selected ? activeColor : null,
              size: 26,
            ),
            child: icon,
          ),
        ],
      ),
    );
  }
}
