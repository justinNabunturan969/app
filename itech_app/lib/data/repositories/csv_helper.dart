// CSV utilities for the admin inventory import/export features.
//
// Pure-Dart on purpose — no `csv` package dependency, so we don't have
// to ship another package or wait on `flutter pub get` for the user.
// The implementation handles the only quoting rule RFC 4180 strictly
// enforces: wrap a field in double-quotes if it contains a comma,
// double-quote, CR, or LF; escape embedded double-quotes by doubling
// them.
//
// File picker / downloader are conditionally implemented:
//   - csv_helper_stub.dart  — no-op on non-web (mobile / desktop)
//   - csv_helper_web.dart   — uses dart:html on web
// The conditional import below is the standard Flutter pattern.

import 'csv_helper_io.dart'
    if (dart.library.html) 'csv_helper_web.dart';

/// One row in a parsed CSV file. Fields are NOT trimmed — the caller can
/// do that as needed.
class CsvRow {
  CsvRow(this.fields, this._header);
  final List<String> fields;
  final List<String> _header;

  /// Convenience: `row['code']` style access using the [header] order
  /// supplied to [Csv.parse]. Returns null if the column is missing.
  String? operator [](String header) {
    final i = _header.indexOf(header);
    if (i == -1 || i >= fields.length) return null;
    return fields[i];
  }

  /// True if the row is missing one of the named required columns
  /// (returns the value too, so the caller can show a useful error).
  String? missingField(Iterable<String> required) {
    for (final col in required) {
      if ((this[col] ?? '').isEmpty) return col;
    }
    return null;
  }
}

/// Parse a CSV byte stream. The first non-empty row is treated as the
/// header. Returns the header plus a list of data rows.
class Csv {
  Csv._();

  static ({List<String> headers, List<CsvRow> rows}) parse(
    String content, {
    String delimiter = ',',
  }) {
    final raw = _parseRows(content, delimiter);
    if (raw.isEmpty) {
      return (headers: const <String>[], rows: const <CsvRow>[]);
    }
    final header = raw.first;
    final dataRows = <CsvRow>[];
    for (var i = 1; i < raw.length; i++) {
      dataRows.add(CsvRow(raw[i], header));
    }
    return (headers: header, rows: dataRows);
  }

  /// Serialise [rows] (list of string lists) to a CSV string. Quotes
  /// fields that contain the delimiter, double-quote, CR, or LF.
  static String encode(
    List<String> header,
    List<List<String>> rows, {
    String delimiter = ',',
  }) {
    final buf = StringBuffer();
    buf.write(_encodeRow(header, delimiter));
    buf.write('\r\n');
    for (final r in rows) {
      buf.write(_encodeRow(r, delimiter));
      buf.write('\r\n');
    }
    return buf.toString();
  }

  static String _encodeRow(List<String> row, String delimiter) {
    return row.map((field) {
      final needsQuotes = field.contains(delimiter) ||
          field.contains('"') ||
          field.contains('\n') ||
          field.contains('\r');
      if (!needsQuotes) return field;
      return '"${field.replaceAll('"', '""')}"';
    }).join(delimiter);
  }

  /// Pure-Dart RFC 4180-ish parser. Handles CRLF, LF, and CR row
  /// terminators, plus double-quote escaping. Returns a list of rows;
  /// each row is a list of fields.
  static List<List<String>> _parseRows(String content, String delimiter) {
    final rows = <List<String>>[];
    final field = StringBuffer();
    final row = <String>[];
    var inQuotes = false;
    var i = 0;
    while (i < content.length) {
      final c = content[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field.write(c);
        i++;
        continue;
      }
      if (c == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (c == delimiter) {
        row.add(field.toString());
        field.clear();
        i++;
        continue;
      }
      if (c == '\r') {
        row.add(field.toString());
        field.clear();
        rows.add(List.of(row));
        row.clear();
        if (i + 1 < content.length && content[i + 1] == '\n') {
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (c == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(List.of(row));
        row.clear();
        i++;
        continue;
      }
      field.write(c);
      i++;
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(List.of(row));
    }
    return rows
        .where((r) => r.any((c) => c.isNotEmpty))
        .toList(growable: false);
  }
}

/// Result of [pickCsvFile]: the raw text content of the chosen file.
/// Null if the user cancelled.
class CsvPickResult {
  const CsvPickResult({required this.fileName, required this.content});
  final String fileName;
  final String content;
}

/// Open a system file picker for `.csv` files, read the picked file,
/// and return its content. Returns null if the user cancels.
///
/// Throws a [StateError] on non-web platforms. The web build (Vercel) is
/// the supported target.
Future<CsvPickResult?> pickCsvFile() => pickCsvFileImpl();

/// Trigger a browser download of the given CSV content. No-op on
/// non-web.
Future<void> downloadCsvFile({
  required String fileName,
  required String content,
}) =>
    downloadCsvFileImpl(fileName: fileName, content: content);
