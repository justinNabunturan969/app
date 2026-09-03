import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../data/repositories/repository_bundle.dart';
import '../../data/repositories/user_repository.dart';
import '../../main.dart';
import '../../theme/design_tokens.dart';

/// Account details for the signed-in administrator. The data comes from the
/// same Supabase `profiles` row used by the rest of the app.
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : PupColors.slateGray;
    final subtle = isDark
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)
        : PupColors.ashGray;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: context.read<RepositoryBundle>().user.getCurrentUser(),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Back to dashboard',
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Admin Profile',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const ThemeMenuButton(),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _HeroCard(
                          initials: _initials(profile?.studentName ?? 'Admin'),
                          name: profile?.studentName ?? 'Loading account…',
                          email: profile?.studentEmail ?? '',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Account Information',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (snapshot.hasError)
                          _MessageCard(
                            icon: Icons.cloud_off_rounded,
                            message:
                                'Unable to load your administrator profile.',
                            color: PupColors.signalRed,
                          )
                        else if (profile == null)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          _InfoCard(
                            icon: Icons.alternate_email_rounded,
                            label: 'Email',
                            value: profile.studentEmail,
                          ),
                          const SizedBox(height: 8),
                          _InfoCard(
                            icon: Icons.badge_rounded,
                            label: 'Staff ID',
                            value: profile.studentId.isEmpty
                                ? 'Not set'
                                : profile.studentId,
                          ),
                          const SizedBox(height: 8),
                          _InfoCard(
                            icon: Icons.school_rounded,
                            label: 'Department / Program',
                            value: profile.studentProgram.isEmpty
                                ? 'PUP Institute of Technology'
                                : profile.studentProgram,
                          ),
                          const SizedBox(height: 18),
                          _MessageCard(
                            icon: Icons.verified_user_rounded,
                            message:
                                'Administrator access is verified through your Supabase profile role.',
                            color: PupColors.successText(context),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmLogout(context),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PupColors.signalRed,
                              side: const BorderSide(
                                color: PupColors.signalRed,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        Text(
                          'Your account information is managed securely in Supabase.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subtle, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'AD';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to manage equipment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await authSessionStorage.clearSession();
    if (context.mounted) context.go('/role');
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.initials,
    required this.name,
    required this.email,
  });

  final String initials;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PupColors.pupMaroon, PupColors.deepMahogany],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Administrator',
                  style: TextStyle(
                    color: PupColors.cyberAmber,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: PupColors.techCyan),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : PupColors.ashGray,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    required this.color,
  });
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
