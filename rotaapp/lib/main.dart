import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/route_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/auth_provider.dart'; // İsteğe bağlı

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Birden fazla Provider kullanmak için MultiProvider kullanın
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RouteProvider()),
        ChangeNotifierProvider(create: (context) => VehicleProvider()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ), // İsteğe bağlı
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
    return MaterialApp(
      title: 'Rota Uygulaması',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66BB6A),
        ), // Figma'daki yeşil tona yakın
        useMaterial3: true,
      ),
      home: MainScreenWrapper(), // Ana ekran yöneticisi
    );
  }
}

// Bottom Navigation Bar ve Ekran Geçişlerini Yöneten Widget
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
    // Figma'daki genel yeşil arka plan rengini alalım (utils/app_colors.dart'a taşınabilir)
    final Color overallBackgroundColor = Color(0xFFDCF0D8);

    return Scaffold(
      // AppBar burada değil, her ekranda kendi AppBar'ı veya içeriği olacak (Stack içinde)
      // Eğer Figma'daki üst kısım (Konum arayın vs.) tüm map sayfasının AppBar'ı gibiyse, o MapScreen'in kendi içinde kalacak.
      // Eğer tüm uygulamanın tek bir AppBar'ı olacaksa, o buraya taşınır ve her ekran widget'ı sadece içeriği olur.
      // Figma'ya göre AppBar benzeri yapı MapScreen'in içinde gibi duruyor. Home dahil.
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
        backgroundColor: overallBackgroundColor, // BNB arka plan rengi
      ),
    );
  }
}
