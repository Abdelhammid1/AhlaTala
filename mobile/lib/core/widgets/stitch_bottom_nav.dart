import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// 4-item bottom navigation bar matching the Stitch design.
///
/// Rendered as a fixed bar with a translucent surface + backdrop blur,
/// safe-area padding at the bottom. Active tab is the brand-container
/// color; inactive tabs are `on-surface-variant`. Tap navigates via
/// go_router — no internal state, the router path decides `activeIndex`.
///
/// Tabs (RTL order in the design; Row lays them naturally):
///   0: الرئيسية       (/)
///   1: القائمة         (/menu — falls back to /categories/... if needed)
///   2: طلباتي          (/profile/orders)
///   3: حسابي           (/profile)
class StitchBottomNav extends StatelessWidget {
  const StitchBottomNav({super.key, required this.active});

  /// Which tab is highlighted. Callers infer this from their route.
  final StitchNavTab active;

  static StitchNavTab detect(String location) {
    if (location.startsWith('/profile/orders')) return StitchNavTab.orders;
    if (location.startsWith('/profile')) return StitchNavTab.profile;
    if (location.startsWith('/menu') || location.startsWith('/categories')) return StitchNavTab.menu;
    return StitchNavTab.home;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xE6FFF8F6), // AppTheme.surface at ~90% opacity
          boxShadow: [
            BoxShadow(color: Color(0x0D1F1B19), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                active: active == StitchNavTab.home,
                icon: Icons.cottage_outlined,
                iconActive: Icons.cottage,
                label: 'الرئيسية',
                onTap: () => context.go('/'),
              ),
              _NavItem(
                active: active == StitchNavTab.menu,
                icon: Icons.restaurant_menu_outlined,
                iconActive: Icons.restaurant_menu,
                label: 'القائمة',
                onTap: () => context.go('/menu'),
              ),
              _NavItem(
                active: active == StitchNavTab.orders,
                icon: Icons.receipt_long_outlined,
                iconActive: Icons.receipt_long,
                label: 'طلباتي',
                onTap: () => context.push('/profile/orders'),
              ),
              _NavItem(
                active: active == StitchNavTab.profile,
                icon: Icons.account_circle_outlined,
                iconActive: Icons.account_circle,
                label: 'حسابي',
                onTap: () => context.push('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum StitchNavTab { home, menu, orders, profile }

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final IconData iconActive;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryContainer : AppTheme.onSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? iconActive : icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.body(
                size: 10,
                weight: active ? FontWeight.w700 : FontWeight.w600,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
