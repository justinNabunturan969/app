import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme_menu_button.dart';
import '../../app/language_controller.dart';
import '../../data/repositories/repository_bundle.dart';
import '../../features/analytics/widgets/achievement_badge.dart';
import '../../main.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import 'package:provider/provider.dart';

/// Student profile tab.
///
/// Reuses the same visual language as Home / Borrowings / Analytics
/// (PupColors, PupGlass, tinted icon chips, light/dark aware) and pulls
/// every piece of data from `StudentDashboardController` so the profile
/// stays in sync with the rest of the app.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? scheme.onSurface : PupColors.slateGray;
    final subtleText = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Consumer<StudentDashboardController>(
      builder: (context, ctrl, _) {
        final language = context.watch<LanguageController>();
        final copy = AppCopy(language.language);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            _EditProfileButton(
                              onPressed: () =>
                                  _showEditProfileSheet(context, ctrl),
                            ),
                            const SizedBox(width: 4),
                            const ThemeMenuButton(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your account, achievements, and preferences.',
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Hero card
                        _ProfileHeroCard(
                          name: ctrl.studentName,
                          program: ctrl.studentProgram,
                          studentId: ctrl.studentId,
                          yearLevel: ctrl.studentYearLevel,
                          section: ctrl.studentSection,
                          memberSince: ctrl.memberSince,
                        ),
                        const SizedBox(height: 14),

                        // Stats grid (2x2)
                        _StatsGrid(
                          active: ctrl.activeBorrowingsCount,
                          overdue: ctrl.overdueCount,
                          returned: ctrl.returnedCount,
                          total: ctrl.totalLoans,
                        ),
                        const SizedBox(height: 16),

                        // Account info
                        _Section(
                          title: 'Account Information',
                          icon: Icons.person_rounded,
                          accent: PupColors.techCyan,
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email',
                          value: ctrl.studentEmail,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Student ID',
                          value: ctrl.studentId,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.school_rounded,
                          label: 'Program',
                          value: ctrl.studentProgram,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.class_rounded,
                          label: 'Year & Section',
                          value:
                              '${ctrl.studentYearLevel} • ${ctrl.studentSection}',
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.event_available_rounded,
                          label: 'Member Since',
                          value: _formatMemberSince(ctrl.memberSince),
                        ),
                        const SizedBox(height: 18),

                        // Achievements
                        _Section(
                          title: 'Achievements',
                          icon: Icons.emoji_events_rounded,
                          accent: PupColors.mintGreen,
                        ),
                        const SizedBox(height: 10),
                        for (final a in _buildAchievements(ctrl))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AchievementBadge(
                              title: a.title,
                              unlocked: a.unlocked,
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Preferences
                        _Section(
                          title: 'Preferences',
                          icon: Icons.tune_rounded,
                          accent: PupColors.cyberAmber,
                        ),
                        const SizedBox(height: 10),
                        _SwitchRow(
                          icon: Icons.notifications_active_rounded,
                          title: 'Push Notifications',
                          subtitle: 'Reminders for due dates and approvals',
                          value: _notificationsEnabled,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _notificationsEnabled = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        _SwitchRow(
                          icon: Icons.vibration_rounded,
                          title: 'Haptic Feedback',
                          subtitle: 'Vibrate on actions and tab switches',
                          value: _hapticsEnabled,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _hapticsEnabled = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        _NavRow(
                          icon: Icons.language_rounded,
                          title: copy.appLanguage,
                          trailing: language.language.label,
                          onTap: () =>
                              _showLanguagePicker(context, language, copy),
                        ),
                        const SizedBox(height: 18),

                        // Support
                        _Section(
                          title: 'Support & About',
                          icon: Icons.help_outline_rounded,
                          accent: PupColors.pupMaroon,
                        ),
                        const SizedBox(height: 10),
                        _NavRow(
                          icon: Icons.help_center_rounded,
                          title: 'Help Center',
                          onTap: () =>
                              _snack(context, 'Opening Help Center...'),
                        ),
                        const SizedBox(height: 8),
                        _NavRow(
                          icon: Icons.description_rounded,
                          title: 'Terms of Service',
                          onTap: () =>
                              _snack(context, 'Opening Terms of Service...'),
                        ),
                        const SizedBox(height: 8),
                        _NavRow(
                          icon: Icons.privacy_tip_rounded,
                          title: 'Privacy Policy',
                          onTap: () =>
                              _snack(context, 'Opening Privacy Policy...'),
                        ),
                        const SizedBox(height: 8),
                        _NavRow(
                          icon: Icons.info_outline_rounded,
                          title: 'About PUP-ITech',
                          trailing: 'v1.0.0',
                          onTap: () => _showAboutDialog(context),
                        ),
                        const SizedBox(height: 8),
                        _NavRow(
                          icon: Icons.palette_rounded,
                          title: 'Design System',
                          trailing: 'v1.0',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/student/design-system');
                          },
                        ),
                        const SizedBox(height: 24),

                        // Logout
                        _LogoutButton(onTap: () => _logout(context)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your borrowings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: PupColors.signalRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await authSessionStorage.clearSession();
    if (!context.mounted) return;
    context.go('/role');
  }

  void _snack(BuildContext context, String message) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    LanguageController language,
    AppCopy copy,
  ) async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.chooseAppLanguage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(copy.appLanguageHelp),
              const SizedBox(height: 12),
              for (final option in AppLanguage.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    option == AppLanguage.english
                        ? Icons.language_rounded
                        : option == AppLanguage.tagalog
                        ? Icons.record_voice_over_rounded
                        : Icons.forum_rounded,
                  ),
                  title: Text(option.label),
                  subtitle: Text(option.speechLocaleId),
                  trailing: option == language.language
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: PupColors.mintGreen,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await language.setLanguage(selected);
    if (!context.mounted) return;
    _snack(context, copy.languageSelected(selected.label));
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    StudentDashboardController ctrl,
  ) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: ctrl.studentName);
    final program = TextEditingController(text: ctrl.studentProgram);
    final year = TextEditingController(text: ctrl.studentYearLevel);
    final section = TextEditingController(text: ctrl.studentSection);

    final values = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Enter your name.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: program,
                decoration: const InputDecoration(labelText: 'Program'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: year,
                      decoration: const InputDecoration(
                        labelText: 'Year level',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: section,
                      decoration: const InputDecoration(labelText: 'Section'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(sheetContext, {
                    'fullName': name.text,
                    'program': program.text,
                    'yearLevel': year.text,
                    'section': section.text,
                  });
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    program.dispose();
    year.dispose();
    section.dispose();
    if (values == null || !context.mounted) return;

    try {
      await context.read<RepositoryBundle>().user.updateCurrentProfile(
        fullName: values['fullName']!,
        program: values['program']!,
        yearLevel: values['yearLevel']!,
        section: values['section']!,
      );
      await ctrl.load();
      if (!context.mounted) return;
      _snack(context, 'Profile updated.');
    } catch (_) {
      if (!context.mounted) return;
      _snack(context, 'Could not update your profile. Please try again.');
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PUP-ITech Borrowing'),
        content: const Text(
          'A prototype equipment-borrowing system for the PUP Institute of Technology.\n\n'
          'Built with Flutter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────

String _formatMemberSince(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

class _Achievement {
  const _Achievement(this.title, this.unlocked);
  final String title;
  final bool unlocked;
}

/// Derives a small set of achievements from the controller's data so the
/// profile always reflects the user's actual activity.
List<_Achievement> _buildAchievements(StudentDashboardController ctrl) {
  final hasHistory = ctrl.historyBorrowings.isNotEmpty;
  final hasReturned = ctrl.returnedCount > 0;
  final hasOverdue = ctrl.overdueCount > 0;
  final isFrequent = ctrl.totalLoans >= 5;
  final isVeteran = ctrl.totalLoans >= 10;

  return [
    _Achievement('Early Adopter', true), // joined in 2024
    _Achievement('First Borrow', hasHistory || ctrl.activeBorrowingsCount > 0),
    _Achievement('On-Time Returner', hasReturned),
    _Achievement('Frequent Borrower', isFrequent),
    _Achievement('Overdue-Free', !hasOverdue && ctrl.totalLoans > 0),
    if (isVeteran) _Achievement('Veteran Borrower (10+)', true),
  ];
}

// ─────────────────────────────────────────────────────────────────────────
// Hero card
// ─────────────────────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.program,
    required this.studentId,
    required this.yearLevel,
    required this.section,
    required this.memberSince,
  });

  final String name;
  final String program;
  final String studentId;
  final String yearLevel;
  final String section;
  final DateTime memberSince;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: PupColors.pupMaroon,
        borderRadius: 18,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PupColors.pupMaroon, PupColors.deepMahogany],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: PupColors.pupMaroon.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PupColors.pupMaroon,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'PUP',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  program,
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$studentId  •  $yearLevel • $section',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event_rounded, size: 12, color: subtleText),
                    const SizedBox(width: 4),
                    Text(
                      'Member since ${_formatMemberSince(memberSince)}',
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Stats grid (2x2)
// ─────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.active,
    required this.overdue,
    required this.returned,
    required this.total,
  });

  final int active;
  final int overdue;
  final int returned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '$active',
                label: 'Active',
                tone: PupColors.techCyan,
                icon: Icons.bolt_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: '$overdue',
                label: 'Overdue',
                tone: PupColors.signalRed,
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '$returned',
                label: 'Returned',
                tone: PupColors.mintGreen,
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: '$total',
                label: 'Total Loans',
                tone: PupColors.cyberAmber,
                icon: Icons.assignment_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String value;
  final String label;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final valueColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _MiniIconChip(icon: icon, tone: tone),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIconChip extends StatelessWidget {
  const _MiniIconChip({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.1),
      ),
      child: Icon(icon, color: tone, size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section header (matches analytics _AnalyticsSection pattern)
// ─────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: titleColor,
            ),
          ),
        ),
        Container(
          height: 3,
          width: 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Info row (account details) — icon + label/value, no trailing
// ─────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final valueColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : PupColors.ashGray;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : PupColors.ashGray.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : PupColors.ashGray.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: labelColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Nav row (settings/support) — icon + title + trailing, tappable
// ─────────────────────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : PupColors.ashGray;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : PupColors.ashGray.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : PupColors.ashGray.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: subtleText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right_rounded, size: 18, color: subtleText),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Switch row (preferences)
// ─────────────────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : PupColors.ashGray;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : PupColors.ashGray.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : PupColors.ashGray.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: subtleText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: PupColors.cyberAmber,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Edit profile button (icon-only, sits in the header next to theme toggle)
// ─────────────────────────────────────────────────────────────────────────

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return IconButton(
      tooltip: 'Edit profile',
      onPressed: onPressed,
      icon: Icon(Icons.edit_rounded, color: fg, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Logout button
// ─────────────────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout_rounded),
        label: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: PupColors.signalRed,
          side: BorderSide(color: PupColors.signalRed.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
