import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class TrendingSearches extends StatelessWidget {
  const TrendingSearches({super.key, required this.onTapChip});

  final ValueChanged<String> onTapChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final borderColor = isDark
        ? PupGlass.darkBorder(PupColors.cyberAmber)
        : PupColors.ashGray.withValues(alpha: 0.3);
    final textColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    final chips = const <String>[
      'Multimeter',
      'Wrench Set',
      'Arduino Kit',
      'Oscilloscope',
      'Power Supply',
      'Soldering',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Trending Now',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: titleColor,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final label = chips[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTapChip(label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
