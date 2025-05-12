import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WakeUpPlannerScreen extends StatefulWidget {
  const WakeUpPlannerScreen({super.key});

  @override
  State<WakeUpPlannerScreen> createState() => _WakeUpPlannerScreenState();
}

class _WakeUpPlannerScreenState extends State<WakeUpPlannerScreen> {
  int step = 1;
  String startLocation = '';
  String destination = '';
  TimeOfDay arrivalTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime arrivalDate = DateTime.now();
  double prepTime = 30;
  String wakeUpTime = '';
  bool alarmSet = false;

  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  void calculateWakeUpTime() {
    final arrivalDateTime = DateTime(
      arrivalDate.year,
      arrivalDate.month,
      arrivalDate.day,
      arrivalTime.hour,
      arrivalTime.minute,
    );

    final wakeUpDateTime = arrivalDateTime.subtract(
      Duration(minutes: 45 + prepTime.toInt()),
    );

    setState(() {
      wakeUpTime = DateFormat('hh:mm a').format(wakeUpDateTime);
    });
  }

  Widget stepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final currentStep = index + 1;
        final isActive = step >= currentStep;
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
              child: Text(
                '$currentStep',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ['Location', 'Time', 'Wake-Up'][index],
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            )
          ],
        );
      }),
    );
  }

  Widget locationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Starting Point', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: startController,
          decoration: const InputDecoration(
            hintText: 'Enter start location',
            prefixIcon: Icon(Icons.location_on),
          ),
          onChanged: (value) => startLocation = value,
        ),
        const SizedBox(height: 16),
        const Text('Destination', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: destinationController,
          decoration: const InputDecoration(
            hintText: 'Enter destination',
            prefixIcon: Icon(Icons.flag),
          ),
          onChanged: (value) => destination = value,
        ),
      ],
    );
  }

  Widget timeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Arrival Time', style: TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.access_time),
          title: Text('${arrivalTime.format(context)}'),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: arrivalTime,
            );
            if (picked != null) {
              setState(() => arrivalTime = picked);
            }
          },
        ),
        const Text('Arrival Date', style: TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(DateFormat.yMMMd().format(arrivalDate)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: arrivalDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => arrivalDate = picked);
            }
          },
        ),
        const Text('Preparation Time (minutes)', style: TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: prepTime,
          min: 15,
          max: 120,
          divisions: 21,
          label: '${prepTime.round()} min',
          onChanged: (value) {
            setState(() => prepTime = value);
          },
        ),
      ],
    );
  }

  Widget wakeUpStep() {
    calculateWakeUpTime();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              const Text('Wake-Up Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(wakeUpTime, style: const TextStyle(fontSize: 32, color: Colors.blue)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.alarm),
                label: Text(alarmSet ? 'Alarm Set!' : 'Set Alarm'),
                onPressed: alarmSet ? null : () => setState(() => alarmSet = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Journey Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: Text('From: $startLocation'),
        ),
        ListTile(
          leading: const Icon(Icons.flag),
          title: Text('To: $destination'),
        ),
        ListTile(
          leading: const Icon(Icons.access_time),
          title: Text('Arrival: ${arrivalTime.format(context)} on ${DateFormat.yMMMd().format(arrivalDate)}'),
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: Text('Preparation Time: ${prepTime.round()} min'),
        ),
      ],
    );
  }

  Widget nextPrevButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (step > 1)
          OutlinedButton(
            onPressed: () => setState(() => step--),
            child: const Text('Back'),
          ),
        ElevatedButton(
          onPressed: () {
            if (step < 3) {
              if (step == 1 && (startLocation.isEmpty || destination.isEmpty)) return;
              setState(() => step++);
            }
          },
          child: Text(step < 3 ? 'Next' : 'Done'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wake-Up Planner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            stepIndicator(),
            const SizedBox(height: 24),
            if (step == 1) locationStep(),
            if (step == 2) timeStep(),
            if (step == 3) wakeUpStep(),
            const SizedBox(height: 24),
            nextPrevButtons(),
          ],
        ),
      ),
    );
  }
}