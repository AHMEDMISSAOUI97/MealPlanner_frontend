import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MealGeneratorScreen extends StatefulWidget {
  const MealGeneratorScreen({super.key});

  @override
  State<MealGeneratorScreen> createState() => _MealGeneratorScreenState();
}

class _MealGeneratorScreenState extends State<MealGeneratorScreen> with SingleTickerProviderStateMixin {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _mealData;
  List<String>? _imageUrls;

  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _ingredientSearchController = TextEditingController();
  String? _mealType;

  List<Map<String, dynamic>> _selectedIngredients = [];
  List<Map<String, dynamic>> _ingredientSuggestions = [];
  List<TextEditingController> _quantityControllers = [];

  String? _caloriesError;
  String? _proteinError;
  String? _carbsError;

  final List<String> _units = ['grams', 'tbsp', 'ml', 'liters', 'pieces'];

  int _currentStep = 0;
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
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
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    setState(() {
      _isAuthenticated = token != null;
      _isChecking = false;
    });
    if (!_isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _animationController.forward();
    }
  }

  Future<void> _fetchIngredientSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _ingredientSuggestions = [];
      });
      return;
    }

    try {
      final apiKey = dotenv.env['USDA_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        setState(() {
          _ingredientSuggestions = [];
          _error = 'USDA API key not found.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.nal.usda.gov/fdc/v1/foods/search?query=$query&api_key=$apiKey&pageSize=5'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final suggestions = List<Map<String, dynamic>>.from(data['foods']).map((food) {
            return {'name': food['description']};
          }).toList();

          final uniqueSuggestions = suggestions
              .asMap()
              .entries
              .map((entry) => entry.value['name'])
              .toSet()
              .map((name) => {'name': name})
              .toList();

          _ingredientSuggestions = uniqueSuggestions.length > 5 ? uniqueSuggestions.sublist(0, 5) : uniqueSuggestions;
        });
      } else {
        setState(() {
          _ingredientSuggestions = [];
          _error = 'Failed to fetch ingredients: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _ingredientSuggestions = [];
        _error = 'Error fetching ingredients: $e';
      });
    }
  }

  void _addIngredient(Map<String, dynamic> ingredient) {
    setState(() {
      _selectedIngredients.add({
        'name': ingredient['name'],
        'quantity': '',
        'unit': ingredient['name'].toLowerCase().contains('tomato') || ingredient['name'].toLowerCase().contains('potato') ? 'pieces' : 'grams',
      });
      _quantityControllers.add(TextEditingController());
      _ingredientSearchController.clear();
      _ingredientSuggestions = [];
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _selectedIngredients.removeAt(index);
      _quantityControllers[index].dispose();
      _quantityControllers.removeAt(index);
    });
  }

  void _updateQuantity(int index, String quantity) {
    String cleanedValue = quantity.replaceFirst(RegExp(r'^0+(?!$)'), '');
    if (cleanedValue.isEmpty) cleanedValue = '0';
    setState(() {
      _selectedIngredients[index]['quantity'] = cleanedValue;
    });
  }

  void _updateUnit(int index, String unit) {
    setState(() {
      _selectedIngredients[index]['unit'] = unit;
    });
  }

  Future<void> _generateMeal() async {
    if (_mealType == null) {
      setState(() {
        _error = 'Please select a meal type.';
      });
      return;
    }
    if (_caloriesController.text.isEmpty || int.tryParse(_caloriesController.text)! < 100) {
      setState(() {
        _error = 'Calories must be at least 100.';
      });
      return;
    }
    if (_proteinController.text.isEmpty || int.tryParse(_proteinController.text)! < 0) {
      setState(() {
        _error = 'Protein must be at least 0.';
      });
      return;
    }
    if (_carbsController.text.isEmpty || int.tryParse(_carbsController.text)! < 0) {
      setState(() {
        _error = 'Carbs must be at least 0.';
      });
      return;
    }
    if (_selectedIngredients.isEmpty) {
      setState(() {
        _error = 'Please add at least one ingredient.';
      });
      return;
    }
    for (var ing in _selectedIngredients) {
      if (ing['quantity'].isEmpty || double.tryParse(ing['quantity']) == null || double.parse(ing['quantity']) <= 0) {
        setState(() {
          _error = 'Please enter a valid quantity for all ingredients.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _mealData = null;
      _imageUrls = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Authentication token not found. Please log in again.';
        _isAuthenticated = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final payload = {
      'meal_type': _mealType,
      'calories': int.parse(_caloriesController.text),
      'protein': int.parse(_proteinController.text),
      'carbs': int.parse(_carbsController.text),
      'ingredients': _selectedIngredients.map((ing) {
        final quantity = double.parse(ing['quantity']);
        final unit = ing['unit'] == 'grams' ? 'gramme' : ing['unit'];
        return '${quantity.toInt()} $unit ${ing['name'].toLowerCase()}';
      }).toList(),
      'ingredient_details': _selectedIngredients.map((ing) {
        return {
          'name': ing['name'],
          'quantity': double.parse(ing['quantity']),
          'unit': ing['unit'],
        };
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/ai-meal/openai'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _mealData = data['meal_plan']['meal'];
          _imageUrls = List<String>.from(data['images_link']);
          _isLoading = false;
          _currentStep = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to generate meal';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToFavorites() async {
    if (_mealData == null) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList('favorites') ?? [];
    final mealEntry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'mealData': _mealData,
      'imageUrls': _imageUrls,
    };
    favorites.add(json.encode(mealEntry));
    await prefs.setStringList('favorites', favorites);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meal saved to favorites!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(child: Text('Image failed to load')),
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    final formKey = _formKeys[_currentStep];
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
      _currentStep--;
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _ingredientSearchController.dispose();
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'Meal Generator',
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of 3',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / 3,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == 0) _buildStep1(),
                          if (_currentStep == 1) _buildStep2(),
                          if (_currentStep == 2 && _mealData != null) _buildStep3(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildStep1() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKeys[0],
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
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.restaurant_menu, color: Colors.white70),
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
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                  DropdownMenuItem(value: 'snack', child: Text('Snack')),
                  DropdownMenuItem(value: 'post_workout', child: Text('Post-Workout')),
                  DropdownMenuItem(value: 'pre_workout', child: Text('Pre-Workout')),
                ],
                onChanged: (value) {
                  setState(() {
                    _mealType = value;
                  });
                },
                value: _mealType,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _caloriesController,
                label: 'Target Calories (kcal)',
                icon: Icons.local_fire_department,
                errorText: _caloriesError,
                hintText: 'Enter at least 100',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? calories = int.tryParse(value);
                  setState(() {
                    _caloriesError = calories == null || calories < 100 ? 'Must be ≥ 100' : null;
                  });
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _proteinController,
                label: 'Target Protein (g)',
                icon: Icons.fitness_center,
                errorText: _proteinError,
                hintText: 'Enter at least 0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? protein = int.tryParse(value);
                  setState(() {
                    _proteinError = protein == null || protein < 0 ? 'Must be ≥ 0' : null;
                  });
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _carbsController,
                label: 'Target Carbs (g)',
                icon: Icons.bakery_dining,
                errorText: _carbsError,
                hintText: 'Enter at least 0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? carbs = int.tryParse(value);
                  setState(() {
                    _carbsError = carbs == null || carbs < 0 ? 'Must be ≥ 0' : null;
                  });
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _nextStep(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKeys[1],
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
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  await _fetchIngredientSuggestions(textEditingValue.text);
                  return _ingredientSuggestions;
                },
                displayStringForOption: (option) => option['name'],
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Search Ingredient (e.g., pasta)',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.fastfood, color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      hintText: 'e.g., pasta, olive oil',
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      _ingredientSearchController.text = value;
                    },
                    onSubmitted: (value) {
                      if (_ingredientSuggestions.isNotEmpty) {
                        _addIngredient(_ingredientSuggestions[0]);
                        controller.clear();
                        setState(() {});
                        onFieldSubmitted();
                      }
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: 200,
                        ),
                        child: Material(
                          elevation: 4,
                          color: Colors.grey.shade800,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  leading: const Icon(Icons.fastfood, color: Colors.white70),
                                  title: Text(
                                    option['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                    _addIngredient(option);
                                    _ingredientSearchController.clear();
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              ..._selectedIngredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ingredient = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ingredient['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: _quantityControllers[index],
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
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
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          String cleanedValue = value.replaceFirst(RegExp(r'^0+(?!$)'), '');
                                          if (cleanedValue.isEmpty) cleanedValue = '0';
                                          _updateQuantity(index, cleanedValue);
                                          _quantityControllers[index].text = cleanedValue;
                                          _quantityControllers[index].selection = TextSelection.fromPosition(
                                            TextPosition(offset: cleanedValue.length),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    DropdownButton<String>(
                                      value: ingredient['unit'],
                                      dropdownColor: Colors.grey.shade800,
                                      style: const TextStyle(color: Colors.white),
                                      items: _units
                                          .map((unit) => DropdownMenuItem(
                                                value: unit,
                                                child: Text(unit),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updateUnit(index, value);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _removeIngredient(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateMeal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Generate Meal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Generated Meal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: _previousStep,
              child: const Text(
                'Back',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_imageUrls != null && _imageUrls!.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls!.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showFullScreenImage(_imageUrls![index]),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _imageUrls![index],
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(child: Text('Image failed to load')),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mealData!['name'],
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3,
                  children: [
                    _buildMacroChip('Calories', '${_mealData!['calories']} kcal', Colors.orange),
                    _buildMacroChip('Protein', '${_mealData!['protein']} g', Colors.blue),
                    _buildMacroChip('Carbs', '${_mealData!['carbs']} g', Colors.green),
                    _buildMacroChip('Fat', '${_mealData!['fat']} g', Colors.purple),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ...List<Map<String, dynamic>>.from(_mealData!['ingredients']).map((ingredient) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ingredient['name']} (${ingredient['quantity']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Calories: ${ingredient['calories']} kcal',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'Protein: ${ingredient['protein']} g',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'Carbs: ${ingredient['carbs']} g',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'Fat: ${ingredient['fat']} g',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  children: List<String>.from(_mealData!['instructions']).asMap().entries.map((entry) {
                    final index = entry.key;
                    final instruction = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              instruction,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveToFavorites,
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share functionality not implemented')),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? errorText,
    required String hintText,
    required TextInputType keyboardType,
    required Function(String) onChanged,
    required TextInputAction textInputAction,
  }) {
    return TextFormField(
      controller: controller,
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
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.red),
      ),
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      onChanged: onChanged,
      textInputAction: textInputAction,
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Chip(
      label: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      backgroundColor: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}