import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Password strength score (0..4) mapped to color + label.
enum PasswordStrength {
  empty,
  weak,
  fair,
  good,
  strong;

  static PasswordStrength from(String value) {
    if (value.isEmpty) return PasswordStrength.empty;
    int score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    // 1..4 → map to weak..strong
    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.fair;
    if (score == 3) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.empty:
        return PupColors.ashGray.withValues(alpha: 0.3);
      case PasswordStrength.weak:
        return PupColors.signalRed;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.good:
        return PupColors.cyberAmber;
      case PasswordStrength.strong:
        return PupColors.mintGreen;
    }
  }

  int get segments {
    switch (this) {
      case PasswordStrength.empty:
        return 0;
      case PasswordStrength.weak:
        return 1;
      case PasswordStrength.fair:
        return 2;
      case PasswordStrength.good:
        return 3;
      case PasswordStrength.strong:
        return 4;
    }
  }
}

/// Password text field with show/hide toggle + 4-segment strength meter.
///
/// Used in both student and admin login pages. Animates segment fill on
/// strength change so the meter feels alive as the user types.
class PasswordStrengthField extends StatefulWidget {
  const PasswordStrengthField({
    super.key,
    required this.controller,
    required this.validator,
    this.label = 'Password',
    this.hint = '••••••••',
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String label;
  final String hint;
  final AutovalidateMode autovalidateMode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordStrengthField> createState() => _PasswordStrengthFieldState();
}

class _PasswordStrengthFieldState extends State<PasswordStrengthField> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength.from(widget.controller.text);
    final showMeter = widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: showMeter
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StrengthBar(
                          filled: strength.segments,
                          total: 4,
                          color: strength.color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: Text(
                          strength.label,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: strength.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(height: 0, width: double.infinity),
        ),
      ],
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({
    required this.filled,
    required this.total,
    required this.color,
  });

  final int filled;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final empty = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : PupColors.ashGray.withValues(alpha: 0.18);

    return Row(
      children: List.generate(total, (i) {
        final isActive = i < filled;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? color : empty,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
