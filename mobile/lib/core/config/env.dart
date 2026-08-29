/// Compile-time configuration.
///
/// Override at run-time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000
///
/// Android emulator hits the host machine at 10.0.2.2 (not 127.0.0.1);
/// iOS simulator can use 127.0.0.1 directly.
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
}
