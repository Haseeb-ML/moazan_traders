import 'package:web/web.dart' as web;

Future<bool> readLoggedInSession(String key) async {
  try {
    return web.window.localStorage.getItem(key) == 'true';
  } catch (_) {
    return false;
  }
}

Future<void> writeLoggedInSession(String key, bool value) async {
  try {
    if (value) {
      web.window.localStorage.setItem(key, 'true');
    } else {
      web.window.localStorage.removeItem(key);
    }
  } catch (_) {
    // Ignore storage errors (e.g. private browsing).
  }
}
