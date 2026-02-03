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
                    const SizedBox(height: 24),

                    // -------- PRAYER TIMES TITLE --------
                    Text(
                      'Jamaat Prayer Times',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------- PRAYER TIMES GRID --------
                    ...prayerTimes.keys.map(_prayerCard),
                    const SizedBox(height: 24),

                    // -------- UPDATE/SET PRAYER TIME BUTTON --------
                    if (widget.isAuthorized)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
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
                            icon: Image.asset(
                              'assets/icons/set-time.png',
                              width: 20,
                              height: 20,
                              color: Colors.white,
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
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _prayerCard(String name) {
    final time = prayerTimes[name]!;
    final isAvailable = time != 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable ? Colors.orange.shade300 : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // -------- PRAYER ICON --------
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isAvailable
                    ? Colors.orange.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                _getPrayerIcon(name),
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 14),

            // -------- PRAYER NAME & TIME --------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? Colors.orange.shade700 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // -------- STATUS INDICATOR --------
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAvailable
                    ? Colors.orange.shade600
                    : Colors.grey.shade400,
                boxShadow: isAvailable
                    ? [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
