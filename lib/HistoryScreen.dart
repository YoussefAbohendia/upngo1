import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _alarmsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _alarmsFuture = _fetchAlarms();
  }

  Future<List<Map<String, dynamic>>> _fetchAlarms() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final response = await Supabase.instance.client
        .from('alarms')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _deleteAllAlarms() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    await Supabase.instance.client
        .from('alarms')
        .delete()
        .eq('user_id', user.id);

    setState(() {
      _alarmsFuture = _fetchAlarms();
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All history deleted!')),
      );
    }
  }

  String _formatAlarmTime(Map<String, dynamic> alarm) {
    try {
      if (alarm['alarm_time'] != null) {
        return alarm['alarm_time'];
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete All History',
            onPressed: _isLoading
                ? null
                : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete All History?'),
                  content: const Text(
                      'Are you sure you want to delete all alarm history? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteAllAlarms();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _alarmsFuture,
        builder: (context, snapshot) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history'));
          }
          final alarms = snapshot.data ?? [];
          if (alarms.isEmpty) {
            return const Center(child: Text('No alarms in history.'));
          }
          return ListView.builder(
            itemCount: alarms.length,
            itemBuilder: (context, idx) {
              final alarm = alarms[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text(alarm['trip_name'] ?? 'Unnamed Trip'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alarm Time: ${_formatAlarmTime(alarm)}'),
                      if (alarm['location'] != null)
                        Text('Destination: ${alarm['location']}'),
                      if (alarm['arrival_time'] != null)
                        Text('Target Arrival: ${alarm['arrival_time']}'),
                      if (alarm['created_at'] != null)
                        Text(
                          'Created: ${DateFormat('y-MM-dd HH:mm').format(DateTime.parse(alarm['created_at']))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
