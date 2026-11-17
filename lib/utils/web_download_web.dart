import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web implementation: triggers a direct browser file download.
Future<void> downloadTextFile(
  BuildContext context, {
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  await downloadBytesFile(
    context,
    filename: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
}

/// Web implementation: triggers a direct browser download for binary files (PDF).
Future<void> downloadBytesFile(
  BuildContext context, {
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/pdf',
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded $filename')),
    );
  }
}
