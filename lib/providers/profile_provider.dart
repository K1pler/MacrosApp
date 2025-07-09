import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  final String uid;
  UserProfile? _profile;
  UserGoals? _goals;
  bool _loading = false;
  String? _error;

  ProfileProvider({required this.uid});

  UserProfile? get profile => _profile;
  UserGoals? get goals => _goals;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadProfileFromFirestore() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _profile = UserProfile.fromJson(data['profile'] ?? {});
        _goals = UserGoals.fromJson(data['goals'] ?? {});
      }
    } catch (e) {
      _error = 'Error al cargar perfil: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> saveProfileToFirestore() async {
    if (_profile == null || _goals == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'profile': _profile!.toJson(),
        'goals': _goals!.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = 'Error al guardar perfil: $e';
    }
    _loading = false;
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void calculateGoals() {
    if (_profile == null) return;
    
    // Usar fórmula Mifflin-St Jeor (más precisa que Harris-Benedict)
    final bmr = _calculateBMRMifflinStJeor(_profile!);
    
    // Calcular TDEE (Total Daily Energy Expenditure)
    final tdee = bmr * _profile!.activityFactor;
    
    // Aplicar déficit/superávit calórico
    final targetCalories = tdee + _profile!.deficit; // Nota: déficit puede ser negativo
    
    // Obtener distribución de macros
    final macros = _profile!.macroDistribution;
    
    // Calcular gramos de cada macronutriente
    // Proteína: 4 kcal/g, Carbohidratos: 4 kcal/g, Grasas: 9 kcal/g
    final proteinCalories = targetCalories * (macros['protein'] ?? 0);
    final carbsCalories = targetCalories * (macros['carbs'] ?? 0);
    final fatCalories = targetCalories * (macros['fat'] ?? 0);
    
    final proteinGrams = proteinCalories / 4;
    final carbsGrams = carbsCalories / 4;
    final fatGrams = fatCalories / 9;
    
    _goals = UserGoals(
      calories: targetCalories,
      protein: proteinGrams,
      carbs: carbsGrams,
      fat: fatGrams,
    );
    notifyListeners();
  }

  /// Fórmula Mifflin-St Jeor (más precisa que Harris-Benedict)
  /// Para hombres: BMR = (10 × peso en kg) + (6.25 × altura en cm) - (5 × edad en años) + 5
  /// Para mujeres: BMR = (10 × peso en kg) + (6.25 × altura en cm) - (5 × edad en años) - 161
  double _calculateBMRMifflinStJeor(UserProfile profile) {
    final baseMetabolism = (10 * profile.weight) + (6.25 * profile.height) - (5 * profile.age);
    
    if (profile.sex == 'male') {
      return baseMetabolism + 5;
    } else {
      return baseMetabolism - 161;
    }
  }

  /// Método alternativo: Fórmula Katch-McArdle (requiere % de grasa corporal)
  /// BMR = 370 + (21.6 × masa magra en kg)
  /// Más precisa si conoces el % de grasa corporal
  double _calculateBMRKatchMcArdle(UserProfile profile, double bodyFatPercentage) {
    final leanMass = profile.weight * (1 - bodyFatPercentage / 100);
    return 370 + (21.6 * leanMass);
  }

  /// Método para obtener información adicional del cálculo
  Map<String, double> getCalculationDetails() {
    if (_profile == null) return {};
    
    final bmr = _calculateBMRMifflinStJeor(_profile!);
    final tdee = bmr * _profile!.activityFactor;
    final targetCalories = tdee + _profile!.deficit;
    
    return {
      'bmr': bmr,
      'tdee': tdee,
      'targetCalories': targetCalories,
      'deficit': _profile!.deficit,
    };
  }
} 