import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String sex;
  int age;
  double weight;
  double height;
  double activityFactor;
  double deficit;
  Map<String, double> macroDistribution;

  UserProfile({
    required this.sex,
    required this.age,
    required this.weight,
    required this.height,
    required this.activityFactor,
    required this.deficit,
    required this.macroDistribution,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      sex: json['sex'] ?? '',
      age: json['age'] ?? 0,
      weight: (json['weight'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
      activityFactor: (json['activityFactor'] ?? 1.2).toDouble(),
      deficit: (json['deficit'] ?? 0).toDouble(),
      macroDistribution: Map<String, double>.from(json['macroDistribution'] ?? {
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
      }),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sex': sex,
      'age': age,
      'weight': weight,
      'height': height,
      'activityFactor': activityFactor,
      'deficit': deficit,
      'macroDistribution': macroDistribution,
    };
  }
}

class UserGoals {
  double calories;
  double protein;
  double carbs;
  double fat;

  UserGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory UserGoals.fromJson(Map<String, dynamic> json) {
    return UserGoals(
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
} 