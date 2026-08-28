// Stub implementation for non-web targets (mobile / desktop). Throws a
// clear error if the caller tries to pick or download a file — the
// admin inventory import/export features are only supported on the web
// build (Vercel). The rest of the app still compiles fine on every
// target because the public API is the same.

import 'csv_helper.dart';

Future<CsvPickResult?> pickCsvFileImpl() async {
  throw StateError(
    'CSV import is only supported on the web build. Use the SQL editor '
    'or the Supabase dashboard for native platforms.',
  );
}

Future<void> downloadCsvFileImpl({
  required String fileName,
  required String content,
}) async {
  throw StateError(
    'CSV export is only supported on the web build.',
  );
}
