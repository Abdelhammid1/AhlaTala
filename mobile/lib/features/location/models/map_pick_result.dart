/// What the map picker returns when the customer taps "تأكيد الموقع".
///
/// [formatted] is the Nominatim-reverse-geocoded line ("حي القادسية،
/// شارع فهد، تبوك، السعودية") — safe to write into
/// SavedAddress.formattedAddress verbatim. Callers can also break it
/// into parts (via `split(', ')`) if they need to seed district/city
/// hints separately.
class MapPickResult {
  const MapPickResult({
    required this.lat,
    required this.lng,
    required this.formatted,
  });
  final double lat;
  final double lng;
  final String formatted;
}
