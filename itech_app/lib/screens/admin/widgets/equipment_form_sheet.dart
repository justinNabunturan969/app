import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../student/models.dart';
import '../../../theme/design_tokens.dart';

/// Shared form sheet for both **adding** and **editing** an equipment row.
///
/// Pass `equipment: null` to create, or a non-null [Equipment] to edit.
/// Returns the populated (or edited) [Equipment] from `Navigator.pop` on
/// success, or `null` if the user cancelled.
class EquipmentFormSheet extends StatefulWidget {
  const EquipmentFormSheet({
    super.key,
    this.equipment,
    required this.onSubmit,
  });

  /// Null = add mode, non-null = edit mode.
  final Equipment? equipment;

  /// Async submit handler. Returns the persisted [Equipment] on success
  /// or null on failure. The sheet shows a snackbar on failure and stays
  /// open so the user can retry.
  final Future<Equipment?> Function(EquipmentFormData data) onSubmit;

  bool get isEdit => equipment != null;

  @override
  State<EquipmentFormSheet> createState() => _EquipmentFormSheetState();
}

class _EquipmentFormSheetState extends State<EquipmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _total;
  late final TextEditingController _available;
  String _classification = 'electrical';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.equipment;
    _code = TextEditingController(text: e?.code ?? '');
    _name = TextEditingController(text: e?.name ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _total = TextEditingController(
      text: e == null ? '' : e.total.toString(),
    );
    _available = TextEditingController(
      text: e == null ? '' : e.available.toString(),
    );
    _classification = e?.classification ?? 'electrical';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _description.dispose();
    _total.dispose();
    _available.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final data = EquipmentFormData(
      code: _code.text.trim(),
      name: _name.text.trim(),
      category: _category.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
      totalCount: int.parse(_total.text.trim()),
      availableCount: int.parse(_available.text.trim()),
      classification: _classification,
    );
    final result = await widget.onSubmit(data);
    if (!mounted) return;
    if (result == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the equipment. Please try again.'),
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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
          child: Form(
            key: _formKey,
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
                Text(
                  widget.isEdit ? 'Edit equipment' : 'Add new equipment',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isEdit
                      ? 'Update the details, then save.'
                      : 'Fill in the inventory details to register a new item.',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                _LabeledField(
                  label: 'Equipment code',
                  hint: 'e.g. E-10115',
                  controller: _code,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Code is required'
                      : null,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Name',
                  hint: 'e.g. Bench Multimeter',
                  controller: _name,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Category',
                  hint: 'e.g. Test Equipment',
                  controller: _category,
                  required: false,
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Location',
                  hint: 'e.g. Room 301 - Electronics Lab',
                  controller: _location,
                  required: false,
                ),
                const SizedBox(height: 16),
                Text(
                  'Classification',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                _ClassificationChips(
                  selected: _classification,
                  onChanged: (v) => setState(() => _classification = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Total count',
                        hint: '0',
                        controller: _total,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) {
                            return 'Enter 0 or more';
                          }
                          return null;
                        },
                        onChanged: (v) {
                          // Keep the available count in range on the
                          // common path: if available > total, clamp it.
                          final total = int.tryParse(v.trim());
                          final avail = int.tryParse(_available.text.trim());
                          if (total != null && avail != null && avail > total) {
                            _available.text = total.toString();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Available',
                        hint: '0',
                        controller: _available,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) {
                            return 'Enter 0 or more';
                          }
                          final total =
                              int.tryParse(_total.text.trim()) ?? 0;
                          if (n > total) {
                            return 'Cannot exceed total ($total)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Description',
                  hint: 'Optional — short blurb about the equipment.',
                  controller: _description,
                  required: false,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
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
                            : Icon(
                                widget.isEdit
                                    ? Icons.save_rounded
                                    : Icons.add_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _submitting
                              ? 'Saving…'
                              : (widget.isEdit ? 'Save changes' : 'Add item'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: PupColors.pupMaroon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EquipmentFormData {
  const EquipmentFormData({
    required this.code,
    required this.name,
    required this.category,
    required this.location,
    required this.description,
    required this.totalCount,
    required this.availableCount,
    required this.classification,
  });
  final String code;
  final String name;
  final String category;
  final String location;
  final String description;
  final int totalCount;
  final int availableCount;
  final String classification;
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.validator,
    this.hint,
    this.required = true,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: subtle,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  color: PupColors.signalRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
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
                color: subtle.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: PupColors.cyberAmber.withValues(alpha: 0.85),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassificationChips extends StatelessWidget {
  const _ClassificationChips({
    required this.selected,
    required this.onChanged,
  });
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final options = const [
      ('electrical', 'Electrical', Icons.bolt_rounded, PupColors.cyberAmber),
      ('computer', 'Computer', Icons.memory_rounded, PupColors.techCyan),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = selected == o.$1;
        return InkWell(
          onTap: () => onChanged(o.$1),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? o.$4.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? o.$4
                    : (isDark
                        ? PupGlass.darkBorder(o.$4)
                        : PupColors.ashGray.withValues(alpha: 0.3)),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  o.$3,
                  size: 14,
                  color: isSelected
                      ? o.$4
                      : (isDark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                          : PupColors.slateGray),
                ),
                const SizedBox(width: 6),
                Text(
                  o.$2,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: isSelected
                        ? o.$4
                        : (isDark
                            ? theme.colorScheme.onSurface
                            : PupColors.slateGray),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
