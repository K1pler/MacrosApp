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
    _tabController = TabController(length: 3, vsync: this); // Cambiar a 3
    
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
          controller: _tabController, // Usar el mismo controller
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Formulario'),
            Tab(icon: Icon(Icons.list), text: 'Gestionar Alimentos'),
            Tab(icon: Icon(Icons.code), text: 'JSON'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Usar el mismo controller
        children: [
          _buildFormTab(foodProvider),
          _buildCrudTab(foodProvider),
          _buildJsonTab(foodProvider),
        ],
      ),
    );
  }

  Widget _buildFormTab(FoodProvider foodProvider) {
    // Controladores para búsqueda y filtro
    final TextEditingController searchController = TextEditingController();
    String? filterType;

    return StatefulBuilder(
      builder: (context, setState) {
        // Filtrado y búsqueda
        List<Food> filteredFoods = foodProvider.foods;
        if (searchController.text.isNotEmpty) {
          filteredFoods = filteredFoods.where((food) =>
            food.nombre.toLowerCase().contains(searchController.text.toLowerCase())
          ).toList();
        }
        if (filterType != null && filterType!.isNotEmpty) {
          filteredFoods = filteredFoods.where((food) => food.tipo == filterType).toList();
        }

        return Column(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Añadir nuevo alimento',
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Buscador y filtro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar alimento...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: filterType,
                    hint: const Text('Tipo'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                      ...foodProvider.foodTypes.map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        filterType = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Lista de alimentos
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filteredFoods.map((food) => Card(
                  child: ListTile(
                    title: Text(food.nombre),
                    subtitle: Text('Tipo: ${food.tipo} | ${food.kcal} kcal | ${food.proteinas}g P | ${food.carbohidratos}g C | ${food.grasas}g G'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final nombreController = TextEditingController(text: food.nombre);
                            final cantidadController = TextEditingController(text: food.cantidadReferencia.toString());
                            final kcalController = TextEditingController(text: food.kcal.toString());
                            final proteinasController = TextEditingController(text: food.proteinas.toString());
                            final carbohidratosController = TextEditingController(text: food.carbohidratos.toString());
                            final grasasController = TextEditingController(text: food.grasas.toString());
                            String tipo = food.tipo;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Editar alimento'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nombreController,
                                          decoration: const InputDecoration(labelText: 'Nombre'),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: tipo,
                                          decoration: const InputDecoration(labelText: 'Tipo'),
                                          items: foodProvider.foodTypes.map((String t) {
                                            return DropdownMenuItem<String>(
                                              value: t,
                                              child: Text(t),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            tipo = newValue!;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: cantidadController,
                                          decoration: const InputDecoration(labelText: 'Cantidad de referencia (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: kcalController,
                                          decoration: const InputDecoration(labelText: 'Kilocalorías'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: proteinasController,
                                          decoration: const InputDecoration(labelText: 'Proteínas (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: carbohidratosController,
                                          decoration: const InputDecoration(labelText: 'Carbohidratos (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: grasasController,
                                          decoration: const InputDecoration(labelText: 'Grasas (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final updatedFood = Food(
                                          id: food.id,
                                          nombre: nombreController.text.trim(),
                                          tipo: tipo,
                                          cantidadReferencia: double.tryParse(cantidadController.text) ?? 0,
                                          kcal: double.tryParse(kcalController.text) ?? 0,
                                          proteinas: double.tryParse(proteinasController.text) ?? 0,
                                          carbohidratos: double.tryParse(carbohidratosController.text) ?? 0,
                                          grasas: double.tryParse(grasasController.text) ?? 0,
                                        );
                                        await foodProvider.updateFood(updatedFood);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar alimento'),
                                content: Text('¿Seguro que deseas eliminar "${food.nombre}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await foodProvider.deleteFood(food.id!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  // Nuevo método para la subpestaña de CRUD
  Widget _buildCrudTab(FoodProvider foodProvider) {
    final TextEditingController searchController = TextEditingController();
    String? filterType;

    return StatefulBuilder(
      builder: (context, setState) {
        List<Food> filteredFoods = foodProvider.foods;
        if (searchController.text.isNotEmpty) {
          filteredFoods = filteredFoods.where((food) =>
            food.nombre.toLowerCase().contains(searchController.text.toLowerCase())
          ).toList();
        }
        if (filterType != null && filterType!.isNotEmpty) {
          filteredFoods = filteredFoods.where((food) => food.tipo == filterType).toList();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar alimento...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: filterType,
                    hint: const Text('Tipo'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                      ...foodProvider.foodTypes.map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        filterType = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filteredFoods.map((food) => Card(
                  child: ListTile(
                    title: Text(food.nombre),
                    subtitle: Text('Tipo: ${food.tipo} | ${food.kcal} kcal | ${food.proteinas}g P | ${food.carbohidratos}g C | ${food.grasas}g G'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final nombreController = TextEditingController(text: food.nombre);
                            final cantidadController = TextEditingController(text: food.cantidadReferencia.toString());
                            final kcalController = TextEditingController(text: food.kcal.toString());
                            final proteinasController = TextEditingController(text: food.proteinas.toString());
                            final carbohidratosController = TextEditingController(text: food.carbohidratos.toString());
                            final grasasController = TextEditingController(text: food.grasas.toString());
                            String tipo = food.tipo;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Editar alimento'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nombreController,
                                          decoration: const InputDecoration(labelText: 'Nombre'),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: tipo,
                                          decoration: const InputDecoration(labelText: 'Tipo'),
                                          items: foodProvider.foodTypes.map((String t) {
                                            return DropdownMenuItem<String>(
                                              value: t,
                                              child: Text(t),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            tipo = newValue!;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: cantidadController,
                                          decoration: const InputDecoration(labelText: 'Cantidad de referencia (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: kcalController,
                                          decoration: const InputDecoration(labelText: 'Kilocalorías'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: proteinasController,
                                          decoration: const InputDecoration(labelText: 'Proteínas (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: carbohidratosController,
                                          decoration: const InputDecoration(labelText: 'Carbohidratos (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: grasasController,
                                          decoration: const InputDecoration(labelText: 'Grasas (g)'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final updatedFood = Food(
                                          id: food.id,
                                          nombre: nombreController.text.trim(),
                                          tipo: tipo,
                                          cantidadReferencia: double.tryParse(cantidadController.text) ?? 0,
                                          kcal: double.tryParse(kcalController.text) ?? 0,
                                          proteinas: double.tryParse(proteinasController.text) ?? 0,
                                          carbohidratos: double.tryParse(carbohidratosController.text) ?? 0,
                                          grasas: double.tryParse(grasasController.text) ?? 0,
                                        );
                                        await foodProvider.updateFood(updatedFood);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar alimento'),
                                content: Text('¿Seguro que deseas eliminar "${food.nombre}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await foodProvider.deleteFood(food.id!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJsonTab(FoodProvider foodProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListView(
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
                    width: double.infinity,
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(0),
                    child: TextFormField(
                      controller: _jsonController,
                      decoration: const InputDecoration(
                        labelText: 'JSON de alimentos',
                        border: OutlineInputBorder(),
                        hintText: 'Pega aquí el JSON con los alimentos...',
                      ),
                      maxLines: 10,
                    ),
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
          // Eliminado el Card de 'Alimentos guardados'
        ],
      ),
    );
  }
} 