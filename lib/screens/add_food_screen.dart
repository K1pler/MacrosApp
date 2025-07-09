import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/food.dart';
import '../providers/food_provider.dart';

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _jsonController = TextEditingController();
  
  // Controladores para formulario individual
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinasController = TextEditingController();
  final _carbohidratosController = TextEditingController();
  final _grasasController = TextEditingController();
  String _selectedType = 'Carne';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Cargar alimentos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FoodProvider>().loadFoodsFromFirestore();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jsonController.dispose();
    _nombreController.dispose();
    _cantidadController.dispose();
    _kcalController.dispose();
    _proteinasController.dispose();
    _carbohidratosController.dispose();
    _grasasController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nombreController.clear();
    _cantidadController.clear();
    _kcalController.clear();
    _proteinasController.clear();
    _carbohidratosController.clear();
    _grasasController.clear();
    setState(() {
      _selectedType = 'Carne';
    });
  }

  Future<void> _addSingleFood() async {
    if (!_formKey.currentState!.validate()) return;

    final food = Food(
      nombre: _nombreController.text.trim(),
      tipo: _selectedType,
      cantidadReferencia: double.parse(_cantidadController.text),
      kcal: double.parse(_kcalController.text),
      proteinas: double.parse(_proteinasController.text),
      carbohidratos: double.parse(_carbohidratosController.text),
      grasas: double.parse(_grasasController.text),
    );

    final success = await context.read<FoodProvider>().addFood(food);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Alimento añadido correctamente!'),
          backgroundColor: Colors.green,
        ),
      );
      _clearForm();
    }
  }

  Future<void> _addFoodsFromJson() async {
    try {
      final jsonText = _jsonController.text.trim();
      if (jsonText.isEmpty) {
        _showError('Por favor, introduce el JSON de alimentos');
        return;
      }

      final dynamic jsonData = json.decode(jsonText);
      List<Food> foods = [];

      if (jsonData is List) {
        // Array de alimentos
        for (var item in jsonData) {
          if (item is Map<String, dynamic>) {
            foods.add(Food.fromJson(item));
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // Un solo alimento
        foods.add(Food.fromJson(jsonData));
      } else {
        _showError('Formato JSON no válido');
        return;
      }

      if (foods.isEmpty) {
        _showError('No se encontraron alimentos válidos en el JSON');
        return;
      }

      final success = await context.read<FoodProvider>().addMultipleFoods(foods);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡${foods.length} alimento(s) añadido(s) correctamente!'),
            backgroundColor: Colors.green,
          ),
        );
        _jsonController.clear();
      }
    } catch (e) {
      _showError('Error al procesar JSON: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = context.watch<FoodProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Alimentos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Formulario'),
            Tab(icon: Icon(Icons.code), text: 'JSON'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (foodProvider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(foodProvider.error!, style: const TextStyle(color: Colors.red))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => foodProvider.clearError(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFormTab(foodProvider),
                _buildJsonTab(foodProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormTab(FoodProvider foodProvider) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información Básica',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del alimento',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fastfood),
                    ),
                    validator: (value) => value?.isEmpty == true ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de alimento',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: foodProvider.foodTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedType = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad de referencia (g)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Requerido';
                      if (double.tryParse(value!) == null) return 'Número válido requerido';
                      return null;
                    },
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
                  const Text(
                    'Información Nutricional',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _kcalController,
                    decoration: const InputDecoration(
                      labelText: 'Kilocalorías',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_fire_department),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Requerido';
                      if (double.tryParse(value!) == null) return 'Número válido requerido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _proteinasController,
                    decoration: const InputDecoration(
                      labelText: 'Proteínas (g)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Requerido';
                      if (double.tryParse(value!) == null) return 'Número válido requerido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _carbohidratosController,
                    decoration: const InputDecoration(
                      labelText: 'Carbohidratos (g)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.grain),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Requerido';
                      if (double.tryParse(value!) == null) return 'Número válido requerido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _grasasController,
                    decoration: const InputDecoration(
                      labelText: 'Grasas (g)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.opacity),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Requerido';
                      if (double.tryParse(value!) == null) return 'Número válido requerido';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: foodProvider.loading ? null : _addSingleFood,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: foodProvider.loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Añadir Alimento', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonTab(FoodProvider foodProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Añadir desde JSON',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes añadir uno o varios alimentos usando formato JSON:',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '''Ejemplo:
[
  {
    "nombre": "Pechuga de Pollo",
    "tipo": "Carne",
    "cantidad_referencia": 100,
    "kcal": 165,
    "proteinas": 31,
    "carbohidratos": 0,
    "grasas": 3.6
  }
]''',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _jsonController,
                  decoration: const InputDecoration(
                    labelText: 'JSON de alimentos',
                    border: OutlineInputBorder(),
                    hintText: 'Pega aquí el JSON con los alimentos...',
                  ),
                  maxLines: 10,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: foodProvider.loading ? null : _addFoodsFromJson,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: foodProvider.loading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Añadir desde JSON', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 16),
        if (foodProvider.foods.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alimentos guardados (${foodProvider.foods.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: foodProvider.foods.length,
                      itemBuilder: (context, index) {
                        final food = foodProvider.foods[index];
                        return ListTile(
                          title: Text(food.nombre),
                          subtitle: Text('${food.tipo} - ${food.kcal} kcal/${food.cantidadReferencia}g'),
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
} 