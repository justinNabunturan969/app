import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';

/// Live "occupancy monitor" for the admin.
///
/// Shows every currently-logged-in user, their state (active / idle /
/// returning), what equipment they're working with, and a real-time idle
/// timer. Tapping a session opens a detail sheet; long-pressing gives the
/// admin a Force Logout action.
class AdminOccupancyScreen extends StatelessWidget {
  const AdminOccupancyScreen({super.key, this.onSwitchTab});

  /// Optional deep-link target. The shell passes this so the screen can
  /// route back to the dashboard.
  final ValueChanged<int>? onSwitchTab;

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
        final sessions = ctrl.activeSessions;
        final active = ctrl.activeOccupancyCount;
        final idle = ctrl.idleOccupancyCount;
        final returning = ctrl.returningOccupancyCount;
        final total = ctrl.occupancyCount;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                // Pull-to-refresh hits the actual `active_sessions`
                // table on Supabase. Until that returns, keep a small
                // floor delay so the indicator has a moment to breathe
                // even on a near-instant response.
                await Future.wait([
                  ctrl.loadActiveSessions(),
                  Future<void>.delayed(const Duration(milliseconds: 350)),
                ]);
              },
              color: PupColors.mintGreen,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Occupancy',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: primaryText,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Who is logged in right now.',
                                      style: TextStyle(
                                        color: subtleText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const _LiveDot(),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Hero "X online" card
                          _OccupancyHeroCard(total: total),
                          const SizedBox(height: 14),

                          // 3-up breakdown strip
                          Row(
                            children: [
                              Expanded(
                                child: _OccupancyStatTile(
                                  label: 'Active',
                                  value: active,
                                  tone: PupColors.mintGreen,
                                  icon: Icons.bolt_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _OccupancyStatTile(
                                  label: 'Idle',
                                  value: idle,
                                  tone: PupColors.cyberAmber,
                                  icon: Icons.pause_circle_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _OccupancyStatTile(
                                  label: 'Returning',
                                  value: returning,
                                  tone: PupColors.techCyan,
                                  icon: Icons.assignment_return_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Section title + count
                          Row(
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                color: PupColors.pupMaroon,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Logged-in Sessions',
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
                  if (sessions.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'No one is online right now.',
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
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) => _SessionCard(
                          session: sessions[i],
                          onTap: () => _showSessionSheet(context, sessions[i]),
                          onKick: () =>
                              _confirmKick(context, ctrl, sessions[i]),
                        ),
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

  Future<void> _confirmKick(
    BuildContext context,
    StudentDashboardController ctrl,
    ActiveSession session,
  ) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force logout?'),
        content: Text(
          'This will terminate ${session.studentName}\'s session. '
          'They will need to sign in again.',
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
            child: const Text('Force Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ctrl.kickSession(session.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged out: ${session.studentName}'),
      ),
    );
  }

  void _showSessionSheet(BuildContext context, ActiveSession s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SessionDetailSheet(session: s),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Live pulsing dot
// ─────────────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PupColors.mintGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PupColors.mintGreen.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
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
                        alpha: 0.6 + _c.value * 0.4,
                      ),
                      blurRadius: 6 + _c.value * 8,
                      spreadRadius: _c.value * 1.5,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: PupColors.mintGreen,
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
// Hero "X online" card
// ─────────────────────────────────────────────────────────────────────────

class _OccupancyHeroCard extends StatelessWidget {
  const _OccupancyHeroCard({required this.total});
  final int total;

  String _peopleLabel(int n) => n == 1 ? 'person' : 'people';

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
              Icons.groups_rounded,
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
                  '$total ${_peopleLabel(total)} online',
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
                  'Right now, across all roles.',
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
// Stats tile (3-up)
// ─────────────────────────────────────────────────────────────────────────

class _OccupancyStatTile extends StatelessWidget {
  const _OccupancyStatTile({
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
// Session card (one row in the list)
// ─────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onKick,
  });

  final ActiveSession session;
  final VoidCallback onTap;
  final VoidCallback onKick;

  Color get _tone {
    switch (session.activity) {
      case SessionActivity.active:
        return PupColors.mintGreen;
      case SessionActivity.idle:
        return PupColors.cyberAmber;
      case SessionActivity.returning:
        return PupColors.techCyan;
    }
  }

  String get _statusLabel {
    switch (session.activity) {
      case SessionActivity.active:
        return 'Active';
      case SessionActivity.idle:
        return 'Idle';
      case SessionActivity.returning:
        return 'Returning soon';
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h ${m}m';
    }
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  Color _avatarBg() {
    // Stable, varied avatar color per session based on id hash.
    final palette = [
      PupColors.pupMaroon,
      PupColors.techCyan,
      PupColors.cyberAmber,
      PupColors.mintGreen,
      const Color(0xFF6F4CE8),
      const Color(0xFFE05BB8),
    ];
    final h = session.id.hashCode.abs();
    return palette[h % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    final idleFor = session.sinceLastActivity;
    final isIdle = session.activity == SessionActivity.idle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onKick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: PupGlass.statCardGlow(
            context: context,
            accent: _tone,
            borderRadius: 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _avatarBg(),
                      _avatarBg().withValues(alpha: 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _avatarBg().withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  session.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.studentName,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(
                          label: _statusLabel,
                          tone: _tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.studentId,
                      style: TextStyle(
                        color: subtle,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (session.equipmentName.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.handyman_rounded,
                            size: 13,
                            color: subtle,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${session.equipmentName}  •  ${session.location ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subtle,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            Icons.travel_explore_rounded,
                            size: 13,
                            color: subtle,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Browsing inventory',
                            style: TextStyle(
                              color: subtle,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isIdle
                              ? Icons.hourglass_bottom_rounded
                              : Icons.timer_outlined,
                          size: 12,
                          color: isIdle
                              ? PupColors.cyberAmber
                              : PupColors.techCyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIdle
                              ? 'Idle ${_formatDuration(idleFor)}'
                              : 'Logged in ${_formatDuration(DateTime.now().difference(session.loginAt))}',
                          style: TextStyle(
                            color: isIdle
                                ? PupColors.cyberAmber
                                : subtle,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick action
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: subtle,
                  size: 18,
                ),
                onSelected: (v) {
                  if (v == 'kick') onKick();
                  if (v == 'message') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Message sent to ${session.studentName} (prototype).',
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'message',
                    child: _MenuRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Send message',
                      color: PupColors.techCyan,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'kick',
                    child: _MenuRow(
                      icon: Icons.logout_rounded,
                      label: 'Force logout',
                      color: PupColors.signalRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.40), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tone,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tone.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w900,
              fontSize: 9.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Session detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({required this.session});
  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? PupColors.darkCard : PupColors.lightCard;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;
    final titleColor =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtle.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [PupColors.pupMaroon, PupColors.deepMahogany],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      session.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.studentName,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${session.studentId}  •  ${session.program}',
                          style: TextStyle(
                            color: subtle,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SheetRow(
                icon: Icons.bolt_rounded,
                tone: PupColors.mintGreen,
                label: 'Status',
                value: _activityLabel(session.activity),
              ),
              _SheetRow(
                icon: Icons.timelapse_rounded,
                tone: PupColors.techCyan,
                label: 'Logged in for',
                value: _formatRelative(session.loginAt),
              ),
              _SheetRow(
                icon: Icons.hourglass_bottom_rounded,
                tone: PupColors.cyberAmber,
                label: 'Since last activity',
                value: _formatRelative(session.lastActivityAt),
              ),
              if (session.equipmentName.isNotEmpty)
                _SheetRow(
                  icon: Icons.handyman_rounded,
                  tone: PupColors.pupMaroon,
                  label: 'Working with',
                  value: '${session.equipmentName}  •  ${session.location ?? ''}',
                )
              else
                _SheetRow(
                  icon: Icons.travel_explore_rounded,
                  tone: PupColors.pupMaroon,
                  label: 'Working with',
                  value: 'Browsing inventory',
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Message sent to ${session.studentName} (prototype).',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PupColors.techCyan,
                        side: BorderSide(
                          color: PupColors.techCyan.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Reuse the kick flow.
                        final ctrl = context.read<StudentDashboardController>();
                        ctrl.kickSession(session.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Logged out: ${session.studentName}',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Force Logout'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PupColors.signalRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRelative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.isNegative) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes.remainder(60)}m ago';
    return '${d.inDays}d ago';
  }

  String _activityLabel(SessionActivity a) {
    switch (a) {
      case SessionActivity.active:
        return 'Active — typing / interacting';
      case SessionActivity.idle:
        return 'Idle — no recent activity';
      case SessionActivity.returning:
        return 'Returning soon — about to log in again';
    }
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor =
        isDark ? theme.colorScheme.onSurface : PupColors.slateGray;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tone.withValues(alpha: 0.30),
                  tone.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tone.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(icon, color: tone, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: subtle,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    height: 1.3,
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
