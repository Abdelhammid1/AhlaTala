import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Thin wrapper around the free Nominatim REST endpoints hosted by
/// OpenStreetMap. Two calls only:
///
///   • **reverse(lat, lng)**  — `lat, lng → عنوان مقروء`, used when
///     the customer drops / drags the pin on the map.
///   • **search(query)**      — `نص → قائمة اقتراحات`, used by the
///     picker's search bar (debounced 400 ms).
///
/// OpenStreetMap's usage policy for the public Nominatim endpoint
/// requires:
///   1. A real `User-Agent` (an anonymous request is rate-limited hard).
///      → we send `AhlaTolla/1.0 (customer@ahlatolla.com)`.
///   2. At most **one request per second**.
///      → this service serialises through an internal 1s throttle
///        (Duration between the last-fired request and the next).
///   3. No heavy production traffic.
///      → fine for MVP customer picking; when we outgrow it, either
///        self-host Nominatim (docker image) or switch to a paid
///        provider (Google, Mapbox, MapTiler).
class GeocodingService {
  GeocodingService(this._client);
  final http.Client _client;

  // Public Nominatim endpoint.
  static const String _base = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'AhlaTolla/1.0 (customer@ahlatolla.com)';

  DateTime _lastRequestAt = DateTime.fromMicrosecondsSinceEpoch(0);
  static const Duration _minGap = Duration(seconds: 1);

  /// Wait until at least [_minGap] has elapsed since the last request.
  Future<void> _throttle() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestAt);
    if (elapsed < _minGap) {
      await Future.delayed(_minGap - elapsed);
    }
    _lastRequestAt = DateTime.now();
  }

  /// Reverse-geocode a coordinate to a human-readable Arabic address.
  /// Returns null on network error or empty response.
  Future<String?> reverse(double lat, double lng) async {
    await _throttle();
    try {
      final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
        'format': 'jsonv2',
        'lat': lat.toString(),
        'lon': lng.toString(),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'ar',
      });
      final res = await _client.get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body);
      if (data is Map && data['display_name'] is String) {
        return (data['display_name'] as String).trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Search the world for [query] biased toward Saudi Arabia (we cap
  /// `countrycodes=sa` so the search returns local matches first). Up
  /// to 8 suggestions returned.
  Future<List<PlaceSuggestion>> search(String query) async {
    if (query.trim().length < 2) return const [];
    await _throttle();
    try {
      final uri = Uri.parse('$_base/search').replace(queryParameters: {
        'format': 'jsonv2',
        'q': query,
        'countrycodes': 'sa',
        'limit': '8',
        'addressdetails': '1',
        'accept-language': 'ar',
      });
      final res = await _client.get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body);
      if (data is! List) return const [];
      return data.map((r) {
        final m = r as Map<String, dynamic>;
        return PlaceSuggestion(
          displayName: (m['display_name'] as String?)?.trim() ?? '',
          lat: double.tryParse(m['lat']?.toString() ?? '') ?? 0,
          lng: double.tryParse(m['lon']?.toString() ?? '') ?? 0,
        );
      }).where((p) => p.displayName.isNotEmpty && p.lat != 0 && p.lng != 0).toList();
    } catch (_) {
      return const [];
    }
  }
}

/// One row in the search-suggestion dropdown.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
  final String displayName;
  final double lat;
  final double lng;
}

final _httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(ref.watch(_httpClientProvider));
});
