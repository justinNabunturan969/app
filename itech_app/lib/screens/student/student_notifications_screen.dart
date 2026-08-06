import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';

/// Notifications tab.
///
/// Surfaces every entry in `StudentDashboardController.notifications`, with
/// type-based coloring, swipe-to-delete, and quick "mark all read" /
/// "clear all" actions. Reuses the PupColors / PupGlass / tinted icon chip
/// language shared by the other student tabs.
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
                                  foregroundColor: PupColors.cyberAmber,
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
                                      ? PupColors.cyberAmber
                                      : PupColors.mintGreen),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterChips(
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
                  _EmptyState(
                    icon: Icons.notifications_off_rounded,
                    label: 'No notifications yet',
                    hint: "You'll see updates about your borrowings here.",
                    subtleText: subtleText,
                  )
                else if (filtered.isEmpty)
                  _EmptyState(
                    icon: Icons.done_all_rounded,
                    label: 'No unread notifications',
                    hint: "You're all caught up. Nice.",
                    subtleText: subtleText,
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = filtered[i];
                        return Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: _SwipeDeleteBackground(),
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
                          child: _NotificationCard(
                            notification: n,
                            onTap: n.isRead
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    ctrl.markRead(n.id);
                                  },
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

// ─────────────────────────────────────────────────────────────────────────
// Type style — color + icon per NotificationType
// ─────────────────────────────────────────────────────────────────────────

({Color tone, IconData icon}) _styleFor(NotificationType t) {
  switch (t) {
    case NotificationType.approved:
      return (tone: PupColors.techCyan, icon: Icons.verified_rounded);
    case NotificationType.rejected:
      return (tone: PupColors.signalRed, icon: Icons.cancel_rounded);
    case NotificationType.reminder:
      return (
        tone: PupColors.cyberAmber,
        icon: Icons.notifications_active_rounded,
      );
    case NotificationType.overdue:
      return (tone: PupColors.signalRed, icon: Icons.warning_amber_rounded);
    case NotificationType.newItem:
      return (tone: PupColors.mintGreen, icon: Icons.fiber_new_rounded);
    case NotificationType.returned:
      return (
        tone: PupColors.mintGreen,
        icon: Icons.assignment_turned_in_rounded,
      );
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${_two(t.month)}/${_two(t.day)}/${t.year}';
}

String _two(int n) => n.toString().padLeft(2, '0');

// ─────────────────────────────────────────────────────────────────────────
// Filter chips — mirrors the Home / Borrowings tab pattern
// ─────────────────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  final int selected;
  final List<String> filters;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final idleBg = Colors.transparent;
    final idleBorder = isDark
        ? PupGlass.darkBorder(PupColors.cyberAmber)
        : PupColors.ashGray.withValues(alpha: 0.3);
    final idleFg = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => InkWell(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected == i ? PupColors.cyberAmber : idleBg,
              border: Border.all(
                color: selected == i ? PupColors.cyberAmber : idleBorder,
              ),
              boxShadow: selected == i
                  ? [
                      BoxShadow(
                        color: PupColors.cyberAmber.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              filters[i],
              style: TextStyle(
                color: selected == i ? const Color(0xFF1B1B1B) : idleFg,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: filters.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
        : PupColors.ashGray;

    final style = _styleFor(notification.type);
    final time = _relativeTime(notification.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: PupGlass.statCardGlow(
                context: context,
                accent: style.tone,
                borderRadius: 16,
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TonedIconChip(icon: style.icon, tone: style.tone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w800
                                      : FontWeight.w900,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              time,
                              style: TextStyle(
                                color: subtleText,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Unread dot — sits in the top-right corner of the card.
            if (!notification.isRead)
              Positioned(
                top: 12,
                right: 14,
                child: IgnorePointer(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: style.tone,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: style.tone.withValues(alpha: 0.55),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: PupColors.signalRed,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PupColors.signalRed.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.delete_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.label,
    required this.hint,
    required this.subtleText,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color subtleText;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 56, color: subtleText),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtleText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtleText.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Toned icon chip — local copy, matches the other tabs
// ─────────────────────────────────────────────────────────────────────────

class _TonedIconChip extends StatelessWidget {
  const _TonedIconChip({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: tone, size: 20),
    );
  }
}
