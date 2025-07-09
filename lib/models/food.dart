import 'package:cloud_firestore/cloud_firestore.dart';

class Food {
  String? id; // Para identificar el documento en Firestore
  String nombre;
  String tipo;
  double cantidadReferencia;
  double kcal;
  double proteinas;
  double carbohidratos;
  double grasas;

  Food({
    this.id,
    required this.nombre,
    required this.tipo,
    required this.cantidadReferencia,
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });

  factory Food.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return Food(
      id: documentId,
      nombre: json['nombre'] ?? '',
      tipo: json['tipo'] ?? '',
      cantidadReferencia: (json['cantidad_referencia'] ?? 0).toDouble(),
      kcal: (json['kcal'] ?? 0).toDouble(),
      proteinas: (json['proteinas'] ?? 0).toDouble(),
      carbohidratos: (json['carbohidratos'] ?? 0).toDouble(),
      grasas: (json['grasas'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'tipo': tipo,
      'cantidad_referencia': cantidadReferencia,
      'kcal': kcal,
      'proteinas': proteinas,
      'carbohidratos': carbohidratos,
      'grasas': grasas,
    };
  }

  // Método para calcular macros por cantidad específica
  Map<String, double> calculateMacrosForQuantity(double quantity) {
    final factor = quantity / cantidadReferencia;
    return {
      'kcal': kcal * factor,
      'proteinas': proteinas * factor,
      'carbohidratos': carbohidratos * factor,
      'grasas': grasas * factor,
    };
  }

  @override
  String toString() {
    return 'Food(nombre: $nombre, tipo: $tipo, cantidad_referencia: ${cantidadReferencia}g, kcal: $kcal, proteinas: ${proteinas}g, carbohidratos: ${carbohidratos}g, grasas: ${grasas}g)';
  }
} 