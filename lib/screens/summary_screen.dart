import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/daily_meal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/food_provider.dart';
import '../models/food.dart';
import '../models/daily_meal.dart';
import '../firebase_status_label.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedFoodType;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mealProvider = Provider.of<DailyMealProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      
      // Cargar datos
      await mealProvider.loadFoods();
      await profileProvider.loadProfileFromFirestore();
      
      // Inicializar filtros para mostrar todos los alimentos
      if (mealProvider.availableFoods.isNotEmpty) {
        mealProvider.filterFoods(tipo: null, searchText: null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const FirebaseStatusIcon(),
        title: const Text('Resumen Diario'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Progreso', icon: Icon(Icons.analytics)),
            Tab(text: 'Añadir Comida', icon: Icon(Icons.add_circle)),
            Tab(text: 'Déficit Total', icon: Icon(Icons.trending_down)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProgressTab(),
          _buildAddFoodTab(),
          _buildDeficitTab(),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return Consumer2<DailyMealProvider, ProfileProvider>(
      builder: (context, mealProvider, profileProvider, child) {
        final currentMeal = mealProvider.currentDayMeal;
        final userGoals = profileProvider.goals;

        if (mealProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (userGoals == null) {
          return const Center(
            child: Text(
              'Complete su perfil para ver el progreso',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return RefreshIndicator(
          color: Colors.red,
          onRefresh: () async {
            if (!mounted) return;
            await Provider.of<ProfileProvider>(context, listen: false).loadProfileFromFirestore();
            if (!mounted) return;
            await Provider.of<DailyMealProvider>(context, listen: false).setSelectedDate(
              Provider.of<DailyMealProvider>(context, listen: false).selectedDate,
            );
            if (!mounted) return;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDateSelector(mealProvider),
                const SizedBox(height: 20),
                _buildMacrosSummaryCard(currentMeal, userGoals),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                _buildConsumedFoodsList(mealProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddFoodTab() {
    return Consumer2<DailyMealProvider, FoodProvider>(
      builder: (context, mealProvider, foodProvider, child) {
        if (mealProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        // Recargar alimentos de FoodProvider en DailyMealProvider si hay cambios
        if (foodProvider.foods.isNotEmpty) {
          mealProvider.syncFoodsFromFoodProvider(foodProvider.foods);
          // Asegurar que se muestren todos los alimentos por defecto
          if (mealProvider.filteredFoods.isEmpty && mealProvider.availableFoods.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mealProvider.filterFoods(tipo: null, searchText: null);
            });
          }
        }

        return RefreshIndicator(
          color: Colors.red,
          onRefresh: () async {
            if (!mounted) return;
            await Provider.of<DailyMealProvider>(context, listen: false).loadFoods();
            if (!mounted) return;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filtro en Card
                Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildSearchAndFilters(mealProvider),
                ),
                // Botón añadir comida combinada en Card centrado
                Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: _buildAddCombinedFoodButton(mealProvider)),
                  ),
                ),
                // Listado de alimentos en Card
                Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildFoodsList(mealProvider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSelector(DailyMealProvider mealProvider) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => _changeDate(mealProvider, -1),
            ),
            Text(
              _formatDate(mealProvider.selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => _changeDate(mealProvider, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosSummaryCard(DailyMeal? currentMeal, userGoals) {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final details = profileProvider.getCalculationDetails();
    final bmr = details['bmr'] ?? 0;
    final tdee = details['tdee'] ?? 0;
    final targetCalories = details['targetCalories'] ?? 0;
    final deficit = details['deficit'] ?? 0;

    final totalKcal = currentMeal?.totalKcal ?? 0;
    final totalProteinas = currentMeal?.totalProteinas ?? 0;
    final totalCarbohidratos = currentMeal?.totalCarbohidratos ?? 0;
    final totalGrasas = currentMeal?.totalGrasas ?? 0;

    final goalKcal = userGoals.calories;
    final goalProteinas = userGoals.protein;
    final goalCarbohidratos = userGoals.carbs;
    final goalGrasas = userGoals.fat;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Resumen de Macros',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tasa Metabólica Basal (TMB): ${bmr.toStringAsFixed(1)} kcal', style: const TextStyle(color: Colors.white70)),
            Text('Gasto total diario (TDEE): ${tdee.toStringAsFixed(1)} kcal', style: const TextStyle(color: Colors.white70)),
            Text('TDEE con déficit/superávit: ${targetCalories.toStringAsFixed(1)} kcal', style: const TextStyle(color: Colors.white70)),
            if (deficit != 0)
              Text('Déficit/Superávit aplicado: ${deficit > 0 ? '+' : ''}${deficit.toStringAsFixed(1)} kcal', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            _buildMacroRowVertical('Calorías', totalKcal, goalKcal, 'kcal', Colors.red),
            _buildMacroRowVertical('Proteínas', totalProteinas, goalProteinas, 'g', Colors.blue),
            _buildMacroRowVertical('Carbohidratos', totalCarbohidratos, goalCarbohidratos, 'g', Colors.green),
            _buildMacroRowVertical('Grasas', totalGrasas, goalGrasas, 'g', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRowVertical(String name, double current, double goal, String unit, Color color) {
    final percentage = goal > 0 ? (current / goal) * 100 : 0;
    final remaining = goal - current;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), // Aumenta el espacio entre macros
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10, // Aumenta el grosor de la barra
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${current.toStringAsFixed(1)}/${goal.toStringAsFixed(1)} $unit',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Text(
                remaining > 0 ? '-${remaining.toStringAsFixed(1)}' : '+${(-remaining).toStringAsFixed(1)}',
                style: TextStyle(
                  color: remaining > 0 ? Colors.grey : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsumedFoodsList(DailyMealProvider mealProvider) {
    final consumedFoods = mealProvider.currentDayMeal?.consumedFoods ?? [];

    if (consumedFoods.isEmpty) {
      return Card(
        color: Colors.grey[900],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No has consumido alimentos hoy',
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey[900],
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Alimentos Consumidos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: consumedFoods.length,
            itemBuilder: (context, index) {
              final food = consumedFoods[index];
              return ListTile(
                title: Text(
                  food.foodName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${food.quantity.toStringAsFixed(1)}g - ${food.kcal.toStringAsFixed(1)} kcal',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () => _editFoodQuantity(mealProvider, index, food),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => mealProvider.removeConsumedFood(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(DailyMealProvider mealProvider) {
    final foodTypes = mealProvider.getFoodTypes();

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la sección
          const Text(
            'Buscar Alimentos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Campo de búsqueda por nombre
          const Text(
            'Buscar por nombre:',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Escribe el nombre del alimento...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                        mealProvider.filterFoods(tipo: _selectedFoodType, searchText: '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (text) {
              mealProvider.filterFoods(tipo: _selectedFoodType, searchText: text.trim());
              setState(() {}); // Para actualizar el botón clear
            },
          ),
          const SizedBox(height: 16),
          
          // Filtro por tipo
          const Text(
            'Filtrar por tipo:',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: foodTypes.contains(_selectedFoodType) ? _selectedFoodType : null,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: Colors.grey[800],
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Todos los tipos'),
              ),
              ...foodTypes.toSet().map((type) => DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFoodType = value;
              });
              mealProvider.filterFoods(tipo: value, searchText: _searchController.text.trim());
            },
          ),
          const SizedBox(height: 16),
          
          // Botón Mostrar Todos
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedFoodType = null;
                    });
                    mealProvider.filterFoods(tipo: null, searchText: '');
                  },
                  icon: const Icon(Icons.clear_all, color: Colors.white),
                  label: const Text('Mostrar Todos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Información de resultados
          Consumer<DailyMealProvider>(
            builder: (context, provider, child) {
              final totalFoods = provider.availableFoods.length;
              final filteredCount = provider.filteredFoods.length;
              
              return Text(
                'Mostrando $filteredCount de $totalFoods alimentos',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFoodsList(DailyMealProvider mealProvider) {
    final foods = mealProvider.filteredFoods;
    final totalFoods = mealProvider.availableFoods.length;

    if (totalFoods == 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No hay alimentos disponibles',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Agrega algunos alimentos en la sección "Añadir Comida"',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (foods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron alimentos',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intenta con otros términos de búsqueda',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedFoodType = null;
                });
                mealProvider.filterFoods(tipo: null, searchText: null);
              },
              icon: const Icon(Icons.clear_all, color: Colors.white),
              label: const Text('Mostrar Todos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: ListTile(
            title: Text(
              food.nombre,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipo: ${food.tipo}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'Por ${food.cantidadReferencia}g: ${food.kcal}kcal, P:${food.proteinas}g, C:${food.carbohidratos}g, G:${food.grasas}g',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.red),
              onPressed: () => _showAddFoodDialog(food, mealProvider),
            ),
          ),
        );
      },
    );
  }

  void _showAddFoodDialog(Food food, DailyMealProvider mealProvider) {
    _quantityController.text = food.cantidadReferencia.toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Añadir ${food.nombre}',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Cantidad (gramos)',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final quantity = double.tryParse(_quantityController.text);
              if (quantity != null && quantity > 0) {
                Navigator.pop(context);
                await mealProvider.addConsumedFood(food, quantity);
                if (mounted) {
                  _tabController.animateTo(0); // Cambiar a la pestaña de progreso
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alimento añadido correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Añadir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editFoodQuantity(DailyMealProvider mealProvider, int index, ConsumedFood food) {
    _quantityController.text = food.quantity.toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Editar ${food.foodName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Cantidad (gramos)',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final quantity = double.tryParse(_quantityController.text);
              if (quantity != null && quantity > 0) {
                Navigator.pop(context);
                await mealProvider.updateConsumedFoodQuantity(index, quantity);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cantidad actualizada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final mealProvider = Provider.of<DailyMealProvider>(context, listen: false);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: mealProvider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.red,
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      await mealProvider.setSelectedDate(selectedDate);
    }
  }

  void _changeDate(DailyMealProvider mealProvider, int days) {
    if (!mounted) return;
    
    final newDate = mealProvider.selectedDate.add(Duration(days: days));
    if (newDate.isBefore(DateTime.now().add(const Duration(days: 2)))) {
      mealProvider.setSelectedDate(newDate);
    }
  }

  Widget _buildAddCombinedFoodButton(DailyMealProvider mealProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => _showAddCombinedFoodDialog(mealProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
        icon: const Icon(Icons.restaurant_menu),
        label: const Text(
          'Añadir Comida Combinada',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showAddCombinedFoodDialog(DailyMealProvider mealProvider) {
    final TextEditingController jsonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Añadir Comida Combinada',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Introduce el JSON de la comida combinada:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: jsonController,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '{"nombre": "Pollo con arroz", "tipo": "Comida combinada", "cantidad_referencia": 300, "kcal": 450, "proteinas": 35, "carbohidratos": 45, "grasas": 12}',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final jsonText = jsonController.text.trim();
              if (jsonText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, introduce el JSON de la comida'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final jsonData = json.decode(jsonText);
                final food = Food.fromJson(jsonData);
                
                // Añadir a la base de datos de alimentos
                final foodProvider = Provider.of<FoodProvider>(context, listen: false);
                final success = await foodProvider.addFood(food);
                
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Comida combinada "${food.nombre}" añadida a la base de datos'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Recargar alimentos en el mealProvider
                  await mealProvider.loadFoods();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al procesar JSON: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Añadir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeficitTab() {
    return Consumer2<DailyMealProvider, ProfileProvider>(
      builder: (context, mealProvider, profileProvider, child) {
        final userGoals = profileProvider.goals;
        
        if (userGoals == null) {
          return const Center(
            child: Text(
              'Complete su perfil para ver el déficit',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildDateRangeSelector(mealProvider),
              const SizedBox(height: 20),
              _buildDeficitSummary(mealProvider, userGoals),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateRangeSelector(DailyMealProvider mealProvider) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Rango de Fechas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha Inicio',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectStartDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(_startDate),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha Fin',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectEndDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(_endDate),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeficitSummary(DailyMealProvider mealProvider, userGoals) {
    if (!mounted) {
      return const SizedBox.shrink();
    }
    
    return FutureBuilder<Map<String, double>>(
      future: _calculateDeficitForRange(mealProvider, userGoals),
      builder: (context, snapshot) {
        if (!mounted) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: Colors.grey[900],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Error al calcular el déficit',
                style: TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final deficitData = snapshot.data ?? {};
        final totalDeficit = deficitData['totalDeficit'] ?? 0.0;
        final totalDays = deficitData['totalDays'] ?? 0.0;
        final averageDeficit = deficitData['averageDeficit'] ?? 0.0;
        final fatLost = deficitData['fatLost'] ?? 0.0;

        return Column(
          children: [
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Resumen del Déficit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDeficitRow('Días analizados', '${totalDays.toInt()}', 'días'),
                    _buildDeficitRow('Déficit total', totalDeficit.toStringAsFixed(0), 'kcal'),
                    _buildDeficitRow('Déficit promedio', averageDeficit.toStringAsFixed(0), 'kcal/día'),
                    _buildDeficitRow('Grasa perdida (aprox.)', fatLost.toStringAsFixed(1), 'kg'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Información Nutricional',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '• 1 kg de grasa = ~7,700 kcal\n'
                      '• Déficit de 500 kcal/día = ~0.5 kg/semana\n'
                      '• Déficit de 1,000 kcal/día = ~1 kg/semana',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeficitRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, double>> _calculateDeficitForRange(DailyMealProvider mealProvider, userGoals) async {
    try {
      double totalDeficit = 0;
      double totalDays = 0;
      
      final currentDate = _startDate;
      final endDate = _endDate;
      
      for (DateTime date = currentDate; 
           date.isBefore(endDate.add(const Duration(days: 1))); 
           date = date.add(const Duration(days: 1))) {
        
        final documentId = DailyMeal.getDocumentId(mealProvider.userId, date);
        
        // Intentar obtener la comida del día
        DailyMeal? meal;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('comidas_diarias')
              .doc(documentId)
              .get();
          
          if (doc.exists) {
            meal = DailyMeal.fromJson(doc.data()!, documentId: doc.id);
          }
        } catch (e) {
          // Ignorar errores y continuar
          continue;
        }

        // Solo considerar días que tengan registros de comidas
        if (meal != null && meal.consumedFoods.isNotEmpty) {
          final consumedKcal = meal.totalKcal;
          final targetKcal = userGoals.calories;
          final dailyDeficit = targetKcal - consumedKcal;
          
          totalDeficit += dailyDeficit;
          totalDays += 1.0;
        }
      }

      final averageDeficit = totalDays > 0 ? totalDeficit / totalDays : 0;
      final fatLost = totalDeficit / 7700; // 1 kg de grasa = ~7,700 kcal

      return {
        'totalDeficit': totalDeficit.toDouble(),
        'totalDays': totalDays.toDouble(),
        'averageDeficit': averageDeficit.toDouble(),
        'fatLost': fatLost.toDouble(),
      };
    } catch (e) {
      // Retornar valores por defecto en caso de error
      return {
        'totalDeficit': 0.0,
        'totalDays': 0.0,
        'averageDeficit': 0.0,
        'fatLost': 0.0,
      };
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _endDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.red,
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _startDate = selectedDate;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.red,
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _endDate = selectedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoy';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Ayer';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Mañana';
    } else {
      return '${date.day} de ${months[date.month - 1]}';
    }
  }
} 