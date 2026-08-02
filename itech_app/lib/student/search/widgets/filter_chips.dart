import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.selectedCategories,
    required this.availableOnly,
    required this.onToggleAvailable,
    required this.onToggleCategory,
  });

  final Set<String> selectedCategories;
  final bool availableOnly;
  final ValueChanged<bool> onToggleAvailable;
  final ValueChanged<String> onToggleCategory;

  @override
  Widget build(BuildContext context) {
    const categories = <String>[
      'Mechanical',
      'Electrical',
      'Tools',
      'Testers',
      'Arduino',
      'Power Supply',
    ];

    // Map UI options to actual model categories.
    // Model uses category values like: Electrical, Mechanical, Testers, Tools.
    String categoryToModel(String ui) {
      switch (ui) {
        case 'Arduino':
          return 'Testers';
        case 'Power Supply':
          return 'Tools';
        default:
          return ui;
      }
    }

    final chips = <_ChipSpec>[
      _ChipSpec('All', null),
      _ChipSpec('Available ✅', 'AVAILABLE'),
      ...categories.map((c) => _ChipSpec(c, categoryToModel(c))),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final spec = chips[i];
          final isSelected = switch (spec.kind) {
            null => selectedCategories.isEmpty && !availableOnly,
            'AVAILABLE' => availableOnly,
            final k => selectedCategories.contains(k as String),
          };

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              final h = isSelected; // selected -> deselect
              if (spec.kind == null) {
                // "All" chip is implemented as reset all filters.
                onToggleAvailable(false);
                onToggleCategory('__RESET__');
              } else if (spec.kind == 'AVAILABLE') {
                onToggleAvailable(!h);
              } else {
                onToggleCategory(spec.kind as String);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? PupColors.cyberAmber : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: PupColors.ashGray.withValues(alpha: 0.3),
                      ),
              ),
              child: Center(
                child: Text(
                  spec.label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF1B1B1B)
                        : PupColors.ashGray,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec(this.label, this.kind);
  final String label;
  final Object? kind;
}
