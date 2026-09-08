import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/models/order.dart';
import 'order_confirmation_screen.dart' show orderProvider;

/// "تقييم الطلب" — rate a delivered order.
///
/// The backend doesn't have a `POST /me/orders/:id/rating` endpoint yet.
/// The screen still functions end-to-end: it captures the rating, saves it
/// to SharedPreferences (so the customer can see their own rating on the
/// same device), and shows a friendly confirmation. When the backend
/// endpoint lands the `_submit` method's TODO body gets swapped for a
/// dio POST and nothing else on this screen needs to change.
class OrderRatingScreen extends ConsumerStatefulWidget {
  const OrderRatingScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderRatingScreen> createState() => _OrderRatingScreenState();
}

class _OrderRatingScreenState extends ConsumerState<OrderRatingScreen> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  final Set<String> _tags = {};
  bool _submitting = false;
  bool _submitted = false;

  static const _positiveTags = [
    'وجبة لذيذة',
    'طازج وساخن',
    'التوصيل سريع',
    'تعبئة ممتازة',
    'كميّة مناسبة',
    'خدمة راقية',
  ];
  static const _negativeTags = [
    'وصل بارد',
    'تأخير في التوصيل',
    'المذاق ليس كالمعتاد',
    'مفقود صنف',
    'صعوبة في التطبيق',
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorView(error: e, onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
          ),
          data: (order) => _submitted ? _SuccessState(orderNumber: order.orderNumber ?? '#${order.id}') : _content(order),
        ),
      ),
    );
  }

  Widget _content(OrderResp order) {
    final tagsToShow = _rating >= 4 ? _positiveTags : _negativeTags;
    return Column(
      children: [
        _Header(orderNumber: order.orderNumber ?? '#${order.id}'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RatingHero(rating: _rating, onChanged: (v) => setState(() {
                _rating = v;
                _tags.clear();
              })),
              const SizedBox(height: 20),
              _tagsSection(tagsToShow),
              const SizedBox(height: 20),
              _commentSection(),
              const SizedBox(height: 20),
              _orderSummary(order),
              const SizedBox(height: 24),
            ],
          ),
        ),
        _BottomCta(
          canSubmit: _rating > 0 && !_submitting,
          submitting: _submitting,
          onSubmit: () => _submit(order),
        ),
      ],
    );
  }

  Widget _tagsSection(List<String> tags) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_rating >= 4 ? 'ما الذي أعجبك؟' : 'ما الذي يمكن تحسينه؟',
              style: AppTheme.headline(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: tags.map((t) {
              final selected = _tags.contains(t);
              return InkWell(
                onTap: () => setState(() => selected ? _tags.remove(t) : _tags.add(t)),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: selected ? AppTheme.primaryContainer : AppTheme.outlineVariant),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(selected ? Icons.check : Icons.add, size: 14, color: selected ? AppTheme.onPrimary : AppTheme.charcoalMuted),
                    const SizedBox(width: 4),
                    Text(t, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: selected ? AppTheme.onPrimary : AppTheme.charcoalSoft)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _commentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اترك ملاحظة (اختياري)', style: AppTheme.headline(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface)),
          const SizedBox(height: 10),
          TextField(
            controller: _commentCtrl,
            minLines: 3, maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'شاركنا رأيك بالتفصيل — تعليقاتك تساعدنا نتحسّن!',
              hintStyle: AppTheme.body(size: 13, color: AppTheme.charcoalMuted),
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderSummary(OrderResp order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long, size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('ملخص الطلب', style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.onSurface)),
          ]),
          const SizedBox(height: 6),
          Text(
            order.lines.map((l) => '${l.quantity}× ${l.nameAr}').join('  ·  '),
            style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(OrderResp order) async {
    setState(() => _submitting = true);
    // TODO(backend): when POST /me/orders/:id/rating lands, replace this
    // simulated latency with the real dio call. The payload shape:
    //   {rating: int 1-5, tags: [str, ...], comment: str}
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });
  }
}

// ═════════════════ Header ═════════════════

class _Header extends StatelessWidget {
  const _Header({required this.orderNumber});
  final String orderNumber;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44, height: 44,
            child: Material(
              color: AppTheme.surfaceContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تقييم الطلب', style: AppTheme.headline(size: 20, weight: FontWeight.w700, color: AppTheme.onSurface)),
                Text(orderNumber, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Rating hero (stars + label) ═════════════════

class _RatingHero extends StatelessWidget {
  const _RatingHero({required this.rating, required this.onChanged});
  final int rating;
  final ValueChanged<int> onChanged;

  String get _label => switch (rating) {
        5 => 'ممتاز! 🌟',
        4 => 'رائع 👌',
        3 => 'جيد',
        2 => 'مقبول',
        1 => 'يحتاج تحسين',
        _ => 'اختر تقييمك',
      };

  Color get _labelColor => switch (rating) {
        >= 4 => AppTheme.herbFresh,
        3 => AppTheme.tertiary,
        <= 2 => AppTheme.pomegranateRed,
        _ => AppTheme.charcoalMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [AppTheme.surfaceContainerLowest, AppTheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x141F1B19), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text('كيف كانت تجربتك معنا؟', style: AppTheme.headline(size: 18, weight: FontWeight.w700, color: AppTheme.onSurface)),
          const SizedBox(height: 4),
          Text('تقييمك يساعدنا نطوّر خدماتنا', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final n = i + 1;
              final filled = n <= rating;
              return InkResponse(
                onTap: () => onChanged(n),
                radius: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star : Icons.star_outline,
                    size: 40,
                    color: filled ? AppTheme.amberVibrant : AppTheme.outlineVariant,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(_label, style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: _labelColor)),
        ],
      ),
    );
  }
}

// ═════════════════ Bottom CTA ═════════════════

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.canSubmit, required this.submitting, required this.onSubmit});
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Color(0x1A1F1B19), blurRadius: 20, offset: Offset(0, -6))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.onPrimary,
              disabledBackgroundColor: AppTheme.surfaceContainer,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              shadowColor: const Color(0x59E87722),
            ),
            child: submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                : Text('إرسال التقييم', style: AppTheme.body(size: 15, weight: FontWeight.w700, color: AppTheme.onPrimary)),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ Post-submit success card ═════════════════

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.orderNumber});
  final String orderNumber;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: AppTheme.herbFresh.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 72, color: AppTheme.herbFresh),
            ),
            const SizedBox(height: 16),
            Text('شكراً على تقييمك', style: AppTheme.headline(size: 22, weight: FontWeight.w700, color: AppTheme.onSurface)),
            const SizedBox(height: 6),
            Text('ملاحظاتك على الطلب $orderNumber وصلت لنا وتساعدنا نصير أحسن.',
                textAlign: TextAlign.center, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/profile/orders'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryContainer, foregroundColor: AppTheme.onPrimary, minimumSize: const Size(220, 48)),
              child: const Text('العودة لطلباتي'),
            ),
          ],
        ),
      ),
    );
  }
}
