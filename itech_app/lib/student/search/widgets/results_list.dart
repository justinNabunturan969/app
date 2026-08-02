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
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = items[i];
          final available = e.available > 0;
          final tone = available ? PupColors.techCyan : PupColors.signalRed;

          return GestureDetector(
            onTap: () => onTapEquipment(e),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: PupGlass.glowContainer(
                context: context,
                accent: tone,
                borderRadius: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      available
                          ? Icons.inventory_2_rounded
                          : Icons.block_rounded,
                      color: tone,
                      size: 17,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: PupColors.slateGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.id}  •  ${e.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: PupColors.ashGray,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tone,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      available ? 'Open' : 'Out',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onToggleLike(e),
                    icon: Icon(
                      e.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: e.isLiked
                          ? PupColors.signalRed
                          : PupColors.ashGray,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 70,
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
                          fontSize: 11,
                        ),
                      ),
                    ),
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
