/// Compile-time configuration.
///
/// The default is production so any build without `--dart-define` still
/// hits a working backend (important for cloud CI systems — Xcode Cloud,
/// Codemagic, etc. — that don't set custom defines by default).
///
/// Override for local dev with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000
///
/// - Android emulator: use `http://10.0.2.2:5000` to hit the host machine.
/// - iOS simulator:    use `http://127.0.0.1:5000` (or the mac's LAN IP).
/// - Real device on LAN: use the mac/PC's LAN IP `http://192.168.x.x:5000`
///   AND make sure the phone is on the same wifi.
///
/// Debug builds keep cleartext HTTP via `network_security_config` /
/// `NSAllowsArbitraryLoadsInWebContent`; release builds are HTTPS-only.
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ahlatala.manasety.ai',
  );
}
