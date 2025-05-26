import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/scheduler.dart' show Ticker;


class WebAlarm extends StatefulWidget {
  const WebAlarm({Key? key}) : super(key: key);

  @override
  State<WebAlarm> createState() => _WebAlarmState();
}

class _WebAlarmState extends State<WebAlarm> {
  bool _isRinging = false;
  late final AudioPlayer _player;
  bool _alarmSet = false;
  DateTime? _alarmTime;
  Duration? _remaining;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _ticker = Ticker(_onTick);
  }

  @override
  void dispose() {
    _player.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_alarmSet && _alarmTime != null) {
      final now = DateTime.now();
      setState(() {
        _remaining = _alarmTime!.difference(now);
      });
      if (_remaining != null && _remaining!.inMilliseconds <= 0) {
        _triggerAlarm();
      }
    }
  }

  void _startAlarmTimer(Duration duration) {
    setState(() {
      _alarmSet = true;
      _alarmTime = DateTime.now().add(duration);
      _remaining = duration;
    });
    _ticker.start();
  }

  Future<void> _triggerAlarm() async {
    if (!_isRinging) {
      setState(() {
        _isRinging = true;
        _alarmSet = false;
      });
      _ticker.stop();

      await _player.play(AssetSource('alarm_sound.mp3'));
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Alarm!'),
            content: const Text('Wake up!'),
            actions: [
              TextButton(
                onPressed: () {
                  _player.stop();
                  Navigator.of(ctx).pop();
                  setState(() => _isRinging = false);
                },
                child: const Text('Stop'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String timeLeft = '';
    if (_alarmSet && _remaining != null && _remaining!.inMilliseconds > 0) {
      final min = _remaining!.inMinutes.remainder(60).toString().padLeft(2, '0');
      final sec = _remaining!.inSeconds.remainder(60).toString().padLeft(2, '0');
      timeLeft = "$min:$sec";
    }

    return Card(
      margin: const EdgeInsets.all(24),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Demo Web Alarm',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_alarmSet && timeLeft.isNotEmpty)
              Text(
                'Alarm in $timeLeft',
                style: const TextStyle(fontSize: 20, color: Colors.blue),
              ),
            if (!_alarmSet)
              ElevatedButton(
                child: const Text('Set 10s Alarm'),
                onPressed: () => _startAlarmTimer(const Duration(seconds: 10)),
              ),
            if (_isRinging)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  "Ringing...",
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              ),
            if (_alarmSet)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  onPressed: () {
                    _ticker.stop();
                    setState(() => _alarmSet = false);
                  },
                  child: const Text("Cancel Alarm"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

