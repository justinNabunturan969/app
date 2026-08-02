import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../student/search/student_search_controller.dart';
import '../../student/search/search_storage.dart';
import '../../student/models.dart';
import '../../theme/design_tokens.dart';

import '../../student/search/widgets/empty_states.dart';
import '../../student/search/widgets/filter_chips.dart';
import '../../student/search/widgets/recent_searches.dart';
import '../../student/search/widgets/trending_searches.dart';
import '../../student/search/widgets/search_bar.dart';
import '../../student/search/widgets/results_grid.dart';
import '../../student/search/widgets/results_list.dart';
import '../../student/search/widgets/sort_bottom_sheet.dart';
import '../../student/search/widgets/view_toggle_row.dart';
import '../../student/search/widgets/voice_search_overlay.dart';

class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  late final TextEditingController _searchC;
  bool _showVoice = false;

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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StudentSearchController(storage: RecentSearchStorage()),
      builder: (context, _) {
        final ctrl = context.watch<StudentSearchController>();

        // Keep controller in sync (one-way from TextField to ctrl)
        if (_searchC.text != ctrl.query) {
          _searchC.value = _searchC.value.copyWith(
            text: ctrl.query,
            selection: TextSelection.collapsed(offset: ctrl.query.length),
          );
        }

        final isEmptySearch = ctrl.query.isEmpty;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: SearchBarHero(
                          controller: _searchC,
                          onClear: () {
                            _searchC.clear();
                            ctrl.clearQuery();
                          },
                          onVoice: () {
                            setState(() => _showVoice = true);
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: FilterChipsRow(
                          selectedCategories: ctrl.filters.categories,
                          availableOnly: ctrl.filters.availableOnly,
                          onToggleAvailable: (_) => ctrl.toggleAvailableOnly(),
                          onToggleCategory: (c) => ctrl.toggleCategory(c),
                        ),
                      ),
                    ),

                    if (isEmptySearch) ...[
                      SliverToBoxAdapter(child: const SizedBox(height: 6)),
                      SliverToBoxAdapter(
                        child: TrendingSearches(
                          onTapChip: (term) {
                            _searchC.text = term;
                            ctrl.setQuery(term);
                          },
                        ),
                      ),
                      SliverToBoxAdapter(child: const SizedBox(height: 14)),
                      SliverToBoxAdapter(
                        child: RecentSearches(
                          queries: ctrl.recentSearches,
                          onApply: (q) {
                            _searchC.text = q;
                            ctrl.setQuery(q);
                          },
                          onClearAll: () async {
                            await ctrl.clearRecentSearches();
                          },
                          onDeleteAt: (index) =>
                              ctrl.deleteRecentSearchAt(index),
                        ),
                      ),
                      SliverToBoxAdapter(child: const SizedBox(height: 24)),
                    ] else if (ctrl.isSearching) ...[
                      SliverToBoxAdapter(child: const SearchingShimmerState()),
                      SliverToBoxAdapter(child: const SizedBox(height: 24)),
                    ] else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Found ${ctrl.results.length} result${ctrl.results.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: PupColors.slateGray,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Switch view',
                                onPressed: () {
                                  ctrl.setViewMode(
                                    ctrl.viewMode == SearchViewMode.grid
                                        ? SearchViewMode.list
                                        : SearchViewMode.grid,
                                  );
                                },
                                icon: Icon(
                                  ctrl.viewMode == SearchViewMode.grid
                                      ? Icons.grid_view_rounded
                                      : Icons.view_list_rounded,
                                  color: PupColors.slateGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 2)),

                      SliverToBoxAdapter(
                        child: ViewToggleRow(
                          mode: ctrl.viewMode,
                          onMode: ctrl.setViewMode,
                          onSort: () {
                            showSortBottomSheet(
                              context: context,
                              current: ctrl.sortBy,
                              onSelected: ctrl.setSortBy,
                            );
                          },
                        ),
                      ),

                      if (ctrl.results.isEmpty)
                        SliverToBoxAdapter(
                          child: NoResultsState(
                            query: ctrl.query,
                            onUseChip: (term) {
                              _searchC.text = term;
                              ctrl.setQuery(term);
                            },
                          ),
                        )
                      else
                        SliverToBoxAdapter(child: _ResultsBody(ctrl: ctrl)),
                      SliverToBoxAdapter(child: const SizedBox(height: 26)),
                    ],
                  ],
                ),

                if (_showVoice)
                  Positioned.fill(
                    child: VoiceSearchOverlay(
                      onTranscribed: (t) {
                        _searchC.text = t;
                        ctrl.setQuery(t);
                      },
                      onCancel: () {
                        setState(() => _showVoice = false);
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
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.ctrl});

  final StudentSearchController ctrl;

  @override
  Widget build(BuildContext context) {
    final items = ctrl.results;

    // For prototype: we cannot mutate Equipment model in controller, so
    // like button currently only shows feedback.
    void onToggleLike(Equipment e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.isLiked ? 'Unliked ${e.name}' : 'Liked ${e.name}'),
        ),
      );
    }

    void onBorrow(Equipment e) {
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Borrow ${e.name}?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: PupColors.slateGray,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${e.id} • ${e.location}',
                  style: TextStyle(
                    color: PupColors.ashGray,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: PupColors.cyberAmber,
                          foregroundColor: const Color(0xFF1B1B1B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Borrow request submitted for ${e.name}',
                              ),
                            ),
                          );
                        },
                        child: const Text('Borrow'),
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

    void onTapEquipment(Equipment e) {
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: PupColors.slateGray,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${e.id} • ${e.location}',
                  style: TextStyle(
                    color: PupColors.ashGray,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  e.description,
                  style: const TextStyle(
                    color: PupColors.slateGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  e.available > 0
                      ? 'Status: Available (${e.available}/${e.total})'
                      : 'Status: Borrowed (${e.available}/${e.total})',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: e.available > 0
                        ? PupColors.mintGreen
                        : PupColors.signalRed,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (ctrl.viewMode == SearchViewMode.grid) {
      return ResultsGrid(
        items: items,
        onTapEquipment: onTapEquipment,
        onToggleLike: onToggleLike,
        onBorrow: onBorrow,
      );
    }

    return ResultsList(
      items: items,
      onTapEquipment: onTapEquipment,
      onToggleLike: onToggleLike,
      onBorrow: onBorrow,
    );
  }
}
