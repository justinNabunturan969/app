import 'dart:async';

import 'package:flutter/foundation.dart';

import '../mock_data.dart';
import '../models.dart';
import 'search_storage.dart';

enum SearchViewMode { grid, list }

enum SearchSortBy {
  relevance,
  nameAsc,
  nameDesc,
  availabilityFirst,
  newestFirst,
}

class SearchFilterState {
  final bool availableOnly;
  final Set<String> categories;

  const SearchFilterState({
    required this.availableOnly,
    required this.categories,
  });

  factory SearchFilterState.initial() =>
      const SearchFilterState(availableOnly: false, categories: <String>{});

  SearchFilterState copyWith({bool? availableOnly, Set<String>? categories}) {
    return SearchFilterState(
      availableOnly: availableOnly ?? this.availableOnly,
      categories: categories ?? this.categories,
    );
  }
}

class StudentSearchController extends ChangeNotifier {
  StudentSearchController({RecentSearchStorage? storage})
    : _storage = storage ?? RecentSearchStorage() {
    _init();
  }

  final RecentSearchStorage _storage;

  // Search
  String _query = '';
  bool _isSearching = false;
  List<Equipment> _results = const [];
  String _activeQuery = '';

  // Filters
  SearchFilterState _filters = SearchFilterState.initial();

  // UI
  SearchViewMode _viewMode = SearchViewMode.grid;
  SearchSortBy _sortBy = SearchSortBy.relevance;

  // History
  List<String> _recentSearches = const [];

  // For debouncing
  Timer? _debounce;

  Future<void> _init() async {
    _recentSearches = await _storage.loadQueries();
    notifyListeners();
  }

  String get query => _query;
  bool get isSearching => _isSearching;
  List<Equipment> get results => _results;
  String get activeQuery => _activeQuery;

  SearchFilterState get filters => _filters;

  SearchViewMode get viewMode => _viewMode;
  SearchSortBy get sortBy => _sortBy;

  List<String> get recentSearches => _recentSearches;

  bool get hasSearched => _activeQuery.isNotEmpty;

  void setQuery(String v) {
    _query = v;
    if (_query.isEmpty) {
      _activeQuery = '';
      _isSearching = false;
      _results = const [];
      _debounce?.cancel();
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _activeQuery = _query.trim();
      _isSearching = false;
      _results = _computeResults();
      notifyListeners();
      _pushRecentSearch(_activeQuery);
    });
  }

  void toggleAvailableOnly() {
    _filters = _filters.copyWith(availableOnly: !_filters.availableOnly);
    _refreshIfNeeded();
  }

  void toggleCategory(String category) {
    if (category == '__RESET__') {
      resetFilters();
      return;
    }

    final next = Set<String>.from(_filters.categories);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    _filters = _filters.copyWith(categories: next);
    _refreshIfNeeded();
  }

  void resetFilters() {
    _filters = SearchFilterState.initial();
    _refreshIfNeeded();
  }

  void setViewMode(SearchViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  void setSortBy(SearchSortBy mode) {
    _sortBy = mode;
    _refreshIfNeeded(force: true);
  }

  void clearQuery() {
    setQuery('');
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = const [];
    await _storage.clearAll();
    notifyListeners();
  }

  Future<void> deleteRecentSearchAt(int index) async {
    if (index < 0 || index >= _recentSearches.length) return;
    final next = List<String>.from(_recentSearches)..removeAt(index);
    _recentSearches = next;
    await _storage.saveQueries(_recentSearches);
    notifyListeners();
  }

  Future<void> applyRecentSearch(String q) async {
    setQuery(q);
    // setQuery already pushes it back into recent after debounce; but also ensure
    // immediate recency.
    await _pushRecentSearch(q, immediate: true);
  }

  void setFiltersAndQuery({required String q}) {
    setQuery(q);
  }

  void _refreshIfNeeded({bool force = false}) {
    if (_activeQuery.isEmpty && !force) return;
    _results = _computeResults();
    notifyListeners();
  }

  List<Equipment> _computeResults() {
    final q = _activeQuery.toLowerCase();
    if (q.isEmpty) return const [];

    final filters = _filters;

    bool matchesFilters(Equipment e) {
      final availableOk = !filters.availableOnly || e.available > 0;
      final catsOk =
          filters.categories.isEmpty || filters.categories.contains(e.category);
      return availableOk && catsOk;
    }

    bool matchesQuery(Equipment e) {
      final haystack = [
        e.name,
        e.id,
        e.category,
        e.location,
        e.description,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }

    List<Equipment> filtered = StudentMockData.equipment
        .where((e) => matchesFilters(e) && matchesQuery(e))
        .toList(growable: false);

    filtered = _sort(filtered, q);
    return filtered;
  }

  List<Equipment> _sort(List<Equipment> list, String q) {
    int relevanceScore(Equipment e) {
      final name = e.name.toLowerCase();
      final id = e.id.toLowerCase();
      int score = 0;
      if (name == q) score += 100;
      if (name.startsWith(q)) score += 40;
      if (id == q) score += 60;
      if (id.startsWith(q)) score += 30;
      if (e.category.toLowerCase().contains(q)) score += 10;
      if (e.location.toLowerCase().contains(q)) score += 6;
      // tie-breaker: popularity not available; use availability
      score += e.available;
      return score;
    }

    final next = [...list];
    switch (_sortBy) {
      case SearchSortBy.relevance:
        next.sort((a, b) => relevanceScore(b).compareTo(relevanceScore(a)));
        break;
      case SearchSortBy.nameAsc:
        next.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SearchSortBy.nameDesc:
        next.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SearchSortBy.availabilityFirst:
        next.sort((a, b) => (b.available).compareTo(a.available));
        break;
      case SearchSortBy.newestFirst:
        // No dateAdded in current model; approximate by original order.
        // Keep stable.
        break;
    }

    return next;
  }

  Future<void> _pushRecentSearch(String q, {bool immediate = false}) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;

    // Keep max size small.
    final max = 10;

    final next = <String>[trimmed];
    for (final existing in _recentSearches) {
      if (existing.toLowerCase() == trimmed.toLowerCase()) continue;
      if (next.length >= max) break;
      next.add(existing);
    }

    _recentSearches = next;
    notifyListeners();

    if (immediate) {
      await _storage.saveQueries(_recentSearches);
    } else {
      // Fire and forget.
      unawaited(_storage.saveQueries(_recentSearches));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
