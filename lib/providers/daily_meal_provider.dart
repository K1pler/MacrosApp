import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_meal.dart';
import '../models/food.dart';

class DailyMealProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;
  
  DailyMeal? _currentDayMeal;
  List<Food> _availableFoods = [];
  List<Food> _filteredFoods = [];
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  
  // Cache para evitar múltiples lecturas del mismo día
  final Map<String, DailyMeal> _mealsCache = {};
  // Cache para alimentos (se carga una sola vez)
  bool _foodsLoaded = false;

  DailyMealProvider({required this.userId}) {
    _loadTodayMeal();
  }

  // Getters
  DailyMeal? get currentDayMeal => _currentDayMeal;
  List<Food> get availableFoods => _availableFoods;
  List<Food> get filteredFoods => _filteredFoods;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;

  // Cargar alimentos solo una vez y cachearlos
  Future<void> loadFoods() async {
    if (_foodsLoaded) return;
    
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore.collection('alimentos').get();
      _availableFoods = snapshot.docs
          .map((doc) => Food.fromJson(doc.data(), documentId: doc.id))
          .toList();
      
      _filteredFoods = List.from(_availableFoods);
      _foodsLoaded = true;
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error cargando alimentos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filtrar alimentos por tipo y/o texto
  void filterFoods({String? tipo, String? searchText}) {
    _filteredFoods = _availableFoods.where((food) {
      bool matchesTipo = tipo == null || tipo.isEmpty || food.tipo == tipo;
      bool matchesText = searchText == null || 
          searchText.isEmpty || 
          food.nombre.toLowerCase().contains(searchText.toLowerCase());
      return matchesTipo && matchesText;
    }).toList();
    notifyListeners();
  }

  // Cambiar fecha seleccionada
  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = date;
    await _loadMealForDate(date);
    notifyListeners();
  }

  // Cargar comida del día actual
  Future<void> _loadTodayMeal() async {
    await _loadMealForDate(DateTime.now());
  }

  // Cargar comida para una fecha específica (con cache)
  Future<void> _loadMealForDate(DateTime date) async {
    final documentId = DailyMeal.getDocumentId(userId, date);
    
    // Verificar cache primero
    if (_mealsCache.containsKey(documentId)) {
      _currentDayMeal = _mealsCache[documentId];
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _firestore
          .collection('comidas_diarias')
          .doc(documentId)
          .get();

      if (doc.exists) {
        _currentDayMeal = DailyMeal.fromJson(doc.data()!, documentId: doc.id);
        _mealsCache[documentId] = _currentDayMeal!;
      } else {
        // Crear nuevo registro para el día
        _currentDayMeal = DailyMeal(
          userId: userId,
          date: date,
          consumedFoods: [],
          totalKcal: 0,
          totalProteinas: 0,
          totalCarbohidratos: 0,
          totalGrasas: 0,
        );
      }
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error cargando comida del día: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Añadir alimento consumido
  Future<void> addConsumedFood(Food food, double quantity) async {
    if (_currentDayMeal == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Calcular valores nutricionales para la cantidad especificada
      final ratio = quantity / food.cantidadReferencia;
      final consumedFood = ConsumedFood(
        foodId: food.id!,
        foodName: food.nombre,
        foodType: food.tipo,
        quantity: quantity,
        kcal: food.kcal * ratio,
        proteinas: food.proteinas * ratio,
        carbohidratos: food.carbohidratos * ratio,
        grasas: food.grasas * ratio,
      );

      _currentDayMeal!.consumedFoods.add(consumedFood);
      _currentDayMeal!.calculateTotals();

      await _saveDailyMeal();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error añadiendo alimento: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Eliminar alimento consumido
  Future<void> removeConsumedFood(int index) async {
    if (_currentDayMeal == null || index >= _currentDayMeal!.consumedFoods.length) return;

    try {
      _isLoading = true;
      notifyListeners();

      _currentDayMeal!.consumedFoods.removeAt(index);
      _currentDayMeal!.calculateTotals();

      await _saveDailyMeal();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error eliminando alimento: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar cantidad de alimento consumido
  Future<void> updateConsumedFoodQuantity(int index, double newQuantity) async {
    if (_currentDayMeal == null || index >= _currentDayMeal!.consumedFoods.length) return;

    try {
      _isLoading = true;
      notifyListeners();

      final consumedFood = _currentDayMeal!.consumedFoods[index];
      
      // Buscar el alimento original para recalcular
      final originalFood = _availableFoods.firstWhere(
        (food) => food.id == consumedFood.foodId,
        orElse: () => Food(
          nombre: consumedFood.foodName,
          tipo: consumedFood.foodType,
          cantidadReferencia: 100,
          kcal: consumedFood.kcal / (consumedFood.quantity / 100),
          proteinas: consumedFood.proteinas / (consumedFood.quantity / 100),
          carbohidratos: consumedFood.carbohidratos / (consumedFood.quantity / 100),
          grasas: consumedFood.grasas / (consumedFood.quantity / 100),
        ),
      );

      final ratio = newQuantity / originalFood.cantidadReferencia;
      consumedFood.quantity = newQuantity;
      consumedFood.kcal = originalFood.kcal * ratio;
      consumedFood.proteinas = originalFood.proteinas * ratio;
      consumedFood.carbohidratos = originalFood.carbohidratos * ratio;
      consumedFood.grasas = originalFood.grasas * ratio;

      _currentDayMeal!.calculateTotals();
      await _saveDailyMeal();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error actualizando cantidad: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar comida diaria en Firestore (optimizado)
  Future<void> _saveDailyMeal() async {
    if (_currentDayMeal == null) return;

    final documentId = DailyMeal.getDocumentId(userId, _currentDayMeal!.date);
    
    await _firestore
        .collection('comidas_diarias')
        .doc(documentId)
        .set(_currentDayMeal!.toJson(), SetOptions(merge: true));

    // Actualizar cache
    _mealsCache[documentId] = _currentDayMeal!;
  }

  // Obtener tipos de alimentos únicos
  List<String> getFoodTypes() {
    return _availableFoods.map((food) => food.tipo).toSet().toList()..sort();
  }

  // Obtener estadísticas de la semana (para gráficos)
  Future<Map<String, List<double>>> getWeeklyStats() async {
    final endDate = _selectedDate;
    final startDate = endDate.subtract(const Duration(days: 6));
    
    List<double> kcalData = [];
    List<double> proteinData = [];
    List<double> carbData = [];
    List<double> fatData = [];

    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final documentId = DailyMeal.getDocumentId(userId, date);
      
      DailyMeal? meal = _mealsCache[documentId];
      
      if (meal == null) {
        try {
          final doc = await _firestore
              .collection('comidas_diarias')
              .doc(documentId)
              .get();
          
          if (doc.exists) {
            meal = DailyMeal.fromJson(doc.data()!, documentId: doc.id);
            _mealsCache[documentId] = meal;
          }
        } catch (e) {
          // Ignorar errores y usar valores por defecto
        }
      }

      kcalData.add(meal?.totalKcal ?? 0);
      proteinData.add(meal?.totalProteinas ?? 0);
      carbData.add(meal?.totalCarbohidratos ?? 0);
      fatData.add(meal?.totalGrasas ?? 0);
    }

    return {
      'kcal': kcalData,
      'proteinas': proteinData,
      'carbohidratos': carbData,
      'grasas': fatData,
    };
  }

  // Limpiar cache (para optimizar memoria)
  void clearOldCache() {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    _mealsCache.removeWhere((key, meal) => meal.date.isBefore(cutoffDate));
  }
} 