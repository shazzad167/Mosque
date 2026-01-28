class Mosque {
  final String osmId;
  final String name;
  final double latitude;
  final double longitude;

  final String? fajr;
  final String? dhuhr;
  final String? asr;
  final String? maghrib;
  final String? isha;

  final double? distanceMeters; // ✅ NEW

  Mosque({
    required this.osmId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.fajr,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
    this.distanceMeters,
  });
}
