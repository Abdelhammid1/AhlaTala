import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../models/map_pick_result.dart';
import '../services/geocoding_service.dart';

/// Full-screen map picker — Stitch _2 shape, powered by OpenStreetMap
/// tiles + Nominatim geocoding. Zero cost, zero API key.
///
/// Behaviour:
///   • Opens centered on the customer's GPS position when granted,
///     else a sane Saudi default (Riyadh).
///   • The pin is fixed at the viewport center; dragging the map
///     effectively moves the pin over the terrain. Every idle position
///     triggers a reverse-geocode (debounced 400ms) so the bottom
///     card's address stays live without hammering Nominatim.
///   • Search bar hits Nominatim's `/search` (biased to `countrycodes=sa`)
///     with a 400ms debounce and shows up to 8 suggestions. Tapping one
///     animates the map to that coordinate.
///   • "الموقع الحالي" FAB re-centers on GPS.
///   • +/- FABs zoom by 1 step.
///   • Bottom sticky bar shows the currently-selected address + the
///     yellow "تأكيد موقع التوصيل" CTA. Returns a [MapPickResult] on
///     confirm.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key, this.initial});

  /// Seed the map at a specific coordinate (edit flow) rather than the
  /// customer's GPS position.
  final MapPickResult? initial;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(24.7136, 46.6753); // Riyadh
  static const double _initialZoom = 15.5;

  final _mapCtrl = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng _pinPosition = _fallbackCenter;
  String _pinAddress = 'جارٍ تحديد الموقع...';
  bool _resolvingAddress = false;
  Timer? _reverseDebounce;
  Timer? _searchDebounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    // Seed initial position — either the passed-in edit target or GPS.
    if (widget.initial != null) {
      _pinPosition = LatLng(widget.initial!.lat, widget.initial!.lng);
      _pinAddress = widget.initial!.formatted;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(_pinPosition, _initialZoom);
      });
    } else {
      _resolveCurrentLocation(initial: true);
    }
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _reverseDebounce?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Try to grab the phone's GPS position; if permission is denied or
  /// the platform can't fix, we stay on the fallback + surface a soft
  /// snackbar (the customer can still drag the map + confirm manually).
  Future<void> _resolveCurrentLocation({bool initial = false}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'location-services-disabled';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'location-denied';
      }
      final pos = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      final coord = LatLng(pos.latitude, pos.longitude);
      _mapCtrl.move(coord, _initialZoom);
      // The onMapEvent will fire and _kickReverse() will pick up the address.
    } catch (_) {
      if (initial && mounted) {
        // Silent on initial — the fallback is fine and the user can
        // adjust. Show hint only on explicit GPS button tap.
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر تحديد موقعك — تحقق من إذن الموقع'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onMapEvent(MapEvent event) {
    // Only trigger a reverse-geocode once the user has settled on a
    // position (map stops moving); intermediate deltas would spam
    // Nominatim past its 1/sec limit.
    final settle = event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventRotateEnd;
    if (!settle) return;
    _kickReverse(event.camera.center);
  }

  void _kickReverse(LatLng at) {
    setState(() {
      _pinPosition = at;
      _resolvingAddress = true;
    });
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 400), () async {
      final svc = ref.read(geocodingServiceProvider);
      final addr = await svc.reverse(at.latitude, at.longitude);
      if (!mounted) return;
      setState(() {
        _resolvingAddress = false;
        _pinAddress = addr ?? 'موقع مختار (بدون عنوان)';
      });
    });
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _suggestions = const [];
        _showSuggestions = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final svc = ref.read(geocodingServiceProvider);
      final list = await svc.search(q);
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _showSuggestions = list.isNotEmpty;
      });
    });
  }

  void _pickSuggestion(PlaceSuggestion s) {
    _searchFocus.unfocus();
    setState(() {
      _showSuggestions = false;
      _searchCtrl.text = s.displayName;
    });
    _mapCtrl.move(LatLng(s.lat, s.lng), 17);
    _kickReverse(LatLng(s.lat, s.lng));
  }

  void _confirm() {
    Navigator.of(context).pop(MapPickResult(
      lat: _pinPosition.latitude,
      lng: _pinPosition.longitude,
      formatted: _pinAddress,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // ───────── Map layer ─────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: widget.initial != null
                  ? LatLng(widget.initial!.lat, widget.initial!.lng)
                  : _fallbackCenter,
              initialZoom: _initialZoom,
              minZoom: 3,
              maxZoom: 19,
              onMapEvent: _onMapEvent,
              // Dismiss the search dropdown when the customer taps
              // the map — feels natural.
              onTap: (_, __) {
                if (_showSuggestions) {
                  setState(() => _showSuggestions = false);
                  _searchFocus.unfocus();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ai.manasety.ahlatala',
                maxZoom: 19,
              ),
            ],
          ),
          // ───────── Center pin (fixed to viewport, not the map) ─────────
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 44, color: AppTheme.primaryContainer),
                  // Small "shadow" ellipse under the pin so it feels
                  // anchored to a specific ground point.
                  Container(
                    width: 12, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ───────── Top header (title + close + search) ─────────
          Positioned(
            top: topPad, left: 0, right: 0,
            child: _TopBar(
              searchCtrl: _searchCtrl,
              searchFocus: _searchFocus,
              onChanged: _onSearchChanged,
              onClose: () => context.pop(),
            ),
          ),
          // ───────── Search suggestions dropdown ─────────
          if (_showSuggestions)
            Positioned(
              top: topPad + 140, left: 12, right: 12,
              child: _SuggestionsList(
                items: _suggestions,
                onPick: _pickSuggestion,
              ),
            ),
          // ───────── Right-side FAB stack (zoom + current location) ─────────
          Positioned(
            top: topPad + 210, left: 12,
            child: Column(
              children: [
                _CircleFab(
                  icon: Icons.my_location,
                  onTap: _resolveCurrentLocation,
                ),
                const SizedBox(height: 8),
                _CircleFab(
                  icon: Icons.add,
                  onTap: () => _mapCtrl.move(_pinPosition, (_mapCtrl.camera.zoom + 1).clamp(3, 19)),
                ),
                const SizedBox(height: 4),
                _CircleFab(
                  icon: Icons.remove,
                  onTap: () => _mapCtrl.move(_pinPosition, (_mapCtrl.camera.zoom - 1).clamp(3, 19)),
                ),
              ],
            ),
          ),
          // ───────── Drag hint (small pill under the top bar) ─────────
          Positioned(
            top: topPad + 148, left: 0, right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalSoft.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.touch_app, size: 14, color: AppTheme.surfaceBright),
                    const SizedBox(width: 6),
                    Text('اسحب الخريطة لتغيير الموقع',
                        style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.surfaceBright)),
                  ]),
                ),
              ),
            ),
          ),
          // ───────── Bottom sticky address card + confirm ─────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomCard(
              address: _pinAddress,
              resolving: _resolvingAddress,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Top bar ═════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchCtrl,
    required this.searchFocus,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(children: [
        // Title bar
        Row(children: [
          _CircleFab(icon: Icons.help_outline, onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اسحب الخريطة أو ابحث عن الحي لتحديد موقع التوصيل')),
            );
          }),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('📍', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('اختر موقع التوصيل',
                      style: AppTheme.headline(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface)),
                ]),
              ),
            ),
          ),
          _CircleFab(icon: Icons.arrow_forward, onTap: onClose),
        ]),
        const SizedBox(height: 8),
        // Search bar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            const Icon(Icons.search, size: 20, color: AppTheme.primaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: searchCtrl,
                focusNode: searchFocus,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن حي أو معلم',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.onSurface),
              ),
            ),
            if (searchCtrl.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  searchCtrl.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close, size: 18, color: AppTheme.charcoalMuted),
                visualDensity: VisualDensity.compact,
              ),
          ]),
        ),
      ]),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.items, required this.onPick});
  final List<PlaceSuggestion> items;
  final ValueChanged<PlaceSuggestion> onPick;
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.surfaceContainerLowest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (_, i) {
            final s = items[i];
            return InkWell(
              onTap: () => onPick(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.flameDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.onSurface),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircleFab extends StatelessWidget {
  const _CircleFab({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 44,
      child: Material(
        color: AppTheme.surfaceContainerLowest,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: const Color(0x33000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 22, color: AppTheme.charcoalSoft),
        ),
      ),
    );
  }
}

// ═════════════════ Bottom card ═════════════════

class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.address,
    required this.resolving,
    required this.onConfirm,
  });
  final String address;
  final bool resolving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Icons.location_on, size: 20, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('عنوان التوصيل المختار',
                          style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Expanded(
                          child: Text(
                            resolving ? 'جارٍ قراءة العنوان...' : address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headline(size: 13, weight: FontWeight.w700, color: AppTheme.onSurface, height: 18 / 13),
                          ),
                        ),
                        if (resolving) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: resolving ? null : onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.tertiaryFixedDim,
                  disabledBackgroundColor: AppTheme.surfaceContainer,
                  foregroundColor: AppTheme.onSurface,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text('تأكيد موقع التوصيل',
                    style: AppTheme.body(size: 15, weight: FontWeight.w800, color: AppTheme.onSurface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
