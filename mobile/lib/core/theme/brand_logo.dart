import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Reusable logo widget. Uses the smallest asset that fits the requested size
/// so we don't decode a 1024x1024 PNG when the AppBar only needs ~40 tall.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40, this.color});
  final double height;

  /// Optional tint. Pass `null` (default) to use the logo's own colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Pick the appropriate bucket
    final String asset;
    if (height <= 64) {
      asset = 'assets/logo_256.png';
    } else if (height <= 200) {
      asset = 'assets/logo_512.png';
    } else {
      asset = 'assets/logo.png';
    }
    return Image.asset(asset, height: height, fit: BoxFit.contain, color: color);
  }
}

/// Compact "chip" version for tight spots (AppBar title bars). The logo already
/// carries its own dark background, so on a light AppBar we clip it to a circle
/// so it reads as an emblem rather than a floating square.
class BrandLogoChip extends StatelessWidget {
  const BrandLogoChip({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: height,
      decoration: const BoxDecoration(
        color: AppTheme.brandDark,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Padding(
        // Small inset so the circular clip doesn't nip the wordmark.
        padding: EdgeInsets.all(height * 0.05),
        child: BrandLogo(height: height),
      ),
    );
  }
}
