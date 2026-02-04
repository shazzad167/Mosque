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

  // -------- HELPER: Get prayer row color --------
  Color _getPrayerRowColor(String prayerName) {
    if (['Fajr', 'Asr', 'Isha'].contains(prayerName)) {
      return Colors.blue.shade50;
    }
    return Colors.amber.shade50;
  }

  // -------- HELPER: Get prayer icon --------
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

  // -------- PRAYER ROW BUILDER --------
  Widget _prayerRow(String prayer) {
    final time = selectedTimes[prayer];
    final label = time == null
        ? 'Select time'
        : '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}'
              ':${time.minute.toString().padLeft(2, '0')} '
              '${fixedMeridiem[prayer]}';

    final rowColor = _getPrayerRowColor(prayer);
    final isSelected = time != null;

    return GestureDetector(
      onTap: () => _pickTime(prayer),
      child: Container(
        decoration: BoxDecoration(
          color: rowColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.orange.shade300 : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            // -------- PRAYER ICON --------
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.shade200
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                _getPrayerIcon(prayer),
                width: 32,
                height: 32,
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
                    prayer,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.orange.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // -------- CLOCK ICON --------
            Icon(
              Icons.schedule_rounded,
              color: isSelected ? Colors.orange.shade600 : Colors.grey.shade400,
              size: 22,
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
        elevation: 0,
        title: Text(widget.mosqueName),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -------- HEADER CARD --------
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400],
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
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Set Prayer Times',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure all five daily prayers',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // -------- PRAYER TIMES TITLE --------
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Jamaat Prayer Times',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // -------- PRAYER ROWS --------
                for (final p in prayers) _prayerRow(p),

                // -------- ERROR MESSAGE --------
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // -------- SAVE BUTTON --------
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : _savePrayerTimes,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_rounded),
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
