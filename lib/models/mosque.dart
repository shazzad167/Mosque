class Mosque {
  final String osmId;
  final String name;
  final double latitude;
  final double longitude;
  final String? distance;
  final String? fajr;
  final String? dhuhr;
  final String? asr;
  final String? maghrib;
  final String? isha;

  const Mosque({
    required this.osmId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.fajr,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
  });

  Mosque copyWith({
    String? osmId,
    String? name,
    double? latitude,
    double? longitude,
    String? distance,
    String? fajr,
    String? dhuhr,
    String? asr,
    String? maghrib,
    String? isha,
  }) {
    return Mosque(
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
    );
  }
}
