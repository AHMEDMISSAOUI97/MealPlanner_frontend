import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Form data
  String? _name, _email, _password, _confirm;
  String? _gender;
  int? _age, _height, _weight;
  String? _goal;
  String? _preferredCuisine;
  List<String> _allergies = [];
  String? _activityLevel;
  int? _birthYear;

  // Controllers for each field
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // State variables
  int _currentStep = 0;
  bool _loading = false;
  String? _error;
  bool _showPassword = false;
  bool _showConfirm = false;

  // Form keys for each step
  final _formKeys = List.generate(12, (_) => GlobalKey<FormState>());

  // Predefined lists
  final List<String> _availableAllergies = [
    'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 'Wheat', 'Soy', 'Fish', 'Shellfish', 'Sesame', 'Gluten',
  ];

  final List<String> _availableCuisines = [
    'Italian', 'Chinese', 'Indian', 'Mexican', 'Japanese', 'Thai', 'French', 'Mediterranean', 'American',
    'Korean', 'Vietnamese', 'Greek', 'Spanish', 'Tunisian', 'Lebanese',
  ];

  final List<String> _activityLevels = ['sedentary', 'light', 'moderate', 'active', 'very_active'];
  final List<String> _goals = ['Lose Weight', 'Gain Weight', 'Healthy Eating'];
  final List<String> _genders = ['male', 'female'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _nextStep(GlobalKey<FormState> formKey) {
    if (formKey.currentState == null || formKey.currentState!.validate()) {
      if (formKey.currentState != null) {
        formKey.currentState!.save();
      }
      setState(() {
        _currentStep++;
        _animationController.reset();
        _animationController.forward();
      });
    }
  }

  void _previousStep() {
    setState(() {
      // Reset dropdown values when navigating back to ensure they are valid
      if (_currentStep == 4) _gender = null; // Gender step
      if (_currentStep == 8) _goal = null; // Goal step
      if (_currentStep == 9) _preferredCuisine = null; // Preferred Cuisine step
      if (_currentStep == 10) _activityLevel = null; // Activity Level step
      _currentStep--;
      _animationController.reset();
      _animationController.forward();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final payload = {
      'name': _name,
      'email': _email,
      'password': _password,
      'password_confirmation': _confirm,
      'gender': _gender,
      'age': _age,
      'height': _height,
      'weight': _weight,
      'goal': _goal,
      'preferred_cuisine': _preferredCuisine,
      'allergies': _allergies,
      'activity_level': _activityLevel,
    };

    final resp = await http.post(
      Uri.parse('http://localhost:8080/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    final data = json.decode(resp.body);
    if (resp.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message']),
          action: SnackBarAction(
            label: 'Go to Login',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    } else {
      setState(() {
        _error = (data['errors']?.values.first?.first) ?? data['message'];
        _currentStep = 0; // Reset to first step to show error
      });
    }

    setState(() {
      _loading = false;
    });
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

  void _selectBirthYear() {
    _birthYear = _birthYear ?? 2000; // Set initial value to 2000
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            width: 300,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _age = 2025 - (_birthYear ?? 2000);
                            _nextStep(_formKeys[5]); // Use the form key for the age step
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Done', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: 100), // 2000 - 1900 = 100
                    itemExtent: 32,
                    onSelectedItemChanged: (index) {
                      _birthYear = 1900 + index;
                    },
                    children: List.generate(126, (index) => 1900 + index)
                        .map((year) => Center(
                              child: Text(
                                year.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 20),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectHeight() {
    _height = _height ?? 170; // Set initial value to 170 cm
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            width: 300,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _height = _height ?? 170;
                            _nextStep(_formKeys[6]); // Use the form key for the height step
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Done', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: 20), // 170 - 150 = 20
                    itemExtent: 32,
                    onSelectedItemChanged: (index) {
                      _height = 150 + index;
                    },
                    children: List.generate(101, (index) => 150 + index)
                        .map((height) => Center(
                              child: Text(
                                '$height cm',
                                style: const TextStyle(color: Colors.white, fontSize: 20),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectWeight() {
    _weight = _weight ?? 70; // Set initial value to 70 kg
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            width: 300,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _weight = _weight ?? 70;
                            _nextStep(_formKeys[7]); // Use the form key for the weight step
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Done', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: 20), // 70 - 50 = 20
                    itemExtent: 32,
                    onSelectedItemChanged: (index) {
                      _weight = 50 + index;
                    },
                    children: List.generate(151, (index) => 50 + index)
                        .map((weight) => Center(
                              child: Text(
                                '$weight kg',
                                style: const TextStyle(color: Colors.white, fontSize: 20),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = 12; // Steps: name, email, password, confirm, gender, age, height, weight, goal, cuisine, activity, allergies

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Up',
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
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of $totalSteps',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / totalSteps,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 350,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          _buildStep(),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_currentStep > 0)
                                ElevatedButton(
                                  onPressed: _previousStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Previous'),
                                ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: _loading
                                    ? null
                                    : (_currentStep == totalSteps - 1
                                        ? _submit
                                        : () => _nextStep(_formKeys[_currentStep])),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(_currentStep == totalSteps - 1 ? 'Sign Up' : 'Next'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text(
                              'Already have an account? Sign in',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0: // Name
        return Form(
          key: _formKeys[0],
          child: _buildTextField(
            Icons.person,
            'Name',
            _nameController,
            (v) => _name = v,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            formKey: _formKeys[0],
          ),
        );
      case 1: // Email
        return Form(
          key: _formKeys[1],
          child: _buildTextField(
            Icons.email,
            'Email',
            _emailController,
            (v) => _email = v,
            validator: (v) => v!.contains('@') ? null : 'Invalid email',
            keyboardType: TextInputType.emailAddress,
            formKey: _formKeys[1],
          ),
        );
      case 2: // Password
        return Form(
          key: _formKeys[2],
          child: _buildTextField(
            Icons.lock,
            'Password',
            _passwordController,
            (v) => _password = v,
            validator: (v) => v!.length >= 8 ? null : 'Min 8 characters',
            obscureText: !_showPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            onChanged: (v) => setState(() => _password = v),
            formKey: _formKeys[2],
          ),
        );
      case 3: // Confirm Password
        return Form(
          key: _formKeys[3],
          child: _buildTextField(
            Icons.lock_outline,
            'Confirm Password',
            _confirmController,
            (v) => _confirm = v,
            validator: (v) => v != _password ? 'Passwords must match' : null,
            obscureText: !_showConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirm ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
            onChanged: (v) => setState(() => _confirm = v),
            formKey: _formKeys[3],
          ),
        );
      case 4: // Gender
        return Form(
          key: _formKeys[4],
          child: _buildDropdownField(
            'Gender',
            _genders,
            _gender,
            (v) => setState(() => _gender = v),
            validator: (v) => v == null ? 'Select gender' : null,
            prefixIcon: const Icon(Icons.person_outline),
            formKey: _formKeys[4],
          ),
        );
      case 5: // Age (Birth Year Picker)
        return Column(
          children: [
            GestureDetector(
              onTap: _selectBirthYear,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake, color: Colors.white70),
                    const SizedBox(width: 16),
                    Text(
                      _birthYear != null ? 'Birth Year: $_birthYear' : 'Select Birth Year',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            if (_birthYear != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Age: ${2025 - _birthYear!}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        );
      case 6: // Height (Picker)
        return Column(
          children: [
            GestureDetector(
              onTap: _selectHeight,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.height, color: Colors.white70),
                    const SizedBox(width: 16),
                    Text(
                      _height != null ? 'Height: $_height cm' : 'Select Height',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 7: // Weight (Picker)
        return Column(
          children: [
            GestureDetector(
              onTap: _selectWeight,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monitor_weight, color: Colors.white70),
                    const SizedBox(width: 16),
                    Text(
                      _weight != null ? 'Weight: $_weight kg' : 'Select Weight',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 8: // Goal
        return Form(
          key: _formKeys[8],
          child: _buildDropdownField(
            'Goal',
            _goals,
            _goal,
            (v) => setState(() => _goal = v),
            validator: (v) => v == null ? 'Select a goal' : null,
            prefixIcon: const Icon(Icons.flag),
            formKey: _formKeys[8],
          ),
        );
      case 9: // Preferred Cuisine
        return Form(
          key: _formKeys[9],
          child: _buildDropdownField(
            'Preferred Cuisine',
            _availableCuisines,
            _preferredCuisine,
            (v) => setState(() => _preferredCuisine = v),
            validator: (v) => v == null ? 'Select a cuisine' : null,
            prefixIcon: const Icon(Icons.fastfood),
            formKey: _formKeys[9],
          ),
        );
      case 10: // Activity Level
        return Form(
          key: _formKeys[10],
          child: _buildDropdownField(
            'Activity Level',
            _activityLevels,
            _activityLevel,
            (v) => setState(() => _activityLevel = v),
            validator: (v) => v == null ? 'Select your activity level' : null,
            prefixIcon: const Icon(Icons.directions_run),
            formKey: _formKeys[10],
          ),
        );
      case 11: // Allergies
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildTextField(
    IconData icon,
    String label,
    TextEditingController controller,
    Function(String?) onSaved, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
    required GlobalKey<FormState> formKey,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _nextStep(formKey),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    String? currentValue,
    Function(String?) onChanged, {
    String? Function(String?)? validator,
    Widget? prefixIcon,
    required GlobalKey<FormState> formKey,
  }) {
    // Ensure currentValue matches an item in the list or is null
    if (currentValue != null && !items.contains(currentValue)) {
      currentValue = null;
      onChanged(null); // Reset the value in the state
    }

    return DropdownButtonFormField<String>(
      value: currentValue,
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
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      validator: validator,
      onChanged: (value) {
        setState(() {
          onChanged(value);
        });
        _nextStep(formKey);
      },
    );
  }
}