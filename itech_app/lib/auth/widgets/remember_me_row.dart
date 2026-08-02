import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class RememberMeRow extends StatelessWidget {
  const RememberMeRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : PupColors.slateGray;
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: PupColors.cyberAmber,
        ),
        const SizedBox(width: 4),
        Text(
          'Remember Me',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
