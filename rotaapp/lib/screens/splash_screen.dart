import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

// MainScreenWrapper'ın olduğu dosyayı import edin (genellikle main.dart)
import 'package:rotaapp/main.dart'; // Proje adınız 'rotaapp' ise bu yolu kullanın, değilse doğru yolu yazın
import '../providers/route_provider.dart'; // RouteProvider'ı import edin

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
    // Minimum splash süresi
    final minDurationFuture =
        Future.delayed(const Duration(seconds: 2)); // En az 2 saniye göster

    // Konum yükleme işlemi
    final locationLoadingFuture = _initializeLocationAndMapProviders();

    try {
      // Hem minimum sürenin dolmasını hem de konumun yüklenmesini bekle
      await Future.wait([
        minDurationFuture,
        locationLoadingFuture,
      ]);

      // Yükleme ve minimum süre tamamlandıysa ana ekrana yönlendir
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreenWrapper()),
        );
      }
    } catch (e) {
      debugPrint('Splash loading error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          // Hata gösterildikten sonra 3 saniye bekleyip yine de ana ekrana geç (veya kalıcı bir hata ekranı gösterebilirsiniz)
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              // Eğer hala hata ekranındaysak ve bu timer tetiklenirse, ana ekrana geç.
              // setState ile hata mesajını null yapmak veya tekrar yüklemeye geçmek gibi
              // farklı stratejiler de izlenebilir, bu örnekte direkt geçiş yapılıyor.
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const MainScreenWrapper()),
              );
            }
          });
        });
      }
    }
  }

  Future<void> _initializeLocationAndMapProviders() async {
    try {
      final status = await Permission.location.request();
      if (!mounted) throw Exception('Widget is not mounted.');

      if (status.isGranted) {
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) throw Exception('Widget is not mounted.');

        if (!isLocationEnabled) {
          // Kullanıcıya daha iyi bir hata mesajı gösterilebilir veya ayarlar sayfasına yönlendirilebilir.
          // Şimdilik sadece hata fırlatıyoruz.
          throw Exception(
              'Konum servisleri kapalı. Lütfen telefonunuzun ayarlarından açın.');
        }

        // Konum almayı deneme
        Position position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 15), // 15 saniye zaman aşımı
            onTimeout: () {
              throw Exception(
                  'Konum alınırken zaman aşımı oluştu. Lütfen daha sonra tekrar deneyin.');
            },
          );
        } on PermissionDeniedException {
          // Konum izni verildi ama servis yine de reddedildi (çok nadir)
          throw Exception('Konum izni reddedildi.');
        } on LocationServiceDisabledException {
          // isLocationServiceEnabled kontrol edilse de bazen bu exception fırlatılabilir
          throw Exception(
              'Konum servisleri kapalı. Lütfen telefonunuzun ayarlarından açın.');
        } catch (e) {
          // Diğer olası hatalar (GPS sinyali yokluğu vb.)
          throw Exception('Konum alınamadı: ${e.toString()}');
        }

        if (mounted) {
          final currentLocation = LatLng(position.latitude, position.longitude);
          // ignore: use_build_context_synchronously // setState veya context kullanımı güvenli
          Provider.of<RouteProvider>(context, listen: false)
              .setStartLocation(currentLocation);
        }
      } else if (status.isDenied) {
        // İzin reddedildiğinde
        throw Exception(
            'Konum izni reddedildi. Uygulama bazı özellikler için konum iznine ihtiyaç duyar.');
      } else if (status.isPermanentlyDenied) {
        // İzin kalıcı olarak reddedildiğinde (kullanıcının ayarlara gitmesi gerekir)
        throw Exception(
            'Konum izni kalıcı olarak reddedildi. Lütfen telefonunuzun ayarlarından izin verin.');
      } else {
        // Diğer durumlar (restricted vb.)
        throw Exception('Konum izni durumu beklenmedik: ${status.toString()}');
      }
    } catch (e) {
      // initializeLocationAndMapProviders içindeki tüm hataları yakalayıp yeniden fırlatıyoruz.
      // Bu, _startLoadingAndNavigate fonksiyonunun catch bloğuna düşmesini sağlar.
      rethrow; // Hatanın orijinalini koruyarak yeniden fırlatır
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cihazın tüm ekranını kaplayacak şekilde Container kullanılıyor
    return Scaffold(
      // AppBar varsa ve body'nin onun altına uzanmasını istiyorsanız bu true kalmalı.
      // Splash ekranında genellikle AppBar olmaz ama tam ekran tasarım için iyi.
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Arka plan rengini kaldırıp, decoration ekliyoruz
        // color: Colors.white, // Bunu kaldırın
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/arkaplan2.png'), // Arka plan resmi
            fit: BoxFit.cover, // Resmi ekranı kaplayacak şekilde ölçekle
          ),
        ),
        child: Center(
          // Yükleme göstergesi ve hata mesajı ortada kalmaya devam edecek
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // İçeriği kadar yer kapla
                  children: [
                    // Resim artık arka plan olduğu için buradan kaldırılıyor
                    // Image.asset('assets/images/arkaplan1.png', width: 150, height: 150,), // Bunu kaldırın
                    // const SizedBox(height: 24), // Gerekirse üst boşluğu ayarlayın
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // İçeriği kadar yer kapla
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 60),
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
                        // Tekrar dene butonuna basılınca hata mesajını temizle,
                        // yükleme durumuna dön ve tekrar yüklemeyi başlat
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _startLoadingAndNavigate();
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
