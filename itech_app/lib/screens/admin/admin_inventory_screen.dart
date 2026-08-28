import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme_menu_button.dart';
import '../../data/repositories/csv_helper.dart';
import '../../student/models.dart';
import '../../student/student_dashboard_controller.dart';
import '../../theme/design_tokens.dart';
import 'widgets/equipment_form_sheet.dart';

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
  String? _classificationFilter; // null = all, 'electrical', or 'computer'

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
        final inText =
            e.name.toLowerCase().contains(q) ||
            e.id.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q);
        if (!inText) return false;
      }
      if (_classificationFilter != null &&
          e.classification != _classificationFilter) {
        return false;
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
                            _HeaderIconButton(
                              icon: Icons.upload_file_rounded,
                              tooltip: 'Import CSV',
                              onTap: () => _importCsv(context, ctrl),
                            ),
                            const SizedBox(width: 4),
                            _HeaderIconButton(
                              icon: Icons.download_rounded,
                              tooltip: 'Export CSV',
                              onTap: () => _exportCsv(context, ctrl),
                            ),
                            const SizedBox(width: 4),
                            FilledButton.icon(
                              onPressed: () => _openAddSheet(context, ctrl),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text(
                                'Add',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: PupColors.pupMaroon,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
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
                        _ClassificationChipsRow(
                          selected: _classificationFilter,
                          onSelected: (v) =>
                              setState(() => _classificationFilter = v),
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
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        // Two cards made the text row too narrow on typical
                        // 360–400dp phones. A single, compact list card is
                        // easier to scan and prevents horizontal overflow.
                        final useSingleColumn =
                            constraints.crossAxisExtent < 430;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: useSingleColumn ? 1 : 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: useSingleColumn ? 3.0 : 1.15,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _InventoryCard(
                              equipment: filtered[i],
                              onTap: () => _showDetails(context, filtered[i]),
                            ),
                            childCount: filtered.length,
                          ),
                        );
                      },
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
      builder: (ctx) => _EquipmentDetailSheet(
        equipment: e,
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(context, e);
        },
        onDelete: () async {
          Navigator.pop(ctx);
          await _confirmDelete(context, e);
        },
      ),
    );
  }

  Future<void> _openAddSheet(
    BuildContext context,
    StudentDashboardController ctrl,
  ) async {
    final created = await showModalBottomSheet<Equipment?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EquipmentFormSheet(
        equipment: null,
        onSubmit: (data) => ctrl.createEquipment(
          code: data.code,
          name: data.name,
          category: data.category.isEmpty ? null : data.category,
          location: data.location.isEmpty ? null : data.location,
          description: data.description.isEmpty ? null : data.description,
          totalCount: data.totalCount,
          classification: data.classification,
        ),
      ),
    );
    if (created != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${created.name} to inventory.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    Equipment e,
  ) async {
    final ctrl = context.read<StudentDashboardController>();
    final updated = await showModalBottomSheet<Equipment?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EquipmentFormSheet(
        equipment: e,
        onSubmit: (data) => ctrl.updateEquipment(
          e.id,
          code: data.code,
          name: data.name,
          category: data.category,
          location: data.location,
          description: data.description,
          totalCount: data.totalCount,
          availableCount: data.availableCount,
          classification: data.classification,
        ),
      ),
    );
    if (updated != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${updated.name}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Equipment e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove equipment?'),
        content: Text(
          'Remove "${e.name}" from the inventory? Active borrowings will '
          'block this — cancel or verify those first.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final ctrl = context.read<StudentDashboardController>();
    final success = await ctrl.deleteEquipment(e.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Removed ${e.name}.'
              : 'Could not remove ${e.name}. It may be referenced by an active borrowing.',
        ),
        backgroundColor: success ? null : PupColors.signalRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    StudentDashboardController ctrl,
  ) async {
    final items = ctrl.equipment;
    final header = const [
      'code',
      'name',
      'category',
      'classification',
      'location',
      'total_count',
      'available_count',
      'description',
    ];
    final rows = items
        .map(
          (e) => [
            e.code,
            e.name,
            e.category,
            e.classification ?? '',
            e.location,
            e.total.toString(),
            e.available.toString(),
            e.description,
          ],
        )
        .toList();
    final csv = Csv.encode(header, rows);
    final fileName =
        'pup_itech_inventory_${DateTime.now().millisecondsSinceEpoch}.csv';
    try {
      await downloadCsvFile(fileName: fileName, content: csv);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export: $e'),
          backgroundColor: PupColors.signalRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importCsv(
    BuildContext context,
    StudentDashboardController ctrl,
  ) async {
    CsvPickResult? picked;
    try {
      picked = await pickCsvFile();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the file picker: $e'),
          backgroundColor: PupColors.signalRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (picked == null) return; // user cancelled
    if (!context.mounted) return;

    final parsed = Csv.parse(picked.content);
    if (parsed.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV is empty or has no data rows.'),
          backgroundColor: PupColors.signalRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final required = const ['code', 'name', 'total_count', 'classification'];
    final errors = <String>[];
    final valid = <_ParsedEquipment>[];
    for (var i = 0; i < parsed.rows.length; i++) {
      final r = parsed.rows[i];
      final rowNum = i + 2; // +1 for 1-index, +1 for header
      final missing = r.missingField(required);
      if (missing != null) {
        errors.add('Row $rowNum: missing "$missing"');
        continue;
      }
      final total = int.tryParse((r['total_count'] ?? '').trim());
      if (total == null || total < 0) {
        errors.add('Row $rowNum: invalid total_count');
        continue;
      }
      final classification = (r['classification'] ?? '').trim().toLowerCase();
      if (classification != 'electrical' && classification != 'computer') {
        errors.add(
          'Row $rowNum: classification must be "electrical" or "computer"',
        );
        continue;
      }
      valid.add(_ParsedEquipment(
        code: (r['code'] ?? '').trim(),
        name: (r['name'] ?? '').trim(),
        category: (r['category'] ?? '').trim(),
        classification: classification,
        location: (r['location'] ?? '').trim(),
        totalCount: total,
        description: (r['description'] ?? '').trim(),
      ));
    }

    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CsvImportPreviewDialog(
        fileName: picked!.fileName,
        validCount: valid.length,
        errorCount: errors.length,
        errors: errors.take(8).toList(),
      ),
    );
    if (proceed != true) return;
    if (!context.mounted) return;

    var ok = 0;
    var failed = 0;
    for (final p in valid) {
      final created = await ctrl.createEquipment(
        code: p.code,
        name: p.name,
        category: p.category.isEmpty ? null : p.category,
        location: p.location.isEmpty ? null : p.location,
        description: p.description.isEmpty ? null : p.description,
        totalCount: p.totalCount,
        classification: p.classification,
      );
      if (created != null) {
        ok++;
      } else {
        failed++;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Imported $ok item(s) from ${picked.fileName}.'
              : 'Imported $ok item(s); $failed failed (likely duplicate codes).',
        ),
        backgroundColor: failed == 0 ? null : PupColors.signalRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ParsedEquipment {
  const _ParsedEquipment({
    required this.code,
    required this.name,
    required this.category,
    required this.classification,
    required this.location,
    required this.totalCount,
    required this.description,
  });
  final String code;
  final String name;
  final String category;
  final String classification;
  final String location;
  final int totalCount;
  final String description;
}

class _CsvImportPreviewDialog extends StatelessWidget {
  const _CsvImportPreviewDialog({
    required this.fileName,
    required this.validCount,
    required this.errorCount,
    required this.errors,
  });
  final String fileName;
  final int validCount;
  final int errorCount;
  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtle = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;
    return AlertDialog(
      title: const Text('Import CSV?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File: $fileName'),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: PupColors.mintGreen, size: 18),
              const SizedBox(width: 6),
              Text(
                '$validCount valid row(s) will be imported.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (errorCount > 0) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_rounded, color: PupColors.signalRed, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$errorCount row(s) will be skipped:',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PupColors.signalRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: PupColors.signalRed.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: errors
                    .map(
                      (e) => Text(
                        '• $e',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: validCount == 0
              ? null
              : () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: PupColors.pupMaroon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Import'),
        ),
      ],
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
              color: selected == i ? PupColors.cyberAmber : Colors.transparent,
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
              filters[i],
              style: TextStyle(
                color: selected == i ? const Color(0xFF1B1B1B) : idleFg,
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
                _MiniIconChip(icon: status.icon, tone: status.tone),
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
                        equipment.category.isEmpty
                            ? (equipment.classification ?? '—')
                            : equipment.category,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
            if (equipment.classification != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    equipment.classification == 'electrical'
                        ? Icons.bolt_rounded
                        : Icons.memory_rounded,
                    size: 11,
                    color: equipment.classification == 'electrical'
                        ? PupColors.cyberAmber
                        : PupColors.techCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    equipment.classification == 'electrical'
                        ? 'Electrical'
                        : 'Computer',
                    style: TextStyle(
                      color: equipment.classification == 'electrical'
                          ? PupColors.cyberAmber
                          : PupColors.techCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    equipment.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtleText,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
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
  const _EquipmentDetailSheet({
    required this.equipment,
    required this.onEdit,
    required this.onDelete,
  });
  final Equipment equipment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            color: isDark ? theme.colorScheme.surface : PupColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              if (equipment.classification != null) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: equipment.classification == 'electrical'
                      ? Icons.bolt_rounded
                      : Icons.memory_rounded,
                  label: 'Classification',
                  value: equipment.classification == 'electrical'
                      ? 'Electrical item'
                      : 'Computer item',
                ),
              ],
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
                      onPressed: onEdit,
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
                      onPressed: onDelete,
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

// ─────────────────────────────────────────────────────────────────────────
// Header icon button (small, square, used in the Inventory title row).
// ─────────────────────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : PupColors.lightCard;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : PupColors.ashGray.withValues(alpha: 0.25);
    final fg = isDark ? theme.colorScheme.onSurface : PupColors.slateGray;

    final button = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Classification filter chips (Electrical / Computer / All).
// ─────────────────────────────────────────────────────────────────────────

class _ClassificationChipsRow extends StatelessWidget {
  const _ClassificationChipsRow({
    required this.selected,
    required this.onSelected,
  });
  final String? selected; // null = all
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : PupColors.ashGray.withValues(alpha: 0.3);
    final idleFg = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
        : PupColors.slateGray;

    Widget chip(String? value, String label, IconData icon, Color tone) {
      final isSelected = selected == value;
      return InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? tone.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? tone : idleBorder,
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isSelected ? tone : idleFg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? tone : idleFg,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(null, 'All', Icons.all_inclusive_rounded, PupColors.cyberAmber),
          const SizedBox(width: 6),
          chip(
            'electrical',
            'Electrical',
            Icons.bolt_rounded,
            PupColors.cyberAmber,
          ),
          const SizedBox(width: 6),
          chip(
            'computer',
            'Computer',
            Icons.memory_rounded,
            PupColors.techCyan,
          ),
        ],
      ),
    );
  }
}
