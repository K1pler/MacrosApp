import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(BuildContext context)? onProfileSaved;
  const ProfileScreen({super.key, this.onProfileSaved});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _deficitController;
  String _sex = 'male';
  double _activityFactor = 1.2;
  String _macroPreset = 'equilibrado';
  
  final Map<String, Map<String, double>> _macroPresets = {
    'deficit': {'protein': 0.35, 'carbs': 0.35, 'fat': 0.30},
    'equilibrado': {'protein': 0.30, 'carbs': 0.40, 'fat': 0.30},
    'volumen': {'protein': 0.25, 'carbs': 0.50, 'fat': 0.25},
    'keto': {'protein': 0.25, 'carbs': 0.05, 'fat': 0.70},
    'alto_protein': {'protein': 0.40, 'carbs': 0.35, 'fat': 0.25},
  };

  Map<String, double> get _currentMacroDistribution => _macroPresets[_macroPreset]!;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _deficitController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      provider.loadProfileFromFirestore().then((_) {
        final profile = provider.profile;
        if (profile != null) {
          setState(() {
            _sex = profile.sex;
            _ageController.text = profile.age.toString();
            _weightController.text = profile.weight.toString();
            _heightController.text = profile.height.toString();
            _activityFactor = profile.activityFactor;
            _deficitController.text = profile.deficit.toString();
            // Detectar qué preset coincide mejor con la distribución guardada
            _macroPreset = _detectMacroPreset(profile.macroDistribution);
          });
        }
      });
    });
  }

  String _detectMacroPreset(Map<String, double> distribution) {
    for (String presetKey in _macroPresets.keys) {
      final preset = _macroPresets[presetKey]!;
      if ((distribution['protein']! - preset['protein']!).abs() < 0.05 &&
          (distribution['carbs']! - preset['carbs']!).abs() < 0.05 &&
          (distribution['fat']! - preset['fat']!).abs() < 0.05) {
        return presetKey;
      }
    }
    return 'equilibrado';
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _deficitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context);
    final loading = provider.loading;
    final error = provider.error;
    final goals = provider.goals;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(error, style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tus Datos', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _sex,
                            decoration: const InputDecoration(
                              labelText: 'Sexo',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Masculino')),
                              DropdownMenuItem(value: 'female', child: Text('Femenino')),
                            ],
                            onChanged: (v) => setState(() => _sex = v ?? 'male'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            decoration: const InputDecoration(
                              labelText: 'Edad (años)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Altura (cm)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<double>(
                            value: _activityFactor,
                            decoration: const InputDecoration(
                              labelText: 'Factor de Actividad',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1.2, child: Text('Sedentario (oficina, poco ejercicio)')),
                              DropdownMenuItem(value: 1.375, child: Text('Ligero (ejercicio 1-3 días/semana)')),
                              DropdownMenuItem(value: 1.55, child: Text('Moderado (ejercicio 3-5 días/semana)')),
                              DropdownMenuItem(value: 1.725, child: Text('Intenso (ejercicio 6-7 días/semana)')),
                              DropdownMenuItem(value: 1.9, child: Text('Muy Intenso (2x/día, muy físico)')),
                            ],
                            onChanged: (v) => setState(() => _activityFactor = v ?? 1.2),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _deficitController,
                            decoration: const InputDecoration(
                              labelText: 'Déficit/Superávit Calórico',
                              helperText: 'Negativo para déficit, positivo para superávit',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Distribución de Macros', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _macroPreset,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Dieta',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'deficit', child: Text('Déficit/Corte (35% P, 35% C, 30% G)')),
                              DropdownMenuItem(value: 'equilibrado', child: Text('Equilibrado (30% P, 40% C, 30% G)')),
                              DropdownMenuItem(value: 'volumen', child: Text('Volumen/Masa (25% P, 50% C, 25% G)')),
                              DropdownMenuItem(value: 'keto', child: Text('Cetogénica (25% P, 5% C, 70% G)')),
                              DropdownMenuItem(value: 'alto_protein', child: Text('Alto en Proteína (40% P, 35% C, 25% G)')),
                            ],
                            onChanged: (v) => setState(() => _macroPreset = v ?? 'equilibrado'),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Distribución actual:', style: TextStyle(color: Colors.grey[300])),
                                const SizedBox(height: 8),
                                Text('Proteínas: ${(_currentMacroDistribution['protein']! * 100).toInt()}%'),
                                Text('Carbohidratos: ${(_currentMacroDistribution['carbs']! * 100).toInt()}%'),
                                Text('Grasas: ${(_currentMacroDistribution['fat']! * 100).toInt()}%'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resultados Calculados', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 16),
                          if (goals != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Calorías Totales:', style: TextStyle(fontSize: 16)),
                                      Text('${goals.calories.toStringAsFixed(0)} kcal', 
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ],
                                  ),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Proteínas:'),
                                      Text('${goals.protein.toStringAsFixed(0)}g'),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Carbohidratos:'),
                                      Text('${goals.carbs.toStringAsFixed(0)}g'),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Grasas:'),
                                      Text('${goals.fat.toStringAsFixed(0)}g'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Completa tus datos y guarda para ver los resultados.',
                                style: TextStyle(color: Colors.white70)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              final profile = UserProfile(
                                sex: _sex,
                                age: int.tryParse(_ageController.text) ?? 0,
                                weight: double.tryParse(_weightController.text) ?? 0,
                                height: double.tryParse(_heightController.text) ?? 0,
                                activityFactor: _activityFactor,
                                deficit: double.tryParse(_deficitController.text) ?? 0,
                                macroDistribution: Map<String, double>.from(_currentMacroDistribution),
                              );
                              provider.updateProfile(profile);
                              provider.calculateGoals();
                              await provider.saveProfileToFirestore();
                              if (widget.onProfileSaved != null) {
                                widget.onProfileSaved!(context);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Guardar Objetivos', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
} 