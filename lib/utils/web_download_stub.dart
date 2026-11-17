import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mobile fallback: copies exported text to clipboard and notifies user.
Future<void> downloadTextFile(
  BuildContext context, {
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) async {
  await Clipboard.setData(ClipboardData(text: content));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$filename copied to clipboard!'),
      ),
    );
  }
}
