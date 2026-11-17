import 'package:flutter/material.dart';

/// Non-web platforms already run natively, so no web install button is needed.
bool get isWebPlatform => false;

bool isPwaStandalone() => true;

Future<void> triggerPwaInstallOrGuide(BuildContext context) async {}
