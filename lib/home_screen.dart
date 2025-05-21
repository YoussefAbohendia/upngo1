import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'navigation_drawer.dart';
import 'auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _greeting = '';
  String? _userName;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _alarms = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _loadUserData();
    _setGreeting();
    _loadMockAlarms(); // For demo purposes
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
          _userName = userData?['display_name'] ?? 'there';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'there';
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

  void _loadMockAlarms() {
    // Mock data for demo purposes
    setState(() {
      _alarms.addAll([
        {
          'id': '1',
          'title': 'Work Day',
          'time': '07:00',
          'days': [1, 2, 3, 4, 5],
          'active': true,
          'vibrate': true,
          'sound': 'Gentle Rise',
          'snooze_duration': 5,
        },
        {
          'id': '2',
          'title': 'Weekend',
          'time': '08:30',
          'days': [6, 7],
          'active': true,
          'vibrate': true,
          'sound': 'Morning Birds',
          'snooze_duration': 10,
        },
        {
          'id': '3',
          'title': 'Gym',
          'time': '06:00',
          'days': [2, 4, 6],
          'active': false,
          'vibrate': true,
          'sound': 'Energetic',
          'snooze_duration': 5,
        },
      ]);
    });
  }

  String _formatTime(String time) {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = timeParts[1];

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
                // Greeting section
                Text(
                  '$_greeting, $_userName!',
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

                // Next alarm section
                _buildNextAlarmCard(),

                const SizedBox(height: 24),

                // Alarms section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Alarms',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to create new alarm
                        Navigator.pushNamed(context, '/alarms/create');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Alarm'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Alarm list
                ..._alarms.map((alarm) => _buildAlarmCard(alarm)).toList(),

                const SizedBox(height: 24),

                // Sleep stats summary
                _buildSleepStatsSummary(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextAlarmCard() {
    // Find the next active alarm
    final now = DateTime.now();
    final today = now.weekday;

    Map<String, dynamic>? nextAlarm;
    int? daysUntilNextAlarm;

    for (final alarm in _alarms) {
      if (!alarm['active']) continue;

      final alarmDays = List<int>.from(alarm['days']);
      if (alarmDays.isEmpty) continue;

      for (int i = 0; i < 7; i++) {
        final checkDay = (today + i) % 7;
        final actualCheckDay = checkDay == 0 ? 7 : checkDay; // Convert 0 to 7 for Sunday

        if (alarmDays.contains(actualCheckDay)) {
          // Parse alarm time
          final timeParts = alarm['time'].split(':');
          final alarmHour = int.parse(timeParts[0]);
          final alarmMinute = int.parse(timeParts[1]);

          final alarmDateTime = DateTime(
            now.year,
            now.month,
            now.day + i,
            alarmHour,
            alarmMinute,
          );

          // Check if alarm is later today or in the future
          if (i > 0 || (i == 0 && alarmDateTime.isAfter(now))) {
            if (nextAlarm == null || i < daysUntilNextAlarm!) {
              nextAlarm = alarm;
              daysUntilNextAlarm = i;
            }
            break;
          }
        }
      }
    }

    if (nextAlarm == null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 36,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Active Alarms',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Tap "Add Alarm" to set a wake-up time',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    String timeUntilText;
    if (daysUntilNextAlarm == 0) {
      timeUntilText = 'Today';
    } else if (daysUntilNextAlarm == 1) {
      timeUntilText = 'Tomorrow';
    } else {
      final nextAlarmDay = (today + daysUntilNextAlarm!) % 7;
      final actualNextAlarmDay = nextAlarmDay == 0 ? 7 : nextAlarmDay;
      final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      timeUntilText = dayNames[actualNextAlarmDay];
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.alarm,
                size: 36,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Alarm',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(nextAlarm['time']),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$timeUntilText | ${nextAlarm['title']}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                        color: alarm['active'] ? Theme.of(context).textTheme.titleLarge?.color : Colors.grey,
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
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepStatsSummary() {
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
                  '7.3',
                  'hrs',
                  'avg. sleep',
                  Icons.nightlight_round,
                ),
                _buildSleepStat(
                  context,
                  '87%',
                  '',
                  'efficiency',
                  Icons.auto_graph,
                ),
                _buildSleepStat(
                  context,
                  '1.2',
                  'x',
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

    // Parse time
    final timeParts = widget.alarm['time'].split(':');
    _selectedTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    // Set selected days
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
        _editedAlarm['time'] = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _toggleDay(int index) {
    setState(() {
      _selectedDays[index] = !_selectedDays[index];

      // Update the days list in edited alarm
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

            // Time picker section
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

            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Alarm Title',
                prefixIcon: Icon(Icons.label),
              ),
            ),

            const SizedBox(height: 24),

            // Days of week
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

            // Additional settings
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
                // Show sound selection dialog (not implemented)
              },
            ),

            ListTile(
              title: const Text('Snooze duration'),
              subtitle: Text('${_editedAlarm['snooze_duration']} min'),
              leading: const Icon(Icons.snooze),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show snooze duration selection dialog (not implemented)
              },
            ),

            const SizedBox(height: 32),

            // Save button
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

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}