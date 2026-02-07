class Mosque {
  final String id; // Can be Firestore Doc ID OR Google Place ID
  final String name;
  final String address; // New: Google gives address, very useful to show
  final double latitude;
  final double longitude;

  // Prayer times (nullable because Google won't have them initially)
  final String? fajr;
  final String? dhuhr;
  final String? asr;
  final String? maghrib;
  final String? isha;

  final double? distanceMeters;
  final bool isFromGoogle; // New: Helps you identify the source in UI

  Mosque({
    required this.id,
    required this.name,
    this.address = '', // Default to empty if not found
    required this.latitude,
    required this.longitude,
    this.fajr,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
    this.distanceMeters,
    this.isFromGoogle = false, // Defaults to false (Firestore)
  });
}
