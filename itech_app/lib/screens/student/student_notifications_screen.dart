import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/notification_views.dart';

/// Notifications tab (full-page surface).
///
/// Used by the admin shell. The student shell now surfaces notifications
/// through the header bell popover (`NotificationsBellButton`) instead of a
/// tab, but both render the exact same feed via the shared widgets in
/// `notification_views.dart`.
///
/// Surfaces every entry in `StudentDashboardController.notifications`, with
/// type-based coloring, swipe-to-delete, and quick "mark all read" /
/// "clear all" actions.
class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  int _filter = 0; // 0=All, 1=Unread
  static const _filters = ['All', 'Unread'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? scheme.onSurface : PupColors.slateGray;
    final subtleText = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Consumer<StudentDashboardController>(
      builder: (context, ctrl, _) {
        final all = ctrl.notifications;
        final unread = ctrl.unreadCount;
        final filtered = _filter == 1
            ? all.where((n) => !n.isRead).toList()
            : all;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            if (unread > 0)
                              TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ctrl.markAllRead();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: PupColors.amberText(context),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            const ThemeMenuButton(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          all.isEmpty
                              ? 'No notifications yet.'
                              : (unread > 0
                                    ? '$unread unread ${unread == 1 ? 'notification' : 'notifications'}'
                                    : 'All caught up'),
                          style: TextStyle(
                            color: all.isEmpty
                                ? subtleText
                                : (unread > 0
                                      ? PupColors.amberText(context)
                                      : PupColors.successText(context)),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        NotificationFilterChips(
                          selected: _filter,
                          filters: _filters,
                          onSelected: (i) => setState(() => _filter = i),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (all.isEmpty)
                  SliverToBoxAdapter(
                    child: NotificationEmptyState(
                      icon: Icons.notifications_off_rounded,
                      label: 'No notifications yet',
                      hint: "You'll see updates about your borrowings here.",
                      subtleText: subtleText,
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: NotificationEmptyState(
                      icon: Icons.done_all_rounded,
                      label: 'No unread notifications',
                      hint: "You're all caught up. Nice.",
                      subtleText: subtleText,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = filtered[i];
                        // Return-related notifications are heads-ups,
                        // not actions. The admin confirms or rejects
                        // from the Pending → Returns tab; tapping the
                        // card used to just mark it read, which the old
                        // "Tap to record the condition" copy implied
                        // was something more.
                        final isReturnAlert = n.type == NotificationType.returned;
                        final style = notificationStyleFor(n.type);
                        return Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: const NotificationSwipeDeleteBackground(),
                          onDismissed: (_) {
                            HapticFeedback.mediumImpact();
                            ctrl.deleteNotification(n.id);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Notification deleted'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                          },
                          child: NotificationCard(
                            notification: n,
                            onTap: (isReturnAlert || n.isRead)
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    ctrl.markRead(n.id);
                                  },
                            footer: isReturnAlert
                                ? NotificationActionHint(
                                    text: 'Open Pending → Returns to confirm or reject',
                                    accent: style.tone,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                if (all.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _confirmClearAll(context, ctrl),
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Clear all notifications',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: PupColors.signalRed,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    StudentDashboardController ctrl,
  ) async {
    HapticFeedback.lightImpact();
    final count = ctrl.notifications.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: Text(
          'This will permanently remove all $count '
          '${count == 1 ? 'notification' : 'notifications'}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: PupColors.signalRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ctrl.clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications cleared'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
