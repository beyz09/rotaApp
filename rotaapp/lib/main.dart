import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Ekranlarınızı ve provider'larınızı import edin
import 'screens/map_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/route_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/auth_provider.dart'; // İsteğe bağlı
import 'providers/theme_provider.dart'; // Yeni provider

// SplashScreen widget'ını import edin
import 'package:rotaapp/splash_screen.dart'; // <<-- splash_screen.dart dosyasının yolunu doğru ayarlayın

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RouteProvider()),
        ChangeNotifierProvider(create: (context) => VehicleProvider()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ), // İsteğe bağlı
        ChangeNotifierProvider(
            create: (context) => ThemeProvider()), // Yeni provider
        // Diğer provider'lar buraya eklenecek
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Rota Uygulaması',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8), // Google Mavi
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        cardColor: const Color(0xFFF8F9FA),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF202124)),
          bodyMedium: TextStyle(color: Color(0xFF5F6368)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF202124)),
          titleTextStyle: TextStyle(
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8), // Google Koyu Mavi
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF202124),
        cardColor: const Color(0xFF303134),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFE8EAED)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF202124),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}

// Bottom Navigation Bar ve Ekran Geçişlerini Yöneten Widget
// Bu widget artık splash screen'den sonra Navigator ile açılacak
class MainScreenWrapper extends StatefulWidget {
  const MainScreenWrapper({super.key});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    const MapScreen(),
    const VehicleScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF303134) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on),
              label: 'Harita',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: 'Araçlar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Ayarlar',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor:
              isDark ? const Color(0xFF8AB4F8) : const Color(0xFF1A73E8),
          unselectedItemColor:
              isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
