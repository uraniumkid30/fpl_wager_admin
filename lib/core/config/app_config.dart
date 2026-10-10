/// Build-time configuration for the admin app.
///
/// Point the app at your API when you run or build it:
///
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// It must be the same server the main FPLboardman app uses.
class AppConfig {
  const AppConfig._();

  /// The backend. Builds use the live server unless told otherwise, e.g.
  /// `--dart-define=API_BASE_URL=http://127.0.0.1:8080` for a local one.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.fplboardman.com',
  );
}
