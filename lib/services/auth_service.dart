import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../utils/session_storage_stub.dart'
    if (dart.library.js_interop) '../utils/session_storage_web.dart';

/// Abstraction for app authentication backed by Firebase Firestore or memory.
abstract class AuthService {
  Future<bool> isLoggedIn();
  Future<String> getCurrentUsername();
  Future<bool> login(String username, String password);
  Future<void> logout();
  Future<bool> changeCredentials({
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  });

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}

/// Stores username & SHA-256 password hash in Firestore `app_config/auth`
/// and persists login session in SharedPreferences.
class FirestoreAuthService implements AuthService {
  static const String _sessionKey = 'moazan_logged_in';
  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = '123456';

  final FirebaseFirestore _firestore;

  FirestoreAuthService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _authDoc =>
      _firestore.collection('app_config').doc('auth');

  Future<Map<String, dynamic>> _ensureAuthDoc() async {
    final fallback = <String, dynamic>{
      'username': _defaultUsername,
      'passwordHash': AuthService.hashPassword(_defaultPassword),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    try {
      final snap = await _authDoc.get().timeout(const Duration(seconds: 4));
      if (snap.exists && snap.data() != null) {
        return snap.data()!;
      }
      // Seed default credentials asynchronously so login never blocks on slow network.
      _authDoc.set(fallback).catchError((_) {});
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return readLoggedInSession(_sessionKey);
  }

  @override
  Future<String> getCurrentUsername() async {
    final data = await _ensureAuthDoc();
    return (data['username'] ?? _defaultUsername).toString();
  }

  @override
  Future<bool> login(String username, String password) async {
    final data = await _ensureAuthDoc();
    final storedUser = (data['username'] ?? _defaultUsername).toString().trim();
    final storedHash = (data['passwordHash'] ?? '').toString();
    final inputHash = AuthService.hashPassword(password);

    if (username.trim().toLowerCase() == storedUser.toLowerCase() &&
        inputHash == storedHash) {
      await writeLoggedInSession(_sessionKey, true);
      return true;
    }
    return false;
  }

  @override
  Future<void> logout() async {
    await writeLoggedInSession(_sessionKey, false);
  }

  @override
  Future<bool> changeCredentials({
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    final data = await _ensureAuthDoc();
    final storedHash = (data['passwordHash'] ?? '').toString();
    if (AuthService.hashPassword(currentPassword) != storedHash) {
      return false;
    }

    await _authDoc.set({
      'username': newUsername.trim(),
      'passwordHash': AuthService.hashPassword(newPassword),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return true;
  }
}

/// In-memory AuthService for unit and widget tests.
class InMemoryAuthService implements AuthService {
  bool _loggedIn;
  String _username;
  String _passwordHash;

  InMemoryAuthService({
    bool initiallyLoggedIn = false,
    String initialUsername = 'admin',
    String initialPassword = '123456',
  })  : _loggedIn = initiallyLoggedIn,
        _username = initialUsername,
        _passwordHash = AuthService.hashPassword(initialPassword);

  @override
  Future<bool> isLoggedIn() async => _loggedIn;

  @override
  Future<String> getCurrentUsername() async => _username;

  @override
  Future<bool> login(String username, String password) async {
    if (username.trim().toLowerCase() == _username.toLowerCase() &&
        AuthService.hashPassword(password) == _passwordHash) {
      _loggedIn = true;
      return true;
    }
    return false;
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
  }

  @override
  Future<bool> changeCredentials({
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    if (AuthService.hashPassword(currentPassword) != _passwordHash) {
      return false;
    }
    _username = newUsername.trim();
    _passwordHash = AuthService.hashPassword(newPassword);
    return true;
  }
}
