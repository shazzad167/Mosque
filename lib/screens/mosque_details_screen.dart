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

  bool hasPrayerTimes = false;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => loading = true);

    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.mosque.osmId)
        .get();

    bool foundAny = false;

    if (doc.exists) {
      final data = doc.data()!;
      for (final key in prayerTimes.keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty && value != 'N/A') {
          prayerTimes[key] = value;
          foundAny = true;
        } else {
          prayerTimes[key] = 'N/A';
        }
      }
    }

    if (!mounted) return;
    setState(() {
      hasPrayerTimes = foundAny;
      loading = false;
    });
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Nearby';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

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
                  ...prayerTimes.keys.map(_prayerRow),
                  const SizedBox(height: 24),
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
                          if (saved == true) _loadPrayerTimes();
                        },
                        child: Text(
                          hasPrayerTimes
                              ? 'Update Prayer Time'
                              : 'Set Prayer Time',
                        ),
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
        children: [Text(name), Text(prayerTimes[name]!)],
      ),
    );
  }
}
