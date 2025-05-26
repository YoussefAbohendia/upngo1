import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'dart:async';


// Replace with your actual Google Maps API Key
const String _googleMapsApiKey = 'AIzaSyAd7cupt2geMSp7t3oiQOT-q6vAC_F-KRg';

class CreateTravelAlarmScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onAlarmCreated;

  const CreateTravelAlarmScreen({
    Key? key,
    required this.onAlarmCreated,
  }) : super(key: key);

  @override
  State<CreateTravelAlarmScreen> createState() => _CreateTravelAlarmScreenState();
}

class _CreateTravelAlarmScreenState extends State<CreateTravelAlarmScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController(text: '');
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  TimeOfDay _targetArrivalTime = TimeOfDay(hour: 9, minute: 0);
  DateTime _targetArrivalDate = DateTime.now().add(Duration(days: 1));
  int _preparationTimeMinutes = 45;
  int _transportMode = 0; // 0: driving, 1: public transit, 2: walking
  List<bool> _repeatDays = List.filled(7, false);
  bool _vibrateEnabled = true;
  String _selectedSound = 'Gentle Rise';
  int _snoozeDuration = 5;

  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  int _estimatedTravelTime = 30; // minutes
  bool _isLoadingTravelTime = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _originLatLng = LatLng(position.latitude, position.longitude);
          _originController.text = '${place.street}, ${place.locality}';
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> _openMapForLocationPicker({required bool isOrigin}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          apiKey: _googleMapsApiKey,
          initialLocation: isOrigin ? _originLatLng : _destinationLatLng,
          title: isOrigin ? 'Select Pickup Location' : 'Select Dropoff Location',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isOrigin) {
          _originLatLng = result['latlng'];
          _originController.text = result['address'] ?? '';
        } else {
          _destinationLatLng = result['latlng'];
          _destinationController.text = result['address'] ?? '';
        }
      });
      // Calculate travel time if both locations are set
      if (_originLatLng != null && _destinationLatLng != null) {
        await _calculateTravelTime();
      }
    }
  }

  Future<void> _calculateTravelTime() async {
    if (_originLatLng == null || _destinationLatLng == null) return;

    setState(() {
      _isLoadingTravelTime = true;
    });

    try {
      String travelMode = 'driving';
      switch (_transportMode) {
        case 0:
          travelMode = 'driving';
          break;
        case 1:
          travelMode = 'transit';
          break;
        case 2:
          travelMode = 'walking';
          break;
      }

      final targetArrivalDateTime = DateTime(
        _targetArrivalDate.year,
        _targetArrivalDate.month,
        _targetArrivalDate.day,
        _targetArrivalTime.hour,
        _targetArrivalTime.minute,
      );

      final plannedDepartureTime = targetArrivalDateTime.subtract(
          Duration(minutes: _preparationTimeMinutes)
      );

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${_originLatLng!.latitude},${_originLatLng!.longitude}&'
              'destination=${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}&'
              'mode=$travelMode&'
              'departure_time=${(plannedDepartureTime.millisecondsSinceEpoch / 1000).round()}&'
              'traffic_model=best_guess&'
              'key=$_googleMapsApiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'][0];

          int durationSeconds;
          if (legs['duration_in_traffic'] != null) {
            durationSeconds = legs['duration_in_traffic']['value'];
          } else {
            durationSeconds = legs['duration']['value'];
          }

          setState(() {
            _estimatedTravelTime = (durationSeconds / 60).ceil();
            _isLoadingTravelTime = false;
          });

          debugPrint('✅ Travel time calculated: $_estimatedTravelTime minutes (with traffic)');
        } else {
          debugPrint('❌ Google Maps API error: ${data['status']}');
          _setDefaultTravelTime();
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        _setDefaultTravelTime();
      }
    } catch (e) {
      debugPrint('❌ Error calculating travel time: $e');
      _setDefaultTravelTime();
    }
  }

  void _setDefaultTravelTime() {
    setState(() {
      switch (_transportMode) {
        case 0: _estimatedTravelTime = 30; break;
        case 1: _estimatedTravelTime = 45; break;
        case 2: _estimatedTravelTime = 60; break;
      }
      _isLoadingTravelTime = false;
    });
    debugPrint('⚠️ Using default travel time: $_estimatedTravelTime minutes');
  }

  void _selectTargetArrivalTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _targetArrivalTime,
      helpText: 'What time do you want to arrive?',
    );

    if (picked != null && picked != _targetArrivalTime) {
      setState(() { _targetArrivalTime = picked; });
      if (_originLatLng != null && _destinationLatLng != null) {
        await _calculateTravelTime();
      }
    }
  }

  void _selectTargetArrivalDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetArrivalDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'What date do you want to arrive?',
    );

    if (picked != null && picked != _targetArrivalDate) {
      setState(() { _targetArrivalDate = picked; });
      if (_originLatLng != null && _destinationLatLng != null) {
        await _calculateTravelTime();
      }
    }
  }

  TimeOfDay _getCalculatedWakeUpTime() {
    final targetArrivalDateTime = DateTime(
      _targetArrivalDate.year,
      _targetArrivalDate.month,
      _targetArrivalDate.day,
      _targetArrivalTime.hour,
      _targetArrivalTime.minute,
    );
    final wakeUpDateTime = targetArrivalDateTime.subtract(
        Duration(minutes: _estimatedTravelTime + _preparationTimeMinutes)
    );
    return TimeOfDay(hour: wakeUpDateTime.hour, minute: wakeUpDateTime.minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final hourLabel = hour == 0 ? '12' : hour.toString();
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourLabel:$minute $period';
  }

  void _toggleDay(int index) {
    setState(() {
      _repeatDays[index] = !_repeatDays[index];
    });
  }

  Future<void> _saveAlarmToSupabase() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    if (_originLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both origin and destination locations.')),
      );
      return;
    }
    setState(() { _isLoading = true; });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to save the alarm.')),
          );
        }
        return;
      }

      final TimeOfDay calculatedWakeUpTime = _getCalculatedWakeUpTime();
      final String formattedWakeUp = '${calculatedWakeUpTime.hour.toString().padLeft(2, '0')}:${calculatedWakeUpTime.minute.toString().padLeft(2, '0')}';
      final String formattedTargetArrival = '${_targetArrivalTime.hour.toString().padLeft(2, '0')}:${_targetArrivalTime.minute.toString().padLeft(2, '0')}';

      final List<int> activeDays = [];
      for (int i = 0; i < _repeatDays.length; i++) {
        if (_repeatDays[i]) { activeDays.add(i + 1); }
      }

      final tripData = {
        'user_id': user.id,
        'trip_name': _titleController.text.trim(),
        'start_location': _originController.text.trim(),
        'destination': _destinationController.text.trim(),
        'travel_time': '$_estimatedTravelTime mins',
        'alarm_time': formattedWakeUp,
        'arrival_time': formattedTargetArrival,
        'arrival_date': DateFormat('yyyy-MM-dd').format(_targetArrivalDate),
        'transport_mode': _transportMode,
        'preparation_time': _preparationTimeMinutes,
        'origin_lat': _originLatLng?.latitude,
        'origin_lng': _originLatLng?.longitude,
        'destination_lat': _destinationLatLng?.latitude,
        'destination_lng': _destinationLatLng?.longitude,
        'created_at': DateTime.now().toIso8601String(),
      };

      final alarmData = {
        'user_id': user.id,
        'trip_name': _titleController.text.trim(),
        'alarm_time': formattedWakeUp,
        'location': _destinationController.text.trim(),
        'active': true,
        'vibrate': _vibrateEnabled,
        'sound': _selectedSound,
        'snooze_duration': _snoozeDuration,
        'repeat_days': activeDays,
        'is_travel_alarm': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client.from('trip_details').insert(tripData);
      } catch (tripError) {
        debugPrint('❌ Error saving trip details: $tripError');
      }

      try {
        final response = await Supabase.instance.client.from('alarms').insert(alarmData).select();
        debugPrint('✅ Alarm saved successfully: $response');
      } catch (alarmError) {
        debugPrint('❌ Error saving alarm: $alarmError');
        rethrow;
      }

      final Map<String, dynamic> newAlarm = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.trim(),
        'time': formattedWakeUp,
        'days': activeDays,
        'active': true,
        'vibrate': _vibrateEnabled,
        'sound': _selectedSound,
        'snooze_duration': _snoozeDuration,
        'is_travel_alarm': true,
        'origin': _originController.text.trim(),
        'destination': _destinationController.text.trim(),
        'target_arrival_time': formattedTargetArrival,
        'target_arrival_date': DateFormat('yyyy-MM-dd').format(_targetArrivalDate),
        'travel_mode': _transportMode,
        'preparation_time': _preparationTimeMinutes,
        'estimated_travel_time': _estimatedTravelTime,
      };

      widget.onAlarmCreated(newAlarm);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Smart travel alarm set!\n'
                  '⏰ Wake up: ${_formatTimeOfDay(calculatedWakeUpTime)}\n'
                  '🚗 Travel: $_estimatedTravelTime min (with traffic)\n'
                  '🎯 Arrive: ${_formatTimeOfDay(_targetArrivalTime)}',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
              (route) => false,
        );
      }
    } catch (error) {
      debugPrint('❌ Error saving alarm: $error');
      if (mounted) {
        String errorMessage = 'Failed to save alarm';
        if (error.toString().contains('alarm_time')) {
          errorMessage = 'Database error: Missing required columns. Please contact support.';
        } else if (error.toString().contains('authentication')) {
          errorMessage = 'Authentication error. Please log in again.';
        } else if (error.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _saveAlarmToSupabase(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Widget _buildDayToggle(int index, String label) {
    return GestureDetector(
      onTap: () => _toggleDay(index),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _repeatDays[index] ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _repeatDays[index] ? Theme.of(context).primaryColor : Colors.grey[400]!,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _repeatDays[index] ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _createAlarm() async {
    await _saveAlarmToSupabase();
  }

  @override
  Widget build(BuildContext context) {
    final calculatedWakeUpTime = _getCalculatedWakeUpTime();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Smart Travel Alarm'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('🚀 Setting up your smart alarm...'),
            SizedBox(height: 8),
            Text(
              'Calculating optimal wake-up time with real-time traffic',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wake-up time card (same as your UI)
              Card(
                margin: const EdgeInsets.only(bottom: 24.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.smart_toy,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🤖 Smart Wake-up Time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTimeOfDay(calculatedWakeUpTime),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      if (_isLoadingTravelTime) ...[
                                        const SizedBox(width: 8),
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isLoadingTravelTime
                                    ? '🚗 Calculating with real-time traffic...'
                                    : '📊 Automatically calculated based on:',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              if (!_isLoadingTravelTime) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '🎯 Target arrival: ${_formatTimeOfDay(_targetArrivalTime)}\n'
                                      '🚗 Travel time: ${_estimatedTravelTime} min (with traffic)\n'
                                      '⏰ Preparation time: ${_preparationTimeMinutes} min\n'
                                      '📱 NO manual time setting needed!',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Trip Name',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., "Morning commute to office"',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a trip name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Uber-style buttons for origin/destination with map picker
              Text(
                '📍 Travel Route',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Origin Picker
              Card(
                child: ListTile(
                  leading: Icon(Icons.radio_button_checked, color: Colors.green),
                  title: Text(
                    _originController.text.isEmpty
                        ? "Select Pickup Location"
                        : _originController.text,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Icon(Icons.map),
                  onTap: () => _openMapForLocationPicker(isOrigin: true),
                ),
              ),
              const SizedBox(height: 8),

              // Destination Picker
              Card(
                child: ListTile(
                  leading: Icon(Icons.location_on, color: Colors.red),
                  title: Text(
                    _destinationController.text.isEmpty
                        ? "Select Dropoff Location"
                        : _destinationController.text,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Icon(Icons.map),
                  onTap: () => _openMapForLocationPicker(isOrigin: false),
                ),
              ),
              const SizedBox(height: 12),

              // Show mini map with markers if both set (optional, Uber-style)
              if (_originLatLng != null || _destinationLatLng != null)
                Container(
                  height: 180,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _originLatLng ??
                            _destinationLatLng ??
                            LatLng(30.0444, 31.2357),
                        zoom: 13,
                      ),
                      markers: {
                        if (_originLatLng != null)
                          Marker(
                            markerId: MarkerId("origin"),
                            position: _originLatLng!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen),
                            infoWindow: InfoWindow(title: "Pickup"),
                          ),
                        if (_destinationLatLng != null)
                          Marker(
                            markerId: MarkerId("dest"),
                            position: _destinationLatLng!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed),
                            infoWindow: InfoWindow(title: "Dropoff"),
                          ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      liteModeEnabled: true,
                    ),
                  ),
                ),

              // ...all your other settings and controls as before...
              // The rest of your alarm options (mode, repeat, alarm, etc.)

              const SizedBox(height: 16),
              // Transport mode
              Text(
                '🚗 How will you travel?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.directions_car),
                    label: Text('Driving'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.directions_bus),
                    label: Text('Transit'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.directions_walk),
                    label: Text('Walking'),
                  ),
                ],
                selected: {_transportMode},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _transportMode = newSelection.first;
                  });
                  if (_originLatLng != null && _destinationLatLng != null) {
                    _calculateTravelTime();
                  }
                },
              ),

              const SizedBox(height: 24),

              // Target arrival time section
              Text(
                '🎯 When do you want to arrive?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '⚡ The alarm will be automatically set based on this target arrival time',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _selectTargetArrivalDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Target Arrival Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('EEE, MMM d, yyyy').format(_targetArrivalDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectTargetArrivalTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Target Arrival Time',
                    prefixIcon: Icon(Icons.access_time),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatTimeOfDay(_targetArrivalTime)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preparation time slider
              Text(
                '⏰ Preparation Time: $_preparationTimeMinutes min',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'How long do you need to get ready before leaving?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Slider(
                value: _preparationTimeMinutes.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                label: '$_preparationTimeMinutes min',
                onChanged: (double value) {
                  setState(() {
                    _preparationTimeMinutes = value.round();
                  });
                  if (_originLatLng != null && _destinationLatLng != null) {
                    _calculateTravelTime();
                  }
                },
              ),

              const SizedBox(height: 24),

              // Repeat days
              Text(
                '📅 Repeat Schedule',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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

              // Alarm options
              Text(
                '🔊 Alarm Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              Card(
                margin: const EdgeInsets.only(top: 10, bottom: 28),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Vibrate'),
                      value: _vibrateEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _vibrateEnabled = value;
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note),
                      title: const Text('Alarm Sound'),
                      trailing: DropdownButton<String>(
                        value: _selectedSound,
                        items: [
                          'Gentle Rise',
                          'Classic Beep',
                          'Nature',
                          'Alarm Buzz',
                        ].map((sound) =>
                            DropdownMenuItem(
                              value: sound,
                              child: Text(sound),
                            )).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedSound = value;
                            });
                          }
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.snooze),
                      title: const Text('Snooze Duration'),
                      trailing: DropdownButton<int>(
                        value: _snoozeDuration,
                        items: [5, 10, 15].map((min) =>
                            DropdownMenuItem(
                              value: min,
                              child: Text('$min min'),
                            )).toList(),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() {
                              _snoozeDuration = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.alarm_add),
                  label: const Text('Set Smart Travel Alarm'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _createAlarm,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                '* The alarm will automatically adapt if your trip details change.\n* Make sure notifications and background permissions are enabled!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------
// Uber-style Location Picker Widget
// -----------------------------
class MapLocationPicker extends StatefulWidget {
  final String apiKey;
  final LatLng? initialLocation;
  final String title;

  const MapLocationPicker({
    Key? key,
    required this.apiKey,
    this.initialLocation,
    required this.title,
  }) : super(key: key);

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late GoogleMapController _mapController;
  LatLng? _selectedLatLng;
  String _address = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _predictions = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialLocation ?? LatLng(30.0444, 31.2357); // Cairo default
    _reverseGeocode(_selectedLatLng!);
  }

  void _onMapTap(LatLng pos) {
    setState(() {
      _selectedLatLng = pos;
      _predictions.clear();
      _searchController.clear();
      _address = '';
    });
    _reverseGeocode(pos);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${widget.apiKey}");
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        setState(() {
          _address = data['results'][0]['formatted_address'];
        });
      }
    }
  }

  Future<void> _searchPlace(String input) async {
    if (input.isEmpty) {
      setState(() => _predictions.clear());
      return;
    }
    setState(() => _searching = true);
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&language=en&components=country:eg|country:us|country:gb|country:ca|country:au");
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        _predictions = List<Map<String, dynamic>>.from(data['predictions']);
        _searching = false;
      });
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'];
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,formatted_address&key=${widget.apiKey}");
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final loc = data['result']['geometry']['location'];
      final latLng = LatLng(loc['lat'], loc['lng']);
      setState(() {
        _selectedLatLng = latLng;
        _address = data['result']['formatted_address'];
        _predictions.clear();
        _searchController.text = _address;
      });
      _mapController.animateCamera(CameraUpdate.newLatLng(latLng));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _selectedLatLng != null
                ? () => Navigator.pop(context, {'latlng': _selectedLatLng, 'address': _address})
                : null,
            child: Text("Confirm", style: TextStyle(color: _selectedLatLng != null ? Colors.blue : Colors.grey)),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for a place",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _searchPlace(text));
              },
            ),
          ),
          if (_searching)
            Center(child: CircularProgressIndicator()),
          if (_predictions.isNotEmpty)
            Container(
              color: Colors.white,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _predictions.length,
                separatorBuilder: (c, i) => Divider(),
                itemBuilder: (context, idx) {
                  final pred = _predictions[idx];
                  return ListTile(
                    title: Text(pred['structured_formatting']?['main_text'] ?? pred['description']),
                    subtitle: Text(pred['structured_formatting']?['secondary_text'] ?? ""),
                    onTap: () => _selectPrediction(pred),
                  );
                },
              ),
            ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: _selectedLatLng ?? LatLng(30.0444, 31.2357), zoom: 14),
              markers: _selectedLatLng != null
                  ? {
                Marker(
                    markerId: MarkerId('selected'),
                    position: _selectedLatLng!,
                    infoWindow: InfoWindow(title: _address))
              }
                  : {},
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTap,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
            ),
          ),
          if (_address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Selected: $_address",
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }
}
