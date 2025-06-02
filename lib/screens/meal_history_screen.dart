import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> with SingleTickerProviderStateMixin {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  bool _isLoading = false;
  String? _error;
  List<dynamic> _allMeals = [];
  List<dynamic> _favoriteMeals = [];
  final Set<int> _expandedMeals = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        await Future.wait([_fetchAllMeals(), _fetchFavoriteMeals()]);
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

  Future<void> _fetchAllMeals() async {
    debugPrint('Fetching all meals');
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
        Uri.parse('http://localhost:8080/api/meals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('All meals fetch response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        setState(() {
          _allMeals = json.decode(resp.body);
          _isLoading = false;
        });
        debugPrint('All meals fetched successfully: ${_allMeals.length} meals');
      } else {
        setState(() {
          _error = 'Failed to load meals: ${resp.statusCode}';
          _isLoading = false;
        });
        debugPrint('Failed to fetch all meals: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching meals: $e';
        _isLoading = false;
      });
      debugPrint('Error fetching all meals: $e');
    }
  }

  Future<void> _fetchFavoriteMeals() async {
    debugPrint('Fetching favorite meals');
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
        Uri.parse('http://localhost:8080/api/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Favorite meals fetch response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        setState(() {
          _favoriteMeals = json.decode(resp.body);
          _isLoading = false;
        });
        debugPrint('Favorite meals fetched successfully: ${_favoriteMeals.length} meals');
      } else {
        setState(() {
          _error = 'Failed to load favorite meals: ${resp.statusCode}';
          _isLoading = false;
        });
        debugPrint('Failed to fetch favorite meals: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching favorite meals: $e';
        _isLoading = false;
      });
      debugPrint('Error fetching favorite meals: $e');
    }
  }

  Future<void> _toggleFavorite(int mealId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _error = 'Authentication token not found. Please log in again.';
          _isAuthenticated = false;
        });
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final resp = await http.post(
        Uri.parse('http://localhost:8080/api/favorites/$mealId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Toggle favorite response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        // Refresh both all meals and favorites to reflect the change
        await Future.wait([_fetchAllMeals(), _fetchFavoriteMeals()]);
      } else {
        setState(() {
          _error = 'Failed to toggle favorite: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error toggling favorite: $e';
      });
      debugPrint('Error toggling favorite: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meal History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All Meals'),
            Tab(text: 'Favorites'),
          ],
        ),
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
                      'Please log in to view your meal history',
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
                                  onPressed: () async {
                                    await Future.wait([_fetchAllMeals(), _fetchFavoriteMeals()]);
                                  },
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
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              // All Meals Tab
                              _buildMealList(_allMeals),
                              // Favorites Tab
                              _buildMealList(_favoriteMeals, isFavoritesTab: true),
                            ],
                          ),
      ),
    );
  }

  Widget _buildMealList(List<dynamic> meals, {bool isFavoritesTab = false}) {
    if (meals.isEmpty) {
      return Center(
        child: Text(
          isFavoritesTab ? 'No favorite meals yet.' : 'No meals found.',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        final isExpanded = _expandedMeals.contains(index);
        final isFavorited = _favoriteMeals.any((fav) => fav['id'] == meal['id']);
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white.withOpacity(0.1),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal['name'] ?? 'Unnamed Meal',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meal['meal_type'] != null
                                ? '${meal['meal_type'][0].toUpperCase()}${meal['meal_type'].substring(1)}'
                                : 'N/A',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorited ? Icons.favorite : Icons.favorite_border,
                            color: isFavorited ? Colors.red : Colors.white70,
                          ),
                          onPressed: () => _toggleFavorite(meal['id']),
                        ),
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedMeals.remove(index);
                              } else {
                                _expandedMeals.add(index);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Macros
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMacroChip('Calories', '${meal['calories'] ?? 'N/A'} kcal', Colors.orange),
                    _buildMacroChip('Protein', '${meal['protein'] ?? 'N/A'} g', Colors.blue),
                    _buildMacroChip('Carbs', '${meal['carbs'] ?? 'N/A'} g', Colors.green),
                    _buildMacroChip('Fat', '${meal['fat'] ?? 'N/A'} g', Colors.purple),
                  ],
                ),
                const SizedBox(height: 8),
                // Date
                Text(
                  meal['created_at'] != null
                      ? 'Added on: ${DateTime.parse(meal['created_at']).toString().split(' ')[0]}'
                      : 'Date: N/A',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                // Expanded Details
                if (isExpanded) ...[
                  const Divider(color: Colors.white70),
                  const SizedBox(height: 8),
                  // Ingredients
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...?meal['ingredients'] != null
                      ? (json.decode(meal['ingredients']) as List<dynamic>).map((ingredient) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_right, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${ingredient['name']}: ${ingredient['quantity']} '
                                    '(Calories: ${ingredient['calories']} kcal, '
                                    'Protein: ${ingredient['protein']} g, '
                                    'Carbs: ${ingredient['carbs']} g, '
                                    'Fat: ${ingredient['fat']} g)',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      : [const Text('No ingredients available', style: TextStyle(color: Colors.white70))],
                  const SizedBox(height: 16),
                  // Instructions
                  const Text(
                    'Instructions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...?meal['instructions'] != null
                      ? (json.decode(meal['instructions']) as List<dynamic>).asMap().entries.map((entry) {
                          final stepIndex = entry.key + 1;
                          final instruction = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$stepIndex. ',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Expanded(
                                  child: Text(
                                    instruction,
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      : [const Text('No instructions available', style: TextStyle(color: Colors.white70))],
                  const SizedBox(height: 16),
                  // Images (if available)
                  if (meal['images'] != null && (meal['images'] as List).isNotEmpty) ...[
                    const Text(
                      'Images',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (meal['images'] as List).length,
                        itemBuilder: (context, imgIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                meal['images'][imgIndex],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey,
                                    child: const Center(
                                      child: Icon(Icons.error, color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
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
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
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