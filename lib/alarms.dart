import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({Key? key}) : super(key: key);

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  List<Map<String, dynamic>> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlarms();
  }

  Future<void> _fetchAlarms() async {
    setState(() => _isLoading = true);
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) throw Exception('No user logged in');

      final response = await Supabase.instance.client
          .from('alarms')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _alarms = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading alarms: $e')),
      );
    }
  }

  Future<void> _deleteAlarm(dynamic alarmId) async {
    try {
      await Supabase.instance.client
          .from('alarms')
          .delete()
          .eq('id', alarmId);

      if (mounted) {
        setState(() {
          _alarms.removeWhere((alarm) => alarm['id'] == alarmId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm deleted!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete alarm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(String? time24) {
    if (time24 == null) return '--:--';
    try {
      final parts = time24.split(':');
      final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      return time.format(context);
    } catch (_) {
      return time24;
    }
  }

  String _repeatDaysString(dynamic repeatDays) {
    if (repeatDays == null) return 'None';
    if (repeatDays is List) {
      if (repeatDays.isEmpty) return 'None';
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
      const weekends = ['Sat', 'Sun'];
      if (repeatDays.length == 5 && weekdays.every(repeatDays.contains)) return 'Weekdays';
      if (repeatDays.length == 2 && weekends.every(repeatDays.contains)) return 'Weekends';
      return repeatDays.join(', ');
    }
    if (repeatDays is String) return repeatDays;
    return 'None';
  }

  void _showEditAlarmDialog(BuildContext context, Map<String, dynamic> alarm) {
    final _labelController = TextEditingController(text: alarm['trip_name'] ?? '');
    final _timeController = TextEditingController(text: alarm['alarm_time'] ?? '');
    final _locationController = TextEditingController(text: alarm['location'] ?? '');
    List<String> _repeatDays = alarm['repeat_days'] is List
        ? List<String>.from(alarm['repeat_days'])
        : (alarm['repeat_days']?.toString().split(',') ?? []);
    bool _vibrate = alarm['vibrate'] ?? false;
    String _sound = alarm['sound'] ?? '';
    int _snoozeDuration = alarm['snooze_duration'] ?? 5;

    TimeOfDay? selectedTime;
    try {
      if (alarm['alarm_time'] != null) {
        final parts = alarm['alarm_time'].split(':');
        selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Alarm'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Time picker
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      selectedTime = time;
                      _timeController.text = time.format(context);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                    ),
                  ),
                ),
                // Alarm label (trip name)
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Alarm Title',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.place),
                  ),
                ),
                const SizedBox(height: 8),
                // Repeat Days
                TextFormField(
                  initialValue: _repeatDays.join(','),
                  decoration: const InputDecoration(
                    labelText: 'Repeat Days (comma separated, e.g. Mon,Tue)',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  onChanged: (val) {
                    _repeatDays = val
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                  },
                ),
                SwitchListTile(
                  title: const Text('Vibrate'),
                  value: _vibrate,
                  onChanged: (val) => setState(() => _vibrate = val),
                  secondary: const Icon(Icons.vibration),
                ),
                // Sound
                TextFormField(
                  initialValue: _sound,
                  decoration: const InputDecoration(
                    labelText: 'Sound',
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  onChanged: (val) => _sound = val,
                ),
                // Snooze
                TextFormField(
                  initialValue: _snoozeDuration.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Snooze Duration (min)',
                    prefixIcon: Icon(Icons.snooze),
                  ),
                  onChanged: (val) => _snoozeDuration = int.tryParse(val) ?? 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final newTime = selectedTime != null
                    ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                    : _timeController.text;
                await Supabase.instance.client
                    .from('alarms')
                    .update({
                  'trip_name': _labelController.text,
                  'alarm_time': newTime,
                  'location': _locationController.text,
                  'repeat_days': _repeatDays,
                  'vibrate': _vibrate,
                  'sound': _sound,
                  'snooze_duration': _snoozeDuration,
                })
                    .eq('id', alarm['id']);
                Navigator.pop(context);
                _fetchAlarms();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alarm updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Alarms'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No alarms set', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Tap "Create Alarm" below to add your first alarm.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alarms.length,
        itemBuilder: (context, index) {
          final alarm = _alarms[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showEditAlarmDialog(context, alarm),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.alarm, color: Theme.of(context).primaryColor, size: 28),
                            const SizedBox(width: 10),
                            Text(_formatTime(alarm['alarm_time']),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              tooltip: "Edit Alarm",
                              onPressed: () => _showEditAlarmDialog(context, alarm),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Delete Alarm",
                              onPressed: () => _deleteAlarm(alarm['id']),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alarm['trip_name'] ?? 'Alarm',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (alarm['location'] != null && (alarm['location'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place, color: Colors.teal, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            alarm['location'],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 20, color: Theme.of(context).primaryColor.withOpacity(0.7)),
                        const SizedBox(width: 8),
                        Text(
                          "Repeat: ${_repeatDaysString(alarm['repeat_days'])}",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (alarm['vibrate'] != null)
                      Row(
                        children: [
                          Icon(Icons.vibration, size: 20, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text("Vibrate: ${alarm['vibrate'] == true ? 'On' : 'Off'}"),
                        ],
                      ),
                    if (alarm['sound'] != null)
                      Row(
                        children: [
                          Icon(Icons.music_note, size: 20, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text("Sound: ${alarm['sound']}"),
                        ],
                      ),
                    if (alarm['snooze_duration'] != null)
                      Row(
                        children: [
                          Icon(Icons.snooze, size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Text("Snooze: ${alarm['snooze_duration']} min"),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "createAlarm",
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/alarms/create');
              if (result == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alarm created successfully! 🎉'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  _fetchAlarms();
                }
              }
            },
            icon: const Icon(Icons.add_alarm),
            label: const Text('Create Alarm'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "goHome",
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
            icon: const Icon(Icons.home),
            label: const Text('Home'),
            backgroundColor: Colors.blueGrey,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
//