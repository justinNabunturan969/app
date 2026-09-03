import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../models.dart';

class ResultsList extends StatelessWidget {
  const ResultsList({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = items[i];
          final available = e.available > 0;
          final tone = available ? PupColors.techCyan : PupColors.signalRed;
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? PupGlass.darkFill(tone)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? PupGlass.darkBorder(tone)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
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
                        child: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: titleColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tone,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          available ? 'Available' : 'Borrowed',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${e.id} • ${e.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: subColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        onPressed: () => onToggleLike(e),
                        icon: Icon(
                          e.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: e.isLiked ? PupColors.signalRed : subColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onBorrow(e),
                          style: FilledButton.styleFrom(
                            backgroundColor: PupColors.cyberAmber,
                            foregroundColor: const Color(0xFF1B1B1B),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Borrow',
                            style: TextStyle(fontWeight: FontWeight.w900),
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
