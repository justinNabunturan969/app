import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../student/models.dart';
import '../student/student_dashboard_controller.dart';
import '../theme/design_tokens.dart';
import 'notification_views.dart';

/// A header action that replaces the old "Notifications" sidebar tab.
///
/// Tapping the bell toggles an anchored popover ([_NotificationsPopover])
/// that renders the live notification feed from [StudentDashboardController].
/// It must be placed somewhere under the `StudentDashboardController`
/// provider (the student shell wraps every tab in it), so it can both read
/// the unread count for its badge and drive mark-read / delete / clear
/// actions.
///
/// ## Overlay open/close behavior
/// The popover is inserted as an [OverlayEntry] rather than pushed as a
/// route, so it floats above the current tab without navigating away:
///   • Tap the bell again  → toggles closed (see [_toggle]).
///   • Tap anywhere outside → a full-screen transparent barrier closes it.
///   • Switch tabs / dispose → [dispose] removes the entry, so a stale
///     popover can never outlive the header that owns it.
///
/// The bell icon itself is wrapped in a [CompositedTransformTarget]; the
/// popover uses a matching [CompositedTransformFollower] so it stays pinned
/// just below the bell even if the header reflows.
class NotificationsBellButton extends StatefulWidget {
  const NotificationsBellButton({super.key});

  @override
  State<NotificationsBellButton> createState() =>
      _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  bool get _isOpen => _entry != null;

  /// Open-or-close the popover.
  ///
  /// Rapid repeated taps are safe: `_entry` is the single source of truth
  /// and is updated synchronously, and Flutter delivers one tap gesture at a
  /// time, so successive taps simply alternate open → closed → open without
  /// ever inserting two entries.
  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    // Defensive: never stack two entries.
    if (_entry != null) return;
    HapticFeedback.selectionClick();
    final overlay = Overlay.of(context);
    // Resolve the controller while this State is still under the shell's
    // provider; the OverlayEntry subtree is parented to the app Overlay
    // (above that provider), so the popover re-provides it itself.
    final ctrl = context.read<StudentDashboardController>();
    _entry = OverlayEntry(builder: (_) => _buildOverlay(ctrl));
    overlay.insert(_entry!);
    if (mounted) setState(() {});
  }

  void _close() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
    if (mounted) setState(() {});
  }

  /// The overlay content: a full-screen tap barrier *under* the popover,
  /// which is anchored to the bell via the [LayerLink].
  ///
  /// [ctrl] is re-provided into this subtree because an [OverlayEntry] is
  /// parented to the app's [Overlay], which sits *above* the shell's
  /// `ChangeNotifierProvider`. Without this the popover's `Consumer`
  /// would throw `ProviderNotFoundException` the moment it opens.
  Widget _buildOverlay(StudentDashboardController ctrl) {
    return Stack(
      children: [
        // Barrier — translucent so taps in empty space dismiss the popover.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        // Popover — pinned below the bell's bottom-right corner.
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: ChangeNotifierProvider<StudentDashboardController>.value(
            value: ctrl,
            child: _NotificationsPopover(onClose: _close),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Guarantees the popover can't leak when the header is torn down
    // (e.g. the user switches to another tab mid-view).
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch (not read) so the badge tracks unread changes in real time,
    // including realtime Supabase updates folded into the controller.
    final unread = context.select<StudentDashboardController, int>(
      (c) => c.unreadCount,
    );

    final icon = Icon(
      _isOpen ? Icons.notifications_rounded : Icons.notifications_none_rounded,
      color: _isOpen || unread > 0 ? PupColors.cyberAmber : null,
    );

    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: 'Notifications',
        child: IconButton(
          onPressed: _toggle,
          icon: unread > 0
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    icon,
                    Positioned(
                      top: -4,
                      right: -6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: PupColors.signalRed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : icon,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Popover body — the relocated notifications feed
// ─────────────────────────────────────────────────────────────────────────

/// The dropdown content shown by [NotificationsBellButton]. Holds the same
/// state and behavior the full-page tab used to: All/Unread filter,
/// mark-all-read, tap-to-mark-read, swipe-to-delete, and clear-all (with a
/// confirmation dialog), plus empty / error states.
class _NotificationsPopover extends StatefulWidget {
  const _NotificationsPopover({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_NotificationsPopover> createState() => _NotificationsPopoverState();
}

class _NotificationsPopoverState extends State<_NotificationsPopover> {
  int _filter = 0; // 0 = All, 1 = Unread
  static const _filters = ['All', 'Unread'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;
    final surface = isDark ? PupColors.darkCardAlt : PupColors.lightCard;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PupColors.ashGray.withValues(alpha: 0.18);

    // Clamp the popover to the viewport so it never overflows on small
    // screens (anchored to the top-right, it grows left + down).
    final mq = MediaQuery.of(context);
    final width = (mq.size.width - 32).clamp(280.0, 380.0);
    final maxHeight = (mq.size.height * 0.72).clamp(320.0, 560.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        // An OverlayEntry has no Material / DefaultTextStyle ancestor, so
        // without this wrapper the popover text fell back to the platform
        // default face and the buttons had no ink host. Re-apply the app's
        // typography (Inter) exactly like every other surface.
        child: Material(
          type: MaterialType.transparency,
          textStyle: theme.textTheme.bodyMedium,
          child: Consumer<StudentDashboardController>(
            builder: (context, ctrl, _) {
              final all = ctrl.notifications;
              final unread = ctrl.unreadCount;
              final filtered = _filter == 1
                  ? all.where((n) => !n.isRead).toList()
                  : all;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PopoverHeader(
                    unread: unread,
                    hasAny: all.isNotEmpty,
                    primaryText: primaryText,
                    onMarkAllRead: () {
                      HapticFeedback.lightImpact();
                      ctrl.markAllRead();
                    },
                    onClose: widget.onClose,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
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
                  ),
                  if (all.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: NotificationFilterChips(
                        selected: _filter,
                        filters: _filters,
                        onSelected: (i) => setState(() => _filter = i),
                      ),
                    ),
                  const Divider(height: 1),
                  Flexible(
                    child: _buildBody(
                      ctrl: ctrl,
                      all: all,
                      filtered: filtered,
                      subtleText: subtleText,
                    ),
                  ),
                  if (all.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: TextButton.icon(
                        onPressed: () => _confirmClearAll(context, ctrl),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text(
                          'Clear all notifications',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: PupColors.signalRed,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Chooses between the error, empty, and list states. A failed background
  /// fetch only shows the retry state when there is genuinely nothing cached;
  /// otherwise the user keeps working with the data they already have (the
  /// shell surfaces a soft banner for that case).
  Widget _buildBody({
    required StudentDashboardController ctrl,
    required List<AppNotification> all,
    required List<AppNotification> filtered,
    required Color subtleText,
  }) {
    if (ctrl.error != null && all.isEmpty) {
      return _PopoverError(onRetry: ctrl.load, subtleText: subtleText);
    }
    if (all.isEmpty) {
      return SingleChildScrollView(
        child: NotificationEmptyState(
          icon: Icons.notifications_off_rounded,
          label: 'No notifications yet',
          hint: "You'll see updates about your borrowings here.",
          subtleText: subtleText,
          compact: true,
        ),
      );
    }
    if (filtered.isEmpty) {
      return SingleChildScrollView(
        child: NotificationEmptyState(
          icon: Icons.done_all_rounded,
          label: 'No unread notifications',
          hint: "You're all caught up. Nice.",
          subtleText: subtleText,
          compact: true,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = filtered[i];
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
            onTap: n.isRead
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    ctrl.markRead(n.id);
                  },
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
    // Show the dialog from the navigator context. `useRootNavigator: false`
    // keeps it scoped to the app's navigator (the popover lives in an
    // OverlayEntry, not a route, so the default lookup still resolves).
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
// Popover header
// ─────────────────────────────────────────────────────────────────────────

class _PopoverHeader extends StatelessWidget {
  const _PopoverHeader({
    required this.unread,
    required this.hasAny,
    required this.primaryText,
    required this.onMarkAllRead,
    required this.onClose,
  });

  final int unread;
  final bool hasAny;
  final Color primaryText;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_rounded,
            size: 18,
            color: PupColors.cyberAmber,
          ),
          const SizedBox(width: 8),
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: primaryText,
            ),
          ),
          const Spacer(),
          if (hasAny && unread > 0)
            TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                foregroundColor: PupColors.cyberAmber,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Mark all read',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Popover error state
// ─────────────────────────────────────────────────────────────────────────

class _PopoverError extends StatelessWidget {
  const _PopoverError({required this.onRetry, required this.subtleText});

  final Future<void> Function() onRetry;
  final Color subtleText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: subtleText),
            const SizedBox(height: 12),
            Text(
              "Couldn't load notifications",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtleText,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
