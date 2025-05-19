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
import 'providers/theme_provider.dart';

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
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
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
      theme: themeProvider.currentTheme,
      // UYGULAMA BAŞLANGICINDA İLK GÖSTERİLECEK EKRAN ARTIK SPLASHSCREEN
      home: const SplashScreen(), // <<-- Burası SplashScreen oldu
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
  int _selectedIndex = 0; // Seçili BNB öğesinin indeksi

  // Bottom Navigation Bar'daki ekranlar
  static final List<Widget> _screens = <Widget>[
    const MapScreen(), // İlk ikon (Harita)
    const VehicleScreen(), // İkinci ikon (Araç)
    const ProfileScreen(), // Üçüncü ikon (Profil)
    const SettingsScreen(), // Dördüncü ikon (Ayarlar)
  ];

  // BNB öğesine tıklandığında
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final backgroundColor =
        themeProvider.isDarkMode ? const Color(0xFF202124) : Colors.white;

    return Scaffold(
      body: Center(
        child: _screens.elementAt(_selectedIndex), // Seçili ekranı göster
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Harita',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Araçlar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
        currentIndex: _selectedIndex, // Seçili indeksi belirt
        selectedItemColor:
            Theme.of(context).colorScheme.primary, // Seçili ikon rengi
        unselectedItemColor: Colors.grey, // Seçili olmayan ikon rengi
        onTap: _onItemTapped, // Tıklama olayını yönet
        type: BottomNavigationBarType.fixed, // İkon sayısı fazlaysa
        backgroundColor: backgroundColor, // BNB arka plan rengi
      ),
    );
  }
}
