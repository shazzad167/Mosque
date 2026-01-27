import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'set_prayer_time_screen.dart';

class MosqueDetailsScreen extends StatefulWidget {
  final String osmId;
  final String mosqueName;
  final bool isAdmin;

  const MosqueDetailsScreen({
    super.key,
    required this.osmId,
    required this.mosqueName,
    this.isAdmin = false,
  });

  @override
  State<MosqueDetailsScreen> createState() => _MosqueDetailsScreenState();
}

class _MosqueDetailsScreenState extends State<MosqueDetailsScreen> {
  Map<String, String> prayerTimes = {
    'Fajr': 'N/A',
    'Dhuhr': 'N/A',
    'Asr': 'N/A',
    'Maghrib': 'N/A',
    'Isha': 'N/A',
  };

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.osmId)
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

  Widget _prayerRow(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(name), Text(prayerTimes[name] ?? 'N/A')],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mosqueName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mosque ID: ${widget.osmId}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jamaat Prayer Times',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _prayerRow('Fajr'),
                  _prayerRow('Dhuhr'),
                  _prayerRow('Asr'),
                  _prayerRow('Maghrib'),
                  _prayerRow('Isha'),
                  const SizedBox(height: 20),
                  if (widget.isAdmin)
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SetPrayerTimeScreen(
                                osmId: widget.osmId,
                                mosqueName: widget.mosqueName,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadPrayerTimes(); // reload after save
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
}
