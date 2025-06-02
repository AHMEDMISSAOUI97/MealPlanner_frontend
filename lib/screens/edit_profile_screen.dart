import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _userData;

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _gender;
  String? _goal;
  String? _activityLevel;
  String? _preferredCuisine;
  List<String> _allergies = [];

  // Predefined lists
  final List<String> _availableAllergies = [
    'Peanuts',
    'Tree Nuts',
    'Milk',
    'Eggs',
    'Wheat',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
    'Gluten',
  ];

  final List<String> _availableCuisines = [
    'Italian',
    'Chinese',
    'Indian',
    'Mexican',
    'Japanese',
    'Thai',
    'French',
    'Mediterranean',
    'American',
    'Korean',
    'Vietnamese',
    'Greek',
    'Spanish',
    'Tunisian',
    'Lebanese',
  ];

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
          _nameController.text = _userData!['name'] ?? '';
          _emailController.text = _userData!['email'] ?? '';
          _passwordController.text = ''; // Password is not fetched for security
          _passwordConfirmController.text = '';
          _ageController.text = _userData!['age']?.toString() ?? '';
          _heightController.text = _userData!['height']?.toString() ?? '';
          _weightController.text = _userData!['weight']?.toString() ?? '';
          _gender = _userData!['gender'];
          _goal = _userData!['goal'];
          _activityLevel = _userData!['activity_level'];
          _preferredCuisine = _userData!['preferred_cuisine'] ?? '';
          // Allergies is now a List<dynamic>, no need for json.decode
          _allergies = _userData!['allergies'] != null && (_userData!['allergies'] as List).isNotEmpty
              ? List<String>.from(_userData!['allergies'].map((item) => item.toString()))
              : [];
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
        _error = 'Error fetching user data: $e';
        _isLoading = false;
      });
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _updateProfile() async {
    debugPrint('Updating profile');
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
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final payload = {
        'name': _nameController.text,
        'email': _emailController.text,
        if (_passwordController.text.isNotEmpty) 'password': _passwordController.text,
        if (_passwordController.text.isNotEmpty) 'password_confirmation': _passwordConfirmController.text,
        'age': _ageController.text.isNotEmpty ? int.parse(_ageController.text) : null,
        'height': _heightController.text.isNotEmpty ? int.parse(_heightController.text) : null,
        'weight': _weightController.text.isNotEmpty ? int.parse(_weightController.text) : null,
        'gender': _gender,
        'goal': _goal,
        'activity_level': _activityLevel,
        'preferred_cuisine': _preferredCuisine,
        'allergies': _allergies,
      };

      final resp = await http.post(
        Uri.parse('http://localhost:8080/api/update-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      debugPrint('Profile update response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final responseData = json.decode(resp.body);
        if (responseData['message'].contains('Email or password updated')) {
          setState(() {
            _isLoading = false;
            _isAuthenticated = false;
          });
          Navigator.pushReplacementNamed(context, '/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email or password updated. Please verify your email and log in again.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully. Daily targets recalculated.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Failed to update profile: ${resp.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error updating profile: $e';
        _isLoading = false;
      });
      debugPrint('Error updating profile: $e');
    }
  }

  void _addAllergy(String allergy) {
    setState(() {
      if (allergy.isNotEmpty && !_allergies.contains(allergy)) {
        _allergies.add(allergy);
      }
    });
  }

  void _removeAllergy(String allergy) {
    setState(() {
      _allergies.remove(allergy);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
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
                      'Please log in to edit your profile',
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
                                        'Edit Your Profile',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
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
                                        if (_error != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        _buildTextField(Icons.person, 'Name', _nameController),
                                        const SizedBox(height: 16),
                                        _buildTextField(Icons.email, 'Email', _emailController),
                                        const SizedBox(height: 16),
                                        _buildTextField(Icons.lock, 'Password (leave blank to keep unchanged)', _passwordController, obscureText: true),
                                        const SizedBox(height: 16),
                                        _buildTextField(Icons.lock, 'Confirm Password', _passwordConfirmController, obscureText: true),
                                        const SizedBox(height: 16),
                                        _buildTextField(Icons.cake, 'Age', _ageController, keyboardType: TextInputType.number),
                                        const SizedBox(height: 16),
                                        _buildTextField(Icons.height, 'Height (cm)', _heightController, keyboardType: TextInputType.number),
                                        const SizedBox(height: 16),
                                        _buildTextField(Icons.fitness_center, 'Weight (kg)', _weightController, keyboardType: TextInputType.number),
                                        const SizedBox(height: 16),
                                        _buildDropdownField(
                                          'Gender',
                                          _gender,
                                          ['male', 'female'],
                                          (value) => setState(() => _gender = value),
                                          prefixIcon: const Icon(Icons.person_outline),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDropdownField(
                                          'Goal',
                                          _goal,
                                          ['Lose Weight', 'Gain Weight', 'Healthy Eating'],
                                          (value) => setState(() => _goal = value),
                                          prefixIcon: const Icon(Icons.flag),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDropdownField(
                                          'Activity Level',
                                          _activityLevel,
                                          ['sedentary', 'light', 'moderate', 'active', 'very_active'],
                                          (value) => setState(() => _activityLevel = value),
                                          prefixIcon: const Icon(Icons.directions_run),
                                        ),
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
                                        _buildDropdownField(
                                          'Preferred Cuisine',
                                          _preferredCuisine,
                                          _availableCuisines,
                                          (value) => setState(() => _preferredCuisine = value),
                                          prefixIcon: const Icon(Icons.fastfood),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Allergies',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          children: _allergies.map((allergy) {
                                            return Chip(
                                              label: Text(
                                                allergy,
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                              backgroundColor: Colors.white.withOpacity(0.2),
                                              onDeleted: () => _removeAllergy(allergy),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            labelText: 'Add Allergy',
                                            prefixIcon: Icon(Icons.warning_amber),
                                            labelStyle: TextStyle(color: Colors.white70),
                                            border: OutlineInputBorder(),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white70),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                            ),
                                          ),
                                          style: const TextStyle(color: Colors.white),
                                          dropdownColor: Colors.grey.shade800,
                                          items: _availableAllergies.map((allergy) {
                                            return DropdownMenuItem(
                                              value: allergy,
                                              child: Text(allergy),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              _addAllergy(value);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Save/Cancel Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _updateProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      child: const Text(
                                        'Save',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
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

  Widget _buildTextField(IconData icon, String label, TextEditingController controller, {bool obscureText = false, TextInputType keyboardType = TextInputType.text, Widget? prefixIcon}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, Function(String?) onChanged, {Widget? prefixIcon}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: prefixIcon,
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      dropdownColor: Colors.grey.shade800,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: const TextStyle(color: Colors.white)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}