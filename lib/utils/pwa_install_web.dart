import 'dart:js_interop';
import 'package:flutter/material.dart';

@JS('moazanIsStandalone')
external bool _moazanIsStandalone();

@JS('moazanCanPromptInstall')
external bool _moazanCanPromptInstall();

@JS('moazanTriggerInstall')
external JSPromise<JSBoolean> _moazanTriggerInstall();

bool get isWebPlatform => true;

bool isPwaStandalone() {
  try {
    return _moazanIsStandalone();
  } catch (_) {
    return false;
  }
}

Future<void> triggerPwaInstallOrGuide(BuildContext context) async {
  try {
    if (_moazanCanPromptInstall()) {
      final accepted = (await _moazanTriggerInstall().toDart).toDart;
      if (accepted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moazan Traders shortcut added to your device!'),
          ),
        );
      }
      return;
    }
  } catch (_) {
    // Fall back to instructions dialog below.
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.install_mobile),
          SizedBox(width: 8),
          Expanded(child: Text('Install App Shortcut')),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Android / Chrome / Edge:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('1. Tap the browser menu (⋮) at top-right.\n'
              '2. Tap "Install app" or "Add to Home screen".'),
          SizedBox(height: 12),
          Text(
            'iPhone / iPad (Safari):',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('1. Tap the Share icon (⬆️) at the bottom.\n'
              '2. Tap "Add to Home Screen" → "Add".'),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
