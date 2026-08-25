import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';

/// Admin "Login History" view.
///
/// Replaces the previous Live Occupancy tab. Shows every recorded
/// session in `session_history` (RLS: admin only) enriched with the
/// signed-in user's credentials (joined from `profiles`) and a
/// summary of what they did during the session (borrowings count +
/// equipment names, joined from `borrowings.requested_at` inside the
/// session window).
///
/// Pull-to-refresh re-runs the controller's `loadLoginHistory`. Tapping
/// a row opens a detail sheet that shows the *full* credential set
/// (name, student ID, email, program, year, section, role) along with
/// the complete activity list for that session.
class AdminLoginHistoryScreen extends StatefulWidget {
  const AdminLoginHistoryScreen({super.key, this.onSwitchTab});

  /// Optional deep-link target. The shell passes this so the screen
  /// can route back to the dashboard (kept for parity with the
  /// previous Live Occupancy screen).
  final ValueChanged<int>? onSwitchTab;

  @override
  State<AdminLoginHistoryScreen> createState() =>
      _AdminLoginHistoryScreenState();
}

class _AdminLoginHistoryScreenState extends State<AdminLoginHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the first fetch on mount. The controller dedupes — the
    // call is cheap if the list is already populated, and the screen
    // gets the data on its first frame instead of an empty placeholder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = context.read<StudentDashboardController>();
      if (ctrl.loginHistory.isEmpty && !ctrl.loginHistoryLoading) {
        ctrl.loadLoginHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Consumer<StudentDashboardController>(
      builder: (context, ctrl, _) {
        final history = ctrl.loginHistory;
        final loading = ctrl.loginHistoryLoading;
        final total = history.length;
        final uniqueUsers = _countUniqueUsers(history);
        final today = _countToday(history);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                // Pull-to-refresh hits `session_history` (and the joined
                // borrowings lookup) on Supabase. Floor delay keeps the
                // indicator from snapping back too fast.
                await Future.wait([
                  ctrl.loadLoginHistory(),
                  Future<void>.delayed(const Duration(milliseconds: 350)),
                ]);
              },
              color: PupColors.techCyan,
              backgroundColor: theme.colorScheme.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Login History',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: primaryText,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Audit log of every session, with '
                                      'credentials and activity.',
                                      style: TextStyle(
                                        color: subtleText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const _HistoryBadge(),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Hero card
                          _LoginHistoryHeroCard(
                            total: total,
                            uniqueUsers: uniqueUsers,
                            today: today,
                          ),
                          const SizedBox(height: 14),

                          // 3-up breakdown strip
                          Row(
                            children: [
                              Expanded(
                                child: _HistoryStatTile(
                                  label: 'Sessions',
                                  value: total,
                                  tone: PupColors.techCyan,
                                  icon: Icons.history_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HistoryStatTile(
                                  label: 'Unique users',
                                  value: uniqueUsers,
                                  tone: PupColors.mintGreen,
                                  icon: Icons.people_alt_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HistoryStatTile(
                                  label: 'Today',
                                  value: today,
                                  tone: PupColors.cyberAmber,
                                  icon: Icons.today_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Section title
                          Row(
                            children: [
                              Icon(
                                Icons.login_rounded,
                                color: PupColors.pupMaroon,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Recorded sessions',
                                style: TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$total total',
                                style: TextStyle(
                                  color: subtleText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  if (loading && history.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (ctrl.loginHistoryError != null && history.isEmpty)
                    SliverToBoxAdapter(
                      child: _HistoryErrorPanel(
                        message: ctrl.loginHistoryError!,
                        onRetry: ctrl.loadLoginHistory,
                        onDismiss: ctrl.clearLoginHistoryError,
                      ),
                    )
                  else if (history.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'No sessions recorded yet.',
                            style: TextStyle(
                              color: PupColors.ashGray,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverList.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final entry = history[i];
                          final isSelf =
                              entry.profileId == ctrl.currentAuthId;
                          return _HistoryCard(
                            entry: entry,
                            onTap: () => _showSessionSheet(
                              context,
                              ctrl,
                              entry,
                            ),
                            onForceLogout: isSelf
                                ? null
                                : () async {
                                    final approved = await _confirmKick(
                                      context,
                                      entry,
                                    );
                                    if (!approved) return;
                                    await _runForceLogout(ctrl, entry);
                                  },
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Open the per-session detail sheet. Shown as a bottom sheet so
  /// the full credential set + activity list has room to breathe
  /// without crowding the timeline.
  void _showSessionSheet(
    BuildContext context,
    StudentDashboardController ctrl,
    LoginHistoryEntry entry,
  ) {
    HapticFeedback.selectionClick();
    final isSelf = entry.profileId == ctrl.currentAuthId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SessionDetailSheet(
        entry: entry,
        onForceLogout: isSelf
            ? null
            : () async {
                final approved = await _confirmKick(context, entry);
                if (!approved || !ctx.mounted) return;
                Navigator.of(ctx).pop();
                await _runForceLogout(ctrl, entry);
              },
      ),
    );
  }

  /// Confirmation dialog for the force-logout security action.
  Future<bool> _confirmKick(
    BuildContext context,
    LoginHistoryEntry entry,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Force logout ${entry.fullName}?'),
        content: const Text(
          'Their active session ends immediately and their device is '
          'returned to the login screen. The action is recorded in '
          'Login History as "Force logout".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: PupColors.signalRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Force logout'),
          ),
        ],
      ),
    );
    return approved ?? false;
  }

  /// Execute the kick and surface the outcome. The controller refreshes
  /// `session_history` afterwards, so the new "Force logout" entry
  /// appears in the list without a manual pull-to-refresh.
  Future<void> _runForceLogout(
    StudentDashboardController ctrl,
    LoginHistoryEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ctrl.forceLogoutFromHistory(entry);
    final message = switch (outcome) {
      ForceLogoutOutcome.terminated =>
        '${entry.fullName} was signed out of all devices.',
      ForceLogoutOutcome.notOnline =>
        '${entry.fullName} has no active session right now.',
      ForceLogoutOutcome.failed =>
        'Could not force logout ${entry.fullName}. Try again.',
    };
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static int _countUniqueUsers(List<LoginHistoryEntry> history) {
    final seen = <String>{};
    for (final e in history) {
      seen.add(e.profileId);
    }
    return seen.length;
  }

  static int _countToday(List<LoginHistoryEntry> history) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return history.where((e) => e.endedAt.isAfter(midnight)).length;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Pill badge in the header — marks the screen as an audit log.
// ─────────────────────────────────────────────────────────────────────────

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PupColors.techCyan.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PupColors.techCyan.withValues(alpha: 0.45),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fact_check_rounded,
            color: PupColors.techCyan,
            size: 12,
          ),
          SizedBox(width: 6),
          Text(
            'AUDIT',
            style: TextStyle(
              color: PupColors.techCyan,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Hero card — totals at a glance.
// ─────────────────────────────────────────────────────────────────────────

class _LoginHistoryHeroCard extends StatelessWidget {
  const _LoginHistoryHeroCard({
    required this.total,
    required this.uniqueUsers,
    required this.today,
  });

  final int total;
  final int uniqueUsers;
  final int today;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PupColors.pupMaroon,
            PupColors.deepMahogany,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PupColors.pupMaroon.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: PupColors.cyberAmber.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.history_edu_rounded,
              color: PupColors.cyberAmber,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total session${total == 1 ? '' : 's'} recorded',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$uniqueUsers unique user${uniqueUsers == 1 ? '' : 's'} '
                  '• $today today',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Stats tile (3-up).
// ─────────────────────────────────────────────────────────────────────────

class _HistoryStatTile extends StatelessWidget {
  const _HistoryStatTile({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
  });

  final String label;
  final int value;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tone.withValues(alpha: 0.32),
                  tone.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: tone.withValues(alpha: 0.45),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: tone, size: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: subtle,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// One row in the list — avatar, name, time range, end reason, activity
// summary.
// ─────────────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.onTap,
    this.onForceLogout,
  });

  final LoginHistoryEntry entry;
  final VoidCallback onTap;

  /// Non-null shows the one-tap force-logout action on the card. Null
  /// (the admin's own rows) hides it entirely.
  final VoidCallback? onForceLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    final reasonTone = _reasonTone(entry.endReason);
    final reasonLabel = _reasonLabel(entry.endReason);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : PupColors.ashGray.withValues(alpha: 0.20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarBubble(initials: entry.initials, role: entry.role),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (entry.role == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: PupColors.pupMaroon
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: PupColors.pupMaroon
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Text(
                              'FACULTY',
                              style: TextStyle(
                                color: PupColors.pupMaroon,
                                fontWeight: FontWeight.w900,
                                fontSize: 8.5,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${entry.studentId} • ${entry.program.isEmpty ? "—" : entry.program}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Time range + duration
                    Row(
                      children: [
                        Icon(
                          Icons.login_rounded,
                          size: 13,
                          color: subtleText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(entry.loggedInAt),
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 11,
                          color: subtleText,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.logout_rounded,
                          size: 13,
                          color: subtleText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(entry.endedAt),
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(entry.duration),
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // End reason + activity summary
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ReasonChip(label: reasonLabel, tone: reasonTone),
                        _ActivityChip(
                          count: entry.borrowingsDuringSession,
                          tone: entry.borrowingsDuringSession > 0
                              ? PupColors.cyberAmber
                              : PupColors.ashGray,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onForceLogout != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onForceLogout,
                  tooltip: 'Force logout ${entry.fullName}',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.logout_rounded),
                  color: PupColors.signalRed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _reasonLabel(String reason) {
    switch (reason) {
      case 'signed_out':
        return 'Signed out';
      case 'closed':
        return 'App closed';
      case 'force_logout':
        return 'Force logout';
      case 'expired':
        return 'Session expired';
      default:
        return reason;
    }
  }

  static Color _reasonTone(String reason) {
    switch (reason) {
      case 'force_logout':
        return PupColors.signalRed;
      case 'expired':
        return PupColors.cyberAmber;
      case 'closed':
        return PupColors.techCyan;
      case 'signed_out':
      default:
        return PupColors.mintGreen;
    }
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    final days = d.inDays;
    final h = d.inHours.remainder(24);
    return h == 0 ? '${days}d' : '${days}d ${h}h';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Avatar bubble — initials + role-tinted ring.
// ─────────────────────────────────────────────────────────────────────────

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.initials, required this.role});

  final String initials;
  final String role;

  @override
  Widget build(BuildContext context) {
    final tone = role == 'admin' ? PupColors.pupMaroon : PupColors.techCyan;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.32),
            tone.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tone.withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: tone,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Reason + activity chips.
// ─────────────────────────────────────────────────────────────────────────

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.count, required this.tone});

  final int count;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final label = count == 0
        ? 'No activity'
        : '$count borrow${count == 1 ? '' : 's'} during session';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handyman_rounded, size: 11, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Error panel — shown when the initial load fails and we have no data
// to fall back on. The banner at the top of the screen handles errors
// once we already have data on screen.
// ─────────────────────────────────────────────────────────────────────────

class _HistoryErrorPanel extends StatelessWidget {
  const _HistoryErrorPanel({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: PupColors.signalRed,
          ),
          const SizedBox(height: 10),
          const Text(
            "Couldn't load login history",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).hintColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Detail sheet — full credentials + full activity list.
// ─────────────────────────────────────────────────────────────────────────

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({required this.entry, this.onForceLogout});

  final LoginHistoryEntry entry;

  /// Non-null shows the "Force logout user" action. Null (the admin's
  /// own session) hides it. The callback confirms, pops the sheet, and
  /// runs the kick — see [_AdminLoginHistoryScreenState._showSessionSheet].
  final Future<void> Function()? onForceLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PupColors.ashGray.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                _AvatarBubble(
                                  initials: entry.initials,
                                  role: entry.role,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.fullName,
                                        style: TextStyle(
                                          color: primaryText,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        entry.email.isEmpty
                                            ? entry.studentId
                                            : entry.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: subtleText,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (entry.role == 'admin')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PupColors.pupMaroon
                                          .withValues(alpha: 0.14),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                        color: PupColors.pupMaroon
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: const Text(
                                      'FACULTY',
                                      style: TextStyle(
                                        color: PupColors.pupMaroon,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Credentials section
                            _SectionHeading(
                              title: 'Credentials',
                              icon: Icons.badge_rounded,
                              accent: PupColors.techCyan,
                            ),
                            const SizedBox(height: 8),
                            _DetailRow(
                              icon: Icons.alternate_email_rounded,
                              label: 'Email',
                              value: entry.email.isEmpty
                                  ? '—'
                                  : entry.email,
                            ),
                            _DetailRow(
                              icon: Icons.numbers_rounded,
                              label: 'Student / Faculty ID',
                              value: entry.studentId,
                            ),
                            _DetailRow(
                              icon: Icons.school_rounded,
                              label: 'Program',
                              value: entry.program.isEmpty
                                  ? '—'
                                  : entry.program,
                            ),
                            _DetailRow(
                              icon: Icons.class_rounded,
                              label: 'Year & section',
                              value:
                                  '${entry.yearLevel.isEmpty ? "—" : entry.yearLevel}'
                                  ' • '
                                  '${entry.section.isEmpty ? "—" : entry.section}',
                            ),
                            _DetailRow(
                              icon: Icons.verified_user_rounded,
                              label: 'Role',
                              value: entry.role,
                            ),

                            const SizedBox(height: 18),

                            // Session section
                            _SectionHeading(
                              title: 'Session',
                              icon: Icons.access_time_rounded,
                              accent: PupColors.cyberAmber,
                            ),
                            const SizedBox(height: 8),
                            _DetailRow(
                              icon: Icons.login_rounded,
                              label: 'Signed in',
                              value: _formatFull(entry.loggedInAt),
                            ),
                            _DetailRow(
                              icon: Icons.timeline_rounded,
                              label: 'Last activity',
                              value: _formatFull(entry.lastActivityAt),
                            ),
                            _DetailRow(
                              icon: Icons.logout_rounded,
                              label: 'Signed out',
                              value: _formatFull(entry.endedAt),
                            ),
                            _DetailRow(
                              icon: Icons.hourglass_bottom_rounded,
                              label: 'Duration',
                              value: _formatDuration(entry.duration),
                            ),
                            _DetailRow(
                              icon: Icons.flag_rounded,
                              label: 'End reason',
                              value: _reasonLabel(entry.endReason),
                            ),

                            if (onForceLogout != null) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: PupColors.signalRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: onForceLogout,
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Force logout user',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            // Activity section
                            _SectionHeading(
                              title: 'Activity during this session',
                              icon: Icons.handyman_rounded,
                              accent: PupColors.mintGreen,
                            ),
                            const SizedBox(height: 8),
                            if (entry.activityNames.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: PupColors.ashGray
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: PupColors.ashGray
                                        .withValues(alpha: 0.30),
                                  ),
                                ),
                                child: const Text(
                                  'No borrowings were created during this '
                                  'session — the user only browsed.',
                                  style: TextStyle(
                                    color: PupColors.ashGray,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              for (final name in entry.activityNames)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6),
                                  child: _ActivityRow(name: name),
                                ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _reasonLabel(String reason) {
    switch (reason) {
      case 'signed_out':
        return 'Signed out normally';
      case 'closed':
        return 'App was closed';
      case 'force_logout':
        return 'Force logout (admin)';
      case 'expired':
        return 'Session expired (heartbeat lost)';
      default:
        return reason;
    }
  }

  static String _formatFull(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds} seconds';
    if (d.inHours < 1) return '${d.inMinutes} minutes';
    if (d.inDays < 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return m == 0 ? '$h hours' : '$h hours $m minutes';
    }
    final days = d.inDays;
    final h = d.inHours.remainder(24);
    return h == 0 ? '$days days' : '$days days $h hours';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Detail row inside the sheet.
// ─────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: subtleText),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: subtleText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PupColors.mintGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: PupColors.mintGreen.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.build_circle_rounded,
            color: PupColors.mintGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section heading inside the detail sheet.
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
