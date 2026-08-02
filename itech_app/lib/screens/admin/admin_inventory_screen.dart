import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';

/// Admin Inventory — full equipment catalogue with availability,
/// category, and location. Search + filter chips; tap a card to view
/// details in a bottom sheet.
class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  final _searchC = TextEditingController();
  String _query = '';
  int _filter = 0; // 0=All, 1=Available, 2=Low Stock, 3=Out

  static const _filters = ['All', 'Available', 'Low Stock', 'Out'];

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  List<Equipment> _applyFilter(List<Equipment> all) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      if (q.isNotEmpty) {
        final inText = e.name.toLowerCase().contains(q) ||
            e.id.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q);
        if (!inText) return false;
      }
      switch (_filter) {
        case 1:
          return e.available > 0;
        case 2:
          // Low stock: available > 0 but <= 33% of total (or 1 when total is 1)
          if (e.available == 0) return false;
          if (e.total <= 1) return e.available == 1;
          return e.available / e.total <= 0.34;
        case 3:
          return e.available == 0;
        default:
          return true;
      }
    }).toList();
  }

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

    return Consumer<StudentDashboardController>(
      builder: (context, ctrl, _) {
        final all = ctrl.equipment;
        final filtered = _applyFilter(all);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Inventory',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const ThemeMenuButton(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${all.length} items  •  ${all.fold<int>(0, (a, e) => a + e.available)} units available',
                          style: TextStyle(
                            color: subtleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SearchBar(
                          controller: _searchC,
                          onChanged: (v) => setState(() => _query = v),
                          onClear: () {
                            _searchC.clear();
                            setState(() => _query = '');
                          },
                        ),
                        const SizedBox(height: 8),
                        _FilterChipsRow(
                          selected: _filter,
                          filters: _filters,
                          onSelected: (i) => setState(() => _filter = i),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: subtleText,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No equipment matches',
                              style: TextStyle(
                                color: subtleText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.45,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _InventoryCard(
                          equipment: filtered[i],
                          onTap: () => _showDetails(context, filtered[i]),
                        ),
                        childCount: filtered.length,
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

  void _showDetails(BuildContext context, Equipment e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EquipmentDetailSheet(equipment: e),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark
        ? PupGlass.darkFill(PupColors.techCyan)
        : PupColors.lightCard;
    final borderColor = isDark
        ? PupGlass.darkBorder(PupColors.techCyan)
        : PupColors.ashGray.withValues(alpha: 0.25);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PupColors.techCyan.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search equipment by name, ID, or category...',
          hintStyle: TextStyle(
            color: PupColors.ashGray.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: PupColors.techCyan,
            size: 20,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: PupColors.ashGray,
                ),
          filled: true,
          fillColor: fill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: PupColors.cyberAmber.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filter chips
// ─────────────────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });
  final int selected;
  final List<String> filters;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final idleBorder = isDark
        ? PupGlass.darkBorder(PupColors.cyberAmber)
        : PupColors.ashGray.withValues(alpha: 0.3);
    final idleFg = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

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
              color: selected == i ? PupColors.cyberAmber : Colors.transparent,
              border: Border.all(
                color:
                    selected == i ? PupColors.cyberAmber : idleBorder,
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
              filters[i],
              style: TextStyle(
                color: selected == i
                    ? const Color(0xFF1B1B1B)
                    : idleFg,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Inventory card
// ─────────────────────────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.equipment, required this.onTap});
  final Equipment equipment;
  final VoidCallback onTap;

  ({Color tone, IconData icon, String label}) get _status {
    if (equipment.available == 0) {
      return (
        tone: PupColors.signalRed,
        icon: Icons.block_rounded,
        label: 'OUT',
      );
    }
    if (equipment.total > 1 && equipment.available / equipment.total <= 0.34) {
      return (
        tone: PupColors.cyberAmber,
        icon: Icons.warning_amber_rounded,
        label: 'LOW',
      );
    }
    return (
      tone: PupColors.techCyan,
      icon: Icons.check_circle_rounded,
      label: 'OK',
    );
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

    final status = _status;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: PupGlass.statCardGlow(
          context: context,
          accent: status.tone,
          borderRadius: 16,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MiniIconChip(
                  icon: status.icon,
                  tone: status.tone,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        equipment.name,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        equipment.category,
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: status.tone.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.tone,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  equipment.id,
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '•',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${equipment.available} / ${equipment.total}',
                  style: TextStyle(
                    color: status.tone,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'available',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.0),
      ),
      child: Icon(icon, color: tone, size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Equipment detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────

class _EquipmentDetailSheet extends StatelessWidget {
  const _EquipmentDetailSheet({required this.equipment});
  final Equipment equipment;

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

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface
                : PupColors.lightCard,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtleText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                equipment.name,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${equipment.id}  •  ${equipment.category}',
                style: TextStyle(
                  color: subtleText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.location_on_rounded,
                label: 'Location',
                value: equipment.location,
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.inventory_rounded,
                label: 'Availability',
                value: '${equipment.available} of ${equipment.total} available',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : PupColors.coolSteel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  equipment.description,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PupColors.pupMaroon,
                        side: BorderSide(
                          color: PupColors.pupMaroon.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'Remove',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PupColors.signalRed,
                        side: BorderSide(
                          color: PupColors.signalRed.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
        : PupColors.ashGray;

    return Row(
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
                label,
                style: TextStyle(
                  color: subtleText,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
