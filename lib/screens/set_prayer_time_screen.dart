import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SetPrayerTimeScreen extends StatefulWidget {
  final String mosqueId;
  final String mosqueName;

  const SetPrayerTimeScreen({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
  });

  @override
  State<SetPrayerTimeScreen> createState() => _SetPrayerTimeScreenState();
}

class _SetPrayerTimeScreenState extends State<SetPrayerTimeScreen> {
  final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final Map<String, TimeOfDay?> selectedTimes = {};

  bool saving = false;
  String? errorMessage;

  /// Fixed AM / PM per prayer
  final Map<String, String> fixedMeridiem = {
    'Fajr': 'AM',
    'Dhuhr': 'PM',
    'Asr': 'PM',
    'Maghrib': 'PM',
    'Isha': 'PM',
  };

  @override
  void initState() {
    super.initState();
    for (final p in prayers) {
      selectedTimes[p] = null;
    }
    _loadExistingTimes();
  }

  // ---------------- Load Existing Data ----------------
  Future<void> _loadExistingTimes() async {
    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.mosqueId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    for (final p in prayers) {
      final raw = data[p];
      if (raw is! String) continue;

      // Extract time and AM/PM (e.g., "5:30 AM" or "12:30 PM")
      final match = RegExp(r'(\d{1,2}):(\d{2})\s+(AM|PM)').firstMatch(raw);
      if (match == null) continue;

      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      final meridiem = match.group(3);

      if (hour != null && minute != null && meridiem != null) {
        // Convert 12-hour format to 24-hour format
        int hour24 = hour;
        if (meridiem == 'PM' && hour != 12) {
          hour24 = hour + 12;
        } else if (meridiem == 'AM' && hour == 12) {
          hour24 = 0;
        }
        selectedTimes[p] = TimeOfDay(hour: hour24, minute: minute);
      }
    }

    if (mounted) setState(() {});
  }

  // ---------------- Time Picker ----------------
  Future<void> _pickTime(String prayer) async {
    final initial =
        selectedTimes[prayer] ?? const TimeOfDay(hour: 1, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedTimes[prayer] = _applyFixedMeridiem(prayer, picked);
    });
  }

  // ---------------- Enforce fixed AM / PM ----------------
  TimeOfDay _applyFixedMeridiem(String prayer, TimeOfDay time) {
    final meridiem = fixedMeridiem[prayer]!;
    int hour = time.hour;

    if (meridiem == 'AM' && hour >= 12) hour -= 12;
    if (meridiem == 'PM' && hour < 12) hour += 12;

    return TimeOfDay(hour: hour, minute: time.minute);
  }

  // ---------------- Save ----------------
  Future<void> _savePrayerTimes() async {
    for (final p in prayers) {
      if (selectedTimes[p] == null) {
        setState(() => errorMessage = 'Please set all prayer times.');
        return;
      }
    }

    setState(() {
      saving = true;
      errorMessage = null;
    });

    final Map<String, String> data = {};

    for (final p in prayers) {
      final t = selectedTimes[p]!;
      final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final minute = t.minute.toString().padLeft(2, '0');
      data[p] = '$hour12:$minute ${fixedMeridiem[p]}';
    }

    await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.mosqueId)
        .set(data, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // -------- UI HELPERS --------
  Color _getPrayerRowColor(String prayerName) {
    if (['Fajr', 'Asr', 'Isha'].contains(prayerName)) {
      return Colors.blue.shade50;
    }
    return Colors.amber.shade50;
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

  Widget _prayerRow(String prayer) {
    final time = selectedTimes[prayer];
    final isSelected = time != null;

    // Display time only if selected
    final timeDisplay = isSelected
        ? '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}'
              ':${time.minute.toString().padLeft(2, '0')} '
              '${fixedMeridiem[prayer]}'
        : '';

    return GestureDetector(
      onTap: () => _pickTime(prayer),
      child: Container(
        decoration: BoxDecoration(
          color: _getPrayerRowColor(prayer),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.orange.shade300 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Image.asset(
              _getPrayerIcon(prayer),
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Image.asset(
              'assets/icons/set-time.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.access_time,
                  size: 20,
                  color: Colors.grey.shade600,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // -------- BUILD --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        title: Text(widget.mosqueName),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final p in prayers) _prayerRow(p),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : _savePrayerTimes,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    saving ? 'Saving...' : 'Save Prayer Times',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
