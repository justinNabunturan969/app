import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// One entry in the responsive shell's nav. Both [NavigationRail] (wide)
/// and `BottomNavigationBar` (narrow) consume the same data so the
/// user gets a consistent label + icon set across form factors.
class ShellTab {
  const ShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// When > 0, a red pill badge with this count is drawn on the tab's
  /// icon in both the bottom-nav and the rail. Tabs that don't need a
  /// badge simply leave it at 0. The shell decides what the count means
  /// (e.g. pending borrow requests, unseen login events).
  final int badgeCount;
}

/// A scaffold that switches between a `BottomNavigationBar` (narrow /
/// mobile) and a `NavigationRail` (wide / desktop / Chrome) based on
/// the current available width. The [body] is wrapped in a
/// `ConstrainedBox(maxWidth: 720)` on wide screens so the content
/// stays readable while still taking advantage of a desktop-sized browser.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.tabs,
    required this.onTabTap,
    required this.body,
    this.unreadCount = 0,
    this.appBarTitle,
    this.showAppBar = false,
  });

  /// Below this width, we render the mobile (bottom-nav) layout. 720dp
  /// is the standard "small tablet / large phone" cutoff in Material 3.
  static const double wideBreakpoint = 720;

  final int currentIndex;
  final List<ShellTab> tabs;
  final ValueChanged<int> onTabTap;
  final Widget body;
  final int unreadCount;
  final String? appBarTitle;
  final bool showAppBar;

  bool _isWide(double width) => width >= wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isWide(constraints.maxWidth)) {
          return _WideScaffold(
            currentIndex: currentIndex,
            tabs: tabs,
            onTabTap: onTabTap,
            body: body,
            unreadCount: unreadCount,
            appBarTitle: appBarTitle,
            showAppBar: showAppBar,
          );
        }
        return _NarrowScaffold(
          currentIndex: currentIndex,
          tabs: tabs,
          onTabTap: onTabTap,
          body: body,
          unreadCount: unreadCount,
          appBarTitle: appBarTitle,
          showAppBar: showAppBar,
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Mobile / narrow: bottom navigation bar
// ───────────────────────────────────────────────────────────────────────

class _NarrowScaffold extends StatelessWidget {
  const _NarrowScaffold({
    required this.currentIndex,
    required this.tabs,
    required this.onTabTap,
    required this.body,
    required this.unreadCount,
    required this.appBarTitle,
    required this.showAppBar,
  });

  final int currentIndex;
  final List<ShellTab> tabs;
  final ValueChanged<int> onTabTap;
  final Widget body;
  final int unreadCount;
  final String? appBarTitle;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark
        ? PupColors.deepMahogany.withValues(alpha: 0.78)
        : PupColors.lightCardAlt.withValues(alpha: 0.92);
    final activeColor = isDark ? PupColors.cyberAmber : PupColors.signalRed;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : PupColors.ashGray.withValues(alpha: 0.75);

    return Scaffold(
      appBar: showAppBar ? _buildAppBar(context) : null,
      body: body,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        child: Container(
          color: navBg,
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: currentIndex,
              onTap: onTabTap,
              backgroundColor: Colors.transparent,
              elevation: 8,
              selectedItemColor: activeColor,
              unselectedItemColor: unselectedColor,
              items: _buildItems(activeColor: activeColor, isDark: isDark),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (appBarTitle == null) return null;
    return AppBar(
      title: Text(appBarTitle!),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  List<BottomNavigationBarItem> _buildItems({
    required Color activeColor,
    required bool isDark,
  }) {
    return List.generate(tabs.length, (i) {
      final tab = tabs[i];
      final selected = i == currentIndex;
      Widget icon = Icon(selected ? tab.selectedIcon : tab.icon);
      // Per-tab badge (admin shell sets badgeCount on specific tabs), with
      // a fallback for the notifications tab driven by `unreadCount` so the
      // student shell keeps its existing behavior without per-tab counts.
      final isNotifTab = tab.label.toLowerCase().contains('notif');
      final count = tab.badgeCount > 0
          ? tab.badgeCount
          : (isNotifTab && i == tabs.length - 1 ? unreadCount : 0);
      if (count > 0) {
        icon = Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              top: -6,
              right: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: PupColors.signalRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return BottomNavigationBarItem(icon: icon, label: tab.label);
    });
  }
}

// ───────────────────────────────────────────────────────────────────────
// Desktop / wide: NavigationRail on the left, constrained body on the right
// ───────────────────────────────────────────────────────────────────────

class _WideScaffold extends StatelessWidget {
  const _WideScaffold({
    required this.currentIndex,
    required this.tabs,
    required this.onTabTap,
    required this.body,
    required this.unreadCount,
    required this.appBarTitle,
    required this.showAppBar,
  });

  final int currentIndex;
  final List<ShellTab> tabs;
  final ValueChanged<int> onTabTap;
  final Widget body;
  final int unreadCount;
  final String? appBarTitle;
  final bool showAppBar;

  static const double _railWidth = 240;
  // 760px made a maximized desktop browser look like a narrow tablet with
  // large empty gutters. 1180px gives dashboard grids enough room to breathe
  // while preserving a deliberate, readable line length on ultrawide screens.
  static const double _contentMaxWidth = 1180;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBg = isDark
        ? PupColors.deepMahogany.withValues(alpha: 0.55)
        : PupColors.lightCardAlt.withValues(alpha: 0.85);
    final activeColor = isDark ? PupColors.cyberAmber : PupColors.signalRed;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : PupColors.ashGray.withValues(alpha: 0.85);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            // ── Left rail ─────────────────────────────────────────
            Container(
              width: _railWidth,
              decoration: BoxDecoration(
                color: railBg,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand mark — gives the rail some visual weight at
                  // the top so it doesn't look like a floating list.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: PupColors.pupMaroon,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/branding/pup_itech_source_icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              semanticLabel: 'PUP-ITech',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PUP-ITech',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Theme.of(context).colorScheme.onSurface
                                      : PupColors.slateGray,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'Equipment Borrowing',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: PupColors.ashGray,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      itemCount: tabs.length,
                      itemBuilder: (context, i) {
                        final tab = tabs[i];
                        final selected = i == currentIndex;
                        final isNotifTab = tab.label
                            .toLowerCase()
                            .contains('notif');
                        final count = tab.badgeCount > 0
                            ? tab.badgeCount
                            : (isNotifTab && i == tabs.length - 1
                                  ? unreadCount
                                  : 0);
                        return _RailTile(
                          tab: tab,
                          selected: selected,
                          activeColor: activeColor,
                          unselectedColor: unselectedColor,
                          showBadge: count > 0,
                          badgeCount: count,
                          onTap: () => onTabTap(i),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // ── Main content area ─────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: showAppBar && appBarTitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                              child: Text(
                                appBarTitle!,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Theme.of(context).colorScheme.onSurface
                                      : PupColors.slateGray,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            Expanded(child: body),
                          ],
                        )
                      : body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.tab,
    required this.selected,
    required this.activeColor,
    required this.unselectedColor,
    required this.onTap,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  final ShellTab tab;
  final bool selected;
  final Color activeColor;
  final Color unselectedColor;
  final VoidCallback onTap;
  final bool showBadge;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintBg = selected
        ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
        : Colors.transparent;

    Widget icon = Icon(
      selected ? tab.selectedIcon : tab.icon,
      color: selected ? activeColor : unselectedColor,
      size: 22,
    );
    if (showBadge) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -4,
            right: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: PupColors.signalRed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: tintBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected
                          ? (isDark
                                ? Theme.of(context).colorScheme.onSurface
                                : PupColors.slateGray)
                          : unselectedColor,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
