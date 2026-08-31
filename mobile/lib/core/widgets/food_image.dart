import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard food image widget for the whole app.
///
/// - When [url] is a live http(s) image, loads it via CachedNetworkImage
///   with a warm brand placeholder + a graceful error fallback (a food icon
///   on brand-soft, not the default red X).
/// - When [url] is null, shows the same fallback.
///
/// Use this everywhere we render an item / category / offer / cart-line image
/// so the app never shows Flutter's default broken-image X in a Play Store
/// screenshot when a mock URL (loremflickr) times out or 500s.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.url,
    this.icon = Icons.restaurant_menu,
    this.iconSize = 42,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final IconData icon;
  final double iconSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      placeholder: (_, __) => _shimmer(context),
      errorWidget: (_, __, ___) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppTheme.brand.withValues(alpha: 0.10),
              AppTheme.brand.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Icon(icon, size: iconSize, color: AppTheme.brand.withValues(alpha: 0.55)),
      );

  Widget _shimmer(BuildContext context) => Container(
        color: const Color(0xFFF4EDE4),
        alignment: Alignment.center,
        child: SizedBox(
          height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brand.withValues(alpha: 0.4)),
        ),
      );
}
