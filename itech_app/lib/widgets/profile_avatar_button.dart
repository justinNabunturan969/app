import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Tappable circular avatar (initials) that opens a popup menu with
/// account actions. Used in place of an in-line logout icon so the user
/// can't trigger a destructive action with a stray tap.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({
    super.key,
    required this.initials,
    required this.roleLabel,
    required this.onProfile,
    required this.onLogout,
    this.onSwitchTheme,
  });

  final String initials;
  final String roleLabel;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final VoidCallback? onSwitchTheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : PupColors.ashGray.withValues(alpha: 0.18),
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onProfile();
            break;
          case 'theme':
            onSwitchTheme?.call();
            break;
          case 'logout':
            onLogout();
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PupColors.pupMaroon, PupColors.deepMahogany],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleLabel,
                    style: TextStyle(
                      color: isDark ? Colors.white : PupColors.slateGray,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Tap an action',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : PupColors.ashGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'profile',
          child: _MenuRow(
            icon: Icons.person_rounded,
            label: 'Profile',
            color: PupColors.techCyan,
          ),
        ),
        if (onSwitchTheme != null)
          PopupMenuItem<String>(
            value: 'theme',
            child: _MenuRow(
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              label: isDark ? 'Light mode' : 'Dark mode',
              color: PupColors.cyberAmber,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: _MenuRow(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            color: PupColors.signalRed,
          ),
        ),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PupColors.pupMaroon, PupColors.deepMahogany],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: PupColors.pupMaroon.withValues(alpha: 0.32),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }
}
