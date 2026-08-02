import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Text field with an icon prefix, inline validation, and an optional
/// trailing check-mark when valid. Used by all the auth fields.
class FormTextField extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final AutovalidateMode autovalidateMode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.text;
        final error = validator(value);
        final showCheck =
            value.trim().isNotEmpty && error == null;

        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: autovalidateMode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: showCheck
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: PupColors.mintGreen,
                    size: 20,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
