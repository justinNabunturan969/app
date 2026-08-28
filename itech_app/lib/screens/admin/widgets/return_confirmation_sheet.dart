import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../student/models.dart';
import '../../../theme/design_tokens.dart';

/// Return condition recorded by the admin during the return
/// confirmation. Maps 1:1 to the database `return_condition` check
/// constraint (migration 0034).
enum ReturnCondition {
  good('good', 'Good', 'No damage. Item is ready to be re-borrowed.',
      PupColors.mintGreen, Icons.check_circle_rounded),
  damaged('damaged', 'Damaged', 'Visible damage. Flag for repair before reuse.',
      PupColors.cyberAmber, Icons.warning_amber_rounded),
  needsRepair('needs_repair', 'Needs Repair', 'Functional issue. Take to maintenance.',
      PupColors.signalRed, Icons.build_rounded);

  const ReturnCondition(
    this.value,
    this.label,
    this.helper,
    this.tone,
    this.icon,
  );
  final String value;
  final String label;
  final String helper;
  final Color tone;
  final IconData icon;

  static ReturnCondition fromValue(String? v) {
    if (v == null) return ReturnCondition.good;
    for (final c in ReturnCondition.values) {
      if (c.value == v) return c;
    }
    return ReturnCondition.good;
  }
}

/// Form sheet the admin fills in to confirm a physical return. Forces
/// them to record the [ReturnCondition] and optionally attach [notes]
/// before the borrowing is moved to history. Used on both the admin
/// dashboard and the Pending Requests screen so the audit trail is
/// consistent regardless of where the admin comes from.
class ReturnConfirmationSheet extends StatefulWidget {
  const ReturnConfirmationSheet({
    super.key,
    required this.borrowing,
    required this.onSubmit,
  });

  final Borrowing borrowing;

  /// Async submit handler. Returns the persisted [Borrowing] on success
  /// (or null on failure). The sheet shows a snackbar and stays open on
  /// failure so the admin can retry.
  final Future<Borrowing?> Function({
    required ReturnCondition condition,
    String? notes,
  }) onSubmit;

  @override
  State<ReturnConfirmationSheet> createState() =>
      _ReturnConfirmationSheetState();
}

class _ReturnConfirmationSheetState extends State<ReturnConfirmationSheet> {
  ReturnCondition _condition = ReturnCondition.good;
  final _notesC = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await widget.onSubmit(
      condition: _condition,
      notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not confirm the return. Please try again.'),
          backgroundColor: PupColors.signalRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(result);
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
    final b = widget.borrowing;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollC) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : PupColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollC,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtleText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: PupColors.pupMaroon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: PupColors.pupMaroon.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: PupColors.pupMaroon,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm return',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Record the condition before closing out the loan.',
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MetaCard(borrowing: b),
              const SizedBox(height: 20),
              Text(
                'ITEM CONDITION',
                style: TextStyle(
                  color: subtleText,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              ...ReturnCondition.values.map(
                (c) => _ConditionOption(
                  condition: c,
                  selected: _condition == c,
                  onTap: () => setState(() => _condition = c),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'NOTES (OPTIONAL)',
                style: TextStyle(
                  color: subtleText,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesC,
                maxLength: 1000,
                maxLines: 3,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1000),
                ],
                decoration: InputDecoration(
                  hintText:
                      'e.g. "missing USB cable", "scratched case near the corner"',
                  hintStyle: TextStyle(
                    color: PupColors.ashGray.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : PupColors.coolSteel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: subtleText.withValues(alpha: 0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _condition.tone.withValues(alpha: 0.85),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Heads-up when the condition will take the item out of
              // service. Surface it inline so the admin sees it before
              // they commit, not after.
              if (_condition != ReturnCondition.good) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _condition.tone.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _condition.tone.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: _condition.tone, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _condition == ReturnCondition.damaged
                              ? 'The item will be flagged for repair and pulled out of the available pool until the equipment office marks it as fixed.'
                              : 'The item will be taken out of service for repair. It will not appear as available to students until you re-enable it from the Inventory tab.',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: subtleText,
                        side: BorderSide(
                          color: subtleText.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_condition.icon, size: 18),
                      label: Text(
                        _submitting
                            ? 'Confirming…'
                            : 'Confirm Return',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _condition.tone,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.borrowing});
  final Borrowing borrowing;

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
    final b = borrowing;

    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) =>
        '${two(d.month)}/${two(d.day)}/${d.year}  •  ${two(d.hour)}:${two(d.minute)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : PupColors.coolSteel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: subtle.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded,
                  size: 16, color: subtle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  b.equipmentName,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MetaLine(
            icon: Icons.person_rounded,
            label: 'Student',
            value: '${b.studentName}  •  ${b.studentId}',
          ),
          const SizedBox(height: 4),
          _MetaLine(
            icon: Icons.event_rounded,
            label: 'Borrowed',
            value: fmt(b.borrowDate),
          ),
          const SizedBox(height: 4),
          _MetaLine(
            icon: Icons.flag_rounded,
            label: 'Status',
            value: b.status == BorrowingStatus.returnRequested
                ? 'Return requested by student'
                : '${b.status.name} (admin closing out)',
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
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
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: subtle),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: TextStyle(
            color: subtle,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ConditionOption extends StatelessWidget {
  const _ConditionOption({
    required this.condition,
    required this.selected,
    required this.onTap,
  });
  final ReturnCondition condition;
  final bool selected;
  final VoidCallback onTap;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? condition.tone.withValues(alpha: 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : PupColors.coolSteel),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? condition.tone
                  : subtle.withValues(alpha: 0.25),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? condition.tone : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? condition.tone
                        : subtle.withValues(alpha: 0.5),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Icon(
                condition.icon,
                size: 18,
                color: selected ? condition.tone : subtle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.label,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      condition.helper,
                      style: TextStyle(
                        color: subtle,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
