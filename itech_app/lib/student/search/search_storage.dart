import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchStorage {
  static const _key = 'student_recent_searches_v1';

  Future<List<String>> loadQueries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  Future<void> saveQueries(List<String> queries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, queries);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
