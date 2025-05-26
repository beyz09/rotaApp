// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:rotaapp/main.dart'; // MainScreenWrapper için
// import 'package:rotaapp/screens/login_screen.dart'; // ŞİMDİLİK GEREKMİYOR
import '../providers/route_provider.dart';
// import '../providers/auth_provider.dart';    // ŞİMDİLİK GEREKMİYOR
import '../providers/vehicle_provider.dart'; // VehicleProvider'ı import edin

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

    // AuthProvider ile ilgili kısımları şimdilik kaldırıyoruz.
    // await Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();

    _performInitializations().then((_) {
      if (mounted) initializationCompleter.complete();
    }).catchError((error) {
      if (mounted) initializationCompleter.completeError(error);
    });

    try {
      await Future.wait([minSplashDuration, initializationCompleter.future]);

      if (mounted) {
        // final authProvider = Provider.of<AuthProvider>(context, listen: false);
        // if (authProvider.isAuthenticated) { // ŞİMDİLİK BU KONTROLÜ KALDIRIYORUZ
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreenWrapper()),
        );
        // } else {
        //   Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(builder: (context) => const LoginScreen()),
        //   );
        // }
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

    // final authProvider = Provider.of<AuthProvider>(context, listen: false); // ŞİMDİLİK GEREKMİYOR
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    List<Future<void>> tasks = [];

    // 1. Konum bilgisini yükle
    tasks.add(_initializeLocation(routeProvider));

    // 2. Araçları yükle (her zaman tüm araçları çek)
    // final bool isLoggedIn = authProvider.isAuthenticated; // ŞİMDİLİK GEREKMİYOR
    // final String? currentUserId = authProvider.userId;    // ŞİMDİLİK GEREKMİYOR

    // if (isLoggedIn) { // ŞİMDİLİK BU KONTROLÜ KALDIRIYORUZ
    debugPrint("SplashScreen: Araçlar yükleniyor...");
    // VehicleProvider'daki fetchVehicles metoduna userId göndermiyoruz, böylece tüm araçları çeker.
    tasks.add(vehicleProvider.fetchVehicles()); // userId parametresi olmadan çağır
    // } else {
    //   debugPrint("SplashScreen: Kullanıcı giriş yapmamış, araçlar temizlenecek.");
    //   vehicleProvider.clearVehiclesLocally();
    // }

    await Future.wait(tasks);
    debugPrint("SplashScreen: Tüm başlangıç görevleri tamamlandı.");
  }

  Future<void> _initializeLocation(RouteProvider routeProvider) async {
    // ... (Bu metodun içeriği aynı kalabilir) ...
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
          throw Exception('Konum alınamadı: ${e.toString()}');
        }

        if (mounted) {
          final currentLocation = LatLng(position.latitude, position.longitude);
          routeProvider.setStartLocation(currentLocation);
          debugPrint("SplashScreen: Konum başarıyla ayarlandı.");
        }
      } else {
        throw Exception('Konum izni verilmedi. Durum: $status');
      }
    } catch (e) {
      debugPrint("SplashScreen: Konum başlatma hatası: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Build metodu öncekiyle aynı kalabilir) ...
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/arkaplan2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _errorMessage ?? 'Bilinmeyen bir hata oluştu.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          _startLoadingAndNavigate();
                        }
                      },
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}