import 'package:flutter/material.dart';

import '../student/models.dart';
import '../theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────
// Shared notification presentation widgets.
//
// These were originally private to `student_notifications_screen.dart`.
// They now live here so the same card / chip / empty-state / styling is
// reused by BOTH surfaces that render the notification feed:
//   • the admin full-page `StudentNotificationsScreen`, and
//   • the student header bell popover (`NotificationsBellButton`).
// Keeping one source of truth means a styling tweak lands everywhere.
// ─────────────────────────────────────────────────────────────────────────

/// Color + icon pair for a given [NotificationType]. Mirrors the neon
/// accent language used across the student/admin tabs.
({Color tone, IconData icon}) notificationStyleFor(NotificationType t) {
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

/// Compact "time ago" label (Just now / 5m ago / 3h ago / 2d ago), falling
/// back to a short date once the entry is older than a week.
String relativeNotificationTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${_two(t.month)}/${_two(t.day)}/${t.year}';
}

String _two(int n) => n.toString().padLeft(2, '0');

// ─────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────

/// A single notification row: tinted icon chip, title, relative time, body,
/// and an unread dot in the corner. Tapping an unread card marks it read
/// (handled by the caller through [onTap]).
///
/// For heads-up notifications (e.g. "student marked an item for return")
/// the caller passes [footer] to render a non-tappable action hint at
/// the bottom of the card — e.g. *"Go to Pending → Returns"*. The
/// caller should also pass `onTap: null` in that case so the card stops
/// looking like a button; the admin acts on it from the Returns tab
/// instead.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.footer,
  });

  final AppNotification notification;
  final VoidCallback? onTap;

  /// Optional widget rendered below the message body. Used to surface a
  /// call-to-action hint (e.g. "Go to Returns") for notifications that
  /// the admin should act on from a specific surface rather than by
  /// tapping the card itself.
  final Widget? footer;

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

    final style = notificationStyleFor(notification.type);
    final time = relativeNotificationTime(notification.timestamp);

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
                        if (footer != null) ...[
                          const SizedBox(height: 8),
                          footer!,
                        ],
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

// ─────────────────────────────────────────────────────────────────────────
// Action hint — small non-tappable footer for heads-up notifications
// ─────────────────────────────────────────────────────────────────────────

/// Small accent-colored pill shown at the bottom of a heads-up
/// notification card (e.g. "Go to Pending → Returns"). Non-interactive
/// by design — the admin acts on the alert from the referenced surface,
/// not by tapping the notification itself. Used to retire the old
/// "Tap to record the condition" affordance, which implied an action
/// the popover never actually performed.
class NotificationActionHint extends StatelessWidget {
  const NotificationActionHint({
    super.key,
    required this.text,
    required this.accent,
  });

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_forward_rounded, size: 13, color: accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filter chips — All / Unread pill row
// ─────────────────────────────────────────────────────────────────────────

class NotificationFilterChips extends StatelessWidget {
  const NotificationFilterChips({
    super.key,
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
// Empty state
// ─────────────────────────────────────────────────────────────────────────

/// Centered icon + label + hint used when there is nothing to show. It is a
/// plain (non-sliver) widget so the caller decides the container: the admin
/// page wraps it in a `SliverToBoxAdapter`, the bell popover drops it
/// straight into a `Flexible`.
class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.subtleText,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color subtleText;

  /// Tighter vertical padding for the constrained popover.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vertical = compact ? 32.0 : 48.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 44 : 56, color: subtleText),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Swipe-to-delete background
// ─────────────────────────────────────────────────────────────────────────

/// Red "Delete" reveal shown behind a notification card while the user
/// swipes it away (used with `Dismissible`).
class NotificationSwipeDeleteBackground extends StatelessWidget {
  const NotificationSwipeDeleteBackground({super.key});

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
// Toned icon chip
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
