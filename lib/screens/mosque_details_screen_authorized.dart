import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mosque.dart';
import 'set_prayer_time_screen.dart';

class MosqueDetailsScreenAuthorized extends StatefulWidget {
  final Mosque mosque;

  const MosqueDetailsScreenAuthorized({super.key, required this.mosque});

  @override
  State<MosqueDetailsScreenAuthorized> createState() =>
      _MosqueDetailsScreenAuthorizedState();
}

class _MosqueDetailsScreenAuthorizedState
    extends State<MosqueDetailsScreenAuthorized> {
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

    // 🔹 Firestore document ID (OSM completely removed)
    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.mosque.id)
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

  String _getPrayerIcon(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return 'assets/icons/fajr.png';
      case 'Dhuhr':
        return 'assets/icons/dhuhr.png';
      case 'Asr':
        return 'assets/icons/asr.png';
      case 'Maghrib':
        return 'assets/icons/maghrib.png';
      case 'Isha':
        return 'assets/icons/isha.png';
      default:
        return 'assets/icons/mosque_marker.png';
    }
  }

  Color _getPrayerRowColor(String prayerName) {
    if (['Fajr', 'Asr', 'Isha'].contains(prayerName)) {
      return Colors.blue.shade50;
    }
    return Colors.amber.shade50;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.green.shade600, elevation: 0),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------- MOSQUE INFO CARD --------
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mosque,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.mosque.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.orange.shade300,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDistance(
                                        widget.mosque.distanceMeters,
                                      ),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade100,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // -------- PRAYER TIMES TITLE --------
                    const Text(
                      'Jamaat Prayer Times',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // -------- PRAYER TIMES LIST --------
                    ...prayerTimes.keys.map(_prayerRow),
                    const SizedBox(height: 16),

                    // -------- SET / UPDATE PRAYER TIME --------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final saved = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SetPrayerTimeScreen(
                                mosqueId: widget.mosque.id,
                                mosqueName: widget.mosque.name,
                              ),
                            ),
                          );
                          if (saved == true) _loadPrayerTimes();
                        },
                        icon: Image.asset(
                          'assets/icons/set-time.png',
                          width: 20,
                          height: 20,
                          color: Colors.white,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.white,
                            );
                          },
                        ),
                        label: Text(
                          hasPrayerTimes
                              ? 'Update Prayer Time'
                              : 'Set Prayer Time',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _prayerRow(String name) {
    final time = prayerTimes[name]!;
    final isAvailable = time != 'N/A';
    final rowColor = _getPrayerRowColor(name);

    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAvailable ? Colors.orange.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isAvailable
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              _getPrayerIcon(name),
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isAvailable ? Colors.orange.shade700 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
