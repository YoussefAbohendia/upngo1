import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'navigation_drawer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alarmHistory = [];
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Last Week', 'Last Month'];

  @override
  void initState() {
    super.initState();
    _loadAlarmHistory();
  }

  Future<void> _loadAlarmHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await AuthService.getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Define date range filter
      DateTime? startDate;
      if (_selectedFilter == 'Last Week') {
        startDate = DateTime.now().subtract(const Duration(days: 7));
      } else if (_selectedFilter == 'Last Month') {
        startDate = DateTime.now().subtract(const Duration(days: 30));
      }

      final supabase = Supabase.instance.client;

// Base query
      var query = supabase
          .from('alarm_history')
          .select('*, alarm_id(*)')
          .eq('user_id', userId)
          .order('date', ascending: false);

// Add date filter if needed
      if (startDate != null) {
        query = supabase
            .from('alarm_history')
            .select('*, alarm_id(*)')
            .eq('user_id', userId)
            .gte('date', startDate.toIso8601String()) // ✅ Apply gte directly here
            .order('date', ascending: false);
      }

      final data = await query;

      setState(() {
        _alarmHistory = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading alarm history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // For demo purposes - create mock data
  void _generateMockData() {
    final now = DateTime.now();

    final List<Map<String, dynamic>> mockData = [
      {
        'id': '1',
        'date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'wakeup_time': '07:30',
        'snooze_count': 2,
        'total_sleep': 7.5,
        'mood_rating': 4,
        'alarm_id': {'title': 'Work Day', 'time': '7:00 AM'}
      },
      {
        'id': '2',
        'date': now.subtract(const Duration(days: 2)).toIso8601String(),
        'wakeup_time': '06:45',
        'snooze_count': 0,
        'total_sleep': 8.2,
        'mood_rating': 5,
        'alarm_id': {'title': 'Early Meeting', 'time': '6:30 AM'}
      },
      {
        'id': '3',
        'date': now.subtract(const Duration(days: 3)).toIso8601String(),
        'wakeup_time': '08:15',
        'snooze_count': 3,
        'total_sleep': 6.8,
        'mood_rating': 3,
        'alarm_id': {'title': 'Work Day', 'time': '7:00 AM'}
      },
      {
        'id': '4',
        'date': now.subtract(const Duration(days: 7)).toIso8601String(),
        'wakeup_time': '09:00',
        'snooze_count': 1,
        'total_sleep': 9.0,
        'mood_rating': 5,
        'alarm_id': {'title': 'Weekend', 'time': '8:30 AM'}
      },
      {
        'id': '5',
        'date': now.subtract(const Duration(days: 10)).toIso8601String(),
        'wakeup_time': '07:15',
        'snooze_count': 2,
        'total_sleep': 7.2,
        'mood_rating': 4,
        'alarm_id': {'title': 'Work Day', 'time': '7:00 AM'}
      },
      {
        'id': '6',
        'date': now.subtract(const Duration(days: 14)).toIso8601String(),
        'wakeup_time': '06:30',
        'snooze_count': 0,
        'total_sleep': 6.5,
        'mood_rating': 3,
        'alarm_id': {'title': 'Early Flight', 'time': '6:00 AM'}
      },
    ];

    setState(() {
      _alarmHistory = mockData;
      _isLoading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadAlarmHistory();
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  Widget _buildMoodIndicator(int rating) {
    IconData icon;
    Color color;

    switch (rating) {
      case 1:
        icon = Icons.sentiment_very_dissatisfied;
        color = Colors.red;
        break;
      case 2:
        icon = Icons.sentiment_dissatisfied;
        color = Colors.orange;
        break;
      case 3:
        icon = Icons.sentiment_neutral;
        color = Colors.yellow.shade700;
        break;
      case 4:
        icon = Icons.sentiment_satisfied;
        color = Colors.lightGreen;
        break;
      case 5:
        icon = Icons.sentiment_very_satisfied;
        color = Colors.green;
        break;
      default:
        icon = Icons.sentiment_neutral;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 28);
  }

  @override
  Widget build(BuildContext context) {
    // If no data in DB, generate mock data for demo
    if (_alarmHistory.isEmpty && !_isLoading) {
      _generateMockData();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep History'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _applyFilter,
            itemBuilder: (BuildContext context) {
              return _filterOptions.map((String filter) {
                return PopupMenuItem<String>(
                  value: filter,
                  child: Row(
                    children: [
                      _selectedFilter == filter
                          ? Icon(Icons.check, color: Theme.of(context).primaryColor, size: 20)
                          : const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      Text(filter),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/history'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarmHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No alarm history found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your alarm history will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alarmHistory.length,
        itemBuilder: (context, index) {
          final history = _alarmHistory[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(history['date']),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildMoodIndicator(history['mood_rating']),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                            context,
                            'Alarm',
                            history['alarm_id']['title'] + ' - ' + history['alarm_id']['time'],
                            Icons.alarm
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                            context,
                            'Wake Up Time',
                            history['wakeup_time'],
                            Icons.access_time
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                            context,
                            'Total Sleep',
                            '${history['total_sleep']} hrs',
                            Icons.nightlight_round
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                            context,
                            'Snoozes',
                            '${history['snooze_count']}',
                            Icons.snooze
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

