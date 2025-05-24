import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'navigation_drawer.dart';
import 'auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Future<void> ensureUserProfileExists() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'email': user.email,
      });
    }
  }

  late AnimationController _animationController;
  String _greeting = '';
  String? _userName;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _alarms = [];

  // ALARM RINGING LOGIC VARS
  Timer? _alarmTimer;
  final AudioPlayer _alarmPlayer = AudioPlayer();
  Set<String> _rungAlarmIdsToday = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    ensureUserProfileExists();
    _loadUserData();
    _setGreeting();
    _loadAlarmsFromSupabase();
    _startAlarmCheck(); // <-- Start alarm checking
  }

  void _startAlarmCheck() {
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkAndRingAlarms());
  }

  void _checkAndRingAlarms() async {
    final now = DateTime.now();
    for (var alarm in _alarms) {
      if (!(alarm['active'] ?? true)) continue;

      String timeString = alarm['time'];
      final parts = timeString.split(':');
      int hour = int.tryParse(parts[0]) ?? 0;
      int minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final alarmTime = DateTime(now.year, now.month, now.day, hour, minute);

      // Only ring if not already rung, and within the current minute
      final alarmId = alarm['id'].toString();
      if (!_rungAlarmIdsToday.contains(alarmId) &&
          now.difference(alarmTime).inSeconds >= 0 &&
          now.difference(alarmTime).inSeconds < 60) {
        _rungAlarmIdsToday.add(alarmId);
        _ringAlarm(alarm);
      }
      // Clear rung alarms at midnight
      if (now.hour == 0 && now.minute == 0 && _rungAlarmIdsToday.isNotEmpty) {
        _rungAlarmIdsToday.clear();
      }
    }
  }

  Future<void> _ringAlarm(Map<String, dynamic> alarm) async {
    await _alarmPlayer.play(AssetSource('alarm_sound.mp3'));
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Alarm: ${alarm['title']}'),
          content: Text('It\'s time!'),
          actions: [
            TextButton(
              onPressed: () {
                _alarmPlayer.stop();
                Navigator.of(ctx).pop();
              },
              child: Text('Stop'),
            ),
          ],
        ),
      );
    }
  }

  void reloadAlarms() {
    _loadAlarmsFromSupabase();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await AuthService.getCurrentUserId();

      if (userId != null) {
        final userData = await AuthService.getUserProfile(userId);
        setState(() {
          _userName = userData?['display_name'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _userName = 'there';
        _isLoading = false;
      });
    }
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greeting = 'Good Morning';
      } else if (hour < 17) {
        _greeting = 'Good Afternoon';
      } else {
        _greeting = 'Good Evening';
      }
    });
  }

  Future<void> _loadAlarmsFromSupabase() async {
    setState(() {
      _alarms.clear();
      _isLoading = true;
    });

    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('alarms')
          .select()
          .eq('user_id', userId);

      final mapped = List<Map<String, dynamic>>.from(data).map((alarm) {
        return {
          'id': alarm['id'],
          'title': alarm['trip_name'] ?? 'Alarm',
          'time': alarm['alarm_time'] ?? '--:--',
          'days': (alarm['repeat_days'] is List)
              ? List<int>.from(alarm['repeat_days'])
              : (alarm['repeat_days'] is String && alarm['repeat_days'].isNotEmpty)
              ? alarm['repeat_days']
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 0)
              .where((e) => e > 0)
              .toList()
              : <int>[],
          'active': alarm['enabled'] ?? true,
          'vibrate': alarm['vibrate'] ?? false,
          'sound': alarm['sound'] ?? '',
          'snooze_duration': alarm['snooze_duration'] ?? 5,
        };
      }).toList();

      setState(() {
        _alarms.addAll(mapped);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading alarms: $e');
    }
  }

  String _formatTime(String time) {
    final timeParts = time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatDays(List<dynamic> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 0) return 'Never';
    if (days.length == 5 && days.contains(1) && days.contains(2) &&
        days.contains(3) && days.contains(4) && days.contains(5)) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }

    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((day) => dayNames[day]).join(', ');
  }

  void _showEditAlarmBottomSheet(Map<String, dynamic> alarm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditAlarmBottomSheet(
        alarm: alarm,
        onSave: (updatedAlarm) {
          setState(() {
            final index = _alarms.indexWhere((a) => a['id'] == updatedAlarm['id']);
            if (index != -1) {
              _alarms[index] = updatedAlarm;
            }
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _alarmTimer?.cancel();
    _alarmPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UpNGo'),
      ),
      drawer: const AppDrawer(currentRoute: '/home'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
        opacity: _animationController,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting $_userName',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  color: Colors.deepPurple.shade50,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pushNamed(context, '/alarms/create'),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Icon(Icons.notifications_active_outlined , color: Colors.deepPurple, size: 32),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alarms',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                    )),
                                const SizedBox(height: 3),
                                Text('Tap here or "Add Alarm" to set a wake-up time',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Alarms',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._alarms.map((alarm) => _buildAlarmCard(alarm)).toList(),
                const SizedBox(height: 24),
                _buildSleepStatsSummary(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ALARM CARD WIDGET
  Widget _buildAlarmCard(Map<String, dynamic> alarm) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () => _showEditAlarmBottomSheet(alarm),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTime(alarm['time']),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: alarm['active']
                            ? Theme.of(context).textTheme.titleLarge?.color
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarm['title'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: alarm['active'] ? Colors.grey.shade700 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDays(alarm['days']),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: alarm['active'] ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm['active'],
                onChanged: (value) {
                  setState(() {
                    alarm['active'] = value;
                  });
                  // Optionally update Supabase
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SLEEP STATS SUMMARY WIDGET
  Widget _buildSleepStatsSummary() {
    final totalAlarms = _alarms.length;
    final avgSnooze = _alarms.isNotEmpty
        ? (_alarms.map((a) => a['snooze_duration'] ?? 0).reduce((a, b) => a + b) / totalAlarms).toStringAsFixed(1)
        : '0.0';
    final efficiency = _alarms.isNotEmpty
        ? '${(100 * _alarms.where((a) => a['active']).length / totalAlarms).toStringAsFixed(0)}%'
        : '--';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sleep Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/history');
                  },
                  child: const Text('View History'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSleepStat(
                  context,
                  totalAlarms.toString(),
                  '',
                  'alarms',
                  Icons.alarm,
                ),
                _buildSleepStat(
                  context,
                  efficiency,
                  '',
                  'enabled',
                  Icons.auto_graph,
                ),
                _buildSleepStat(
                  context,
                  avgSnooze,
                  ' min',
                  'avg. snooze',
                  Icons.snooze,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepStat(
      BuildContext context,
      String value,
      String unit,
      String label,
      IconData icon,
      ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 28,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ===========================
// EditAlarmBottomSheet Widget
// ===========================

class EditAlarmBottomSheet extends StatefulWidget {
  final Map<String, dynamic> alarm;
  final Function(Map<String, dynamic>) onSave;

  const EditAlarmBottomSheet({
    Key? key,
    required this.alarm,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditAlarmBottomSheet> createState() => _EditAlarmBottomSheetState();
}

class _EditAlarmBottomSheetState extends State<EditAlarmBottomSheet> {
  late Map<String, dynamic> _editedAlarm;
  late TextEditingController _titleController;
  late TimeOfDay _selectedTime;
  final List<bool> _selectedDays = List.generate(7, (_) => false);

  @override
  void initState() {
    super.initState();
    _editedAlarm = Map.from(widget.alarm);
    _titleController = TextEditingController(text: widget.alarm['title']);

    final timeParts = widget.alarm['time'].split(':');
    _selectedTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final days = List<int>.from(widget.alarm['days']);
    for (int i = 0; i < 7; i++) {
      int dayIndex = i + 1;
      if (dayIndex > 7) dayIndex = 1;
      _selectedDays[i] = days.contains(dayIndex);
    }
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _editedAlarm['time'] =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _toggleDay(int index) {
    setState(() {
      _selectedDays[index] = !_selectedDays[index];

      final List<int> days = [];
      for (int i = 0; i < 7; i++) {
        if (_selectedDays[i]) {
          int dayIndex = i + 1;
          if (dayIndex > 7) dayIndex = 1;
          days.add(dayIndex);
        }
      }
      _editedAlarm['days'] = days;
    });
  }

  void _saveAlarm() {
    _editedAlarm['title'] = _titleController.text.isNotEmpty
        ? _titleController.text
        : 'Alarm';

    widget.onSave(_editedAlarm);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Alarm',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Alarm Title',
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Repeat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDayToggle(0, 'M'),
                _buildDayToggle(1, 'T'),
                _buildDayToggle(2, 'W'),
                _buildDayToggle(3, 'T'),
                _buildDayToggle(4, 'F'),
                _buildDayToggle(5, 'S'),
                _buildDayToggle(6, 'S'),
              ],
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Vibrate'),
              value: _editedAlarm['vibrate'],
              onChanged: (value) {
                setState(() {
                  _editedAlarm['vibrate'] = value;
                });
              },
            ),
            ListTile(
              title: const Text('Sound'),
              subtitle: Text(_editedAlarm['sound']),
              leading: const Icon(Icons.music_note),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Not implemented
              },
            ),
            ListTile(
              title: const Text('Snooze duration'),
              subtitle: Text('${_editedAlarm['snooze_duration']} min'),
              leading: const Icon(Icons.snooze),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Not implemented
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAlarm,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save Alarm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayToggle(int index, String label) {
    return GestureDetector(
      onTap: () => _toggleDay(index),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: _selectedDays[index]
            ? Theme.of(context).primaryColor
            : Colors.grey.shade300,
        child: Text(
          label,
          style: TextStyle(
            color: _selectedDays[index] ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
