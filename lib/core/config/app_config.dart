/// Central configuration for the new NexaMart backend (NestJS).
///
/// The legacy PHP endpoints under `lib/utils/api_constants.dart` are being
/// retired in favour of the typed repository layer that talks to this API.
class AppConfig {
  AppConfig._();

  /// Toggle between local development and production.
  ///
  /// During migration we point at the local NestJS server. Flip
  /// [useProduction] to `true` (or override via --dart-define) before release.
  static const bool useProduction = bool.fromEnvironment(
    'USE_PROD',
    defaultValue: false,
  );

  /// Android emulator reaches the host machine on 10.0.2.2.
  /// For a physical device on the same LAN, replace with your machine IP.
  static const String _devHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String _prodHost = String.fromEnvironment(
    'API_HOST_PROD',
    defaultValue: 'https://api.mlands-nexamart.com',
  );

  static String get host => useProduction ? _prodHost : _devHost;

  /// Versioned API prefix configured in the backend (`app.setGlobalPrefix`).
  static const String apiPrefix = '/api/v1';

  static String get baseUrl => '$host$apiPrefix';

  /// Network timeouts.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Homepage client-side cache window. The server caches per-branch for 120s;
  /// we keep a short local mirror so tab switches feel instant.
  static const Duration homeCacheTtl = Duration(seconds: 90);
}
