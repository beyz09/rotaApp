import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core kütüphanesi
import 'firebase_options.dart'; // Firebase yapılandırma seçenekleri (FlutterFire CLI tarafından oluşturulur)

// Proje içi ekran ve provider importları
import 'screens/map_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'providers/route_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

// Uygulamanın ana başlangıç noktası
void main() async {
  // Flutter binding'lerinin başlatıldığından emin ol (özellikle Firebase gibi eklentiler için)
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase'i başlat
  // `DefaultFirebaseOptions.currentPlatform` FlutterFire CLI ile `flutterfire configure` komutu çalıştırıldığında otomatik oluşturulan platforma özgü seçenekleri kullanır.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Uygulamayı çalıştır
  runApp(
    // MultiProvider, uygulama genelinde birden fazla state management provider'ı sağlamak için kullanılır
    MultiProvider(
      providers: [
        // Rota ile ilgili durumları yöneten provider
        ChangeNotifierProvider(create: (context) => RouteProvider()),
        // Araçlarla ilgili durumları yöneten provider
        ChangeNotifierProvider(create: (context) => VehicleProvider()),
        // Kimlik doğrulama (authentication) ile ilgili durumları yöneten provider
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        // Tema (açık/koyu mod) ile ilgili durumları yöneten provider
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(), // Ana uygulama widget'ı
    ),
  );
}

// Ana uygulama widget'ı (MaterialApp'ı içerir)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tema provider'ına erişim
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Rota Uygulaması', // Uygulama başlığı (görev yöneticisi gibi yerlerde görünür)
      debugShowCheckedModeBanner: false, // Sağ üstteki "DEBUG" bandını kaldırır
      // Açık tema ayarları
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8), // Ana renk şeması için tohum renk
          brightness: Brightness.light, // Açık tema
        ),
        useMaterial3: true, // Material 3 tasarım dilini kullan
        scaffoldBackgroundColor: Colors.white, // Scaffold'ların varsayılan arka plan rengi
        cardColor: const Color(0xFFF8F9FA), // Card widget'larının varsayılan arka plan rengi
        textTheme: const TextTheme( // Varsayılan metin stilleri
          bodyLarge: TextStyle(color: Color(0xFF202124)), // Büyük gövde metni
          bodyMedium: TextStyle(color: Color(0xFF5F6368)), // Orta gövde metni
        ),
        appBarTheme: const AppBarTheme( // AppBar için varsayılan tema
          backgroundColor: Colors.white, // Arka plan rengi
          elevation: 0, // Gölge yok
          iconTheme: IconThemeData(color: Color(0xFF202124)), // İkon rengi
          titleTextStyle: TextStyle( // Başlık metni stili
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardTheme( // Card widget'ları için varsayılan tema
          elevation: 1, // Hafif gölge
          shape: RoundedRectangleBorder( // Yuvarlak köşeler
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Koyu tema ayarları
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8), // Koyu tema için tohum renk
          brightness: Brightness.dark, // Koyu tema
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
      // Uygulamanın hangi temayı kullanacağını belirler (ThemeProvider'dan alınır)
      themeMode: themeProvider.themeMode,
      // Uygulama ilk açıldığında gösterilecek ekran
      home: const SplashScreen(),
      // İsimlendirilmiş rotalar (sayfa geçişleri için)
      routes: {
        '/main': (context) => const MainScreenWrapper(), // Ana ekran (içinde BottomNavigationBar var)
        '/login': (context) => const LoginScreen(), // Giriş ekranı
        '/register': (context) => const RegisterScreen(), // Kayıt ekranı
        '/privacy-policy': (context) => const PrivacyPolicyScreen(), // Gizlilik politikası ekranı
        '/terms-of-service': (context) => const TermsOfServiceScreen(), // Kullanım koşulları ekranı
      },
    );
  }
}

// Drawer (yan menü) ve ana ekran içeriğini yöneten bir sarmalayıcı widget.
// Bu widget, SplashScreen'den sonra '/main' rotası ile çağrılır.
class MainScreenWrapper extends StatefulWidget {
  const MainScreenWrapper({super.key});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  int _selectedIndex = 0; // Başlangıçta seçili olan drawer menü öğesinin indeksi (Harita)

  // Drawer menüsüne karşılık gelen ekranların listesi
  static final List<Widget> _screens = <Widget>[
    const MapScreen(),        // Index 0: Harita Ekranı
    const VehicleScreen(),    // Index 1: Araçlar Ekranı
    const ProfileScreen(),    // Index 2: Profil Ekranı
    const SettingsScreen(),   // Index 3: Ayarlar Ekranı
  ];

  // Drawer'daki bir öğeye tıklandığında çağrılır
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Seçili indeksi güncelle
    });
    Navigator.pop(context); // Drawer'ı kapat
  }

  @override
  Widget build(BuildContext context) {
    // Mevcut temanın karanlık mod olup olmadığını kontrol et
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // AppBar (üst çubuk)
      appBar: AppBar(
        // Sol tarafta menü ikonunu gösterir, Builder ile Scaffold context'ine erişilir
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // Drawer'ı aç
            },
          ),
        ),
        title: const Text('RotaApp'), // AppBar başlığı
      ),
      // Drawer (yan menü)
      drawer: Drawer(
        // Drawer'ın şekli (sağ üst ve sağ alt köşeleri yuvarlak)
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
        ),
        child: Container(
          // Drawer arka plan resmi (açık/koyu moda göre değişir)
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDark
                  ? 'assets/images/drawer2.png' // Koyu mod için resim
                  : 'assets/images/drawer.png'), // Açık mod için resim
              fit: BoxFit.cover, // Resmi kaplayacak şekilde ayarla
            ),
          ),
          child: ListView( // Kaydırılabilir menü öğeleri
            padding: EdgeInsets.zero, // Varsayılan padding'i kaldır
            children: [
              // Drawer'ın üst kısmında kapatma butonu için boşluk ve buton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Sağa yasla
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close), // Kapatma ikonu
                      onPressed: () {
                        Navigator.pop(context); // Drawer'ı kapat
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0), // Öğeler arası boşluk
              // Harita menü öğesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Card( // Daha şık görünüm için Card içinde ListTile
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  margin: EdgeInsets.zero, // Card'ın kendi margin'ini sıfırla
                  child: ListTile(
                    leading: const Icon(Icons.location_on), // İkon
                    title: const Text('Harita'), // Metin
                    selected: _selectedIndex == 0, // Bu öğe seçiliyse
                    selectedColor: const Color(0xFF435E91), // Seçili renk
                    onTap: () {
                      _onItemTapped(0); // Tıklandığında Harita ekranına geç
                    },
                  ),
                ),
              ),
              // Araçlar menü öğesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Card(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: const Text('Araçlar'),
                    selected: _selectedIndex == 1,
                    selectedColor: const Color(0xFF435E91),
                    onTap: () {
                      _onItemTapped(1); // Tıklandığında Araçlar ekranına geç
                    },
                  ),
                ),
              ),
              // Profil menü öğesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Card(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profil'),
                    selected: _selectedIndex == 2,
                    selectedColor: const Color(0xFF435E91),
                    onTap: () {
                      _onItemTapped(2); // Tıklandığında Profil ekranına geç
                    },
                  ),
                ),
              ),
              // Ayarlar menü öğesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Card(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Ayarlar'),
                    selected: _selectedIndex == 3,
                    selectedColor: const Color(0xFF435E91),
                    onTap: () {
                      _onItemTapped(3); // Tıklandığında Ayarlar ekranına geç
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Scaffold'un ana gövdesi, seçili olan ekranı gösterir
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
    );
  }
}