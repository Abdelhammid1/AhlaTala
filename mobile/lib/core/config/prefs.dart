import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single, app-wide SharedPreferences provider. Resolved once before
/// `runApp` in `main.dart` and injected as an override, so every consumer
/// (cart, auth, saved-phone, inbox poller) reads it **synchronously** —
/// no more per-provider FutureProvider indirection, no more race between
/// the first frame and prefs resolving.
final sharedPrefsProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError(
    'sharedPrefsProvider was read before it was overridden in main.dart. '
    'Ensure main() awaits SharedPreferences.getInstance() and passes it '
    'into ProviderScope(overrides: ...).',
  );
});
