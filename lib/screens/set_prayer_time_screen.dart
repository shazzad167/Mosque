import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> hourControllers = {};
  final Map<String, TextEditingController> minuteControllers = {};

  final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  bool saving = false;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    for (var p in prayers) {
      hourControllers[p] = TextEditingController();
      minuteControllers[p] = TextEditingController();
    }
    _loadExistingTimes();
  }

  Future<void> _loadExistingTimes() async {
    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.osmId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      for (var p in prayers) {
        final time = data[p] ?? '';
        if (time.isNotEmpty && time.contains(':')) {
          final parts = time.split(':');
          hourControllers[p]?.text = parts[0];
          minuteControllers[p]?.text = parts[1];
        }
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _savePrayerTimes() async {
    setState(() => validationMessage = null);

    for (var p in prayers) {
      final h = hourControllers[p]!.text;
      final m = minuteControllers[p]!.text;

      if (h.isEmpty || m.isEmpty) {
        setState(() => validationMessage = 'All fields are required');
        return;
      }
      final hVal = int.tryParse(h);
      final mVal = int.tryParse(m);

      if (hVal == null ||
          hVal < 1 ||
          hVal > 12 ||
          mVal == null ||
          mVal < 0 ||
          mVal > 59) {
        setState(
          () => validationMessage = 'Hour must be 01-12 and Minute 00-59',
        );
        return;
      }
    }

    setState(() => saving = true);

    final Map<String, String> prayerData = {};
    for (var p in prayers) {
      prayerData[p] =
          '${hourControllers[p]!.text}:${minuteControllers[p]!.text}';
    }

    await FirebaseFirestore.instance
        .collection('mosque')
        .doc(widget.osmId)
        .set(prayerData, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => saving = false);
    Navigator.pop(context, true); // return true to reload
  }

  Widget _timeRow(String prayer) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: TextFormField(
            controller: hourControllers[prayer],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'HH'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':'),
        ),
        SizedBox(
          width: 60,
          child: TextFormField(
            controller: minuteControllers[prayer],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'MM'),
          ),
        ),
        const SizedBox(width: 10),
        Text(prayer),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Prayer Time - ${widget.mosqueName}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                for (var p in prayers) ...[
                  _timeRow(p),
                  const SizedBox(height: 16),
                ],
                if (validationMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      validationMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: saving ? null : _savePrayerTimes,
                    child: saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
