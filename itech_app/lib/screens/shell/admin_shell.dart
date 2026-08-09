import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repository_bundle.dart';
import '../../app/language_controller.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/responsive_scaffold.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_inventory_screen.dart';
import '../admin/admin_login_history_screen.dart';
import '../admin/admin_pending_requests_screen.dart';
import '../admin/admin_scan_screen.dart';
import '../student/student_notifications_screen.dart';

/// Admin shell — hosts the 5 admin tabs (Dashboard, Login History,
/// Inventory, Pending, Scan). On mobile it renders a glass bottom-nav;
/// on desktop / Chrome it renders a side NavigationRail. Each tab
/// provides its own header, so the shell intentionally has no AppBar.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static List<ShellTab> _tabs(AppCopy copy) => [
    ShellTab(
      label: copy.dashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    ShellTab(
      label: 'History',
      icon: Icons.history_edu_outlined,
      selectedIcon: Icons.history_edu_rounded,
    ),
    ShellTab(
      label: copy.inventory,
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
    ),
    ShellTab(
      label: copy.pending,
      icon: Icons.pending_actions_outlined,
      selectedIcon: Icons.pending_actions_rounded,
    ),
    ShellTab(
      label: copy.scan,
      icon: Icons.qr_code_scanner_rounded,
      selectedIcon: Icons.qr_code_scanner_rounded,
    ),
    ShellTab(
      label: copy.notifications,
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StudentDashboardController>(
      create: (ctx) =>
          StudentDashboardController(bundle: ctx.read<RepositoryBundle>())
            ..load(),
      builder: (context, _) {
        final ctrl = context.watch<StudentDashboardController>();
        final copy = AppCopy(context.watch<LanguageController>().language);
        return ResponsiveScaffold(
          currentIndex: _index,
          tabs: _tabs(copy),
          unreadCount: ctrl.unreadCount,
          onTabTap: (i) {
            if (i == _index) return;
            HapticFeedback.selectionClick();
            setState(() => _index = i);
          },
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: _AdminShellBody(
                loading: ctrl.loading,
                error: ctrl.error,
                hasData:
                    ctrl.equipment.isNotEmpty ||
                    ctrl.activeBorrowings.isNotEmpty ||
                    ctrl.notifications.isNotEmpty,
                onRetry: ctrl.load,
                page: _pageForIndex(_index),
              ),
            ),
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
        return AdminLoginHistoryScreen(onSwitchTab: switchTo);
      case 2:
        return const AdminInventoryScreen();
      case 3:
        return const AdminPendingRequestsScreen();
      case 4:
        return const AdminScanScreen();
      case 5:
        return const StudentNotificationsScreen();
      case 0:
      default:
        return AdminDashboardScreen(onSwitchTab: switchTo);
    }
  }
}

/// Wraps a tab page with a top-level loading / error / banner state.
/// Same UX as the student shell: only the very first load gets a full
/// spinner, and subsequent refresh failures degrade to a slim banner so
/// the admin can still work with the data they already have.
class _AdminShellBody extends StatelessWidget {
  const _AdminShellBody({
    required this.loading,
    required this.error,
    required this.hasData,
    required this.onRetry,
    required this.page,
  });

  final bool loading;
  final String? error;
  final bool hasData;
  final Future<void> Function() onRetry;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    if (loading && !hasData) {
      return const _AdminLoadingScaffold();
    }
    if (error != null && !hasData) {
      return _AdminErrorScaffold(message: error!, onRetry: onRetry);
    }
    if (error != null) {
      return Column(
        children: [
          _AdminErrorBanner(message: error!, onRetry: onRetry),
          Expanded(child: page),
        ],
      );
    }
    return page;
  }
}

class _AdminLoadingScaffold extends StatelessWidget {
  const _AdminLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? PupColors.cyberAmber : PupColors.signalRed;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tint),
            const SizedBox(height: 14),
            Text(
              'Loading from Supabase…',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).hintColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminErrorScaffold extends StatelessWidget {
  const _AdminErrorScaffold({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: PupColors.signalRed,
              ),
              const SizedBox(height: 14),
              const Text(
                "Couldn't reach the database",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminErrorBanner extends StatelessWidget {
  const _AdminErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PupColors.signalRed.withValues(alpha: 0.10),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: PupColors.signalRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
