import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// One row in the admin dashboard's "Recent Activity" feed.
class ActivityFeedItem extends StatelessWidget {
  const ActivityFeedItem({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  /// Absolute, permanent date stamp — e.g. "Aug 28, 2026 · 2:45 PM".
  /// Unlike a relative "2h ago" label, this never changes or loses
  /// meaning as the entry ages, so the feed reads as a proper log.
  String _formatTimestamp(DateTime t) {
    final local = t.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} · '
        '$hour12:$minute $amPm';
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tone.withValues(alpha: 0.30),
                  tone.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tone.withValues(alpha: 0.40),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: tone, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityFeedHeader extends StatelessWidget {
  const ActivityFeedHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PupColors.techCyan.withValues(alpha: 0.30),
                PupColors.techCyan.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: PupColors.techCyan.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: PupColors.techCyan,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Recent Activity',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: -0.1,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class EmptyActivityHint extends StatelessWidget {
  const EmptyActivityHint({super.key, required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tone = PupColors.ashGray;
    final messageColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: messageColor,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
