import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/meal_generator_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/meal_history_screen.dart';
import 'package:flutter/foundation.dart' show debugPrint;

void main() async {
  debugPrint('Starting app initialization');
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Flutter binding initialized');
    await dotenv.load(fileName: ".env");
    debugPrint('Dotenv loaded successfully');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }
  debugPrint('Running app');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp');
    return MaterialApp(
      title: 'AI Meal Planner',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      initialRoute: '/home',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/home': (_) => const HomeScreen(),
        '/meal_generator': (_) => const MealGeneratorScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/edit_profile': (_) => const EditProfileScreen(),
        '/meal_history': (_) => const MealHistoryScreen(),
      },
    );
  }
}