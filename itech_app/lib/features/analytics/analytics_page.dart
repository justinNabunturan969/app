import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../theme/design_tokens.dart';
import '../../student/student_dashboard_controller.dart';
import '../../widgets/notifications_bell_button.dart';

import 'data/mock_data.dart';
import 'widgets/stat_card.dart';
import 'widgets/bar_chart.dart';
import 'widgets/progress_list.dart';
import 'widgets/achievement_badge.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageIn;

  @override
  void initState() {
    super.initState();
    _pageIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pageIn.forward();
  }

  @override
  void dispose() {
    _pageIn.dispose();
    super.dispose();
  }

  Widget _stagger(int i, Widget child) {
    final start = i * 0.06;
    final end = start + 0.35;
    final anim = CurvedAnimation(
      parent: _pageIn,
      curve: Interval(
        start.clamp(0, 1),
        end.clamp(0, 1),
        curve: Curves.easeOut,
      ),
    );
    return FadeTransition(opacity: anim, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final weeklyActivity = context
        .select<StudentDashboardController, List<int>>(
          (controller) => controller.weeklyActivity,
        );
    final maxItemCount = AnalyticsMockData.topItems
        .map((e) => e.count)
        .fold<int>(0, (a, b) => a > b ? a : b);

    final percentOnTime = (AnalyticsMockData.onTimeRate * 100).round();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? theme.colorScheme.surface : PupColors.coolSteel;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'My Borrowing Analytics',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        actions: const [NotificationsBellButton(), ThemeMenuButton()],
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stagger(
                      0,
                      SizedBox(
                        // Bumped from 118 → 122 to absorb the ~0.8px content
                        // overflow (icon 34 + gap 10 + number + gap 4 + label
                        // render slightly taller than the original 118 budget).
                        height: 122,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            StatCard(
                              icon: Icons.book_rounded,
                              tone: PupColors.cyberAmber,
                              label: 'Total Borrowed',
                              targetValue: AnalyticsMockData.totalBorrowed,
                              isPercent: false,
                            ),
                            const SizedBox(width: 12),
                            StatCard(
                              icon: Icons.inventory_2_rounded,
                              tone: PupColors.techCyan,
                              label: 'Active Borrowings',
                              targetValue: AnalyticsMockData.activeBorrowings,
                              isPercent: false,
                            ),
                            const SizedBox(width: 12),
                            StatCard(
                              icon: Icons.timelapse_rounded,
                              tone: PupColors.mintGreen,
                              label: 'On-Time Rate',
                              targetValue: percentOnTime,
                              isPercent: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _stagger(1, MonthlyActivityBarChart(data: weeklyActivity)),
                    const SizedBox(height: 16),
                    _stagger(
                      2,
                      _AnalyticsSection(
                        title: 'Most Borrowed Items',
                        child: _TopItemsList(maxItemCount: maxItemCount),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _stagger(
                      3,
                      _AnalyticsSection(
                        title: 'Category Breakdown',
                        child: const _CategoryBreakdown(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _stagger(
                      4,
                      _AnalyticsSection(
                        title: 'Achievements',
                        child: const _AchievementsList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stagger(
                      5,
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _onTap,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PupColors.brand(context),
                                side: BorderSide(
                                  color: PupColors.brand(
                                    context,
                                  ).withValues(alpha: 0.4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Share Stats',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _onTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: PupColors.cyberAmber,
                                foregroundColor: const Color(0xFF1B1B1B),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Export Data',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap() {
    HapticFeedback.lightImpact();
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = scheme.onSurface;

    // Pick accent color based on title context
    final accent = switch (title) {
      'Most Borrowed Items' => PupColors.pupMaroon,
      'Category Breakdown' => PupColors.techCyan,
      'Achievements' => PupColors.mintGreen,
      _ => PupColors.cyberAmber,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: PupGlass.container(
        context: context,
        accent: accent,
        borderRadius: 18,
        blur: 14,
        offsetY: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (title) {
                  'Most Borrowed Items' => Icons.trending_up_rounded,
                  'Category Breakdown' => Icons.pie_chart_rounded,
                  'Achievements' => Icons.emoji_events_rounded,
                  _ => Icons.analytics_rounded,
                },
                size: 18,
                color: accent,
              ),
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
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TopItemsList extends StatelessWidget {
  const _TopItemsList({required this.maxItemCount});

  final int maxItemCount;

  @override
  Widget build(BuildContext context) {
    final items = AnalyticsMockData.topItems;

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          ProgressListItem(
            title: '${i + 1}. ${items[i].name}',
            value: items[i].count,
            maxValue: maxItemCount,
            color: PupColors.pupMaroon,
            rightText: '${items[i].count}x',
          ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown();

  @override
  Widget build(BuildContext context) {
    final cats = AnalyticsMockData.categories;
    final max = AnalyticsMockData.totalBorrowed;

    return Column(
      children: [
        for (final c in cats)
          ProgressListItem(
            title: c.name,
            value: (max * c.pct).round(),
            maxValue: max,
            color: c.color,
            rightText: '${(c.pct * 100).round()}%',
          ),
      ],
    );
  }
}

class _AchievementsList extends StatelessWidget {
  const _AchievementsList();

  @override
  Widget build(BuildContext context) {
    final achievements = AnalyticsMockData.achievements;

    return Column(
      children: [
        for (int i = 0; i < achievements.length; i++) ...[
          AchievementBadge(
            title: achievements[i].title,
            unlocked: achievements[i].unlocked,
          ),
          if (i != achievements.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
