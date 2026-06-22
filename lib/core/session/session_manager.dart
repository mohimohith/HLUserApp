import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owns the authenticated session: JWT access/refresh tokens, the selected
/// branch, and the cached user profile. Tokens live in the platform keystore
/// (Keychain / EncryptedSharedPreferences) via [FlutterSecureStorage].
///
/// A single shared instance is exposed so the Dio interceptors and the UI
/// observe the same auth state. [isAuthenticated] is a [ValueListenable] so
/// widgets can react to login/logout without manual plumbing.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user';
  static const _kBranch = 'selected_branch_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  String? _branchId;

  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get user => _user;
  String? get userId => _user?['id'] as String?;
  String? get userName => _user?['name'] as String?;
  String? get userPhone => _user?['phone'] as String?;
  String? get branchId => _branchId;
  bool get hasBranch => _branchId != null && _branchId!.isNotEmpty;

  /// Load any persisted session into memory. Call once during app startup
  /// (splash) before deciding the landing screen.
  Future<void> bootstrap() async {
    _accessToken = await _storage.read(key: _kAccess);
    _refreshToken = await _storage.read(key: _kRefresh);
    _branchId = await _storage.read(key: _kBranch);
    final rawUser = await _storage.read(key: _kUser);
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        _user = json.decode(rawUser) as Map<String, dynamic>;
      } catch (_) {
        _user = null;
      }
    }
    isAuthenticated.value = _accessToken != null && _refreshToken != null;
  }

  /// Persist a freshly issued token pair (login or refresh response).
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    isAuthenticated.value = true;
  }

  /// Persist the full login result: tokens + user profile.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    await saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await saveUser(user);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    _user = user;
    await _storage.write(key: _kUser, value: json.encode(user));
  }

  Future<void> setBranch(String branchId) async {
    _branchId = branchId;
    await _storage.write(key: _kBranch, value: branchId);
  }

  /// Wipe the session (logout or unrecoverable 401). Keeps the selected branch
  /// so a logged-out user can still browse the correct store catalog.
  Future<void> clear({bool keepBranch = true}) async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
    if (!keepBranch) {
      _branchId = null;
      await _storage.delete(key: _kBranch);
    }
    isAuthenticated.value = false;
  }
}
