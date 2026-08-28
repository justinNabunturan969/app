import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import 'widgets/return_confirmation_sheet.dart';

/// Admin Pending Requests — the equipment office's review queue.
///
/// Shows every borrowing whose status is `pending` (submitted by a student
/// but not yet approved/rejected), plus loans in the `return_requested`
/// state waiting for an admin to verify the physical hand-in (migration
/// 0014). One-tap approve moves it to `activeBorrowings`; reject moves it
/// to `historyBorrowings` as `rejected`; verifying a return credits the
/// inventory. All admin list actions flow through the controller.
class AdminPendingRequestsScreen extends StatefulWidget {
  const AdminPendingRequestsScreen({
    super.key,
    this.pendingReturnBorrowingId,
  });

  /// When this notifier carries a borrowing id, the screen auto-opens
  /// the return-confirmation form for that borrowing and clears the
  /// notifier. The admin shell flips this from the Notifications tab
  /// when the admin taps a "Return to confirm" entry.
  final ValueNotifier<String?>? pendingReturnBorrowingId;

  @override
  State<AdminPendingRequestsScreen> createState() =>
      _AdminPendingRequestsScreenState();
}

class _AdminPendingRequestsScreenState
    extends State<AdminPendingRequestsScreen> {
  int _filter = 0; // 0=All, 1=Pending, 2=Approved, 3=Rejected, 4=Returns
  static const _filters = ['All', 'Pending', 'Approved', 'Rejected', 'Returns'];

  @override
  void initState() {
    super.initState();
    // Listen for deep-links from the Notifications tab. When the admin
    // taps a "Return to confirm" entry, the shell sets this notifier
    // and switches to this tab; we then pop the form for that
    // borrowing and clear the notifier so we don't re-open on
    // subsequent rebuilds.
    widget.pendingReturnBorrowingId?.addListener(_handlePendingReturn);
    // The notifier may already be set by the time we mount (the shell
    // flipped it before the tab swap). Cover that race.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingReturn();
    });
  }

  @override
  void dispose() {
    widget.pendingReturnBorrowingId?.removeListener(_handlePendingReturn);
    super.dispose();
  }

  /// Pops the structured return-confirmation form for the borrowing
  /// whose id is in [widget.pendingReturnBorrowingId]. Clears the
  /// notifier so we only act once per tap.
  void _handlePendingReturn() {
    final notifier = widget.pendingReturnBorrowingId;
    if (notifier == null) return;
    final id = notifier.value;
    if (id == null) return;
    notifier.value = null;
    if (!mounted) return;
    final ctrl = context.read<StudentDashboardController>();
    final all = <Borrowing>[
      ...ctrl.pendingBorrowings,
      ...ctrl.activeBorrowings,
      ...ctrl.historyBorrowings,
    ];
    Borrowing? target;
    for (final b in all) {
      if (b.id == id) {
        target = b;
        break;
      }
    }
    // Scope the filter to the Returns tab so the admin immediately
    // sees the card with the matching context.
    setState(() => _filter = 4);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not find that loan — it may already be returned.',
          ),
          backgroundColor: PupColors.cyberAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Defer the dialog to the next frame so the tab swap animation
    // doesn't fight the modal slide-in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _confirmVerifyReturn(context, ctrl, target!);
    });
  }

  List<Borrowing> _apply(List<Borrowing> all) {
    switch (_filter) {
      case 1:
        return all.where((b) => b.status == BorrowingStatus.pending).toList();
      case 2:
        return all.where((b) => b.status == BorrowingStatus.approved).toList();
      case 3:
        return all.where((b) => b.status == BorrowingStatus.rejected).toList();
      case 4:
        return all
            .where((b) => b.status == BorrowingStatus.returnRequested)
            .toList();
      default:
        return all;
    }
  }

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
        // The full queue = pending requests + return requests awaiting
        // verification + recent approved/rejected decisions (drawn from
        // history). Sorted by most recent.
        final all =
            <Borrowing>[
              ...ctrl.pendingBorrowings,
              ...ctrl.activeBorrowings.where(
                (b) => b.status == BorrowingStatus.returnRequested,
              ),
              ...ctrl.historyBorrowings.where(
                (b) =>
                    b.status == BorrowingStatus.approved ||
                    b.status == BorrowingStatus.rejected,
              ),
            ]..sort((a, b) {
              int rank(Borrowing x) => switch (x.status) {
                BorrowingStatus.pending => 0,
                BorrowingStatus.returnRequested => 1,
                _ => 2,
              };
              final r = rank(a).compareTo(rank(b));
              if (r != 0) return r;
              return b.borrowDate.compareTo(a.borrowDate);
            });

        final pendingCount = ctrl.pendingRequestsCount;
        final filtered = _apply(all);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: PupColors.cyberAmber,
              backgroundColor: theme.colorScheme.surface,
              // Pull-to-refresh forces a borrowings refetch so the admin
              // can manually catch up if a realtime event was missed.
              // Without this, the only recovery from a stale list was
              // a full app restart.
              onRefresh: () => ctrl.refreshBorrowings(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Pending Requests',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: primaryText,
                                  ),
                                ),
                              ),
                              if (pendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PupColors.cyberAmber,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Color(0xFF1B1B1B),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              // Explicit refresh button — the same
                              // hook the periodic poll and pull-to-refresh
                              // call. Gives the admin a one-tap way to
                              // catch up without restarting the app.
                              _RefreshButton(onPressed: ctrl.refreshBorrowings),
                              const SizedBox(width: 4),
                              const ThemeMenuButton(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingCount == 0
                                ? 'No requests waiting for review.'
                                : '$pendingCount ${pendingCount == 1 ? 'request' : 'requests'} waiting for review.',
                            style: TextStyle(
                              color: subtleText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            const SizedBox(height: 12),
                            _UrgentReviewBanner(
                              count: pendingCount,
                              onReviewNow: () => setState(() => _filter = 1),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _FilterChipsRow(
                            selected: _filter,
                            filters: _filters,
                            onSelected: (i) => setState(() => _filter = i),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                _emptyIconFor(_filter),
                                size: 48,
                                color: subtleText,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _emptyLabelFor(_filter),
                                style: TextStyle(
                                  color: subtleText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final b = filtered[i];
                          final isReturnRequest =
                              b.status == BorrowingStatus.returnRequested;
                          return _RequestCard(
                            borrowing: b,
                            onApprove: b.status == BorrowingStatus.pending
                                ? () => _confirmApprove(context, ctrl, b)
                                : null,
                            onReject: b.status == BorrowingStatus.pending
                                ? () => _confirmReject(context, ctrl, b)
                                : null,
                            onVerifyReturn: isReturnRequest
                                ? () => _confirmVerifyReturn(context, ctrl, b)
                                : null,
                          );
                        },
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

  IconData _emptyIconFor(int f) {
    switch (f) {
      case 2:
        return Icons.check_circle_outline_rounded;
      case 3:
        return Icons.cancel_outlined;
      case 4:
        return Icons.assignment_return_outlined;
      default:
        return Icons.inbox_rounded;
    }
  }

  String _emptyLabelFor(int f) {
    switch (f) {
      case 1:
        return 'No pending requests';
      case 2:
        return 'No approved requests yet';
      case 3:
        return 'No rejected requests';
      case 4:
        return 'No returns waiting for verification';
      default:
        return 'Nothing in the queue';
    }
  }

  /// Admin confirms the physical hand-in of a `return_requested` loan.
  /// Opens the structured return confirmation form so the admin has to
  /// record a condition (good / damaged / needs_repair) before the loan
  /// is closed out. The form is shared with the admin dashboard's
  /// "Confirm Returns" section so the audit trail is consistent.
  Future<void> _confirmVerifyReturn(
    BuildContext context,
    StudentDashboardController ctrl,
    Borrowing b,
  ) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<Borrowing?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReturnConfirmationSheet(
        borrowing: b,
        onSubmit: ({required condition, notes}) => ctrl.confirmReturnBorrowing(
          b.id,
          condition: condition.value,
          notes: notes,
        ),
      ),
    );
    if (!context.mounted) return;
    if (result == null) return;
    final cond = result.returnCondition;
    final msg = switch (cond) {
      'good' =>
        'Return confirmed — ${result.equipmentName} is back in the available pool.',
      'damaged' =>
        '${result.equipmentName} flagged as damaged. Pulled from the pool until the equipment office marks it fixed.',
      'needs_repair' =>
        '${result.equipmentName} sent to repair. Hidden from students until you re-enable it.',
      _ => 'Return confirmed for ${result.equipmentName}.',
    };
    final tone = switch (cond) {
      'good' => PupColors.mintGreen,
      _ => PupColors.cyberAmber,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: tone,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    StudentDashboardController ctrl,
    Borrowing b,
  ) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve request?'),
        content: Text(
          "Approve ${b.studentName}'s request for ${b.equipmentName}? "
          'It will become an active loan.',
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
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final approved = await ctrl.approveBorrowing(b.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? 'Approved — ${b.equipmentName} is now active.'
              : 'Could not approve this request. Please refresh and try again.',
        ),
        backgroundColor: approved ? null : PupColors.signalRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmReject(
    BuildContext context,
    StudentDashboardController ctrl,
    Borrowing b,
  ) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request?'),
        content: Text(
          "Reject ${b.studentName}'s request for ${b.equipmentName}? "
          'The student will see this in their history.',
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final rejected = await ctrl.rejectBorrowing(b.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rejected
              ? 'Rejected — ${b.equipmentName}'
              : 'Could not reject this request. Please refresh and try again.',
        ),
        backgroundColor: rejected ? null : PupColors.signalRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _UrgentReviewBanner extends StatelessWidget {
  const _UrgentReviewBanner({required this.count, required this.onReviewNow});

  final int count;
  final VoidCallback onReviewNow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count pending requests need review',
      child: Material(
        color: PupColors.cyberAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onReviewNow,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.priority_high_rounded,
                  color: PupColors.cyberAmber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'request needs' : 'requests need'} your review',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Text(
                  'Review now',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filter chips (matches the admin inventory style)
// ─────────────────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
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
    final idleBorder = isDark
        ? PupGlass.darkBorder(PupColors.cyberAmber)
        : PupColors.ashGray.withValues(alpha: 0.3);
    final idleFg = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => InkWell(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected == i ? PupColors.cyberAmber : Colors.transparent,
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Request card
// ─────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.borrowing,
    required this.onApprove,
    required this.onReject,
    this.onVerifyReturn,
  });

  final Borrowing borrowing;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onVerifyReturn;

  ({Color tone, IconData icon, String label}) get _statusStyle {
    switch (borrowing.status) {
      case BorrowingStatus.pending:
        return (
          tone: PupColors.cyberAmber,
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
        );
      case BorrowingStatus.returnRequested:
        return (
          tone: PupColors.techCyan,
          icon: Icons.assignment_return_rounded,
          label: 'Return pending',
        );
      case BorrowingStatus.approved:
        return (
          tone: PupColors.mintGreen,
          icon: Icons.check_circle_rounded,
          label: 'Approved',
        );
      case BorrowingStatus.rejected:
        return (
          tone: PupColors.signalRed,
          icon: Icons.cancel_rounded,
          label: 'Rejected',
        );
      default:
        return (
          tone: PupColors.ashGray,
          icon: Icons.help_outline_rounded,
          label: 'Unknown',
        );
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

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: style.tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: student + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(name: borrowing.studentName, tone: style.tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrowing.studentName,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      borrowing.studentId,
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
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

          // Equipment
          _Row(
            icon: Icons.precision_manufacturing_rounded,
            label: 'Equipment',
            value: borrowing.equipmentName,
            subtleText: subtleText,
            titleColor: titleColor,
          ),
          const SizedBox(height: 6),
          _Row(
            icon: Icons.event_rounded,
            label: 'Requested for',
            value:
                '${_date(borrowing.borrowDate)}  →  ${_date(borrowing.returnDate)}',
            subtleText: subtleText,
            titleColor: titleColor,
          ),
          if (borrowing.purpose.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : PupColors.coolSteel,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, size: 14, color: subtleText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      borrowing.purpose,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions (only for pending)
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PupColors.signalRed,
                      side: BorderSide(
                        color: PupColors.signalRed.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: PupColors.mintGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Verify-return action (for loans awaiting physical hand-in).
          if (onVerifyReturn != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onVerifyReturn,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text(
                  'Verify Return',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: PupColors.mintGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime d) =>
      '${_two(d.month)}/${_two(d.day)}/${_two(d.year % 100)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtleText,
    required this.titleColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color subtleText;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: subtleText),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: TextStyle(
            color: subtleText,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.tone});
  final String name;
  final Color tone;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.35), tone.withValues(alpha: 0.12)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: tone.withValues(alpha: 0.5), width: 1.1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: tone,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
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

/// Compact icon-only refresh button. One tap calls
/// `StudentDashboardController.refreshBorrowings()` so the admin can
/// catch up on a missed realtime event without restarting the app.
/// The button is disabled (and shows a spinning ring) while a refresh
/// is already in flight, so accidental double-taps don't pile up
/// duplicate requests.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _busy = false;

  Future<void> _handle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tint = PupColors.cyberAmber;
    return Tooltip(
      message: 'Refresh requests',
      child: InkResponse(
        radius: 22,
        onTap: _busy ? null : _handle,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? tint.withValues(alpha: 0.12)
                : tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? tint.withValues(alpha: 0.4)
                  : tint.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(tint),
                  ),
                )
              : Icon(Icons.refresh_rounded, color: tint, size: 20),
        ),
      ),
    );
  }
}
