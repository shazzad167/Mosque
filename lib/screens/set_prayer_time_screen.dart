import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SetPrayerTimeScreen extends StatefulWidget {
  final String osmId;
  final String mosqueName;

  const SetPrayerTimeScreen({
    super.key,
    required this.osmId,
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

  /// Fixed AM / PM per prayer (user never selects this)
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

  // ---------------- Load Existing Data (robust) ----------------
  Future<void> _loadExistingTimes() async {
    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.osmId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    for (final p in prayers) {
      final raw = data[p];
      if (raw is! String) continue;

      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
      if (match == null) continue;

      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);

      if (hour != null && minute != null) {
        selectedTimes[p] = TimeOfDay(hour: hour % 24, minute: minute);
      }
    }

    if (mounted) setState(() {});
  }

  // ---------------- Time Picker (1–12 only, no AM/PM UI) ----------------
  Future<void> _pickTime(String prayer) async {
    final initial =
        selectedTimes[prayer] ?? const TimeOfDay(hour: 1, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false, // 🔑 forces 1–12 UI
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedTimes[prayer] = _applyFixedMeridiem(prayer, picked);
    });
  }

  // ---------------- Enforce fixed AM / PM silently ----------------
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
        .doc(widget.osmId)
        .set(data, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ---------------- UI Row ----------------
  Widget _prayerRow(String prayer) {
    final time = selectedTimes[prayer];
    final label = time == null
        ? 'Select time'
        : '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}'
              ':${time.minute.toString().padLeft(2, '0')} '
              '${fixedMeridiem[prayer]}';

    return ListTile(
      title: Text(prayer),
      subtitle: Text(label),
      trailing: Image.asset('assets/icons/set-time.png', width: 26, height: 26),
      onTap: () => _pickTime(prayer),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mosqueName)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final p in prayers) _prayerRow(p),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),

          /// ✅ FIXED: SafeArea prevents nav-bar overlap
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: saving ? null : _savePrayerTimes,
                  child: saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
