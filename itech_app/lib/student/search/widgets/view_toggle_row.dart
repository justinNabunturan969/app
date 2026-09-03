import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../student_search_controller.dart';

class ViewToggleRow extends StatelessWidget {
  const ViewToggleRow({
    super.key,
    required this.mode,
    required this.onMode,
    required this.onSort,
  });

  final SearchViewMode mode;
  final ValueChanged<SearchViewMode> onMode;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ToggleButton(
            label: 'List',
            icon: Icons.view_list_rounded,
            active: mode == SearchViewMode.list,
            onTap: () => onMode(SearchViewMode.list),
          ),
          const SizedBox(width: 10),
          _ToggleButton(
            label: 'Grid',
            icon: Icons.grid_view_rounded,
            active: mode == SearchViewMode.grid,
            onTap: () => onMode(SearchViewMode.grid),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Sort',
            onPressed: onSort,
            icon: const Icon(Icons.sort_rounded),
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : PupColors.slateGray,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : PupColors.slateGray;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? PupColors.cyberAmber
              : isDark
              ? PupColors.darkCard
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (active)
              BoxShadow(
                color: PupColors.cyberAmber.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05),
            width: isDark ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? const Color(0xFF1B1B1B) : inactiveColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: active ? const Color(0xFF1B1B1B) : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
