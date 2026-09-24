import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Full-screen animated overlay shown when an order is confirmed. Auto-
/// dismisses after ~2.2s so the caller can immediately route to the
/// order confirmation screen — the animation is purely a celebration
/// moment, not a place the customer needs to interact with.
///
/// Composition:
///   • Cream backdrop that fades in
///   • Green success ring that bounces (elasticOut) then settles
///   • Checkmark inside the ring (fades in a beat after the ring)
///   • "شكراً على طلبك من أحلى طلة 🎉" headline
///   • "طلبك قيد التحضير — سنبعث تحديث حالته لحظياً" subtitle
///   • Small brand tag on the far bottom
///
/// Returns a Future<void> that completes when the overlay auto-closes.
class PaymentSuccessAnimation {
  const PaymentSuccessAnimation._();

  static Future<void> show(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Order confirmed',
      barrierColor: const Color(0xF2FFF8F6),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const _SuccessOverlay(),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}

class _SuccessOverlay extends StatefulWidget {
  const _SuccessOverlay();
  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay> with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _copyCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _copyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _play();
  }

  Future<void> _play() async {
    _ringCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _checkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    _copyCtrl.forward();
    // Hold the celebratory moment before the caller routes onward.
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _checkCtrl.dispose();
    _copyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Material wrapper is required — without it, Text descendants inside
    // showGeneralDialog fall back to Flutter's debug DefaultTextStyle,
    // which paints every glyph with a yellow underline (the "you forgot
    // a Material ancestor" hint).
    return Material(
      type: MaterialType.transparency,
      child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Bouncy green ring + checkmark ───
          SizedBox(
            width: 132, height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft radial halo
                FadeTransition(
                  opacity: _ringCtrl,
                  child: Container(
                    width: 132, height: 132,
                    decoration: BoxDecoration(
                      color: AppTheme.herbFresh.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: CurvedAnimation(parent: _ringCtrl, curve: Curves.elasticOut),
                  child: Container(
                    width: 96, height: 96,
                    decoration: const BoxDecoration(color: AppTheme.herbFresh, shape: BoxShape.circle),
                  ),
                ),
                FadeTransition(
                  opacity: _checkCtrl,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1.0)
                        .chain(CurveTween(curve: Curves.easeOutBack))
                        .animate(_checkCtrl),
                    child: const Icon(Icons.check_rounded, size: 60, color: AppTheme.surfaceBright),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ─── Copy fades up ───
          FadeTransition(
            opacity: _copyCtrl,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(_copyCtrl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'شكراً على طلبك من أحلى طلة 🎉',
                    textAlign: TextAlign.center,
                    style: AppTheme.headline(size: 22, weight: FontWeight.w800, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'طلبك قيد التحضير — سنُرسل لك تحديث حالته لحظة بلحظة.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.charcoalMuted, height: 20 / 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryFixed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department, size: 14, color: AppTheme.flameDeep),
                      const SizedBox(width: 4),
                      Text('أحلى طلة',
                          style: AppTheme.body(size: 11, weight: FontWeight.w800, color: AppTheme.flameDeep, letterSpacing: 0.4)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
