import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../features/analytics/widgets/bar_chart.dart';
import '../../main.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/profile_avatar_button.dart';

/// Admin Dashboard — the equipment office's home base.
///
/// Shows: overdue alert (hero), 3-up stat tiles, quick actions, weekly
/// activity chart, recent activity feed, and pending requests preview
/// with inline Approve / Reject actions.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, this.onSwitchTab});

  /// Callback to switch the admin shell to a specific tab index.
  /// Provided by [AdminShell] so the dashboard's stat cards and quick
  /// actions can deep-link into the other admin screens.
  final ValueChanged<int>? onSwitchTab;

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

    return Consumer<StudentDashboardController>(
      builder: (context, ctrl, _) {
        final equipment = ctrl.equipment;
        final totalUnits = equipment.fold<int>(0, (a, e) => a + e.total);
        final availableUnits = equipment.fold<int>(
          0,
          (a, e) => a + e.available,
        );
        final outCount = ctrl.activeBorrowingsCount + ctrl.overdueCount;
        final pendingCount = ctrl.pendingRequestsCount;
        final overdueCount = ctrl.overdueCount;
        final pending = ctrl.pendingBorrowings;
        // Loans waiting for an admin's Confirm Return to credit inventory.
        // ONLY items the student actually asked to return (status =
        // return_requested). Including active/overdue here was a bug — it
        // surfaced a "Verify Return" button on every fresh borrow and let
        // the admin accidentally flip a loan to `returned` before the
        // student ever handed the item back, which is what the user hit.
        final returnRequests = ctrl.activeBorrowings
            .where((b) => b.status == BorrowingStatus.returnRequested)
            .toList()
          ..sort((a, b) => b.borrowDate.compareTo(a.borrowDate));
        final activity =
            ctrl.activity.where((a) => a.scope == ActivityScope.admin).toList()
              // Sort newest-first by the entry's real timestamp so the feed
              // always reads as a chronological log, regardless of the order
              // events were folded in (realtime diffs, login history, local
              // CRUD ops can all interleave).
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final visibleActivity = activity.take(8).toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                // Pull-to-refresh kicks a real borrowings refetch. The
                // periodic 15s poll is the background safety net, but
                // an admin who's staring at the dashboard wants an
                // immediate catch-up after the gesture.
                await Future.wait([
                  ctrl.refreshBorrowings(),
                  ctrl.loadActiveSessions(),
                ]);
              },
              color: PupColors.cyberAmber,
              backgroundColor: theme.colorScheme.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // SliverToBoxAdapter hands the child unbounded vertical
                        // space. With the default `mainAxisSize: max` the
                        // Column would try to grow to infinity and Flutter
                        // would render zero content (looks like a blank
                        // screen). `min` makes the Column size to the sum
                        // of its children, which is what we want here.
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Dashboard',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: primaryText,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Manage equipment, requests, and returns.',
                                      style: TextStyle(
                                        color: subtleText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ProfileAvatarButton(
                                initials: 'AD',
                                roleLabel: 'Admin',
                                onProfile: () => context.push('/admin/profile'),
                                onLogout: () => _logout(context),
                                onSwitchTheme: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Use the palette icon to switch theme.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              const ThemeMenuButton(),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Overdue alert
                          if (overdueCount > 0) ...[
                            _OverdueAlert(
                              count: overdueCount,
                              onTap: onSwitchTab == null
                                  ? null
                                  : () => onSwitchTab!(3),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Pending requests are the first operational task
                          // for staff, so keep their actionable preview at the
                          // top of the dashboard rather than below analytics.
                          Row(
                            children: [
                              const Expanded(
                                child: _SectionHeader(
                                  title: 'Pending Requests',
                                  icon: Icons.hourglass_top_rounded,
                                  accent: PupColors.cyberAmber,
                                ),
                              ),
                              if (pending.isNotEmpty && onSwitchTab != null)
                                TextButton(
                                  onPressed: () => onSwitchTab!(3),
                                  style: TextButton.styleFrom(
                                    foregroundColor: PupColors.cyberAmber,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'See all',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (pending.isEmpty)
                            const EmptyActivityHint(
                              label:
                                  'No pending requests — you\'re all caught up!',
                              icon: Icons.inbox_rounded,
                            )
                          else
                            for (final b in pending.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PendingPreviewCard(
                                  borrowing: b,
                                  onApprove: () async {
                                    HapticFeedback.lightImpact();
                                    final approved = await ctrl
                                        .approveBorrowing(b.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          approved
                                              ? 'Approved: ${b.equipmentName}'
                                              : 'Could not approve the request. Please try again.',
                                        ),
                                        backgroundColor: approved
                                            ? null
                                            : PupColors.signalRed,
                                      ),
                                    );
                                  },
                                  onReject: () async {
                                    HapticFeedback.lightImpact();
                                    final rejected = await ctrl.rejectBorrowing(
                                      b.id,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          rejected
                                              ? 'Rejected: ${b.equipmentName}'
                                              : 'Could not reject the request. Please try again.',
                                        ),
                                        backgroundColor: rejected
                                            ? null
                                            : PupColors.signalRed,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          const SizedBox(height: 16),

                          // Confirm Returns — loans waiting for the admin
                          // to confirm the physical hand-in. Confirming
                          // credits equipment availability immediately.
                          Row(
                            children: [
                              const Expanded(
                                child: _SectionHeader(
                                  title: 'Confirm Returns',
                                  icon: Icons.assignment_return_rounded,
                                  accent: PupColors.techCyan,
                                ),
                              ),
                              if (returnRequests.isNotEmpty &&
                                  onSwitchTab != null)
                                TextButton(
                                  onPressed: () => onSwitchTab!(3),
                                  style: TextButton.styleFrom(
                                    foregroundColor: PupColors.techCyan,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'See all',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (returnRequests.isEmpty)
                            const EmptyActivityHint(
                              label: 'No returns to confirm — all clear!',
                              icon: Icons.assignment_turned_in_rounded,
                            )
                          else
                            for (final b in returnRequests.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ReturnConfirmCard(
                                  borrowing: b,
                                  onConfirm: () async {
                                    HapticFeedback.lightImpact();
                                    final confirmed = await ctrl
                                        .confirmReturnBorrowing(b.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          confirmed
                                              ? 'Return confirmed — ${b.equipmentName} is available again.'
                                              : 'Could not confirm this return. Please refresh and try again.',
                                        ),
                                        backgroundColor: confirmed
                                            ? null
                                            : PupColors.signalRed,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          const SizedBox(height: 16),

                          // 3-up stats grid (Available / Out / Pending)
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  value: '$availableUnits',
                                  label: 'Available units',
                                  tone: PupColors.techCyan,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatTile(
                                  value: '$outCount',
                                  label: 'Out right now',
                                  tone: PupColors.mintGreen,
                                  icon: Icons.bolt_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatTile(
                                  value: '$pendingCount',
                                  label: 'Pending',
                                  tone: PupColors.cyberAmber,
                                  icon: Icons.hourglass_top_rounded,
                                  onTap: onSwitchTab == null
                                      ? null
                                      : () => onSwitchTab!(3),
                                ),
                              ),
                            ],
                          ),
                          if (totalUnits > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              '$availableUnits of $totalUnits units available across ${equipment.length} types of equipment',
                              style: TextStyle(
                                color: subtleText,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Live occupancy peek
                          _OccupancyPeekCard(
                            total: ctrl.occupancyCount,
                            active: ctrl.activeOccupancyCount,
                            idle: ctrl.idleOccupancyCount,
                            returning: ctrl.returningOccupancyCount,
                            sessions: ctrl.activeSessions.take(4).toList(),
                            onTap: onSwitchTab == null
                                ? null
                                : () => onSwitchTab!(1),
                          ),
                          const SizedBox(height: 18),

                          // Quick actions
                          const _SectionHeader(
                            title: 'Quick Actions',
                            icon: Icons.flash_on_rounded,
                            accent: PupColors.cyberAmber,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  label: 'Review\nPending',
                                  count: pendingCount,
                                  tone: PupColors.cyberAmber,
                                  icon: Icons.pending_actions_rounded,
                                  onTap: onSwitchTab == null
                                      ? null
                                      : () => onSwitchTab!(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuickAction(
                                  label: 'Scan\nQR',
                                  tone: PupColors.techCyan,
                                  icon: Icons.qr_code_scanner_rounded,
                                  onTap: onSwitchTab == null
                                      ? null
                                      : () => onSwitchTab!(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuickAction(
                                  label: 'View\nInventory',
                                  tone: PupColors.pupMaroon,
                                  icon: Icons.inventory_2_rounded,
                                  onTap: onSwitchTab == null
                                      ? null
                                      : () => onSwitchTab!(2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Weekly activity chart
                          MonthlyActivityBarChart(data: ctrl.weeklyActivity),
                          const SizedBox(height: 18),

                          // Recent activity
                          ActivityFeedHeader(
                            trailing: Text(
                              '${activity.length} events',
                              style: TextStyle(
                                color: subtleText,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (visibleActivity.isEmpty)
                            const EmptyActivityHint(
                              label: 'No recent activity yet',
                              icon: Icons.history_toggle_off_rounded,
                            )
                          else
                            for (final entry in visibleActivity)
                              ActivityFeedItem(
                                icon: entry.icon,
                                tone: entry.tone,
                                title: entry.title,
                                subtitle: entry.subtitle,
                                timestamp: entry.timestamp,
                              ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to manage the system.',
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
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await authSessionStorage.clearSession();
    if (!context.mounted) return;
    context.go('/role');
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.30),
                accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Overdue alert
// ─────────────────────────────────────────────────────────────────────────

class _OverdueAlert extends StatelessWidget {
  const _OverdueAlert({required this.count, this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : PupColors.slateGray;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : PupColors.slateGray.withValues(alpha: 0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: PupGlass.statCardGlow(
            context: context,
            accent: PupColors.signalRed,
            borderRadius: 16,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PupColors.signalRed,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: PupColors.signalRed.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'item' : 'items'} overdue',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Past the return date — review and follow up.',
                      style: TextStyle(
                        color: subtitleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: subtitleColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Stat tile (3-up grid)
// ─────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.tone,
    required this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final Color tone;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final valueColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    final card = Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MiniIconChip(icon: icon, tone: tone),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: tone.withValues(alpha: 0.7),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : PupColors.ashGray,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

class _MiniIconChip extends StatelessWidget {
  const _MiniIconChip({required this.icon, required this.tone});
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.1),
      ),
      child: Icon(icon, color: tone, size: 16),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Quick action card
// ─────────────────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.tone,
    required this.icon,
    this.count,
    this.onTap,
  });

  final String label;
  final Color tone;
  final IconData icon;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    final card = Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MiniIconChip(icon: icon, tone: tone),
              const Spacer(),
              if (count != null && count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Pending preview card with inline Approve / Reject
// ─────────────────────────────────────────────────────────────────────────

class _PendingPreviewCard extends StatelessWidget {
  const _PendingPreviewCard({
    required this.borrowing,
    required this.onApprove,
    required this.onReject,
  });

  final Borrowing borrowing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: PupColors.cyberAmber,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniIconChip(
                icon: Icons.hourglass_top_rounded,
                tone: PupColors.cyberAmber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrowing.equipmentName,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${borrowing.studentName}  •  ${borrowing.studentId}',
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (borrowing.purpose.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        borrowing.purpose,
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PupColors.signalRed,
                      side: BorderSide(
                        color: PupColors.signalRed.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: PupColors.mintGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Live occupancy peek card (dashboard → tap to open Live tab)
// ─────────────────────────────────────────────────────────────────────────

class _OccupancyPeekCard extends StatelessWidget {
  const _OccupancyPeekCard({
    required this.total,
    required this.active,
    required this.idle,
    required this.returning,
    required this.sessions,
    required this.onTap,
  });

  final int total;
  final int active;
  final int idle;
  final int returning;
  final List<ActiveSession> sessions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: PupGlass.statCardGlow(
            context: context,
            accent: PupColors.mintGreen,
            borderRadius: 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PupColors.mintGreen.withValues(alpha: 0.30),
                          PupColors.mintGreen.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PupColors.mintGreen.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.podcasts_rounded,
                      color: PupColors.mintGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$total online right now',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _LivePulsingDot(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$active active  •  $idle idle  •  $returning returning',
                          style: TextStyle(
                            color: subtle,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, color: subtle),
                ],
              ),
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Stacked avatars (max 4). Width is explicit because
                    // the parent Row leaves the cross-axis (width)
                    // unconstrained — without it, the inner Stack throws
                    // "A Stack requires bounded constraints" at layout.
                    SizedBox(
                      // 4 avatars × 22px stride + 32px avatar width =
                      // 120px worst case. Round up to 124 to keep a hair
                      // of breathing room.
                      width: 124,
                      height: 32,
                      child: Stack(
                        children: [
                          for (int i = 0; i < sessions.length && i < 4; i++)
                            Positioned(
                              left: i * 22.0,
                              child: _PeekAvatar(
                                initials: sessions[i].initials,
                                color: _avatarColor(sessions[i].id),
                                ring: isDark
                                    ? PupColors.darkCard
                                    : Colors.white,
                              ),
                            ),
                          if (total > 4)
                            Positioned(
                              left: 4 * 22.0,
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: PupColors.ashGray.withValues(
                                    alpha: 0.30,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? PupColors.darkCard
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  '+${total - 4}',
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap to view all sessions',
                        style: TextStyle(
                          color: subtle,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _avatarColor(String id) {
    final palette = [
      PupColors.pupMaroon,
      PupColors.techCyan,
      PupColors.cyberAmber,
      PupColors.mintGreen,
      const Color(0xFF6F4CE8),
      const Color(0xFFE05BB8),
    ];
    return palette[id.hashCode.abs() % palette.length];
  }
}

class _PeekAvatar extends StatelessWidget {
  const _PeekAvatar({
    required this.initials,
    required this.color,
    required this.ring,
  });

  final String initials;
  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _LivePulsingDot extends StatefulWidget {
  const _LivePulsingDot();

  @override
  State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: PupColors.mintGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PupColors.mintGreen.withValues(
                  alpha: 0.5 + _c.value * 0.5,
                ),
                blurRadius: 4 + _c.value * 6,
                spreadRadius: _c.value * 1.2,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact "Confirm Returns" card shown on the admin dashboard for each
/// loan in the `return_requested` state (plus active/overdue rows the
/// admin can close out manually if the student never tapped Return). Tapping
/// the action button calls [onConfirm] — the parent wires that to
/// `StudentDashboardController.confirmReturnBorrowing`.
class _ReturnConfirmCard extends StatelessWidget {
  const _ReturnConfirmCard({
    required this.borrowing,
    required this.onConfirm,
  });

  final Borrowing borrowing;
  final VoidCallback onConfirm;

  ({Color tone, IconData icon, String label}) get _statusStyle {
    switch (borrowing.status) {
      case BorrowingStatus.returnRequested:
        return (
          tone: PupColors.techCyan,
          icon: Icons.assignment_return_rounded,
          label: 'Return pending',
        );
      case BorrowingStatus.overdue:
        return (
          tone: PupColors.signalRed,
          icon: Icons.warning_amber_rounded,
          label: 'Overdue',
        );
      case BorrowingStatus.active:
      default:
        return (
          tone: PupColors.cyberAmber,
          icon: Icons.bolt_rounded,
          label: 'Active',
        );
    }
  }

  String get _initials {
    final parts = borrowing.studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    final style = _statusStyle;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: style.tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.tone.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: style.tone.withValues(alpha: 0.45),
                    width: 1.1,
                  ),
                ),
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: style.tone,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrowing.studentName,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${borrowing.studentId}  •  ${borrowing.equipmentName}',
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: style.tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: style.tone.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    color: style.tone,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: const Text(
                'Verify Return',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: PupColors.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
