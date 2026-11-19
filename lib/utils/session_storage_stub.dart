import 'package:shared_preferences/shared_preferences.dart';

Future<bool> readLoggedInSession(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> writeLoggedInSession(String key, bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  } catch (_) {
    // Ignore storage errors so login never blocks.
  }
}
