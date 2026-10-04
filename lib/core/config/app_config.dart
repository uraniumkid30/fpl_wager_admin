/// Build-time configuration for the admin app.
///
/// Point the app at your API when you run or build it:
///
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// It must be the same server the main FPLwager app uses.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://35.217.63.208',
  );
}
