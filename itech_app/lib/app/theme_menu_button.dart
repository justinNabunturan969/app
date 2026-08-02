import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme_controller.dart';

/// A reusable AppBar / header action that opens a Light / Dark / System menu
/// bound to a [ThemeController] provided higher in the tree.
///
/// The trigger icon swaps automatically to reflect the current mode
/// (sun / moon / brightness-auto) and the active option shows a check.
class ThemeMenuButton extends StatelessWidget {
  const ThemeMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ThemeController, ThemeMode>((c) => c.mode);
    final iconData = switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
    final tooltip = switch (mode) {
      ThemeMode.light => 'Theme: Light',
      ThemeMode.dark => 'Theme: Dark',
      ThemeMode.system => 'Theme: System',
    };

    return PopupMenuButton<ThemeMode>(
      icon: Icon(iconData),
      tooltip: tooltip,
      onSelected: (next) async {
        HapticFeedback.selectionClick();
        await context.read<ThemeController>().setMode(next);
      },
      itemBuilder: (context) => [
        _ThemeMenuItem(
          value: ThemeMode.light,
          label: 'Light',
          icon: Icons.light_mode_rounded,
          current: mode,
        ),
        _ThemeMenuItem(
          value: ThemeMode.dark,
          label: 'Dark',
          icon: Icons.dark_mode_rounded,
          current: mode,
        ),
        _ThemeMenuItem(
          value: ThemeMode.system,
          label: 'System',
          icon: Icons.brightness_auto_rounded,
          current: mode,
        ),
      ],
    );
  }
}

class _ThemeMenuItem extends PopupMenuItem<ThemeMode> {
  _ThemeMenuItem({
    required ThemeMode value,
    required String label,
    required IconData icon,
    required ThemeMode current,
  }) : super(
         value: value,
         child: Row(
           children: [
             Icon(icon, size: 18),
             const SizedBox(width: 12),
             Text(label),
             const Spacer(),
             if (current == value) const Icon(Icons.check, size: 18),
           ],
         ),
       );
}
