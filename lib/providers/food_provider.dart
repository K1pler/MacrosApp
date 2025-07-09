import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food.dart';

class FoodProvider extends ChangeNotifier {
  List<Food> _foods = [];
  bool _loading = false;
  String? _error;

  List<Food> get foods => _foods;
  bool get loading => _loading;
  String? get error => _error;

  // Tipos de alimentos predefinidos
  final List<String> foodTypes = [
    'Carne',
    'Verdura',
    'Lácteo',
    'Cereal',
    'Fruta',
    'Legumbre',
    'Fruto Seco',
    'Pescado',
    'Dulce',
    'Bebida',
    'Otro',
  ];

  Future<void> loadFoodsFromFirestore() async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('alimentos')
          .orderBy('nombre')
          .get();
      
      _foods = querySnapshot.docs.map((doc) {
        return Food.fromJson(doc.data(), documentId: doc.id);
      }).toList();
    } catch (e) {
      _error = 'Error al cargar alimentos: $e';
    }
    
    _loading = false;
    notifyListeners();
  }

  Future<bool> addFood(Food food) async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('alimentos')
          .add(food.toJson());
      
      // Añadir el alimento a la lista local con el ID generado
      food.id = docRef.id;
      _foods.add(food);
      _foods.sort((a, b) => a.nombre.compareTo(b.nombre));
      
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al añadir alimento: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addMultipleFoods(List<Food> foods) async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('alimentos');
      
      // Añadir cada alimento al batch
      for (Food food in foods) {
        final docRef = collection.doc(); // Genera un ID único
        batch.set(docRef, food.toJson());
        food.id = docRef.id; // Asignar el ID generado
      }
      
      // Ejecutar todas las operaciones en una sola transacción
      await batch.commit();
      
      // Añadir los alimentos a la lista local
      _foods.addAll(foods);
      _foods.sort((a, b) => a.nombre.compareTo(b.nombre));
      
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al añadir alimentos: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateFood(Food food) async {
    if (food.id == null) return false;
    
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      await FirebaseFirestore.instance
          .collection('alimentos')
          .doc(food.id!)
          .update(food.toJson());
      
      // Actualizar en la lista local
      final index = _foods.indexWhere((f) => f.id == food.id);
      if (index != -1) {
        _foods[index] = food;
        _foods.sort((a, b) => a.nombre.compareTo(b.nombre));
      }
      
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar alimento: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFood(String foodId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      await FirebaseFirestore.instance
          .collection('alimentos')
          .doc(foodId)
          .delete();
      
      // Eliminar de la lista local
      _foods.removeWhere((food) => food.id == foodId);
      
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar alimento: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  List<Food> searchFoods(String query) {
    if (query.isEmpty) return _foods;
    
    return _foods.where((food) {
      return food.nombre.toLowerCase().contains(query.toLowerCase()) ||
             food.tipo.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  List<Food> getFoodsByType(String type) {
    return _foods.where((food) => food.tipo == type).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 