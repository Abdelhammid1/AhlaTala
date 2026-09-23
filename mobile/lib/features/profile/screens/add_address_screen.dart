import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/auth_repository.dart';
import 'addresses_screen.dart';

/// Add / edit a saved delivery address — Stitch _3.
///
/// Contains everything the redesigned address record models:
///  - a map preview strip on top (placeholder for now; wires to the map
///    picker screen — Task #70 — when the Google Maps SDK ships)
///  - selected-place card
///  - typed label chips (منزل / مكتب / فندق / استراحة / موقع آخر)
///  - free-form form: label name, district, apt + floor side-by-side,
///    extra details
///  - "إرشادات التوصيل" — 4 icon-toggle tiles (اتصل بي عند الوصول /
///    لا ترن الجرس / اتركه عند الباب / صورة للمدخل)
///  - a warm info banner
///  - sticky "حفظ ومتابعة" button
///
/// All fields write into the extended `AuthRepository.createAddress` /
/// `updateAddress` payload — the Stitch _3 columns land end-to-end in
/// `saved_addresses` server-side.
class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({
    super.key,
    this.existing,
    this.seedLat,
    this.seedLng,
    this.seedFormatted,
  });

  /// When set, the screen edits this row instead of inserting a new one.
  final SavedAddress? existing;
  // Seed values from a map picker return trip (Task #70 will pass them).
  final double? seedLat;
  final double? seedLng;
  final String? seedFormatted;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  static const _labelTypes = <_LabelChoice>[
    _LabelChoice(id: 'home', label: 'منزل', icon: Icons.home_outlined),
    _LabelChoice(id: 'office', label: 'مكتب', icon: Icons.work_outline),
    _LabelChoice(id: 'hotel', label: 'فندق', icon: Icons.hotel_outlined),
    _LabelChoice(id: 'rest', label: 'استراحة', icon: Icons.deck_outlined),
    _LabelChoice(id: 'other', label: 'موقع آخر', icon: Icons.location_on_outlined),
  ];

  late final TextEditingController _labelCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _aptCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _extraCtrl;
  late final TextEditingController _contactCtrl;
  String _labelType = 'home';
  bool _leaveAtDoor = false;
  bool _dontRingBell = false;
  bool _contactOnArrival = false;
  bool _photoRequested = false; // client-side flag: reserves the photo tile
  bool _isDefault = false;
  bool _busy = false;
  double? _lat;
  double? _lng;
  String? _formatted;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _districtCtrl = TextEditingController(text: e?.districtName ?? '');
    _aptCtrl = TextEditingController(text: e?.aptNumber ?? '');
    _floorCtrl = TextEditingController(text: e?.floor ?? '');
    _extraCtrl = TextEditingController(text: e?.extraDetails ?? e?.addressText ?? '');
    _contactCtrl = TextEditingController(text: e?.contactPhone ?? '');
    _labelType = e?.labelType ?? 'home';
    _leaveAtDoor = e?.leaveAtDoor ?? false;
    _dontRingBell = e?.dontRingBell ?? false;
    _contactOnArrival = (e?.contactPhone ?? '').isNotEmpty;
    _isDefault = e?.isDefault ?? false;
    _lat = widget.seedLat ?? e?.lat;
    _lng = widget.seedLng ?? e?.lng;
    _formatted = widget.seedFormatted ?? e?.formattedAddress;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _districtCtrl.dispose();
    _aptCtrl.dispose();
    _floorCtrl.dispose();
    _extraCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم العنوان مطلوب')),
      );
      return;
    }
    // Compose the free-form address_text from the structured fields so the
    // legacy address_text column still holds a usable one-line summary —
    // admins / drivers who look at that column keep seeing something sane.
    final parts = <String>[
      if (_formatted != null && _formatted!.isNotEmpty) _formatted!,
      if (_districtCtrl.text.trim().isNotEmpty) 'حي ${_districtCtrl.text.trim()}',
      if (_aptCtrl.text.trim().isNotEmpty) 'شقة ${_aptCtrl.text.trim()}',
      if (_floorCtrl.text.trim().isNotEmpty) 'الطابق ${_floorCtrl.text.trim()}',
      if (_extraCtrl.text.trim().isNotEmpty) _extraCtrl.text.trim(),
    ];
    final addressText = parts.isEmpty ? label : parts.join('، ');

    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      if (widget.existing == null) {
        await repo.createAddress(
          label: label,
          text: addressText,
          isDefault: _isDefault,
          labelType: _labelType,
          districtName: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
          aptNumber: _aptCtrl.text.trim().isEmpty ? null : _aptCtrl.text.trim(),
          floor: _floorCtrl.text.trim().isEmpty ? null : _floorCtrl.text.trim(),
          extraDetails: _extraCtrl.text.trim().isEmpty ? null : _extraCtrl.text.trim(),
          contactPhone: _contactOnArrival && _contactCtrl.text.trim().isNotEmpty
              ? _contactCtrl.text.trim()
              : null,
          leaveAtDoor: _leaveAtDoor,
          dontRingBell: _dontRingBell,
          lat: _lat,
          lng: _lng,
          formattedAddress: _formatted,
        );
      } else {
        await repo.updateAddress(
          widget.existing!.id,
          label: label,
          addressText: addressText,
          isDefault: _isDefault,
          labelType: _labelType,
          districtName: _districtCtrl.text.trim(),
          aptNumber: _aptCtrl.text.trim(),
          floor: _floorCtrl.text.trim(),
          extraDetails: _extraCtrl.text.trim(),
          contactPhone: _contactOnArrival ? _contactCtrl.text.trim() : '',
          leaveAtDoor: _leaveAtDoor,
          dontRingBell: _dontRingBell,
          lat: _lat,
          lng: _lng,
          formattedAddress: _formatted,
        );
      }
      ref.invalidate(savedAddressesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الحفظ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(top: topPad + 64, bottom: 120),
            children: [
              _MapPreview(
                formatted: _formatted,
                onEdit: () async {
                  // Map picker screen (Task #70) is deferred behind the API
                  // key. Until it ships, the field is read-only. When it
                  // ships, replace with:
                  //   final res = await context.push<MapPickResult>('/map/pick');
                  //   if (res != null) setState(() {
                  //     _lat = res.lat; _lng = res.lng; _formatted = res.formatted;
                  //   });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اختيار الموقع من الخريطة سيتاح قريباً')),
                  );
                },
              ),
              const SizedBox(height: 16),
              _SectionHeader('تفاصيل العنوان', badge: 'مطلوب'),
              const SizedBox(height: 8),
              _LabelTypeChips(
                selected: _labelType,
                onPick: (id) => setState(() => _labelType = id),
              ),
              const SizedBox(height: 16),
              _FieldLabel('اسم العنوان', required: true),
              _FieldWrapper(
                child: TextField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    hintText: 'مثال: منزل العائلة',
                    prefixIcon: Icon(Icons.bookmark_border, size: 18, color: AppTheme.charcoalMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FieldLabel('اسم الحي'),
              _FieldWrapper(
                child: TextField(
                  controller: _districtCtrl,
                  decoration: const InputDecoration(
                    hintText: 'مثال: حي القادسية',
                    prefixIcon: Icon(Icons.location_city_outlined, size: 18, color: AppTheme.charcoalMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _FieldLabel('رقم الشقة/المنزل'),
                  _FieldWrapper(child: TextField(
                    controller: _aptCtrl,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(hintText: 'مثال: شقة 4', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  )),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _FieldLabel('الطابق'),
                  _FieldWrapper(child: TextField(
                    controller: _floorCtrl,
                    decoration: const InputDecoration(hintText: 'مثال: الدور الثاني', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  )),
                ])),
              ]),
              const SizedBox(height: 12),
              _FieldLabel('تفاصيل إضافية (اختياري)', trailing: 'علامة مميزة'),
              _FieldWrapper(child: TextField(
                controller: _extraCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'مثال: بجوار مسجد النور، المدخل الجانبي مع درجات حجرية...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              )),
              const SizedBox(height: 20),
              _SectionHeader('إرشادات التوصيل', badge: 'جديد'),
              const SizedBox(height: 8),
              _InstructionsGrid(
                contactOnArrival: _contactOnArrival,
                dontRingBell: _dontRingBell,
                leaveAtDoor: _leaveAtDoor,
                photoRequested: _photoRequested,
                onContactChanged: (v) => setState(() => _contactOnArrival = v),
                onDontRingChanged: (v) => setState(() => _dontRingBell = v),
                onLeaveAtDoorChanged: (v) => setState(() => _leaveAtDoor = v),
                onPhotoChanged: (v) => setState(() => _photoRequested = v),
              ),
              if (_contactOnArrival) ...[
                const SizedBox(height: 12),
                _FieldLabel('رقم للتواصل'),
                _FieldWrapper(child: TextField(
                  controller: _contactCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '05XXXXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18, color: AppTheme.charcoalMuted),
                    border: InputBorder.none,
                  ),
                )),
              ],
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                title: Text('اجعله العنوان الافتراضي', style: AppTheme.body(size: 14, weight: FontWeight.w700)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                activeColor: AppTheme.primaryContainer,
              ),
              const SizedBox(height: 12),
              const _WarmInfoBanner(),
              const SizedBox(height: 8),
            ],
          ),
          _StickyHeader(topPad: topPad, isEdit: widget.existing != null),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _StickySaveBar(busy: _busy, onSave: _save, isEdit: widget.existing != null),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Small building blocks ═════════════════

class _LabelChoice {
  const _LabelChoice({required this.id, required this.label, required this.icon});
  final String id;
  final String label;
  final IconData icon;
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({required this.topPad, required this.isEdit});
  final double topPad;
  final bool isEdit;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, top: 0,
      child: Container(
        color: const Color(0xD9FFF8F6),
        padding: EdgeInsets.only(top: topPad),
        height: topPad + 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            SizedBox(
              width: 40, height: 40,
              child: Material(
                color: AppTheme.surfaceContainer,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(isEdit ? 'تعديل عنوان' : 'أضف موقع جديد',
                style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
            const Spacer(),
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: AppTheme.primaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.person, color: AppTheme.onPrimary, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StickySaveBar extends StatelessWidget {
  const _StickySaveBar({required this.busy, required this.onSave, required this.isEdit});
  final bool busy;
  final VoidCallback onSave;
  final bool isEdit;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Color(0x1A1F1B19), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.onPrimary,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(isEdit ? 'حفظ التغييرات' : 'حفظ ومتابعة الطلب',
                style: AppTheme.body(size: 15, weight: FontWeight.w800, color: AppTheme.onPrimary)),
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.formatted, required this.onEdit});
  final String? formatted;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppTheme.surfaceCream,
                  AppTheme.primaryFixed.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Stack(alignment: Alignment.center, children: [
              // Placeholder "map" — decorative crossroads shape.
              CustomPaint(size: const Size.fromHeight(130), painter: _MapPlaceholderPainter()),
              Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppTheme.primaryContainer, shape: BoxShape.circle),
                child: const Icon(Icons.restaurant, color: AppTheme.onPrimary, size: 22),
              ),
              Positioned(
                bottom: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBright.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Google',
                      style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalSoft)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.flameDeep),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatted ?? 'حدد موقع التوصيل من الخريطة',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTheme.headline(size: 14, weight: FontWeight.w700)),
                  Text(formatted != null ? 'مسحوب من Google Maps' : 'ثم اضغط "تعديل" أدناه',
                      style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted)),
                ],
              ),
            ),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('تعديل',
                    style: AppTheme.body(size: 12, weight: FontWeight.w800, color: AppTheme.primary)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MapPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = AppTheme.flameDeep.withValues(alpha: 0.5)
      ..strokeWidth = 8;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), road);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), road);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.badge});
  final String title;
  final String? badge;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        Text(title, style: AppTheme.headline(size: 16, weight: FontWeight.w700)),
        const SizedBox(width: 8),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.herbFresh.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge!,
                style: AppTheme.body(size: 10, weight: FontWeight.w800, color: AppTheme.herbFresh)),
          ),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.required = false, this.trailing});
  final String label;
  final bool required;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        Text(label,
            style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.charcoalSoft)),
        const Spacer(),
        if (required)
          Text('مطلوب', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.pomegranateRed))
        else if (trailing != null)
          Text(trailing!, style: AppTheme.body(size: 10, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
      ]),
    );
  }
}

class _FieldWrapper extends StatelessWidget {
  const _FieldWrapper({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: child,
      ),
    );
  }
}

class _LabelTypeChips extends StatelessWidget {
  const _LabelTypeChips({required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _AddAddressScreenState._labelTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _AddAddressScreenState._labelTypes[i];
          final active = t.id == selected;
          return InkWell(
            onTap: () => onPick(t.id),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? AppTheme.charcoalSoft : AppTheme.surfaceCreamSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icon, size: 16,
                    color: active ? AppTheme.surfaceBright : AppTheme.charcoalMuted),
                const SizedBox(width: 6),
                Text(t.label,
                    style: AppTheme.body(size: 12, weight: FontWeight.w700,
                        color: active ? AppTheme.surfaceBright : AppTheme.charcoalSoft)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _InstructionsGrid extends StatelessWidget {
  const _InstructionsGrid({
    required this.contactOnArrival,
    required this.dontRingBell,
    required this.leaveAtDoor,
    required this.photoRequested,
    required this.onContactChanged,
    required this.onDontRingChanged,
    required this.onLeaveAtDoorChanged,
    required this.onPhotoChanged,
  });
  final bool contactOnArrival, dontRingBell, leaveAtDoor, photoRequested;
  final ValueChanged<bool> onContactChanged, onDontRingChanged, onLeaveAtDoorChanged, onPhotoChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.4,
        children: [
          _ToggleTile(icon: Icons.phone_in_talk_outlined, label: 'اتصل بي عند الوصول', active: contactOnArrival, onTap: () => onContactChanged(!contactOnArrival)),
          _ToggleTile(icon: Icons.notifications_off_outlined, label: 'لا ترن الجرس', active: dontRingBell, onTap: () => onDontRingChanged(!dontRingBell)),
          _ToggleTile(icon: Icons.meeting_room_outlined, label: 'اتركه عند الباب', active: leaveAtDoor, onTap: () => onLeaveAtDoorChanged(!leaveAtDoor)),
          _ToggleTile(icon: Icons.photo_camera_outlined, label: 'صورة للمدخل', active: photoRequested, onTap: () => onPhotoChanged(!photoRequested)),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? AppTheme.charcoalSoft : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppTheme.charcoalSoft : AppTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryContainer : AppTheme.surfaceCream,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 16, color: active ? AppTheme.onPrimary : AppTheme.charcoalSoft),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTheme.body(size: 11, weight: FontWeight.w700,
                    color: active ? AppTheme.surfaceBright : AppTheme.charcoalSoft, height: 14 / 11)),
          ),
        ]),
      ),
    );
  }
}

class _WarmInfoBanner extends StatelessWidget {
  const _WarmInfoBanner();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryFixed.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_dining_outlined, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مشاوي أحلى طلة تصلك ساخنة',
                    style: AppTheme.headline(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('صناديق حرارية خاصة للمحافظة على نكهة الفحم ودرجة الحرارة أثناء التوصيل',
                    style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted, height: 14 / 11)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
