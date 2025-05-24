import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'HistoryScreen.dart';
import 'create_alarm_screen.dart';
import 'create_travel_alarm_screen.dart';
import 'splash_screen.dart';
import 'app theme.dart';
import 'alarms.dart'; // Make sure this file exists and is in the correct directory

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uxqfsyyqjdaszdavnerc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV4cWZzeXlxamRhc3pkYXZuZXJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY2MTc1NzIsImV4cCI6MjA2MjE5MzU3Mn0.O_xLDwHz2fTabx8Kf3jtlM4LQJNqgvFBF0VdFwdc3QA',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UpNGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/history': (context) => const HistoryScreen(),
        '/alarms': (context) => const AlarmsScreen(),            // ✅ ADDED THIS LINE
        '/alarms/create': (context) => const CreateAlarmScreen(),
        // Add other simple static routes here if needed
      },

      // 🔄 For routes needing parameters (like travel alarm or ringing alarm)
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/create-travel-alarm':
            return MaterialPageRoute(
              builder: (context) => CreateTravelAlarmScreen(
                onAlarmCreated: (alarm) {
                  debugPrint('Created travel alarm: $alarm');
                },
              ),
            );

        }
      },

      // 🚫 Handles invalid routes gracefully
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(
              child: Text('The page you are looking for does not exist.'),
            ),
          ),
        );
      },
    );
  }
}
