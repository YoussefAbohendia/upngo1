import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'navigation_drawer.dart';
import 'create_travel_alarm_screen.dart';

class CreateAlarmScreen extends StatefulWidget {
  const CreateAlarmScreen({Key? key}) : super(key: key);

  @override
  State<CreateAlarmScreen> createState() => _CreateAlarmScreenState();
}

class _CreateAlarmScreenState extends State<CreateAlarmScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Alarm'),
      ),
      drawer: const AppDrawer(currentRoute: '/alarms/create'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Alarm Type',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildAlarmTypeCard(
              context,
              title: "up'Ngo Alarm",
              description: 'Set a wake-up alarm based on your travel destination and arrival time.',
              icon: Icons.map,
              onTap: () => _navigateToTravelAlarmCreation(context),
            ),
            const SizedBox(height: 16),
            _buildAlarmTypeCard(
              context,
              title: 'Smart Alarm',
              description: 'Let the app determine the optimal wake-up time based on your sleep cycle.',
              icon: Icons.auto_awesome,
              onTap: () => _showComingSoonDialog(context),
              isDisabled: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmTypeCard(
      BuildContext context, {
        required String title,
        required String description,
        required IconData icon,
        required VoidCallback onTap,
        bool isDisabled = false,
      }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.withOpacity(0.1)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: isDisabled ? Colors.grey : Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? Colors.grey : null,
                        )),
                    const SizedBox(height: 4),
                    Text(description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDisabled ? Colors.grey : Colors.grey.shade600,
                        )),
                  ],
                ),
              ),
              isDisabled
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Coming Soon', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              )
                  : const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToStandardAlarmCreation(BuildContext parentContext) async {
    TimeOfDay selectedTime = TimeOfDay.now();
    String alarmTitle = 'Alarm';
    List<bool> selectedDays = List.filled(7, false);

    final result = await showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Standard Alarm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null && picked != selectedTime) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: Text(
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Alarm Title'),
                      onChanged: (value) => alarmTitle = value,
                    ),
                    const SizedBox(height: 16),
                    const Text('Repeat on'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDayToggle(0, 'M', selectedDays, setState),
                        _buildDayToggle(1, 'T', selectedDays, setState),
                        _buildDayToggle(2, 'W', selectedDays, setState),
                        _buildDayToggle(3, 'T', selectedDays, setState),
                        _buildDayToggle(4, 'F', selectedDays, setState),
                        _buildDayToggle(5, 'S', selectedDays, setState),
                        _buildDayToggle(6, 'S', selectedDays, setState),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final List<int> activeDays = [];
                    for (int i = 0; i < selectedDays.length; i++) {
                      if (selectedDays[i]) activeDays.add(i + 1);
                    }

                    final Map<String, dynamic> newAlarm = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': alarmTitle.isNotEmpty ? alarmTitle : 'Alarm',
                      'time':
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      'days': activeDays,
                      'active': true,
                      'vibrate': true,
                      'sound': 'Gentle Rise',
                      'snooze_duration': 5,
                    };

                    Navigator.of(context).pop(newAlarm);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      Navigator.pop(parentContext, result);
    }
  }

  Widget _buildDayToggle(int index, String label, List<bool> selectedDays, Function setState) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDays[index] = !selectedDays[index];
        });
      },
      child: CircleAvatar(
        radius: 16,
        backgroundColor: selectedDays[index] ? Theme.of(context).primaryColor : Colors.grey.shade300,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selectedDays[index] ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _navigateToTravelAlarmCreation(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTravelAlarmScreen(
          onAlarmCreated: (alarm) => Navigator.pop(context, alarm),
        ),
      ),
    );

    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Coming Soon'),
          content: const Text('This feature is still under development and will be available in a future update!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
