// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:rotaapp/main.dart'; // MainScreenWrapper için
import 'package:rotaapp/screens/login_screen.dart'; // LoginScreen için import eklendi
import '../providers/route_provider.dart';
import '../providers/auth_provider.dart';    // AuthProvider için import eklendi
import '../providers/vehicle_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startLoadingAndNavigate();
  }

  Future<void> _startLoadingAndNavigate() async {
    final minSplashDuration = Future.delayed(const Duration(seconds: 2));
    final initializationCompleter = Completer<void>();

    // AuthProvider'ın durumunu kontrol et
    await Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();

    _performInitializations().then((_) {
      if (mounted) initializationCompleter.complete();
    }).catchError((error) {
      if (mounted) initializationCompleter.completeError(error);
    });

    try {
      await Future.wait([minSplashDuration, initializationCompleter.future]);

      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) { // Kullanıcı giriş yapmışsa
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreenWrapper()),
          );
        } else { // Kullanıcı giriş yapmamışsa LoginScreen'e yönlendir
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Splash loading error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Başlangıç hatası: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  Future<void> _performInitializations() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    List<Future<void>> tasks = [];

    // 1. Konum bilgisini yükle
    tasks.add(_initializeLocation(routeProvider));

    // 2. Araçları yükle
    final bool isLoggedIn = authProvider.isAuthenticated;
    final String? currentUserId = authProvider.userId;

    if (isLoggedIn && currentUserId != null) {
      debugPrint("SplashScreen: Araçlar yükleniyor (Kullanıcı: $currentUserId)...");
      // VehicleProvider'daki fetchVehicles metoduna userId gönder.
      // Eğer fetchVehicles metodu userId parametresi almıyorsa veya farklı bir yapıda ise
      // burayı VehicleProvider'ınıza göre düzenlemeniz gerekebilir.
      tasks.add(vehicleProvider.fetchVehicles(userId: currentUserId));
    } else {
      debugPrint("SplashScreen: Kullanıcı giriş yapmamış veya userId yok, araçlar temizlenecek.");
      vehicleProvider.clearVehiclesLocally(); // Yerel araç listesini temizle
    }

    await Future.wait(tasks);
    debugPrint("SplashScreen: Tüm başlangıç görevleri tamamlandı.");
  }

  Future<void> _initializeLocation(RouteProvider routeProvider) async {
    try {
      if (!mounted) return;
      final status = await Permission.location.request();
      if (!mounted) return;

      if (status.isGranted) {
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;

        if (!isLocationEnabled) {
          throw Exception('Konum servisleri kapalı. Lütfen telefonunuzun ayarlarından açın.');
        }

        Position position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Konum alınırken zaman aşımı oluştu.'),
          );
        } catch (e) {
          // Daha spesifik hata mesajları
          if (e is TimeoutException) {
             throw Exception('Konum bilgisi alınamadı: Zaman aşımı.');
          }
          throw Exception('Konum bilgisi alınamadı: ${e.toString()}');
        }

        if (mounted) {
          final currentLocation = LatLng(position.latitude, position.longitude);
          routeProvider.setStartLocation(currentLocation);
          debugPrint("SplashScreen: Konum başarıyla ayarlandı: $currentLocation");
        }
      } else if (status.isDenied || status.isPermanentlyDenied) {
         throw Exception('Konum izni verilmedi. Uygulamanın konumunuza erişmesi gerekiyor.');
      } else {
        throw Exception('Konum izni durumu bilinmiyor: $status');
      }
    } catch (e) {
      debugPrint("SplashScreen: Konum başlatma hatası: $e");
      // Hata mesajını olduğu gibi _startLoadingAndNavigate'e iletmek için rethrow
      // Orada _errorMessage'a atanacak.
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // AppBar arkasına gövdeyi uzat (opsiyonel)
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/arkaplan2.png'), // Arka plan resmi
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Yükleme çubuğu rengi
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Yükleniyor...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Column( // Hata durumu için UI
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        _errorMessage ?? 'Bilinmeyen bir hata oluştu.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, // Hata mesajı rengi
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          _startLoadingAndNavigate(); // Yeniden yüklemeyi ve yönlendirmeyi başlat
                        }
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}