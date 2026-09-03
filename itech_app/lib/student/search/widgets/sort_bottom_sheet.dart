import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../student_search_controller.dart';

class SortBottomSheet extends StatelessWidget {
  const SortBottomSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final SearchSortBy current;
  final ValueChanged<SearchSortBy> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PupColors.slateGray;

    Widget option(SearchSortBy value, String label) {
      final selected = value == current;
      return ListTile(
        dense: true,
        leading: Icon(
          selected ? Icons.radio_button_checked_rounded : Icons.circle_outlined,
          color: selected
              ? PupColors.cyberAmber
              : isDark
              ? Colors.white70
              : PupColors.ashGray,
        ),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        onTap: () => onSelected(value),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sort By',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          option(SearchSortBy.relevance, 'Relevance'),
          option(SearchSortBy.nameAsc, 'Name (A-Z)'),
          option(SearchSortBy.nameDesc, 'Name (Z-A)'),
          option(
            SearchSortBy.availabilityFirst,
            'Availability (In Stock First)',
          ),
          option(SearchSortBy.newestFirst, 'Newest First'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PupColors.cyberAmber,
                  foregroundColor: const Color(0xFF1B1B1B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showSortBottomSheet({
  required BuildContext context,
  required SearchSortBy current,
  required ValueChanged<SearchSortBy> onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? PupColors.darkCard
        : Colors.white,
    showDragHandle: true,
    isScrollControlled: false,
    builder: (context) {
      return SortBottomSheet(
        current: current,
        onSelected: (v) {
          onSelected(v);
          Navigator.pop(context);
        },
      );
    },
  );
}
