import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/notifications_bell_button.dart';

/// "My Borrowings" tab.
///
/// Reuses the same design language as the Home tab (`PupColors`, `PupGlass`,
/// tinted icon chips, light/dark aware palette) and surfaces three buckets
/// of data from `StudentDashboardController`:
///   • Active   — loans currently checked out, with a live countdown
///   • Overdue  — loans past their return date, highlighted in red
///   • History  — completed/approved/rejected records
///
/// The controller's 1-second ticker drives the live countdowns for free.
class StudentBorrowingsScreen extends StatefulWidget {
  const StudentBorrowingsScreen({super.key});

  @override
  State<StudentBorrowingsScreen> createState() =>
      _StudentBorrowingsScreenState();
}

class _StudentBorrowingsScreenState extends State<StudentBorrowingsScreen>
    with SingleTickerProviderStateMixin {
  int _filter = 0; // 0=All, 1=Active, 2=Overdue, 3=History
  static const _filters = ['All', 'Active', 'Overdue', 'History'];

  // One-shot entrance animation. Forwards once on first build so the list
  // cards "fly in" during the demo / first impression.
  late final AnimationController _pageIn;

  @override
  void initState() {
    super.initState();
    _pageIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _pageIn.dispose();
    super.dispose();
  }

  Widget _stagger(int i, Widget child) {
    const cap = 7;
    final start = (i.clamp(0, cap) / cap) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _pageIn,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, _) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }

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
        final active = ctrl.activeBorrowings;
        final overdue = ctrl.overdueBorrowings;
        final history = ctrl.historyBorrowings;
        final returnedCount = history
            .where((b) => b.status == BorrowingStatus.returned)
            .length;
        final filtered = _applyFilter(active, overdue, history);

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
                                'My Borrowings',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const _HeaderBadge(),
                            const SizedBox(width: 4),
                            const NotificationsBellButton(),
                            const SizedBox(width: 4),
                            const ThemeMenuButton(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track your active loans, due dates, and full history.',
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          active: active.length,
                          overdue: overdue.length,
                          returned: returnedCount,
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
                if (filtered.isEmpty)
                  _EmptyState(
                    icon: _emptyIconFor(_filter),
                    label: _emptyLabelFor(_filter),
                    subtleText: subtleText,
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _stagger(
                        i,
                        _BorrowingCard(
                          borrowing: filtered[i],
                          onReturn: () =>
                              _confirmReturn(context, ctrl, filtered[i]),
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

  List<Borrowing> _applyFilter(
    List<Borrowing> active,
    List<Borrowing> overdue,
    List<Borrowing> history,
  ) {
    switch (_filter) {
      case 1:
        return active;
      case 2:
        return overdue;
      case 3:
        return history;
      default:
        return [...active, ...overdue, ...history];
    }
  }

  IconData _emptyIconFor(int f) {
    switch (f) {
      case 1:
        return Icons.assignment_outlined;
      case 2:
        return Icons.check_circle_outline_rounded;
      case 3:
        return Icons.history_rounded;
      default:
        return Icons.inbox_rounded;
    }
  }

  String _emptyLabelFor(int f) {
    switch (f) {
      case 1:
        return 'No active borrowings';
      case 2:
        return 'Nothing overdue — keep it up!';
      case 3:
        return 'No borrowing history yet';
      default:
        return 'Nothing to show';
    }
  }

  Future<void> _confirmReturn(
    BuildContext context,
    StudentDashboardController ctrl,
    Borrowing b,
  ) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return equipment?'),
        content: Text(
          'Mark "${b.equipmentName}" as returned? The admin will be notified to verify the physical return.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: PupColors.mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Return'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final returned = await ctrl.returnBorrowing(b.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          returned
              ? '${b.equipmentName} returned — admin notified'
              : 'Could not submit the return request. Please try again.',
        ),
        backgroundColor: returned ? null : PupColors.signalRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

/// Small maroon pill showing the number of items currently out (active +
/// overdue). Lives next to the screen title and updates with the ticker.
class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge();

  @override
  Widget build(BuildContext context) {
    final count = context.select<StudentDashboardController, int>(
      (c) => c.activeBorrowingsCount + c.overdueCount,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PupColors.pupMaroon,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count OUT',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Summary row — mirrors the Home tab's _QuickStatsRow
// ─────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.active,
    required this.overdue,
    required this.returned,
  });

  final int active;
  final int overdue;
  final int returned;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        children: [
          _SummaryCard(
            label: 'Active: $active',
            tone: PupColors.techCyan,
            icon: Icons.assignment_rounded,
          ),
          const SizedBox(width: 14),
          _SummaryCard(
            label: 'Overdue: $overdue',
            tone: PupColors.signalRed,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 14),
          _SummaryCard(
            label: 'Returned: $returned',
            tone: PupColors.mintGreen,
            icon: Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final Color tone;
  final IconData icon;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: _pressed
            ? PupGlass.pressedDecoration(
                context: context,
                accent: widget.tone,
                borderRadius: 18,
              )
            : PupGlass.statCardGlow(
                context: context,
                accent: widget.tone,
                borderRadius: 18,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TonedIconChip(icon: widget.icon, tone: widget.tone),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filter chips — mirrors the Home tab's _CategoryChips
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
// Borrowing card
// ─────────────────────────────────────────────────────────────────────────

/// One row in the borrowings list. The card adapts to the borrowing's
/// status:
///   • active   → live countdown + progress bar + Extend/Return actions
///   • overdue  → overdue duration + full red bar + Extend/Return Now
///   • history  → static date rows + status pill, no actions
class _BorrowingCard extends StatelessWidget {
  const _BorrowingCard({required this.borrowing, required this.onReturn});

  final Borrowing borrowing;
  final VoidCallback onReturn;

  ({Color tone, IconData icon, String label}) get _statusStyle {
    switch (borrowing.status) {
      case BorrowingStatus.pending:
        return (
          tone: PupColors.cyberAmber,
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
        );
      case BorrowingStatus.active:
        return (
          tone: PupColors.techCyan,
          icon: Icons.bolt_rounded,
          label: 'Active',
        );
      case BorrowingStatus.returnRequested:
        return (
          tone: PupColors.cyberAmber,
          icon: Icons.assignment_return_rounded,
          label: 'Return pending',
        );
      case BorrowingStatus.overdue:
        return (
          tone: PupColors.signalRed,
          icon: Icons.warning_amber_rounded,
          label: 'Overdue',
        );
      case BorrowingStatus.returned:
        return (
          tone: PupColors.mintGreen,
          icon: Icons.check_circle_rounded,
          label: 'Returned',
        );
      case BorrowingStatus.approved:
        return (
          tone: PupColors.techCyan,
          icon: Icons.assignment_turned_in_rounded,
          label: 'Approved',
        );
      case BorrowingStatus.rejected:
        return (
          tone: PupColors.ashGray,
          icon: Icons.block_rounded,
          label: 'Rejected',
        );
      case BorrowingStatus.cancelled:
        return (
          tone: PupColors.ashGray,
          icon: Icons.cancel_schedule_send_rounded,
          label: 'Cancelled',
        );
    }
  }

  String get _secondDateLabel {
    switch (borrowing.status) {
      case BorrowingStatus.pending:
        return 'Requested';
      case BorrowingStatus.active:
      case BorrowingStatus.overdue:
        return 'Due';
      case BorrowingStatus.returnRequested:
        return 'Awaiting verification';
      case BorrowingStatus.returned:
      case BorrowingStatus.approved:
        return 'Returned';
      case BorrowingStatus.rejected:
        return 'Decided';
      case BorrowingStatus.cancelled:
        return 'Withdrawn';
    }
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
    final isActionable =
        borrowing.status == BorrowingStatus.active ||
        borrowing.status == BorrowingStatus.overdue;
    final isLive = isActionable; // shows live countdown + bar

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: style.tone,
        borderRadius: 18,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + name/meta + status pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TonedIconChip(icon: style.icon, tone: style.tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrowing.equipmentName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${borrowing.id}  •  QR: ${borrowing.qrCode}',
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: style.label, color: style.tone),
            ],
          ),
          const SizedBox(height: 12),

          // Date rows
          _DateRow(
            label: 'Borrowed',
            date: borrowing.borrowDate,
            subtleText: subtleText,
            titleColor: titleColor,
          ),
          const SizedBox(height: 4),
          _DateRow(
            label: _secondDateLabel,
            date: borrowing.returnDate,
            subtleText: subtleText,
            titleColor: titleColor,
          ),

          // Live countdown + bar (only for active/overdue)
          if (isLive) ...[
            const SizedBox(height: 10),
            _CountdownAndBar(borrowing: borrowing, tone: style.tone),
          ],

          // Actions
          if (isActionable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Extension requested for ${borrowing.equipmentName}',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: style.tone,
                      side: BorderSide(
                        color: style.tone.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Extend',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onReturn,
                    style: FilledButton.styleFrom(
                      backgroundColor: style.tone,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      borrowing.status == BorrowingStatus.overdue
                          ? 'Return Now'
                          : 'Return',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.subtleText,
    required this.titleColor,
  });

  final String label;
  final DateTime date;
  final Color subtleText;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${_two(date.month)}/${_two(date.day)}/${date.year} • '
        '${_two(date.hour)}:${_two(date.minute)}';
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: subtleText,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            formatted,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// Live countdown + thin progress bar for active/overdue borrowings.
/// Rebuilds every second via the controller's ticker.
class _CountdownAndBar extends StatelessWidget {
  const _CountdownAndBar({required this.borrowing, required this.tone});

  final Borrowing borrowing;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final remaining = borrowing.remaining();
    final isOverdue = remaining.isNegative;

    final track = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : PupColors.ashGray.withValues(alpha: 0.18);

    double progress;
    if (isOverdue) {
      progress = 1.0;
    } else {
      final total = borrowing.returnDate
          .difference(borrowing.borrowDate)
          .inSeconds;
      if (total <= 0) {
        progress = 1.0;
      } else {
        final elapsed = DateTime.now()
            .difference(borrowing.borrowDate)
            .inSeconds;
        progress = (elapsed / total).clamp(0.0, 1.0);
      }
    }

    final barColor = isOverdue ? PupColors.signalRed : tone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isOverdue ? Icons.timer_off_rounded : Icons.timer_rounded,
              size: 14,
              color: barColor,
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(remaining),
              style: TextStyle(
                color: barColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: track),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor.withValues(alpha: 0.7), barColor],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    if (d.isNegative) {
      final o = -d;
      if (o.inDays > 0) {
        return 'Overdue by ${o.inDays}d ${o.inHours.remainder(24)}h';
      }
      if (o.inHours > 0) {
        return 'Overdue by ${o.inHours}h ${o.inMinutes.remainder(60)}m';
      }
      return 'Overdue by ${o.inMinutes}m';
    }
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h left';
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m left';
    }
    if (d.inMinutes > 0) return '${d.inMinutes}m left';
    return 'Due now';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
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
    required this.subtleText,
  });

  final IconData icon;
  final String label;
  final Color subtleText;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: subtleText),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: subtleText,
                  fontWeight: FontWeight.w700,
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
// Toned icon chip — local copy of the Home tab's _TonedIconChip so the
// file is self-contained.
// ─────────────────────────────────────────────────────────────────────────

class _TonedIconChip extends StatelessWidget {
  const _TonedIconChip({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: tone, size: 22),
    );
  }
}
