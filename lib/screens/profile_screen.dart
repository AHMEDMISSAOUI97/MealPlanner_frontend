import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    debugPrint('Checking authentication');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      debugPrint('Auth token: $token');
      setState(() {
        _isAuthenticated = token != null;
        _isChecking = false;
      });
      if (_isAuthenticated) {
        _fetchUserData();
      } else {
        debugPrint('User not authenticated, redirecting to login');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      setState(() {
        _isChecking = false;
        _error = 'Error checking authentication: $e';
      });
    }
  }

  Future<void> _fetchUserData() async {
    debugPrint('Fetching user data');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _error = 'Authentication token not found. Please log in again.';
          _isLoading = false;
          _isAuthenticated = false;
        });
        debugPrint('Token missing during fetch, setting error');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('User data fetch response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        setState(() {
          _userData = json.decode(resp.body);
          _isLoading = false;
        });
        debugPrint('User data fetched successfully: ${_userData!['name']}');
      } else {
        setState(() {
          _error = 'Failed to load profile: ${resp.statusCode}';
          _isLoading = false;
        });
        debugPrint('Failed to fetch user data: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching profile: $e';
        _isLoading = false;
      });
      debugPrint('Error fetching user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchUserData,
            ),
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/edit_profile');
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade900, Colors.grey.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isChecking
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : !_isAuthenticated
                ? const Center(
                    child: Text(
                      'Please log in to view your profile',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red, fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchUserData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Center(
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: Text(
                                          _userData!['name']?[0] ?? 'A',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _userData!['name'] ?? 'User',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _userData!['email'] ?? 'Not set',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Personal Info Card
                                _buildSectionTitle('Personal Information'),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Colors.white.withOpacity(0.1),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildProfileField(Icons.cake, 'Age', _userData!['age']?.toString() ?? 'Not set'),
                                        _buildProfileField(Icons.person, 'Gender', _userData!['gender'] ?? 'Not set'),
                                        _buildProfileField(Icons.height, 'Height', _userData!['height'] != null ? '${_userData!['height']} cm' : 'Not set'),
                                        _buildProfileField(Icons.fitness_center, 'Weight', _userData!['weight'] != null ? '${_userData!['weight']} kg' : 'Not set'),
                                        _buildProfileField(Icons.flag, 'Goal', _userData!['goal'] ?? 'Not set'),
                                        _buildProfileField(Icons.directions_run, 'Activity Level', _userData!['activity_level'] ?? 'Not set'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Preferences Card
                                _buildSectionTitle('Preferences'),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Colors.white.withOpacity(0.1),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildProfileField(Icons.restaurant, 'Preferred Cuisine', _userData!['preferred_cuisine'] ?? 'Not set'),
                                        _buildProfileField(
                                          Icons.warning,
                                          'Allergies',
                                          _userData!['allergies'] == null || (_userData!['allergies'] as List).isEmpty
                                              ? 'None'
                                              : (_userData!['allergies'] as List<dynamic>).join(', '),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Daily Targets Card
                                _buildSectionTitle('Daily Targets (Auto-Calculated)'),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Colors.white.withOpacity(0.1),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 3,
                                      children: [
                                        _buildMacroChip('Calories', '${_userData!['daily_calories'] ?? 0} kcal', Colors.orange),
                                        _buildMacroChip('Protein', '${_userData!['daily_protein'] ?? 0} g', Colors.blue),
                                        _buildMacroChip('Carbs', '${_userData!['daily_carbs'] ?? 0} g', Colors.green),
                                        _buildMacroChip('Fat', '${_userData!['daily_fat'] ?? 0} g', Colors.purple),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Chip(
      label: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
      backgroundColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}