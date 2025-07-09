import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/daily_meal_provider.dart';
import '../providers/profile_provider.dart';
import '../models/food.dart';
import '../models/daily_meal.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mealProvider = Provider.of<DailyMealProvider>(context, listen: false);
      mealProvider.loadFoods();
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildDateSelector(mealProvider),
              const SizedBox(height: 20),
              _buildMacrosSummaryCard(currentMeal, userGoals),
              const SizedBox(height: 20),
              _buildProgressChart(currentMeal, userGoals),
              const SizedBox(height: 20),
              _buildConsumedFoodsList(mealProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddFoodTab() {
    return Consumer<DailyMealProvider>(
      builder: (context, mealProvider, child) {
        if (mealProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        return Column(
          children: [
            _buildSearchAndFilters(mealProvider),
            Expanded(
              child: _buildFoodsList(mealProvider),
            ),
          ],
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
    final totalKcal = currentMeal?.totalKcal ?? 0;
    final totalProteinas = currentMeal?.totalProteinas ?? 0;
    final totalCarbohidratos = currentMeal?.totalCarbohidratos ?? 0;
    final totalGrasas = currentMeal?.totalGrasas ?? 0;

    final goalKcal = userGoals.objetivoKcal;
    final goalProteinas = userGoals.objetivoProteinas;
    final goalCarbohidratos = userGoals.objetivoCarbohidratos;
    final goalGrasas = userGoals.objetivoGrasas;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Resumen de Macros',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMacroRow('Calorías', totalKcal, goalKcal, 'kcal', Colors.red),
            const SizedBox(height: 12),
            _buildMacroRow('Proteínas', totalProteinas, goalProteinas, 'g', Colors.blue),
            const SizedBox(height: 12),
            _buildMacroRow('Carbohidratos', totalCarbohidratos, goalCarbohidratos, 'g', Colors.green),
            const SizedBox(height: 12),
            _buildMacroRow('Grasas', totalGrasas, goalGrasas, 'g', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(String name, double current, double goal, String unit, Color color) {
    final percentage = goal > 0 ? (current / goal) * 100 : 0;
    final remaining = goal - current;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        Expanded(
          flex: 3,
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${current.toStringAsFixed(1)}/${goal.toStringAsFixed(1)} $unit',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            remaining > 0 ? '-${remaining.toStringAsFixed(1)}' : '+${(-remaining).toStringAsFixed(1)}',
            style: TextStyle(
              color: remaining > 0 ? Colors.grey : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart(DailyMeal? currentMeal, userGoals) {
    if (currentMeal == null) return const SizedBox();

    final progressData = currentMeal.getProgressPercentage({
      'kcal': userGoals.objetivoKcal,
      'proteinas': userGoals.objetivoProteinas,
      'carbohidratos': userGoals.objetivoCarbohidratos,
      'grasas': userGoals.objetivoGrasas,
    });

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Progreso Diario (%)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 120,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0: return const Text('Kcal', style: TextStyle(color: Colors.white, fontSize: 10));
                            case 1: return const Text('Prot', style: TextStyle(color: Colors.white, fontSize: 10));
                            case 2: return const Text('Carb', style: TextStyle(color: Colors.white, fontSize: 10));
                            case 3: return const Text('Gras', style: TextStyle(color: Colors.white, fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: progressData['kcal']!.clamp(0, 120), color: Colors.red)]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: progressData['proteinas']!.clamp(0, 120), color: Colors.blue)]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: progressData['carbohidratos']!.clamp(0, 120), color: Colors.green)]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: progressData['grasas']!.clamp(0, 120), color: Colors.orange)]),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar alimento...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        mealProvider.filterFoods(tipo: _selectedFoodType);
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
            onChanged: (value) {
              mealProvider.filterFoods(
                tipo: _selectedFoodType,
                searchText: value,
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedFoodType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Filtrar por tipo',
              labelStyle: const TextStyle(color: Colors.grey),
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
              ...foodTypes.map((type) => DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFoodType = value;
              });
              mealProvider.filterFoods(
                tipo: value,
                searchText: _searchController.text,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFoodsList(DailyMealProvider mealProvider) {
    final foods = mealProvider.filteredFoods;

    if (foods.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron alimentos',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            onPressed: () {
              final quantity = double.tryParse(_quantityController.text);
              if (quantity != null && quantity > 0) {
                mealProvider.addConsumedFood(food, quantity);
                Navigator.pop(context);
                _tabController.animateTo(0); // Cambiar a la pestaña de progreso
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alimento añadido correctamente'),
                    backgroundColor: Colors.green,
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
            onPressed: () {
              final quantity = double.tryParse(_quantityController.text);
              if (quantity != null && quantity > 0) {
                mealProvider.updateConsumedFoodQuantity(index, quantity);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cantidad actualizada'),
                    backgroundColor: Colors.green,
                  ),
                );
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
    final newDate = mealProvider.selectedDate.add(Duration(days: days));
    if (newDate.isBefore(DateTime.now().add(const Duration(days: 2)))) {
      mealProvider.setSelectedDate(newDate);
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