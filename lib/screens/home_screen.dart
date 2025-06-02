import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer; // For logging

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;
  bool _isLoggedIn = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _checkLoginStatus();
    _animationController.forward();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    developer.log('Auth token: $token', name: 'HomeScreen');
    setState(() {
      _isLoggedIn = token != null;
    });
    if (_isLoggedIn) {
      developer.log('User is logged in, fetching data...', name: 'HomeScreen');
      _fetchUserData();
    } else {
      developer.log('User is not logged in', name: 'HomeScreen');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      setState(() {
        _error = 'Authentication token not found. Please log in again.';
        _loading = false;
        _isLoggedIn = false;
      });
      developer.log('Token missing during fetch, setting error', name: 'HomeScreen');
      return;
    }

    final resp = await http.get(
      Uri.parse('http://localhost:8080/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      setState(() {
        _userData = json.decode(resp.body);
        _loading = false;
      });
      developer.log('User data fetched successfully: ${_userData!['name']}', name: 'HomeScreen');
    } else {
      setState(() {
        _error = 'Failed to load user data: ${resp.statusCode}';
        _loading = false;
      });
      developer.log('Failed to fetch user data: ${resp.statusCode}', name: 'HomeScreen');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setState(() {
      _isLoggedIn = false;
      _userData = null;
      _error = null;
    });
    developer.log('Logged out successfully', name: 'HomeScreen');
    Navigator.pushReplacementNamed(context, '/login');
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isLoggedIn)
            PopupMenuButton<String>(
              icon: const Icon(Icons.person, color: Colors.white),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.pushNamed(context, '/profile');
                } else if (value == 'meal_history') {
                  Navigator.pushNamed(context, '/meal_history');
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.account_circle, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'meal_history',
                  child: Row(
                    children: [
                      Icon(Icons.fastfood, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Meal History'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image + dark overlay
          Image.asset('assets/images/bg_screen.png', fit: BoxFit.cover),
          Container(color: Colors.black38),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchUserData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.85),
                                foregroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 36, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 4,
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SingleChildScrollView(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 16),
                                // Logo
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    'assets/images/logo_meal_planner.png',
                                    width: 72,
                                    height: 72,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Title or Greeting
                                Text(
                                  _isLoggedIn
                                      ? 'Welcome, ${_userData!['name']}!'
                                      : 'AI Meal Planner',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 24),
                                // Daily Targets (only if logged in)
                                if (_isLoggedIn)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Column(
                                      children: [
                                        _buildTargetCard(
                                          title: 'Calories',
                                          value: _userData!['daily_calories'].toString(),
                                          unit: 'kcal',
                                          icon: Icons.local_fire_department,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildTargetCard(
                                          title: 'Protein',
                                          value: _userData!['daily_protein'].toString(),
                                          unit: 'g',
                                          icon: Icons.fitness_center,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildTargetCard(
                                          title: 'Carbs',
                                          value: _userData!['daily_carbs'].toString(),
                                          unit: 'g',
                                          icon: Icons.bakery_dining,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildTargetCard(
                                          title: 'Fat',
                                          value: _userData!['daily_fat'].toString(),
                                          unit: 'g',
                                          icon: Icons.local_dining,
                                          color: Colors.purple,
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                    ),
                                  ),
                                // Dynamic Button
                                ElevatedButton(
                                  onPressed: () {
                                    if (_isLoggedIn) {
                                      Navigator.pushNamed(context, '/meal_generator');
                                    } else {
                                      Navigator.pushNamed(context, '/login');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.85),
                                    foregroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 36, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    _isLoggedIn ? 'Plan Your Meal' : 'Get Started',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value $unit',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
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
}