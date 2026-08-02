import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class RecentSearches extends StatelessWidget {
  const RecentSearches({
    super.key,
    required this.queries,
    required this.onApply,
    required this.onClearAll,
    required this.onDeleteAt,
  });

  final List<String> queries;
  final ValueChanged<String> onApply;
  final VoidCallback onClearAll;
  final Future<void> Function(int index) onDeleteAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: titleColor,
                  ),
                ),
              ),
              if (queries.isNotEmpty)
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear all'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (queries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(height: 1),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ...List.generate(queries.length, (i) {
                  final q = queries[i];
                  return DismissibleRecentSearch(
                    q: q,
                    index: i,
                    onApply: onApply,
                    onDeleteAt: onDeleteAt,
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

class DismissibleRecentSearch extends StatelessWidget {
  const DismissibleRecentSearch({
    super.key,
    required this.q,
    required this.index,
    required this.onApply,
    required this.onDeleteAt,
  });

  final String q;
  final int index;
  final ValueChanged<String> onApply;
  final Future<void> Function(int index) onDeleteAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('recent_$q'),
        direction: DismissDirection.endToStart,
        background: Container(
          height: 46,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(
            color: PupColors.signalRed.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => onDeleteAt(index),
        child: InkWell(
          onTap: () => onApply(q),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: glassDecoration(
              context,
              PupColors.cyberAmber,
              borderRadius: 14,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: PupColors.cyberAmber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    q,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
