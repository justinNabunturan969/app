import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class NoResultsState extends StatelessWidget {
  const NoResultsState({
    super.key,
    required this.query,
    required this.onUseChip,
  });

  final String query;
  final ValueChanged<String> onUseChip;

  @override
  Widget build(BuildContext context) {
    const popular = ['Multimeter', 'Wrench', 'Arduino', 'Oscilloscope'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : PupColors.slateGray;
    final subColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : PupColors.ashGray;
    final panelFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.65);
    final panelBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.search_rounded, color: PupColors.cyberAmber),
              const SizedBox(width: 10),
              Text(
                'No results found for "$query"',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panelFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try searching for:',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '• Different keywords',
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '• Check spelling',
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '• Use shorter terms',
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Popular Searches:',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: popular.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final label = popular[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onUseChip(label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: PupColors.ashGray.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SearchingShimmerState extends StatelessWidget {
  const SearchingShimmerState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : PupColors.slateGray;

    // Simple shimmer blocks (no dependency)
    Widget block() => Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.55),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: PupColors.cyberAmber,
              ),
              const SizedBox(width: 8),
              Text(
                'Searching…',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: block(),
            ),
          ),
        ],
      ),
    );
  }
}
