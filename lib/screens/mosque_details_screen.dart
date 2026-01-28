import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mosque.dart';
import 'set_prayer_time_screen.dart';

class MosqueDetailsScreen extends StatefulWidget {
  final Mosque mosque;
  final bool isAuthorized;

  const MosqueDetailsScreen({
    super.key,
    required this.mosque,
    required this.isAuthorized,
  });

  @override
  State<MosqueDetailsScreen> createState() => _MosqueDetailsScreenState();
}

class _MosqueDetailsScreenState extends State<MosqueDetailsScreen> {
  bool loading = true;

  final Map<String, String> prayerTimes = {
    'Fajr': 'N/A',
    'Dhuhr': 'N/A',
    'Asr': 'N/A',
    'Maghrib': 'N/A',
    'Isha': 'N/A',
  };

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
  }

  // ---------------- LOAD PRAYER TIMES ----------------

  Future<void> _loadPrayerTimes() async {
    setState(() => loading = true);

    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.mosque.osmId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      prayerTimes['Fajr'] = data['Fajr'] ?? 'N/A';
      prayerTimes['Dhuhr'] = data['Dhuhr'] ?? 'N/A';
      prayerTimes['Asr'] = data['Asr'] ?? 'N/A';
      prayerTimes['Maghrib'] = data['Maghrib'] ?? 'N/A';
      prayerTimes['Isha'] = data['Isha'] ?? 'N/A';
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  // ---------------- DISTANCE FORMAT ----------------

  String _formatDistance(double? meters) {
    if (meters == null) return 'Nearby';

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mosque.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📍 DISTANCE
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Distance: ${_formatDistance(widget.mosque.distanceMeters)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Jamaat Prayer Times',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  _prayerRow('Fajr'),
                  _prayerRow('Dhuhr'),
                  _prayerRow('Asr'),
                  _prayerRow('Maghrib'),
                  _prayerRow('Isha'),

                  const SizedBox(height: 24),

                  // 🔐 ADMIN ONLY
                  if (widget.isAuthorized)
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          final saved = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SetPrayerTimeScreen(
                                osmId: widget.mosque.osmId,
                                mosqueName: widget.mosque.name,
                              ),
                            ),
                          );

                          if (saved == true) {
                            _loadPrayerTimes(); // 🔄 AUTO RELOAD
                          }
                        },
                        child: const Text('Set Prayer Time'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _prayerRow(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(name), Text(prayerTimes[name] ?? 'N/A')],
      ),
    );
  }
}
