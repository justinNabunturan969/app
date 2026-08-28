import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repository_bundle.dart';
import '../../app/language_controller.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/skeleton_loading_view.dart';

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

  static List<ShellTab> _tabs(AppCopy copy) => [
    ShellTab(
      label: copy.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    ShellTab(
      label: copy.analytics,
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
    ),
    ShellTab(
      label: copy.borrowings,
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
    ),
    ShellTab(
      label: copy.profile,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
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
          currentIndex: index,
          tabs: _tabs(copy),
          unreadCount: ctrl.unreadCount,
          onTabTap: (i) {
            if (i == index) return;
            setState(() => index = i);
          },
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _ShellBody(
              loading: ctrl.loading,
              error: ctrl.error,
              hasData:
                  ctrl.equipment.isNotEmpty ||
                  ctrl.activeBorrowings.isNotEmpty ||
                  ctrl.notifications.isNotEmpty,
              onRetry: ctrl.load,
              page: _pageForIndex(index),
            ),
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

/// Wraps a tab page with a top-level loading and error state. We only
/// show the loading spinner on the *initial* load (when there's no data
/// to display yet) so the user doesn't see a flash of empty content.
/// Once the first load completes, refreshes go through the per-screen
/// RefreshIndicator instead, which gives a much less jarring UX.
class _ShellBody extends StatelessWidget {
  const _ShellBody({
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
      return const _LoadingScaffold();
    }
    if (error != null && !hasData) {
      return _ErrorScaffold(message: error!, onRetry: onRetry);
    }
    if (error != null) {
      // Soft error: keep the page on screen but show a thin banner at the
      // top so the user knows a refresh would be a good idea.
      return Column(
        children: [
          _ErrorBanner(message: error!, onRetry: onRetry),
          Expanded(child: page),
        ],
      );
    }
    return page;
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const SkeletonLoadingView();
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message, required this.onRetry});

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
              Icon(
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

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
