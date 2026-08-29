import 'package:flutter/material.dart';

import '../../../data/models/order.dart';

/// Horizontal timeline: confirmed → preparing → (on_the_way|ready_for_pickup) → delivered.
/// Terminal states (cancelled / failed) render as a compact red chip instead.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.status,
    required this.fulfillmentType, // 'delivery' | 'pickup'
  });

  final String status;
  final String fulfillmentType;

  static const _order = [
    'confirmed',
    'preparing',
    'on_the_way', // replaced by ready_for_pickup for pickup
    'delivered',
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') return _terminalChip('ملغى', Colors.red);
    if (status == 'failed') return _terminalChip('فشل الدفع', Colors.red);

    final steps = List<String>.from(_order);
    if (fulfillmentType == 'pickup') {
      steps[2] = 'ready_for_pickup';
    }

    final currentIdx = steps.indexOf(status);
    // If status isn't in the timeline (e.g. 'created'), fall back to a chip.
    if (currentIdx == -1) {
      return _terminalChip(orderStatusAr(status), Colors.grey);
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final passed = (i ~/ 2) < currentIdx;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: passed ? theme.colorScheme.primary : Colors.grey.shade300,
                  ),
                );
              }
              final idx = i ~/ 2;
              return _dot(context, done: idx < currentIdx, current: idx == currentIdx);
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(steps.length, (i) {
              final label = orderStatusAr(steps[i]);
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: i <= currentIdx ? theme.colorScheme.primary : Colors.grey,
                    fontWeight: i == currentIdx ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, {required bool done, required bool current}) {
    final theme = Theme.of(context);
    final color = (done || current) ? theme.colorScheme.primary : Colors.grey.shade300;
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : (current
              ? Container(
                  margin: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                )
              : null),
    );
  }

  Widget _terminalChip(String label, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ),
      );
}
