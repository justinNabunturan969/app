import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../app/language_controller.dart';
import '../../student/models.dart';
import '../../student/search/widgets/borrow_confirm_sheet.dart';
import '../../student/search/widgets/voice_search_overlay.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/notifications_bell_button.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late final TextEditingController _searchC;
  bool _showVoice = false;
  int _selectedChip = 0;

  // Sentence case for consistency (was: 'ALL', 'Available Now', etc.)
  static const _chips = [
    'All',
    'Available now',
    'Mechanical',
    'Electrical',
    'Tools',
    'Testers',
  ];

  @override
  void initState() {
    super.initState();
    _searchC = TextEditingController();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _syncCategoryFilter(StudentDashboardController ctrl) {
    final chip = _chips[_selectedChip];
    if (chip == 'All' || chip == 'Available now') {
      ctrl.selectCategory('All');
    } else {
      ctrl.selectCategory(chip);
    }
  }

  List<Equipment> _visibleEquipment(StudentDashboardController ctrl) {
    // Hide items the student already has an open request for (pending,
    // active, or overdue). Tapping "Tap to borrow" on those would just
    // bounce off the DB's unique-index constraint.
    final openIds = ctrl.openRequestEquipmentIds;
    bool isAvailableForThisStudent(Equipment e) =>
        e.available > 0 && !openIds.contains(e.id);

    if (ctrl.query.trim().isNotEmpty) {
      return ctrl.filtered
          .where((e) => !openIds.contains(e.id))
          .toList(growable: false);
    }

    final chip = _chips[_selectedChip];
    return ctrl.equipment.where((e) {
      if (chip == 'Available now') return isAvailableForThisStudent(e);
      if (chip == 'All') return !openIds.contains(e.id);
      return e.category == chip && !openIds.contains(e.id);
    }).toList();
  }

  Future<void> _runSearch(StudentDashboardController ctrl) async {
    FocusScope.of(context).unfocus();
    await ctrl.submitSearch(_searchC.text);
  }

  Future<void> _refresh(StudentDashboardController ctrl) async {
    // Pulls every list (equipment, borrowings, notifications, profile)
    // from Supabase in parallel via the controller's `load()`. We keep
    // a small floor delay so the RefreshIndicator has a moment to
    // finish its own animation even on a near-instant response.
    await Future.wait([
      ctrl.load(),
      Future<void>.delayed(const Duration(milliseconds: 400)),
    ]);
  }

  /// Opens the borrow confirmation sheet for the given equipment item.
  /// Wired to the home screen's equipment grid — tapping a card (or the
  /// Borrow button on it) drops the user into the same aesthetic
  /// confirmation flow as the search screen, with the DB write going
  /// through `StudentDashboardController.requestBorrowing`.
  Future<void> _onBorrowEquipment(
    BuildContext context,
    Equipment equipment,
  ) async {
    final created = await BorrowConfirmSheet.show(
      context,
      equipment: equipment,
    );
    if (!context.mounted || created == null) return;
    showBorrowSuccessSnackBar(context, created.equipmentName);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;

    return Consumer<StudentDashboardController>(
      builder: (context, ctrl, _) {
        final language = context.watch<LanguageController>().language;
        final firstName = ctrl.studentFirstName;
        final greeting = hour < 12
            ? 'Good Morning'
            : hour < 18
            ? 'Good Afternoon'
            : 'Good Evening';

        final items = _visibleEquipment(ctrl);
        final isSearching = ctrl.isSearching;
        final hasQuery = ctrl.query.trim().isNotEmpty;
        final recent = ctrl.recentStudentActivity;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => _refresh(ctrl),
                  color: PupColors.cyberAmber,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _GreetingHeader(
                                greeting: greeting,
                                firstName: firstName,
                                program: ctrl.studentProgram,
                              ),
                              const SizedBox(height: 12),
                              // (The previous "Go online / You're online"
                              // presence card lived here. The product
                              // direction changed: the student account no
                              // longer exposes a manual presence toggle, and
                              // the auto-heartbeat in the
                              // SessionLifecycleGuard keeps the underlying
                              // `active_sessions` row warm in the
                              // background. Admin-facing audit / live views
                              // live on the admin account.)
                              const SizedBox(height: 12),
                              // 3-up stats row (no horizontal scroll)
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Active',
                                      value: ctrl.activeBorrowingsCount,
                                      tone: PupColors.techCyan,
                                      icon: Icons.bolt_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Pending',
                                      value: ctrl.pendingRequestsCount,
                                      tone: PupColors.cyberAmber,
                                      icon: Icons.hourglass_top_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Overdue',
                                      value: ctrl.overdueCount,
                                      tone: PupColors.signalRed,
                                      icon: Icons.warning_amber_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _SearchBar(
                                controller: _searchC,
                                onChanged: ctrl.debounceSearch,
                                onSubmit: () => _runSearch(ctrl),
                                onVoice: () =>
                                    setState(() => _showVoice = true),
                                onClear: () {
                                  _searchC.clear();
                                  ctrl.clearSearch();
                                },
                              ),
                              const SizedBox(height: 10),
                              _CategoryChips(
                                selected: _selectedChip,
                                categories: _chips,
                                onSelected: (i) {
                                  setState(() => _selectedChip = i);
                                  _syncCategoryFilter(ctrl);
                                  if (ctrl.query.trim().isNotEmpty) {
                                    ctrl.submitSearch(ctrl.query);
                                  }
                                },
                              ),
                              if (hasQuery) ...[
                                const SizedBox(height: 6),
                                Text(
                                  isSearching
                                      ? 'Searching…'
                                      : 'Found ${items.length} result${items.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      if (isSearching)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (items.isEmpty)
                        SliverToBoxAdapter(
                          child: EmptyStateView(
                            icon: hasQuery
                                ? Icons.search_off_rounded
                                : Icons.inventory_2_outlined,
                            title: hasQuery
                                ? 'No equipment found'
                                : 'Nothing here yet',
                            message: hasQuery
                                ? 'We couldn\'t find anything matching "${ctrl.query}". Try a different search or category.'
                                : 'No equipment in this category right now. Switch to another category above.',
                            actionLabel: hasQuery ? 'Clear search' : null,
                            onAction: hasQuery
                                ? () {
                                    _searchC.clear();
                                    ctrl.clearSearch();
                                  }
                                : null,
                            accent: hasQuery
                                ? PupColors.cyberAmber
                                : PupColors.techCyan,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  // Keep enough vertical room for a two-line
                                  // equipment name plus the borrow CTA on
                                  // narrow phones. The old 1.45 ratio could
                                  // overflow the card by a few pixels.
                                  childAspectRatio: 1.15,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _EquipmentCard(
                                equipment: items[i],
                                onBorrow: () =>
                                    _onBorrowEquipment(context, items[i]),
                              ),
                              childCount: items.length,
                            ),
                          ),
                        ),
                      // Recently borrowed strip — only when no active search
                      if (!hasQuery && recent.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 22)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: _SectionTitle(
                              title: 'Recently Borrowed',
                              icon: Icons.history_rounded,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: recent.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) =>
                                  _RecentActivityCard(entry: recent[i]),
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
                if (_showVoice)
                  Positioned.fill(
                    child: VoiceSearchOverlay(
                      onTranscribed: (text) {
                        _searchC.text = text;
                        ctrl.submitSearch(text);
                      },
                      onPartialTranscribed: (text) {
                        _searchC.text = text;
                        ctrl.submitSearch(text);
                      },
                      onCancel: () => setState(() => _showVoice = false),
                      language: language,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Greeting + header
// ─────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greeting,
    required this.firstName,
    required this.program,
  });

  final String greeting;
  final String firstName;
  final String program;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: subtleText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$firstName 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                program,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: subtleText,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: PupColors.pupMaroon,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'PUP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const NotificationsBellButton(),
        const SizedBox(width: 6),
        const ThemeMenuButton(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Presence card — REMOVED.
//
// The student account no longer renders a manual "Go online / You're
// online" toggle. That control surface has been moved to the admin
// account (where it now drives a Login History / audit log view), and
// the underlying `active_sessions` row is still kept warm in the
// background by `SessionLifecycleGuard` (see `lib/main.dart`) so any
// future admin-side view of "currently online" keeps working.
//
// The previous `_PresenceCard`, `_PulseDot`, and `_PresenceErrorListener`
// widgets were removed alongside the `goOnline` / `goOffline` /
// `presenceError` API on `StudentDashboardController`.
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// 3-up stat tile
// ─────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
  });

  final String label;
  final int value;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: tone,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tone.withValues(alpha: 0.32),
                  tone.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tone.withValues(alpha: 0.45),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: tone, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: subtleText,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Search bar (cleaner suffix arrangement: voice in prefix, single search
// submit, clear on demand)
// ─────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.onVoice,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onVoice;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final fill = isDark
        ? PupGlass.darkFill(PupColors.techCyan)
        : PupColors.lightCard;
    final borderColor = isDark
        ? PupGlass.darkBorder(PupColors.techCyan)
        : PupColors.ashGray.withValues(alpha: 0.25);
    final textColor = isDark ? scheme.onSurface : PupColors.slateGray;
    final hintColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.6)
        : PupColors.ashGray.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? PupGlass.darkShadow(PupColors.techCyan, blur: 14, offsetY: 6)
            : [
                BoxShadow(
                  color: PupColors.techCyan.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor),
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: 'Search equipment…',
          hintStyle: TextStyle(color: hintColor),
          // Search icon (left) + Voice icon (left, after a thin divider)
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(Icons.search_rounded, color: PupColors.techCyan),
              ),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : PupColors.ashGray.withValues(alpha: 0.30),
              ),
            ],
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          filled: true,
          fillColor: fill,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: PupColors.cyberAmber.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
          // Only the voice mic (always visible) and a clear-X when there's text.
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Voice search',
                visualDensity: VisualDensity.compact,
                onPressed: onVoice,
                icon: const Icon(
                  Icons.mic_rounded,
                  color: PupColors.cyberAmber,
                ),
              ),
              if (hasText)
                IconButton(
                  tooltip: 'Clear',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : PupColors.ashGray,
                  ),
                ),
            ],
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Category chips
// ─────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.categories,
    required this.onSelected,
  });

  final int selected;
  final List<String> categories;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final idleBg = Colors.transparent;
    final idleBorder = isDark
        ? PupGlass.darkBorder(PupColors.cyberAmber)
        : PupColors.ashGray.withValues(alpha: 0.3);
    final idleFg = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => InkWell(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected == i ? PupColors.cyberAmber : idleBg,
              border: Border.all(
                color: selected == i ? PupColors.cyberAmber : idleBorder,
              ),
              boxShadow: selected == i
                  ? [
                      BoxShadow(
                        color: PupColors.cyberAmber.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              categories[i],
              style: TextStyle(
                color: selected == i ? const Color(0xFF1B1B1B) : idleFg,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    return Row(
      children: [
        Icon(icon, color: PupColors.cyberAmber, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Equipment card (grid tile)
// ─────────────────────────────────────────────────────────────────────────

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.equipment, required this.onBorrow});

  final Equipment equipment;
  final VoidCallback onBorrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final available = equipment.available > 0;
    final ribbonColor = available ? PupColors.techCyan : PupColors.signalRed;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    final mainIcon = available
        ? _iconForCategory(equipment.category)
        : Icons.lock_outline_rounded;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      // InkWell renders the ripple. Wrap with `Material` so the
      // ripple clips to the rounded corners instead of the default
      // rectangular hit area.
      child: InkWell(
        onTap: onBorrow,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: PupGlass.statCardGlow(
            context: context,
            accent: ribbonColor,
            borderRadius: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ribbonColor.withValues(alpha: 0.32),
                          ribbonColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ribbonColor.withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(mainIcon, color: ribbonColor, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ribbonColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: ribbonColor.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      available ? 'Available' : 'Borrowed',
                      style: TextStyle(
                        color: ribbonColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        equipment.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${equipment.available}/${equipment.total}',
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // The visible Borrow CTA. Lives inside the InkWell so a
                  // tap anywhere on the card (including this row) opens
                  // the confirmation sheet, but rendering it as its own
                  // row gives the user an obvious affordance.
                  Row(
                    children: [
                      Icon(
                        available ? Icons.outbox_rounded : Icons.block_rounded,
                        size: 13,
                        color: available
                            ? PupColors.cyberAmber
                            : PupColors.ashGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        available ? 'Tap to borrow' : 'Out of stock',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: available
                              ? PupColors.cyberAmber
                              : PupColors.ashGray,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'electrical':
      return Icons.bolt_rounded;
    case 'mechanical':
      return Icons.precision_manufacturing_rounded;
    case 'tools':
      return Icons.handyman_rounded;
    case 'testers':
      return Icons.science_rounded;
    default:
      return Icons.inventory_2_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Recently Borrowed card (horizontal scroll item)
// ─────────────────────────────────────────────────────────────────────────

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: entry.tone,
        borderRadius: 16,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  entry.tone.withValues(alpha: 0.32),
                  entry.tone.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: entry.tone.withValues(alpha: 0.45),
                width: 1.0,
              ),
            ),
            child: Icon(entry.icon, color: entry.tone, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                        : PupColors.ashGray,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
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
