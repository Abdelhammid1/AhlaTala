import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/prefs.dart';
import 'core/theme/app_theme.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/cart/screens/order_review_screen.dart';
import 'features/checkout/screens/gateway_stub_screen.dart';
import 'features/checkout/screens/order_confirmation_screen.dart';
import 'features/item_details/screens/item_details_screen.dart';
import 'features/loyalty/screens/loyalty_screen.dart';
import 'features/menu/screens/categories_screen.dart';
import 'features/menu/screens/category_items_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/verify_screen.dart';
import 'features/notifications/providers/notifications_providers.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/notifications/services/inbox_poller.dart';
import 'features/notifications/services/local_pusher.dart';
import 'features/profile/screens/order_history_screen.dart';
import 'features/profile/screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve SharedPreferences ONCE, up-front, so every downstream provider
  // (cart, auth, saved-phone, inbox poller) reads it synchronously and the
  // first frame never races the async prefs load.
  final prefs = await SharedPreferences.getInstance();
  await LocalPusher.instance.init();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const AhlaTollaApp(),
  ));
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const CategoriesScreen()),
    GoRoute(
      path: '/categories/:id',
      builder: (context, state) => CategoryItemsScreen(
        categoryId: int.parse(state.pathParameters['id']!),
        title: state.extra is String ? state.extra as String : null,
      ),
    ),
    GoRoute(
      path: '/items/:id',
      builder: (context, state) => ItemDetailsScreen(
        itemId: int.parse(state.pathParameters['id']!),
      ),
    ),
    // E2
    GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
    GoRoute(path: '/review', builder: (_, __) => const OrderReviewScreen()),
    // E3
    GoRoute(
      path: '/checkout/gateway/:orderId',
      builder: (_, s) => GatewayStubScreen(orderId: int.parse(s.pathParameters['orderId']!)),
    ),
    GoRoute(
      path: '/orders/:orderId/confirmation',
      builder: (_, s) => OrderConfirmationScreen(orderId: int.parse(s.pathParameters['orderId']!)),
    ),
    // E5
    GoRoute(path: '/loyalty', builder: (_, __) => const LoyaltyScreen()),
    // E8
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    // E9
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/verify',
      builder: (_, s) => VerifyScreen(
        phone: s.uri.queryParameters['phone'] ?? '',
        devCode: s.uri.queryParameters['dev_code'],
      ),
    ),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/profile/orders', builder: (_, __) => const OrderHistoryScreen()),
  ],
);

class AhlaTollaApp extends ConsumerWidget {
  const AhlaTollaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // E8: whenever we learn who the current customer is (via saved phone),
    // arm the inbox poller for that id. Provider disposes cleanly on switch.
    ref.listen(currentCustomerProvider, (previous, next) {
      final poller = ref.read(inboxPollerProvider);
      if (poller == null) return;
      final cust = next.valueOrNull;
      if (cust != null) {
        poller.start(cust.customerId);
      } else {
        poller.stop();
      }
    });

    return MaterialApp.router(
      title: 'أحلى طلة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
