class SmartAlarmMapScreen extends StatefulWidget {
  const SmartAlarmMapScreen({Key? key}) : super(key: key);

  @override
  State<SmartAlarmMapScreen> createState() => _SmartAlarmMapScreenState();
}

class _SmartAlarmMapScreenState extends State<SmartAlarmMapScreen> {
  // Google Maps Controller
  late GoogleMapController mapController;

  // Markers for origin and destination
  final Set<Marker> _markers = {};

  // Polylines for route
  final Map<PolylineId, Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  // Current location
  LocationData? currentLocation;
  final Location location = Location();

  // Location controllers
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Selected locations
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;

  // Travel time and distance
  String _travelTime = "0 min";
  int _travelTimeMinutes = 0;
  String _distance = "0 km";

  // Arrival time
  TimeOfDay _arrivalTime = TimeOfDay.now();

  // Preparation time (default 30 minutes)
  int _preparationTime = 30;

  // Wake up time
  String _wakeUpTime = "--:--";
  DateTime? _wakeUpDateTime;

  // Notification plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    mapController.dispose();
    super.dispose();
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    currentLocation = await location.getLocation();
    setState(() {
      _originLatLng = LatLng(
          currentLocation!.latitude!,
          currentLocation!.longitude!
      );
      _updateMarkers();
      _moveCamera();
    });

    // Get address for current location
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          currentLocation!.latitude!,
          currentLocation!.longitude!
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _originController.text = "${place.name}, ${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      debugPrint("Error getting address: $e");
    }
  }

  // Update markers on map
  void _updateMarkers() {
    _markers.clear();

    // Add origin marker
    if (_originLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _originLatLng!,
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Add destination marker
    if (_destinationLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  // Move camera to show all markers
  void _moveCamera() {
    if (_originLatLng != null && _destinationLatLng != null) {
      // Calculate bounds to include both markers
      double minLat = _originLatLng!.latitude < _destinationLatLng!.latitude
          ? _originLatLng!.latitude
          : _destinationLatLng!.latitude;
      double maxLat = _originLatLng!.latitude > _destinationLatLng!.latitude
          ? _originLatLng!.latitude
          : _destinationLatLng!.latitude;
      double minLng = _originLatLng!.longitude < _destinationLatLng!.longitude
          ? _originLatLng!.longitude
          : _destinationLatLng!.longitude;
      double maxLng = _originLatLng!.longitude > _destinationLatLng!.longitude
          ? _originLatLng!.longitude
          : _destinationLatLng!.longitude;

      // Add padding to bounds
      final double padding = 0.01;
      minLat -= padding;
      maxLat += padding;
      minLng -= padding;
      maxLng += padding;

      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50, // Padding
        ),
      );
    } else if (_originLatLng != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_originLatLng!, 14),
      );
    }
  }

  // Search for a location
  Future<void> _searchLocation(String input, bool isOrigin) async {
    try {
      List<Location> locations = await locationFromAddress(input);

      if (locations.isNotEmpty) {
        setState(() {
          if (isOrigin) {
            _originLatLng = LatLng(
                locations[0].latitude,
                locations[0].longitude
            );
          } else {
            _destinationLatLng = LatLng(
                locations[0].latitude,
                locations[0].longitude
            );
          }
          _updateMarkers();
          _moveCamera();
        });

        // If both origin and destination are set, get route
        if (_originLatLng != null && _destinationLatLng != null) {
          _getRoute();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find location: $e')),
      );
    }
  }

  // Get route between origin and destination
  void _getRoute() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      'YOUR_GOOGLE_MAPS_API_KEY', // Replace with your API key
      PointLatLng(_originLatLng!.latitude, _originLatLng!.longitude),
      PointLatLng(_destinationLatLng!.latitude, _destinationLatLng!.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates.clear();
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    // Mock data for travel time and distance since we can't really calculate it without premium APIs
    // In a real app, you would use the Distance Matrix API or Directions API to get accurate data
    final double distance = _calculateDistance(_originLatLng!, _destinationLatLng!);
    final int timeMinutes = (distance * 2).round(); // Rough estimate: 30 km/h average speed

    setState(() {
      _distance = "${distance.toStringAsFixed(1)} km";
      _travelTimeMinutes = timeMinutes;
      _travelTime = "$timeMinutes min";
      _calculateWakeUpTime();

      PolylineId id = const PolylineId("route");
      Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.blue,
        points: polylineCoordinates,
        width: 5,
      );
      _polylines[id] = polyline;
    });
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    double lat1 = start.latitude * (3.14159265359 / 180);
    double lat2 = end.latitude * (3.14159265359 / 180);
    double lon1 = start.longitude * (3.14159265359 / 180);
    double lon2 = end.longitude * (3.14159265359 / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = (dLat / 2).sin() * (dLat / 2).sin() +
        (dLon / 2).sin() * (dLon / 2).sin() * lat1.cos() * lat2.cos();
    double c = 2 * a.sqrt().atan2((1 - a).sqrt());

    return earthRadius * c;
  }

  // Show time picker for arrival time
  Future<void> _selectArrivalTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
    );

    if (picked != null && picked != _arrivalTime) {
      setState(() {
        _arrivalTime = picked;
        _calculateWakeUpTime();
      });
    }
  }

  // Calculate wake up time based on arrival time, travel time, and preparation time
  void _calculateWakeUpTime() {
    if (_travelTimeMinutes == 0) return;

    // Get current date
    DateTime now = DateTime.now();
    DateTime arrivalDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _arrivalTime.hour,
      _arrivalTime.minute,
    );

    // If arrival time is earlier than current time, assume it's for tomorrow
    if (arrivalDateTime.isBefore(now)) {
      arrivalDateTime = arrivalDateTime.add(const Duration(days: 1));
    }

    // Calculate wake up time: arrival time - travel time - preparation time
    _wakeUpDateTime = arrivalDateTime.subtract(Duration(
      minutes: _travelTimeMinutes + _preparationTime,
    ));

    setState(() {
      _wakeUpTime = DateFormat('hh:mm a').format(_wakeUpDateTime!);
    });
  }

  // Set an alarm for wake up time
  Future<void> _setAlarm() async {
    if (_wakeUpDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please calculate wake up time first')),
      );
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Smart Alarm Notifications',
      channelDescription: 'Notifications for wake up alarms',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // Calculate time difference for scheduling
    final DateTime now = DateTime.now();
    final Duration difference = _wakeUpDateTime!.difference(now);

    if (difference.isNegative) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wake up time is in the past!')),
      );
      return;
    }

    // Schedule notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Time to Wake Up!',
      'You need to leave for ${_destinationController.text} in $_preparationTime minutes',
      now.add(difference),
      platformDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarm set for $_wakeUpTime')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Wake Up Alarm'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _originLatLng ?? const LatLng(0, 0),
                zoom: 14,
              ),
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
                if (_originLatLng != null) {
                  _moveCamera();
                }
              },
              markers: _markers,
              polylines: Set<Polyline>.of(_polylines.values),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),

          // Location inputs and results
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Origin input
                    TextField(
                      controller: _originController,
                      decoration: InputDecoration(
                        labelText: 'Starting Point',
                        hintText: 'Enter your location',
                        prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (value) => _searchLocation(value, true),
                    ),
                    const SizedBox(height: 12),

                    // Destination input
                    TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Where are you going?',
                        prefixIcon: const Icon(Icons.location_searching, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (value) => _searchLocation(value, false),
                    ),
                    const SizedBox(height: 20),

                    // Travel information
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _infoCard(
                          title: 'Distance',
                          value: _distance,
                          icon: Icons.directions_car,
                        ),
                        _infoCard(
                          title: 'Travel Time',
                          value: _travelTime,
                          icon: Icons.timer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Arrival time
                    InkWell(
                      onTap: _selectArrivalTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          prefixIcon: const Icon(Icons.access_time),
                          suffixIcon: const Icon(Icons.keyboard_arrow_down),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "${_arrivalTime.format(context)}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Preparation time slider
                    Row(
                      children: [
                        const Icon(Icons.shower, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text("Preparation Time:"),
                        Expanded(
                          child: Slider(
                            value: _preparationTime.toDouble(),
                            min: 10,
                            max: 120,
                            divisions: 22,
                            label: "$_preparationTime min",
                            onChanged: (value) {
                              setState(() {
                                _preparationTime = value.round();
                                _calculateWakeUpTime();
                              });
                            },
                          ),
                        ),
                        Text(
                          "$_preparationTime min",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Wake up time
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Wake Up Time",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _wakeUpTime,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Based on $_travelTime travel time and $_preparationTime min prep time",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Set alarm button
                    ElevatedButton.icon(
                      onPressed: _setAlarm,
                      icon: const Icon(Icons.alarm_add),
                      label: const Text("SET ALARM"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Info card widget for displaying travel info
  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}// main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const MyApp());
}

// Get Supabase client instance to use throughout the app
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const SmartAlarmMapScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing Login...')),
        );

        // Implement Supabase login logic
        final AuthResponse res = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (res.session != null) {
          // Navigate to home screen after successful login
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // Handle error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login failed. Please check your credentials.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo
                const Icon(
                  Icons.flutter_dash,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),

                // App Name
                const Text(
                  'Flutter Auth',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 48),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Implement forgot password logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Forgot password feature')),
                            );
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      ElevatedButton(
                        onPressed: _login,
                        child: const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Social Login
                      const Row(
                        children: [
                          Expanded(child: Divider(thickness: 1)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Social Login Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(icon: Icons.facebook, color: Colors.blue.shade800),
                          _socialButton(icon: Icons.g_mobiledata, color: Colors.red),
                          _socialButton(icon: Icons.apple, color: Colors.black),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?"),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () {
          // Implement social login
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login with ${icon.toString()}')),
          );
        },
        iconSize: 32,
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing Sign Up...')),
        );

        // Implement Supabase signup logic
        final AuthResponse res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'full_name': _nameController.text,
          },
        );

        final Session? session = res.session;
        final User? user = res.user;

        if (user != null) {
          // Handle email confirmation if needed
          if (session == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please check your email for confirmation link')),
              );
              Navigator.pushReplacementNamed(context, '/login');
            }
          } else {
            // Navigate to home screen after successful signup
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        } else {
          // Handle error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign up failed. Please try again.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to Terms & Conditions')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Profile Picture Placeholder
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 60,
                        color: Colors.blue,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Signup Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Full Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Terms and Conditions Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Sign Up Button
                    ElevatedButton(
                      onPressed: _signup,
                      child: const Text(
                        'SIGN UP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?"),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Log In',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Home Screen with navigation to Map Screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Alarm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.alarm,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Never Be Late Again!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Set your destination and arrival time, and we\'ll calculate when you need to wake up based on real-time traffic data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
              icon: const Icon(Icons.map),
              label: const Text('Plan Your Journey'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Logged in as: ${user?.email ?? 'No email available'}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}