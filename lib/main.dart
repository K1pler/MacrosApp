import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/summary_screen.dart';
import 'screens/add_food_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/profile_provider.dart';
import 'providers/food_provider.dart';
import 'providers/daily_meal_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Usuario temporal fijo
  const uid = 'temp_user_123';
  runApp(MyApp(uid: uid));
}

class MyApp extends StatelessWidget {
  final String uid;
  const MyApp({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider(uid: uid)),
        ChangeNotifierProvider(create: (_) => FoodProvider()),
        ChangeNotifierProvider(create: (_) => DailyMealProvider(userId: uid)),
      ],
      child: MaterialApp(
        title: 'MacrosApp',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.red[800],
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.dark(
            primary: Colors.red[800]!,
            secondary: Colors.redAccent,
            background: Colors.black,
            surface: Colors.grey[900]!,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.red,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const MainNavigation(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0; // Inicia en Resumen (primera pestaña)

  static void _showProfileSavedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Datos de perfil guardados en la nube!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const SummaryScreen();
      case 1:
        return const AddFoodScreen();
      case 2:
        return ProfileScreen(onProfileSaved: (ctx) => _showProfileSavedSnackbar(ctx));
      default:
        return const SummaryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.red[800],
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Añadir alimento',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Mi perfil',
          ),
        ],
      ),
    );
  }
}