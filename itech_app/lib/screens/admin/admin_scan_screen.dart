import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../data/models/student_card.dart';
import '../../services/nfc_service.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';

/// Admin Scan — NFC reader for verifying student ID when borrowing
/// or returning equipment.
///
/// Flow:
/// 1. Staff taps "Scan Student ID". NFC session starts, the on-screen
///    prompt switches to "Hold card near phone".
/// 2. Student taps their ID. The phone reads the UID, the app resolves
///    it to a [StudentCard] via [StudentCardRegistry], and the card
///    details (name, program, year/section) appear below the viewfinder.
/// 3. The student's active borrowings load; staff taps "Mark Returned"
///    on the one they want to close, which goes through the same
///    [StudentDashboardController.returnBorrowing] path the student
///    side uses.
class AdminScanScreen extends StatefulWidget {
  const AdminScanScreen({super.key});

  @override
  State<AdminScanScreen> createState() => _AdminScanScreenState();
}

class _AdminScanScreenState extends State<AdminScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLine;

  Borrowing? _lastScanned;
  final List<Borrowing> _recentScans = [];

  /// The student that was just resolved from the last NFC tap. Null if
  /// no successful tap yet, or the tap failed UID resolution.
  StudentCard? _lastStudent;
  String? _lastUid;
  bool _nfcSessionActive = false;
  StreamSubscription<NfcTap>? _tapSub;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLine.dispose();
    _tapSub?.cancel();
    NfcService.instance.stopSession();
    super.dispose();
  }

  Future<void> _startNfcScan(StudentDashboardController ctrl) async {
    if (_nfcSessionActive) return;
    HapticFeedback.mediumImpact();

    // Listen to taps BEFORE starting the session, otherwise a fast
    // tap could fire before the subscription is attached.
    _tapSub?.cancel();
    _tapSub = NfcService.instance.onTap.listen(
      (tap) => _onCardTapped(ctrl, tap),
      onError: (Object e) => _onNfcError(e),
    );

    setState(() {
      _nfcSessionActive = true;
      _lastStudent = null;
      _lastUid = null;
    });

    try {
      await NfcService.instance.startSession(
        alertMessage: 'Hold the student ID near the top of the phone.',
      );
    } on NfcException catch (e) {
      _onNfcError(e);
    } catch (e) {
      _onNfcError(e);
    }
  }

  Future<void> _cancelNfcScan() async {
    await NfcService.instance.stopSession(alertMessage: 'Scan cancelled.');
    _tapSub?.cancel();
    _tapSub = null;
    if (!mounted) return;
    setState(() => _nfcSessionActive = false);
  }

  void _onCardTapped(StudentDashboardController ctrl, NfcTap tap) {
    HapticFeedback.heavyImpact();
    final student = StudentCardRegistry.instance.lookup(tap.uidHex);

    if (!mounted) return;
    setState(() {
      _nfcSessionActive = false;
      _lastUid = tap.uidHex;
      _lastStudent = student;
    });

    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unknown card: ${tap.uidHex}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final active = [...ctrl.activeBorrowings, ...ctrl.overdueBorrowings];
    final mine = active
        .where((b) => b.studentId == student.studentId)
        .toList(growable: false);

    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullName} has no active borrowings.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Auto-select the first one; the staff can still pick another from
    // the recent list below. Most returns are a single-item interaction.
    setState(() {
      _lastScanned = mine.first;
      _recentScans.insert(0, mine.first);
      if (_recentScans.length > 5) _recentScans.removeLast();
    });
  }

  void _onNfcError(Object error) {
    if (!mounted) return;
    setState(() => _nfcSessionActive = false);
    final msg = error is NfcException
        ? error.message
        : 'NFC read failed: $error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _markReturned(StudentDashboardController ctrl, Borrowing b) {
    HapticFeedback.lightImpact();
    // Admin verifies the physical hand-in via the NFC scan flow. The
    // scan path is the fast / high-throughput one (staff tap a card and
    // accept the return in a single motion), so we default the
    // condition to 'good' with no notes — if anything is off, the
    // admin can re-open the borrowing from the dashboard's Confirm
    // Returns section and re-record it. Migration 0034 made the
    // `condition` parameter required; we hardcode it here for the
    // happy path.
    unawaited(
      ctrl.confirmReturnBorrowing(b.id, condition: 'good').then((result) {
        if (!mounted) return;
        if (result != null) {
          setState(() {
            _lastScanned = null;
            _recentScans.remove(b);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${b.equipmentName} return verified'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not verify return of ${b.equipmentName}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }),
    );
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
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
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
                                'Scan Student ID',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const ThemeMenuButton(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _nfcSessionActive
                              ? 'Hold the student ID near the top of the phone to verify and complete a return.'
                              : "Tap a student's ID card to verify identity and complete a return.",
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Viewfinder(
                      animation: _scanLine,
                      isActive: _nfcSessionActive || _lastScanned == null,
                      isNfcListening: _nfcSessionActive,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: _nfcSessionActive
                          ? OutlinedButton.icon(
                              onPressed: _cancelNfcScan,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text(
                                'Cancel Scan',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PupColors.signalRed,
                                side: BorderSide(
                                  color: PupColors.signalRed.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () => _startNfcScan(ctrl),
                              icon: const Icon(Icons.contactless_rounded),
                              label: const Text(
                                'Scan Student ID',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: PupColors.techCyan,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                if (_lastStudent != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _StudentIdentityCard(
                        student: _lastStudent!,
                        uid: _lastUid,
                      ),
                    ),
                  ),
                if (_lastScanned != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _ScanResultCard(
                        borrowing: _lastScanned!,
                        onReturn: () => _markReturned(ctrl, _lastScanned!),
                        onClear: () => setState(() => _lastScanned = null),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: PupColors.brand(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recent Scans',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: primaryText,
                            ),
                          ),
                        ),
                        Container(
                          height: 3,
                          width: 28,
                          decoration: BoxDecoration(
                            color: PupColors.pupMaroon.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_recentScans.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : PupColors.ashGray.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.qr_code_rounded,
                              size: 20,
                              color: subtleText,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'No scans yet today',
                              style: TextStyle(
                                color: subtleText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
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
                      itemCount: _recentScans.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final b = _recentScans[i];
                        return _RecentScanRow(
                          borrowing: b,
                          onReturn: () => _markReturned(ctrl, b),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Viewfinder (decorative — animates a horizontal scan line)
// ─────────────────────────────────────────────────────────────────────────

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.animation,
    required this.isActive,
    this.isNfcListening = false,
  });
  final Animation<double> animation;
  final bool isActive;
  final bool isNfcListening;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F19),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: PupColors.techCyan.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle grid pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),

            // Scan line — sweeps top to bottom. `Positioned` must be a
            // direct child of Stack: nesting it under a LayoutBuilder
            // crashes with "Incorrect use of ParentDataWidget" the moment
            // this tab opens, so the sweep position is driven through
            // Align instead (0 → top edge, 1 → bottom edge).
            if (isActive)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return Align(
                        alignment: Alignment(0, animation.value * 2 - 1),
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PupColors.techCyan.withValues(alpha: 0.0),
                                PupColors.techCyan.withValues(alpha: 0.9),
                                PupColors.techCyan.withValues(alpha: 0.0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: PupColors.techCyan.withValues(
                                  alpha: 0.55,
                                ),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Corner brackets
            Positioned(
              top: 20,
              left: 20,
              child: _Corner(
                alignment: Alignment.topLeft,
                color: isActive
                    ? PupColors.techCyan
                    : PupColors.techCyan.withValues(alpha: 0.4),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: _Corner(
                alignment: Alignment.topRight,
                color: isActive
                    ? PupColors.techCyan
                    : PupColors.techCyan.withValues(alpha: 0.4),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: _Corner(
                alignment: Alignment.bottomLeft,
                color: isActive
                    ? PupColors.techCyan
                    : PupColors.techCyan.withValues(alpha: 0.4),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: _Corner(
                alignment: Alignment.bottomRight,
                color: isActive
                    ? PupColors.techCyan
                    : PupColors.techCyan.withValues(alpha: 0.4),
              ),
            ),

            // Center label
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isNfcListening
                        ? Icons.contactless_rounded
                        : Icons.qr_code_2_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 56,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isNfcListening
                        ? 'Hold card near phone'
                        : (isActive ? 'Ready to scan' : 'Last scan ready'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment, required this.color});
  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _CornerPainter(alignment: alignment, color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.alignment, required this.color});
  final Alignment alignment;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final path = Path();
    if (alignment == Alignment.topLeft) {
      path.moveTo(0, h);
      path.lineTo(0, 0);
      path.lineTo(w, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, h);
      path.lineTo(w, h);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(w, 0);
      path.lineTo(w, h);
      path.lineTo(0, h);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.alignment != alignment;
}

// ─────────────────────────────────────────────────────────────────────────
// Scan result card
// ─────────────────────────────────────────────────────────────────────────

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.borrowing,
    required this.onReturn,
    required this.onClear,
  });

  final Borrowing borrowing;
  final VoidCallback onReturn;
  final VoidCallback onClear;

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

    final isOverdue = borrowing.status == BorrowingStatus.overdue;
    final tone = isOverdue ? PupColors.signalRed : PupColors.techCyan;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PupColors.mintGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR Verified',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      borrowing.qrCode,
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, color: subtleText),
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            borrowing.equipmentName,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Borrowed by ${borrowing.studentName}  •  ${borrowing.studentId}',
            style: TextStyle(
              color: subtleText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (isOverdue) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PupColors.signalRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: PupColors.signalRed.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Overdue — please follow up with the student',
                style: TextStyle(
                  color: PupColors.signalRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReturn,
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
              label: const Text(
                'Mark as Returned',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: PupColors.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
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

// ─────────────────────────────────────────────────────────────────────────
// Recent scan row
// ─────────────────────────────────────────────────────────────────────────

class _RecentScanRow extends StatelessWidget {
  const _RecentScanRow({required this.borrowing, required this.onReturn});
  final Borrowing borrowing;
  final VoidCallback onReturn;

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
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : PupColors.ashGray.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.qr_code_rounded, size: 18, color: PupColors.techCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  borrowing.equipmentName,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${borrowing.studentName}  •  ${borrowing.qrCode}',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReturn,
            style: TextButton.styleFrom(
              foregroundColor: PupColors.mintGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Return',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Student identity card (shown after a successful NFC tap resolves)
// ─────────────────────────────────────────────────────────────────────────

class _StudentIdentityCard extends StatelessWidget {
  const _StudentIdentityCard({required this.student, this.uid});

  final StudentCard student;
  final String? uid;

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
    final tone = PupColors.techCyan;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tone.withValues(alpha: 0.32),
                  tone.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tone.withValues(alpha: 0.45),
                width: 1.1,
              ),
            ),
            child: Icon(Icons.school_rounded, color: tone, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  student.program,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: subtleText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MetaChip(label: student.studentId),
                    const SizedBox(width: 6),
                    _MetaChip(label: student.yearSection),
                  ],
                ),
                if (uid != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'UID  $uid',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: subtleText,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = PupColors.techCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
