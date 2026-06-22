import '../../core/network/api_client.dart';
import '../../core/session/session_manager.dart';

/// All authentication flows against the new backend. On success it persists the
/// session (tokens + user) through [SessionManager] so the rest of the app and
/// the Dio interceptors pick it up automatically.
class AuthRepository {
  AuthRepository({ApiClient? client, SessionManager? session})
      : _api = client ?? ApiClient.instance,
        _session = session ?? SessionManager.instance;

  final ApiClient _api;
  final SessionManager _session;

  /// Request an OTP for [phone]. Returns the dev code when the backend runs in
  /// dev-expose mode (handy while SMS isn't wired up), otherwise null.
  Future<String?> requestOtp(String phone) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/otp/request',
      body: {'phone': phone},
    );
    return res.data['devCode']?.toString();
  }

  /// Verify [code] for [phone]; auto-registers a new customer on first login.
  /// Persists tokens + profile and returns the user map.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    String? name,
    String? email,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      body: {
        'phone': phone,
        'code': code,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final data = res.data;
    await _session.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  /// Fetch the fresh profile for the current session and cache it.
  Future<Map<String, dynamic>> me() async {
    final res = await _api.get<Map<String, dynamic>>('/auth/me');
    await _session.saveUser(res.data);
    return res.data;
  }

  /// Update the signed-in customer's profile (name / email) and refresh the
  /// cached session user.
  Future<Map<String, dynamic>> updateProfile({String? name, String? email}) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/users/me',
      body: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    await _session.saveUser(res.data);
    return res.data;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Best-effort server revoke; local clear is what matters.
    }
    await _session.clear();
  }
}
