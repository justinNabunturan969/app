import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../models.dart';

class ResultsGrid extends StatelessWidget {
  const ResultsGrid({
    super.key,
    required this.items,
    required this.onTapEquipment,
    required this.onToggleLike,
    required this.onBorrow,
  });

  final List<Equipment> items;
  final ValueChanged<Equipment> onTapEquipment;
  final ValueChanged<Equipment> onToggleLike;
  final ValueChanged<Equipment> onBorrow;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
        ),
        itemBuilder: (context, i) {
          final e = items[i];
          final available = e.available > 0;
          final tone = available ? PupColors.techCyan : PupColors.signalRed;
          // techCyan fails AA as small text on the pale light-mode tint, so
          // use the theme-aware cyan for the label; signalRed stays readable.
          final toneText = available
              ? PupColors.accentText(context)
              : PupColors.signalRed;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final titleColor = isDark
              ? Theme.of(context).colorScheme.onSurface
              : PupColors.slateGray;
          final subColor = isDark
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : PupColors.ashGray;

          return GestureDetector(
            onTap: () => onTapEquipment(e),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: PupGlass.glowContainer(
                context: context,
                accent: tone,
                borderRadius: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          available
                              ? Icons.inventory_2_rounded
                              : Icons.block_rounded,
                          color: tone,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                height: 1.2,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${e.available}/${e.total} available',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: tone.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          available ? 'Open' : 'Out',
                          style: TextStyle(
                            color: toneText,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onToggleLike(e),
                        icon: Icon(
                          e.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: e.isLiked ? PupColors.signalRed : subColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onBorrow(e),
                          style: FilledButton.styleFrom(
                            backgroundColor: PupColors.cyberAmber,
                            foregroundColor: const Color(0xFF1B1B1B),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Borrow',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
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
      ),
    );
  }
}
