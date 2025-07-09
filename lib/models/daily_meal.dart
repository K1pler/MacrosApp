import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumedFood {
  String foodId;
  String foodName;
  String foodType;
  double quantity; // cantidad en gramos
  double kcal;
  double proteinas;
  double carbohidratos;
  double grasas;

  ConsumedFood({
    required this.foodId,
    required this.foodName,
    required this.foodType,
    required this.quantity,
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });

  factory ConsumedFood.fromJson(Map<String, dynamic> json) {
    return ConsumedFood(
      foodId: json['foodId'] ?? '',
      foodName: json['foodName'] ?? '',
      foodType: json['foodType'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      kcal: (json['kcal'] ?? 0).toDouble(),
      proteinas: (json['proteinas'] ?? 0).toDouble(),
      carbohidratos: (json['carbohidratos'] ?? 0).toDouble(),
      grasas: (json['grasas'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodId': foodId,
      'foodName': foodName,
      'foodType': foodType,
      'quantity': quantity,
      'kcal': kcal,
      'proteinas': proteinas,
      'carbohidratos': carbohidratos,
      'grasas': grasas,
    };
  }
}

class DailyMeal {
  String? id;
  String userId;
  DateTime date;
  List<ConsumedFood> consumedFoods;
  double totalKcal;
  double totalProteinas;
  double totalCarbohidratos;
  double totalGrasas;
  DateTime? lastUpdated;

  DailyMeal({
    this.id,
    required this.userId,
    required this.date,
    required this.consumedFoods,
    required this.totalKcal,
    required this.totalProteinas,
    required this.totalCarbohidratos,
    required this.totalGrasas,
    this.lastUpdated,
  });

  factory DailyMeal.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return DailyMeal(
      id: documentId,
      userId: json['userId'] ?? '',
      date: (json['date'] as Timestamp).toDate(),
      consumedFoods: (json['consumedFoods'] as List<dynamic>? ?? [])
          .map((item) => ConsumedFood.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalKcal: (json['totalKcal'] ?? 0).toDouble(),
      totalProteinas: (json['totalProteinas'] ?? 0).toDouble(),
      totalCarbohidratos: (json['totalCarbohidratos'] ?? 0).toDouble(),
      totalGrasas: (json['totalGrasas'] ?? 0).toDouble(),
      lastUpdated: json['lastUpdated'] != null 
          ? (json['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(_normalizeDate(date)),
      'consumedFoods': consumedFoods.map((food) => food.toJson()).toList(),
      'totalKcal': totalKcal,
      'totalProteinas': totalProteinas,
      'totalCarbohidratos': totalCarbohidratos,
      'totalGrasas': totalGrasas,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Normalizar fecha para evitar problemas de timezone
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Obtener el ID del documento basado en userId y fecha (optimización Firestore)
  static String getDocumentId(String userId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateString = normalizedDate.toIso8601String().split('T')[0];
    return '${userId}_$dateString';
  }

  // Calcular totales automáticamente
  void calculateTotals() {
    totalKcal = consumedFoods.fold(0, (acc, food) => acc + food.kcal);
    totalProteinas = consumedFoods.fold(0, (acc, food) => acc + food.proteinas);
    totalCarbohidratos = consumedFoods.fold(0, (acc, food) => acc + food.carbohidratos);
    totalGrasas = consumedFoods.fold(0, (acc, food) => acc + food.grasas);
  }

  // Obtener resumen de macros restantes basado en objetivos
  Map<String, double> getRemainingMacros(Map<String, double> goals) {
    return {
      'kcal': (goals['kcal'] ?? 0) - totalKcal,
      'proteinas': (goals['proteinas'] ?? 0) - totalProteinas,
      'carbohidratos': (goals['carbohidratos'] ?? 0) - totalCarbohidratos,
      'grasas': (goals['grasas'] ?? 0) - totalGrasas,
    };
  }

  // Obtener porcentaje de progreso hacia objetivos
  Map<String, double> getProgressPercentage(Map<String, double> goals) {
    return {
      'kcal': goals['kcal'] != 0 ? (totalKcal / goals['kcal']!) * 100 : 0,
      'proteinas': goals['proteinas'] != 0 ? (totalProteinas / goals['proteinas']!) * 100 : 0,
      'carbohidratos': goals['carbohidratos'] != 0 ? (totalCarbohidratos / goals['carbohidratos']!) * 100 : 0,
      'grasas': goals['grasas'] != 0 ? (totalGrasas / goals['grasas']!) * 100 : 0,
    };
  }
} 