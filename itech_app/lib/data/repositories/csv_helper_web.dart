// Web implementation of the CSV file picker / downloader. Uses
// `dart:html` (only available on web, hence the conditional import in
// csv_helper.dart). Wraps a `<input type="file">` for picking and an
// `<a download>` for downloading.

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'csv_helper.dart';

Future<CsvPickResult?> pickCsvFileImpl() async {
  final input = html.FileUploadInputElement()
    ..accept = '.csv,text/csv';

  final completer = Completer<CsvPickResult?>();
  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final text = reader.result as String;
      completer.complete(
        CsvPickResult(fileName: file.name, content: text),
      );
    });
    reader.onError.listen((_) {
      completer.completeError(
        StateError('Could not read the selected file.'),
      );
    });
    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}

Future<void> downloadCsvFileImpl({
  required String fileName,
  required String content,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = html.Blob(<Object>[bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
