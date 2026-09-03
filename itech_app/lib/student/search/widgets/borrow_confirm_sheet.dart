import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/design_tokens.dart';
import '../../models.dart';
import '../../student_dashboard_controller.dart';

/// Rooms inside the iTech facility a request can be tied to. Picked from
/// a fixed list so admins get a consistent label; `null` means "No room".
final List<String> _itechRooms = [
  for (var n = 200; n <= 214; n++) 'Room $n',
  for (var n = 300; n <= 314; n++) 'Room $n',
];

/// Bottom sheet that confirms a borrow request. Shows the equipment card,
/// an optional purpose text field, and handles the submit / loading /
/// error states in one place. Caller passes the [Equipment] and gets a
/// [Future<Borrowing?>] back — the freshly-created row on success, or
/// `null` if the user cancelled.
class BorrowConfirmSheet extends StatefulWidget {
  const BorrowConfirmSheet({super.key, required this.equipment});

  final Equipment equipment;

  /// Convenience helper. Pops the sheet, runs the request, and returns
  /// the freshly-created borrowing if it succeeded. Caller is
  /// responsible for the success / error UI after the sheet closes.
  static Future<Borrowing?> show(
    BuildContext context, {
    required Equipment equipment,
  }) async {
    return showModalBottomSheet<Borrowing>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider<StudentDashboardController>.value(
          value: context.read<StudentDashboardController>(),
          child: BorrowConfirmSheet(equipment: equipment),
        );
      },
    );
  }

  @override
  State<BorrowConfirmSheet> createState() => _BorrowConfirmSheetState();
}

class _BorrowConfirmSheetState extends State<BorrowConfirmSheet> {
  final TextEditingController _purposeC = TextEditingController();
  final FocusNode _purposeFocus = FocusNode();
  bool _submitting = false;
  String? _error;
  int _quantity = 1;
  String? _room;

  @override
  void dispose() {
    _purposeC.dispose();
    _purposeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ctrl = context.read<StudentDashboardController>();
      final created = await ctrl.requestBorrowing(
        widget.equipment,
        quantity: _quantity,
        purpose: _purposeC.text.trim().isEmpty ? null : _purposeC.text.trim(),
        room: _room,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _humanize(e);
      });
    }
  }

  /// Supabase / RLS errors come back as `PostgrestException` with a long
  /// technical message. Strip it down to something a student can act on.
  String _humanize(Object e) {
    final raw = e.toString();
    if (raw.contains('row-level security')) {
      return "You don't have permission to do that. Try logging in again.";
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return "Can't reach the database. Check your internet and try again.";
    }
    if (raw.contains('JWT') || raw.contains('Auth')) {
      return "Your session has expired. Please log in again.";
    }
    // The unique index `borrowings_one_open_request_per_student_item`
    // (added in migration 0003) blocks a second open request for the
    // same equipment. Surface it as actionable text instead of the
    // raw Postgres message.
    if (raw.contains('duplicate key') ||
        raw.contains('borrowings_one_open_request_per_student_item') ||
        raw.contains('23505')) {
      return "You already have a pending or active request for this item. "
          'Return it or cancel it first, then try again.';
    }
    return "Something went wrong submitting your request. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipment;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = e.available > 0;
    final tone = available ? PupColors.techCyan : PupColors.signalRed;

    // Pre-flight check: the DB has a unique index that blocks a second
    // open request for the same (student, equipment). If the controller
    // already has a matching active or pending row, surface that here
    // so the user never gets the raw Postgres error.
    final ctrl = context.watch<StudentDashboardController>();
    final hasOpenRequest =
        ctrl.activeBorrowings.any((b) => b.equipmentId == e.id) ||
        ctrl.pendingBorrowings.any((b) => b.equipmentId == e.id);

    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      // Lift the sheet above the keyboard when the purpose field is
      // focused. Without this the field would be hidden under the IME.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(equipment: e, tone: tone, isDark: isDark),
                const SizedBox(height: 18),
                _DetailRow(equipment: e),
                const SizedBox(height: 14),
                _QuantityPicker(
                  quantity: _quantity,
                  max: e.available,
                  enabled: !_submitting && !hasOpenRequest,
                  onChanged: (quantity) => setState(() => _quantity = quantity),
                ),
                const SizedBox(height: 14),
                _RoomPicker(
                  room: _room,
                  enabled: !_submitting,
                  onChanged: (room) => setState(() => _room = room),
                ),
                const SizedBox(height: 14),
                _PurposeField(
                  controller: _purposeC,
                  focusNode: _purposeFocus,
                  enabled: !_submitting,
                ),
                const SizedBox(height: 16),
                if (hasOpenRequest && _error == null)
                  _ErrorBanner(
                    message:
                        "You already have an open request for this item. "
                        'Return it first or wait for admin to process it.',
                  ),
                if (_error != null) _ErrorBanner(message: _error!),
                _ActionRow(
                  submitting: _submitting,
                  available: available,
                  hasOpenRequest: hasOpenRequest,
                  onCancel: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  onSubmit: (_submitting || !available || hasOpenRequest)
                      ? null
                      : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Sheet pieces — kept as private widgets so the parent stays scannable.
// ───────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.equipment,
    required this.tone,
    required this.isDark,
  });

  final Equipment equipment;
  final Color tone;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Round gradient badge — the "this is the equipment you're
        // borrowing" focal point of the sheet.
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tone.withValues(alpha: 0.35),
                tone.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tone.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: isDark ? 0.35 : 0.20),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            equipment.available > 0
                ? Icons.inventory_2_rounded
                : Icons.block_rounded,
            color: tone,
            size: 32,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Confirm Borrow Request',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: subtleText,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                equipment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.equipment});

  final Equipment equipment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DetailChip(
            icon: Icons.tag_rounded,
            label:
                'ID: ${equipment.code.isEmpty ? equipment.id : equipment.code}',
          ),
          _DetailChip(
            icon: Icons.place_rounded,
            label: equipment.location.isEmpty
                ? 'Room not specified'
                : equipment.location,
          ),
          _DetailChip(
            icon: Icons.event_available_rounded,
            label: '3 days',
            tooltip: 'Default loan period after admin approval',
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label, this.tooltip});

  final IconData icon;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: PupColors.ashGray),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) return content;
    return Tooltip(message: tooltip!, child: content);
  }
}

class _QuantityPicker extends StatelessWidget {
  const _QuantityPicker({
    required this.quantity,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final canDecrease = enabled && quantity > 1;
    final canIncrease = enabled && quantity < max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: PupColors.techCyan),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity to borrow',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                Text(
                  '$max available',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          _QuantityButton(
            icon: Icons.remove_rounded,
            enabled: canDecrease,
            onTap: () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            enabled: canIncrease,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      color: PupColors.cyberAmber,
      disabledColor: Theme.of(context).disabledColor,
      style: IconButton.styleFrom(
        backgroundColor: PupColors.cyberAmber.withValues(alpha: 0.12),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _RoomPicker extends StatelessWidget {
  const _RoomPicker({
    required this.room,
    required this.enabled,
    required this.onChanged,
  });

  /// Currently selected room label; `null` renders as "No room".
  final String? room;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final label = room ?? 'No room';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_outlined, color: PupColors.techCyan),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                Text(
                  "Where you'll use it",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: room,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              hint: Text(
                'No room',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              disabledHint: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: PupColors.cyberAmber,
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('No room'),
                ),
                for (final r in _itechRooms)
                  DropdownMenuItem<String>(value: r, child: Text(r)),
              ],
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurposeField extends StatelessWidget {
  const _PurposeField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Purpose',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: isDark
                    ? Theme.of(context).colorScheme.onSurface
                    : PupColors.slateGray,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(optional)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: PupColors.ashGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          minLines: 2,
          maxLines: 3,
          maxLength: 200,
          textInputAction: TextInputAction.newline,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Electronics lab experiment, capstone prototype…',
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: PupColors.cyberAmber,
                width: 1.5,
              ),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.submitting,
    required this.available,
    required this.hasOpenRequest,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool submitting;
  final bool available;
  final bool hasOpenRequest;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  // Effective enable state for the primary action. Out of stock and
  // already-on-loan states both disable the button.
  bool get _canSubmit => available && !submitting && !hasOpenRequest;

  String get _label {
    if (hasOpenRequest) return 'Already Requested';
    if (!available) return 'Out of Stock';
    return 'Submit Request';
  }

  IconData get _icon {
    if (hasOpenRequest) return Icons.lock_outline_rounded;
    if (!available) return Icons.block_rounded;
    return Icons.outbox_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? Theme.of(context).colorScheme.onSurface
                    : PupColors.slateGray,
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: _canSubmit
                    ? PupColors.cyberAmber
                    : PupColors.ashGray,
                foregroundColor: const Color(0xFF1B1B1B),
                disabledBackgroundColor: PupColors.ashGray.withValues(
                  alpha: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: _canSubmit ? 2 : 0,
                shadowColor: PupColors.cyberAmber.withValues(alpha: 0.5),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF1B1B1B),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icon, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PupColors.signalRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PupColors.signalRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: PupColors.signalRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PupColors.signalRed,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight, theme-friendly snackbar that replaces the default red
/// one for success cases. Pushed from the search screen after the
/// borrow sheet closes successfully.
void showBorrowSuccessSnackBar(BuildContext context, String equipmentName) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: isDark
            ? const Color(0xFF1F2A22)
            : const Color(0xFFE8F5EC),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: PupColors.mintGreen.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PupColors.mintGreen.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: PupColors.mintGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Request submitted',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurface
                          : PupColors.slateGray,
                    ),
                  ),
                  Text(
                    'Awaiting admin approval for $equipmentName.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PupColors.ashGray,
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
