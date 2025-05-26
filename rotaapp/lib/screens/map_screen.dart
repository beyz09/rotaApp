// lib/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' as l; // latlong2'nin Distance sınıfı için alias
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http; // HTTP istekleri için
import 'dart:convert'; // JSON işleme için
import 'dart:async'; // TimeoutException gibi asenkron yardımcılar için
import 'package:url_launcher/url_launcher.dart'; // Harici URL'leri açmak için
import 'package:flutter/scheduler.dart'; // WidgetsBinding.instance.addPostFrameCallback için
import 'package:flutter/foundation.dart'; // debugPrint için

// Proje içi model ve provider importları
import '../models/location_result.dart';
import '../models/route_option.dart';
import '../models/fuel_cost_calculator.dart';
import '../models/vehicle.dart';
import '../models/route_step.dart';
import '../data/predefined_tolls.dart';
import '../providers/route_provider.dart';
import '../providers/vehicle_provider.dart';

// DraggableScrollableSheet'te hangi içeriğin gösterileceğini belirler
enum SheetType {
  none, // Sheet kapalı veya boş
  searchResults, // Konum arama sonuçları gösteriliyor
  routeOptions, // Rota seçenekleri gösteriliyor
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Durum değişkenleri
  bool _isCalculatingRoute = false; // Rota hesaplama işlemi devam ediyor mu?
  bool _isSearchingLocation = false; // Konum arama işlemi devam ediyor mu?
  SheetType _currentSheet = SheetType.none; // Aktif sheet tipini tutar
  List<LocationResult> _searchResults = []; // Konum arama sonuçlarını tutar
  bool _isStartSearchActive = true; // Başlangıç TextField'ı mı yoksa Varış TextField'ı mı aktif?
  bool _showRouteStepsDetails = false; // Rota adımları detayları gösteriliyor mu?

  // Controller ve FocusNode'lar
  final MapController _mapController = MapController(); // Harita kontrolleri için
  final TextEditingController _startController = TextEditingController(); // Başlangıç TextField'ı için
  final TextEditingController _endController = TextEditingController(); // Varış TextField'ı için
  final FocusNode _startFocusNode = FocusNode(); // Başlangıç TextField focus yönetimi
  final FocusNode _endFocusNode = FocusNode(); // Varış TextField focus yönetimi

  // Sabitler
  static const String turkeyViewBox = '25.5,35.5,45.0,42.0'; // Nominatim aramalarını Türkiye ile sınırlandırmak için
  final double _sampleFuelPricePerLiter = 42.0; // Örnek yakıt fiyatı (ileride dinamikleşebilir)
  final l.Distance _distanceCalculator = const l.Distance(); // İki coğrafi nokta arası mesafe hesaplamak için
  static const double _gateMatchThresholdMeters = 50000; // Gişe eşleştirme için maksimum tolerans mesafesi (metre)

  @override
  void initState() {
    super.initState();
    // Focus değişikliklerini dinleyerek sheet görünürlüğünü yönet
    _startFocusNode.addListener(_onFocusChange);
    _endFocusNode.addListener(_onFocusChange);

    // Widget ağacı oluşturulduktan sonra çalışacak kod
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeProvider = Provider.of<RouteProvider>(context, listen: false);
      // Eğer başlangıç konumu (örn: mevcut konum) varsa ve TextField boşsa, "Mevcut Konum" yaz ve haritayı oraya taşı
      if (routeProvider.startLocation != null &&
          _startController.text.isEmpty) {
        _startController.text = 'Mevcut Konum';
        // Harita hareketini bir sonraki frame'e erteleyerek olası render hatalarını önle
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) { // Widget hala ağaçtaysa işlem yap
            try {
              _mapController.move(routeProvider.startLocation!, 13);
            } catch (e) { /* Harita henüz hazır değilse oluşabilecek hatayı sessizce yoksay */ }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Listener'ları ve controller'ları temizle
    _startFocusNode.removeListener(_onFocusChange);
    _endFocusNode.removeListener(_onFocusChange);
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _startController.dispose();
    _endController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // TextField focus durumlarına göre arama sonuçları sheet'ini yönetir
  void _onFocusChange() {
    // Eğer iki TextField da focus dışıysa ve arama sonuçları sheet'i açıksa, kapat
    if (!_startFocusNode.hasFocus && !_endFocusNode.hasFocus) {
      if (_currentSheet == SheetType.searchResults && mounted) {
        setState(() {
          _currentSheet = SheetType.none;
          _searchResults = [];
        });
      }
    } else {
      // Eğer bir TextField focus aldıysa, hangisinin aktif olduğunu belirle
      // ve arama sonuçları sheet'i açıksa, mevcut sonuçları temizle
      if (mounted) {
        setState(() {
          _isStartSearchActive = _startFocusNode.hasFocus;
          if (_currentSheet == SheetType.searchResults) {
            _searchResults = []; // Yeni arama için eski sonuçları temizle
          }
        });
      }
    }
  }

  // Kullanıcıya hata veya uyarı mesajı göstermek için SnackBar kullanır
  void _showErrorSnackBar(String message, {bool isWarning = false}) {
    if (!mounted) return; // Widget ağaçtan kaldırıldıysa işlem yapma
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Varsa önceki SnackBar'ı kaldır
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning ? Colors.orangeAccent : Colors.redAccent, // Uyarı ise turuncu, hata ise kırmızı
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Verilen sorgu ile Nominatim API üzerinden konum araması yapar
  Future<void> _performSearch(String query) async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final bool isStart = _isStartSearchActive; // Hangi TextField için arama yapılıyor?

    // Özel durum: "Mevcut Konum" araması
    if (isStart && query.trim().toLowerCase() == 'mevcut konum') {
      final currentLocation = routeProvider.startLocation;
      if (currentLocation != null) {
        _startController.text = 'Mevcut Konum';
        routeProvider.setStartLocation(currentLocation); // Global state'e kaydet
        _startFocusNode.unfocus(); // TextField'dan focus'u kaldır
        if (mounted) {
          setState(() {
            _searchResults = [];
            _currentSheet = SheetType.none; // Arama sonuçları sheet'ini kapat
          });
          try {
            _mapController.move(currentLocation, 13); // Haritayı mevcut konuma taşı
          } catch (_) { /* Harita hatasını yoksay */ }
        }
      } else {
        _showErrorSnackBar('Mevcut konum bilgisi alınamadı.', isWarning: true);
      }
      return;
    }

    // Boş sorgu ise arama yapma, sonuçları temizle
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchingLocation = false;
          if (_currentSheet == SheetType.searchResults) {
            _currentSheet = SheetType.none;
          }
        });
      }
      return;
    }

    // Eğer aktif bir rota varsa ve yeni bir arama yapılıyorsa, eski rotayı temizle
    if (routeProvider.routeOptionsList.isNotEmpty) {
      routeProvider.clearRouteResults();
      if (mounted && _currentSheet == SheetType.routeOptions) {
        setState(() {
          _currentSheet = SheetType.none; // Rota seçenekleri sheet'ini kapat
          _showRouteStepsDetails = false;
        });
      }
    }

    // Arama başladığında UI'ı güncelle
    if (mounted) {
      setState(() {
        _isSearchingLocation = true; // Yükleme göstergesi için
        _searchResults = [];
        _currentSheet = SheetType.searchResults; // Arama sonuçları sheet'ini aç
      });
    }

    try {
      // Nominatim API'ye istek at
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=10&viewbox=$turkeyViewBox&bounded=1&accept-language=tr');
      final response = await http.get(url, headers: {
        'User-Agent': 'FuelEstimateApp/1.0' // Nominatim için User-Agent gerekli
      }).timeout(const Duration(seconds: 10)); // 10 saniye zaman aşımı

      List<LocationResult> results = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        results = data
            .map((item) {
              // Gelen veriyi LocationResult modeline dönüştür
              final double? lat = double.tryParse(item['lat']?.toString() ?? '');
              final double? lon = double.tryParse(item['lon']?.toString() ?? '');
              final String name = item['display_name']?.toString() ?? '';
              if (lat != null && lon != null && name.isNotEmpty) {
                return LocationResult(
                    displayName: name,
                    coordinates: LatLng(lat, lon),
                    type: item['type']?.toString() ?? '');
              }
              return null; // Geçersiz veri ise null döndür
            })
            .whereType<LocationResult>() // Sadece geçerli LocationResult objelerini al
            .toList();
      } else {
        _showErrorSnackBar('Arama sunucusu hatası: ${response.statusCode}', isWarning: true);
      }

      if (!mounted) return; // Widget ağaçtan kaldırıldıysa işlem yapma

      // Arama sonuçlarını ve UI'ı güncelle
      setState(() {
        _searchResults = results;
        _isSearchingLocation = false; // Yükleme göstergesini kapat
        _currentSheet = results.isNotEmpty ? SheetType.searchResults : SheetType.none;
        if (results.isEmpty && query.isNotEmpty) {
          _showErrorSnackBar('Arama sonucu bulunamadı.', isWarning:true);
        }
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearchingLocation = false;
        _currentSheet = SheetType.none;
      });
      _showErrorSnackBar('Arama sunucusu zaman aşımına uğradı.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearchingLocation = false;
        _currentSheet = SheetType.none;
      });
      _showErrorSnackBar('Arama sırasında bir hata oluştu.');
    }
  }

  // Arama sonuçlarından bir konum seçildiğinde çalışır
  void _selectLocation(LocationResult location) {
    final controller = _isStartSearchActive ? _startController : _endController; // İlgili TextField controller'ı
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    controller.text = location.displayName; // TextField'a seçilen konumu yaz
    // Seçilen konumu RouteProvider'a kaydet
    if (_isStartSearchActive) {
      routeProvider.setStartLocation(location.coordinates);
      _startFocusNode.unfocus(); // Focus'u kaldır
    } else {
      routeProvider.setEndLocation(location.coordinates);
      _endFocusNode.unfocus(); // Focus'u kaldır
    }

    // Arama sonuçları sheet'ini kapat
    if (mounted) {
      setState(() {
        _searchResults = [];
        _currentSheet = SheetType.none;
      });
    }
  }

  // Başlangıç ve varış noktalarını ve metinlerini değiştirir
  void _swapStartEndLocations() {
    if (!mounted) return;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    // Geçici değişkenlerde mevcut değerleri sakla
    final tempStartLoc = routeProvider.startLocation;
    final tempEndLoc = routeProvider.endLocation;
    final tempStartText = _startController.text;
    final tempEndText = _endController.text;

    // Değerleri çaprazla
    _startController.text = tempEndText;
    _endController.text = tempStartText;
    routeProvider.setStartLocation(tempEndLoc);
    routeProvider.setEndLocation(tempStartLoc);

    // UI'ı güncelle
    if (mounted) {
      setState(() {
        _searchResults = []; // Varsa arama sonuçlarını temizle
        _currentSheet = SheetType.none; // Sheet'i kapat
        _showRouteStepsDetails = false; // Rota detaylarını gizle
      });
    }
    // Focus'ları kaldır
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();
  }

  // "Rota Bul" butonuna tıklandığında rota hesaplama işlemini başlatır
  void _onRouteSearchRequested() async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    _startFocusNode.unfocus(); // Arama inputlarından focus'u kaldır
    _endFocusNode.unfocus();

    // Başlangıç veya varış noktası seçilmemişse hata göster
    if (start == null || end == null) {
      _showErrorSnackBar('Lütfen başlangıç ve varış noktalarını seçin.', isWarning: true);
      return;
    }

    // Rota hesaplama başladığında UI'ı güncelle
    if (mounted) {
      setState(() {
        _isCalculatingRoute = true; // Yükleme göstergesi için
        _currentSheet = SheetType.none; // Mevcut sheet'i kapat (önceki arama veya rota sonuçları olabilir)
        routeProvider.clearRouteResults(); // Önceki rota sonuçlarını temizle
        _showRouteStepsDetails = false; // Rota adımlarını gizle
        _searchResults = []; // Arama sonuçlarını temizle
      });
    }

    try {
      // OSRM API'den rota seçeneklerini çek
      final routeOptions = await _fetchRouteOptions(start, end);
      if (!mounted) return; // Widget ağaçtan kaldırıldıysa işlem yapma

      routeProvider.setRouteOptions(routeOptions); // Gelen rota seçeneklerini state'e kaydet

      // Rota hesaplama bittiğinde UI'ı güncelle
      setState(() {
        _isCalculatingRoute = false; // Yükleme göstergesini kapat
        if (routeOptions.isNotEmpty) {
          _currentSheet = SheetType.routeOptions; // Rota seçenekleri sheet'ini aç
          if (routeProvider.selectedRouteOption != null) {
            // Seçili bir rota varsa haritayı rotaya sığdır
            _fitMapToRoute(routeProvider.selectedRouteOption!.points);
          }
        } else {
          _currentSheet = SheetType.none; // Rota bulunamadıysa sheet'i kapalı tut
        }
      });
    } on http.ClientException catch (e) { // Özellikle ağ veya sunucuya ulaşılamama durumu
      debugPrint("OSRM ClientException in _onRouteSearchRequested: ${e.message}");
      if (!mounted) return;
      setState(() {
        _isCalculatingRoute = false;
        _currentSheet = SheetType.none;
      });
      _showErrorSnackBar('Rota sunucusuna ulaşılamadı. İnternet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.');
    } catch (e) { // Diğer genel hatalar
      debugPrint("Rota hesaplama sırasında genel hata: ${e.toString()}");
      if (!mounted) return;
      setState(() {
        _isCalculatingRoute = false;
        _currentSheet = SheetType.none;
      });
      _showErrorSnackBar('Rota hesaplanırken bir sorun oluştu.');
    }
  }

  // OSRM (Open Source Routing Machine) API'sini kullanarak rota seçeneklerini alır
  Future<List<RouteOption>> _fetchRouteOptions(LatLng start, LatLng end) async {
    // OSRM API endpoint'i: başlangıç ve varış koordinatları, tam rota geometrisi, alternatif rotalar, adımlar ve ek bilgiler
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true&steps=true&annotations=true');

    http.Response response;
    try {
      // API'ye GET isteği at, 30 saniye zaman aşımı uygula
      response = await http.get(url).timeout(const Duration(seconds: 30));
    } on TimeoutException catch (_) {
      debugPrint("OSRM Request Timed Out after 30 seconds for URL: $url");
      // Zaman aşımı durumunda özel bir ClientException fırlat
      throw http.ClientException("Rota sunucusu zaman aşımına uğradı.", url);
    } catch (e) { // Diğer ağ bağlantı hataları
      debugPrint("OSRM Request failed before getting response for URL: $url. Error: $e");
      throw http.ClientException("Rota sunucusuna bağlanılamadı.", url);
    }

    // Yanıt başarılı değilse (HTTP 200 OK değilse)
    if (response.statusCode != 200) {
      debugPrint('OSRM API Error: ${response.statusCode} - ${response.body}');
      String errorMessage = 'Rota sunucusu hatası (${response.statusCode}).';
      // Spesifik hata kodlarına göre kullanıcıya daha anlaşılır mesajlar ver
      if (response.statusCode == 400) { // Bad Request
        if (response.body.toLowerCase().contains("too big") ||
            response.body.toLowerCase().contains("retaillimit")) {
          errorMessage = 'Seçilen rota çok uzun veya karmaşık. Daha kısa bir mesafe deneyin.';
        } else {
          errorMessage = 'Rota isteği geçersiz veya hatalı (400).';
        }
      } else if (response.statusCode == 429) { // Too Many Requests
        errorMessage = 'Çok fazla istek gönderildi. Lütfen biraz bekleyip tekrar deneyin (429).';
      }
      _showErrorSnackBar(errorMessage);
      return []; // Boş liste döndür
    }

    final data = json.decode(response.body); // Yanıtı JSON olarak parse et
    // Rota bulunamadıysa veya 'routes' alanı boşsa
    if (data['routes'] == null || data['routes'].isEmpty) {
      _showErrorSnackBar('Belirtilen noktalar arasında rota bulunamadı.', isWarning: true);
      return [];
    }

    // Araç ve yakıt hesaplayıcı bilgilerini al
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final selectedVehicle = vehicleProvider.selectedVehicle;
    const double cityPercentageForFuel = 50.0; // Yakıt hesaplaması için şehir içi kullanım yüzdesi (varsayılan)
    final calculator = selectedVehicle != null
        ? FuelCostCalculator(
            vehicle: selectedVehicle,
            fuelPricePerLiter: _sampleFuelPricePerLiter, // Örnek yakıt fiyatı
            cityPercentage: cityPercentageForFuel)
        : null; // Araç seçilmemişse hesaplayıcı null olur

    List<RouteOption> routeOptions = []; // Oluşturulacak rota seçenekleri listesi

    // API'den gelen her bir rota alternatifi için döngü
    for (var routeIndex = 0; routeIndex < data['routes'].length; routeIndex++) {
      final routeData = data['routes'][routeIndex];
      final String routeName = routeIndex == 0
          ? 'En Hızlı Rota' // İlk rota genellikle en hızlıdır
          : 'Alternatif Rota ${routeIndex + 1}'; // Diğerleri alternatif olarak numaralandırılır

      // Rota geometrisini (koordinat listesini) parse et
      final List<LatLng> points =
          (routeData['geometry']['coordinates'] as List<dynamic>? ?? [])
              .map((coord) {
                if (coord is List && coord.length >= 2) { // Koordinat [lon, lat] formatında
                  final double? lon = (coord[0] as num?)?.toDouble();
                  final double? lat = (coord[1] as num?)?.toDouble();
                  if (lat != null && lon != null) return LatLng(lat, lon);
                }
                return null;
              })
              .whereType<LatLng>() // Sadece geçerli LatLng objelerini al
              .toList();

      if (points.isEmpty) continue; // Rota noktası yoksa bu alternatifi atla

      // Mesafe (metre) ve süre (saniye) bilgilerini al
      final double distanceMeters = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
      final double durationSeconds = (routeData['duration'] as num?)?.toDouble() ?? 0.0;
      final double distanceKm = distanceMeters / 1000; // Metreyi kilometreye çevir
      final int durationMinutes = (durationSeconds / 60).round(); // Saniyeyi dakikaya çevir ve yuvarla

      // Rota adımlarını (manevralarını) parse et
      List<RouteStep> routeSteps = [];
      if (routeData['legs'] != null &&
          routeData['legs'].isNotEmpty &&
          routeData['legs'][0]['steps'] != null) {
        routeSteps = (routeData['legs'][0]['steps'] as List<dynamic>)
            .map((stepData) => RouteStep.fromJson(stepData)) // Her adımı RouteStep modeline dönüştür
            .toList();
      }

      // Rota adımlarını kullanarak detaylı geçiş ücreti hesapla
      final tollResult = _calculateDetailedToll(routeSteps);
      final double calculatedTollCost = tollResult['totalCost'] as double; // Toplam gişe maliyeti
      final bool hasTollSection = tollResult['hasTollRoadSectionVisible'] as bool; // Rota üzerinde ücretli yol bölümü var mı?
      final List<String> tollSegmentsDescriptions = tollResult['segments'] as List<String>; // Tespit edilen ücretli segmentlerin açıklamaları

      Map<String, dynamic> costDetails = {}; // Rota maliyet detaylarını tutacak map
      Map<String, double>? costRange; // Min-Max maliyet aralığı

      if (calculator != null) { // Araç seçilmişse yakıt ve toplam maliyeti hesapla
        costDetails = calculator.calculateRouteDetails(distanceKm, additionalTollCost: calculatedTollCost);
        costRange = calculator.calculateRouteCost(distanceKm, additionalTollCost: calculatedTollCost);
      } else { // Araç seçilmemişse sadece gişe maliyetini ekle
        costDetails['additionalTollCost'] = calculatedTollCost;
      }

      // Gişe bilgilerini maliyet detaylarına ekle
      costDetails['identifiedTollSegments'] = tollSegmentsDescriptions;
      costDetails['tollCostUnknown'] = tollResult['tollCostUnknown'] as bool; // Gişe maliyeti bilinmiyor mu?
      costDetails['hasTollRoadSectionVisible'] = hasTollSection;

      // RouteOption objesini oluştur ve listeye ekle
      routeOptions.add(RouteOption(
        name: routeName,
        distance: '${distanceKm.toStringAsFixed(1)} km', // Mesafeyi formatla
        duration: '$durationMinutes dk', // Süreyi formatla
        isTollRoad: hasTollSection, // Ücretli yol içeriyor mu? (Bu eski bir alan, routeDetails'dan kontrol ediliyor)
        points: points, // Rota koordinatları
        costRange: costRange, // Maliyet aralığı
        routeDetails: costDetails, // Detaylı maliyet bilgileri
        steps: routeSteps, // Rota adımları
        intermediatePlaces: const [], // Ara geçiş noktaları (Bu özellik kaldırılmış görünüyor)
      ));
    }
    return routeOptions; // Oluşturulan rota seçenekleri listesini döndür
  }

  // Verilen bir koordinata en yakın gişeyi bulur
  // `gates` listesindeki gişelerden `coordinate`'e `thresholdMeters` mesafesinden daha yakın olanı döndürür
  TollGate? _findClosestGate(LatLng coordinate, List<TollGate> gates, double thresholdMeters) {
    TollGate? closestGate;
    double minDistance = double.infinity; // Başlangıçta minimum mesafeyi sonsuz olarak ayarla

    if (gates.isEmpty) { // Aranacak gişe yoksa null döndür
      return null;
    }

    // Tüm gişeler üzerinde dönerek en yakın olanı bul
    for (final gate in gates) {
      final distance = _distanceCalculator(coordinate, gate.coordinates); // İki nokta arası mesafeyi hesapla
      if (distance < minDistance) { // Eğer bu gişe daha yakınsa
        minDistance = distance;
        closestGate = gate;
      }
    }

    // En yakın gişe bulunduysa ve eşik mesafesi içindeyse döndür
    if (closestGate != null) {
      if (minDistance <= thresholdMeters) {
        return closestGate; // Eşik dahilindeyse eşleşme başarılı
      } else {
        return null; // Eşik dışındaysa eşleşme başarısız
      }
    } else {
      return null; // Hiç gişe bulunamadıysa (liste boşsa buraya düşer)
    }
  }

  // Rota adımlarını analiz ederek detaylı geçiş ücreti (otoyol) maliyetini hesaplar.
  // Otoyol giriş ve çıkışlarını tespit etmeye çalışır, en yakın gişeleri bulur ve maliyeti predefined_tolls.dart'tan alır.
  Map<String, dynamic> _calculateDetailedToll(List<RouteStep> steps) {
    double totalTollCost = 0.0; // Toplam hesaplanan gişe maliyeti
    List<String> identifiedTollSegments = []; // Tespit edilen ücretli segmentlerin listesi (örn: "Gişe A -> Gişe B (15.00 ₺)")
    bool tollCostUnknown = false; // Herhangi bir segmentin maliyeti bilinmiyorsa true olur
    bool hasTollRoadSectionVisible = false; // Otoyol olarak işaretlenmiş bir bölüm var mı?
    bool isOnOtoyolSegment = false; // Şu anda bir otoyol segmentinde miyiz?
    int potentialOtoyolEntryStepIndex = -1; // Potansiyel otoyol giriş adımının indeksi

    // Adımlar üzerinde dönerek otoyol segmentlerini tespit et
    for (int i = 0; i < steps.length; i++) {
      final currentStep = steps[i];
      final previousStep = i > 0 ? steps[i - 1] : null; // Bir önceki adım (varsa)
      final currentRoadName = currentStep.name.toLowerCase(); // Mevcut adımın yol adı
      final previousRoadName = previousStep?.name.toLowerCase() ?? ''; // Önceki adımın yol adı
      final bool isCurrentOtoyol = currentRoadName.contains('otoyol'); // Mevcut adım otoyol mu?
      final bool isPreviousOtoyol = previousRoadName.contains('otoyol'); // Önceki adım otoyol muydu?

      // Otoyola giriş tespiti: Mevcut adım otoyol, ve daha önce otoyolda değildik VEYA önceki adım otoyol değildi
      if (isCurrentOtoyol && !isOnOtoyolSegment) {
        if (!isPreviousOtoyol || i == 0) { // Ya ilk adım otoyol ya da otoyol olmayan bir yoldan otoyola geçiş
          isOnOtoyolSegment = true;
          potentialOtoyolEntryStepIndex = i; // Bu adımı potansiyel giriş olarak işaretle
        }
      }
      // Otoyoldan çıkış tespiti: Mevcut adım otoyol DEĞİL, ama bir önceki adım otoyoldu VE otoyol segmentindeydik
      else if (!isCurrentOtoyol && isPreviousOtoyol && isOnOtoyolSegment) {
        // Potansiyel giriş adım indeksi geçerli değilse (bir hata durumu), segmenti sıfırla ve devam et
        if (potentialOtoyolEntryStepIndex < 0) {
          isOnOtoyolSegment = false;
          potentialOtoyolEntryStepIndex = -1;
          continue;
        }

        // Gerçek giriş referans adımını belirle:
        // Eğer potansiyel girişten bir önceki adım otoyol değilse, o adımı referans al (bağlantı yolu vs. olabilir)
        // Yoksa potansiyel giriş adımını referans al.
        RouteStep actualEntryReferenceStep;
        int actualEntryReferenceStepIndex;
        if (potentialOtoyolEntryStepIndex > 0 &&
            !steps[potentialOtoyolEntryStepIndex - 1].name.toLowerCase().contains('otoyol')) {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex - 1];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex - 1;
        } else {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex;
        }
        // Gerçek çıkış referans adımı: otoyoldan çıkılan mevcut adım
        final RouteStep actualExitReferenceStep = currentStep;
        final int actualExitReferenceStepIndex = i;

        // Referans adımlarının koordinatlarına en yakın giriş ve çıkış gişelerini bul
        final closestEntryGate = _findClosestGate(actualEntryReferenceStep.location, allTollGates, _gateMatchThresholdMeters);
        final closestExitGate = _findClosestGate(actualExitReferenceStep.location, allTollGates, _gateMatchThresholdMeters);

        String segmentDesc; // Bu segmentin açıklaması
        double? segmentCost; // Bu segmentin maliyeti
        bool currentSegmentCostUnknown = false; // Bu spesifik segmentin maliyeti bilinmiyor mu?

        // Hem giriş hem de çıkış gişesi bulunduysa
        if (closestEntryGate != null && closestExitGate != null) {
          // YENİ KONTROL: Eğer giriş ve çıkış gişesi aynıysa, bu segmenti atla (kısa bir otoyol kullanımı veya hatalı eşleşme olabilir)
          if (closestEntryGate.name == closestExitGate.name) {
            debugPrint('DEBUG:       -> SKIPPED: Entry and Exit gates are the same: "${closestEntryGate.name}".');
            // Bu segment maliyete eklenmez ve listeye dahil edilmez.
          } else {
            final entryName = closestEntryGate.name;
            final exitName = closestExitGate.name;
            segmentDesc = "$entryName -> $exitName"; // Segment açıklaması: "Giriş Gişesi -> Çıkış Gişesi"

            // Önceden tanımlanmış gişe maliyet matrisinden bu segmentin maliyetini bul
            if (tollCostsMatrix.containsKey(entryName) && tollCostsMatrix[entryName]!.containsKey(exitName)) {
              segmentCost = tollCostsMatrix[entryName]![exitName]!;
            } else if (tollCostsMatrix.containsKey(exitName) && tollCostsMatrix[exitName]!.containsKey(entryName)) {
              // Ters yönde de kontrol et (örn: A->B maliyeti B->A ile aynı olabilir)
              segmentCost = tollCostsMatrix[exitName]![entryName]!;
            } else {
              // Maliyet bulunamadıysa, bu segmentin maliyeti bilinmiyor
              currentSegmentCostUnknown = true;
              tollCostUnknown = true; // Genel olarak en az bir bilinmeyen maliyet var
            }

            if (segmentCost != null) {
              totalTollCost += segmentCost; // Bulunan maliyeti toplam maliyete ekle
              identifiedTollSegments.add("$segmentDesc (${segmentCost.toStringAsFixed(2)} ₺)");
            } else {
              identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
            }
            hasTollRoadSectionVisible = true; // Ücretli bir yol segmenti tespit edildi
          }
        } else {
          // Giriş veya çıkış gişelerinden biri veya ikisi bulunamadıysa
          segmentDesc = "Ücretli Yol Segmenti (Referans Adımlar: $actualEntryReferenceStepIndex-${actualExitReferenceStepIndex})";
          if (closestEntryGate != null) segmentDesc += " (Giriş: ${closestEntryGate.name}?)";
          else if (closestExitGate != null) segmentDesc += " (Çıkış: ${closestExitGate.name}?)";
          else segmentDesc += " (Gişeler Belirlenemedi)";

          identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
          hasTollRoadSectionVisible = true; // Ücretli yol olduğu tahmin ediliyor ama gişeler net değil
          tollCostUnknown = true; // Maliyet bilinmiyor
        }
        // Otoyol segmenti bitti, durumu sıfırla
        isOnOtoyolSegment = false;
        potentialOtoyolEntryStepIndex = -1;
      }
    }

    // Döngü bittikten sonra hala bir otoyol segmentindeysek (rota otoyolda bitiyorsa)
    if (isOnOtoyolSegment && potentialOtoyolEntryStepIndex != -1) {
      // Yukarıdaki mantığın benzeri, ancak çıkış noktası rotanın son adımı olarak kabul edilir
      // Potansiyel giriş adım indeksi geçerli değilse (bir hata durumu), segmenti sıfırla ve devam et
      if (potentialOtoyolEntryStepIndex < 0) {/* Bu durum olmamalı, ama güvenlik için */ } else {
        RouteStep actualEntryReferenceStep;
        int actualEntryReferenceStepIndex;
        // Gerçek giriş referans adımını belirle (yukarıdaki gibi)
        if (potentialOtoyolEntryStepIndex > 0 &&
            !steps[potentialOtoyolEntryStepIndex - 1].name.toLowerCase().contains('otoyol')) {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex - 1];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex - 1;
        } else {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex;
        }
        // Çıkış referans adımı rotanın son adımıdır
        final RouteStep actualExitReferenceStep = steps.last;
        final int actualExitReferenceStepIndex = steps.length - 1;

        // En yakın giriş ve çıkış gişelerini bul
        final closestEntryGate = _findClosestGate(actualEntryReferenceStep.location, allTollGates, _gateMatchThresholdMeters);
        final closestExitGate = _findClosestGate(actualExitReferenceStep.location, allTollGates, _gateMatchThresholdMeters);

        String segmentDesc;
        double? segmentCost;
        bool currentSegmentCostUnknown = false;

        if (closestEntryGate != null && closestExitGate != null) {
          // YENİ KONTROL: Giriş ve çıkış gişesi aynıysa atla
          if (closestEntryGate.name == closestExitGate.name) {
            debugPrint('DEBUG:       -> SKIPPED (End of Route): Entry and Exit gates are the same: "${closestEntryGate.name}".');
          } else {
            final entryName = closestEntryGate.name;
            final exitName = closestExitGate.name;
            segmentDesc = "$entryName -> $exitName (Rota Sonu)"; // Rota sonunda olduğunu belirt
            // Maliyeti bul
            if (tollCostsMatrix.containsKey(entryName) && tollCostsMatrix[entryName]!.containsKey(exitName)) {
              segmentCost = tollCostsMatrix[entryName]![exitName]!;
            } else if (tollCostsMatrix.containsKey(exitName) && tollCostsMatrix[exitName]!.containsKey(entryName)) {
              segmentCost = tollCostsMatrix[exitName]![entryName]!;
            } else {
              currentSegmentCostUnknown = true;
              tollCostUnknown = true;
            }
            if (segmentCost != null) {
              totalTollCost += segmentCost;
              identifiedTollSegments.add("$segmentDesc (${segmentCost.toStringAsFixed(2)} ₺)");
            } else {
              identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
            }
            hasTollRoadSectionVisible = true;
          }
        } else {
          // Gişelerden biri veya ikisi bulunamadı (rota sonu için)
          segmentDesc = "Ücretli Yol Segmenti (Referans Adımlar: $actualEntryReferenceStepIndex-${actualExitReferenceStepIndex} - Rota Sonu)";
          // (Benzer şekilde hangi gişenin bulunamadığı eklenebilir)
          identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
          hasTollRoadSectionVisible = true;
          tollCostUnknown = true;
        }
      }
    }
    // Hesaplanan toplam maliyeti, segment listesini (tekrarları kaldırarak), maliyetin bilinip bilinmediğini ve ücretli yol varlığını döndür
    return {
      'totalCost': totalTollCost,
      'segments': identifiedTollSegments.toSet().toList(), // Olası tekrarlanan segmentleri kaldır
      'tollCostUnknown': tollCostUnknown,
      'hasTollRoadSectionVisible': hasTollRoadSectionVisible,
    };
  }

  // _getSignificantPlaceName ve _getIntermediatePlaceNames fonksiyonları kaldırıldığı için yorumları da kaldırıldı.

  // Haritayı verilen rota noktalarını içerecek şekilde ayarlar
  void _fitMapToRoute(List<LatLng> points) {
    if (points.isNotEmpty && mounted) { // Nokta listesi boş değilse ve widget hala ağaçtaysa
      try {
        _mapController.fitCamera( // Harita kamerasını ayarla
          CameraFit.bounds( // Belirli sınırlar içine sığdır
            bounds: LatLngBounds.fromPoints(points), // Verilen noktalardan sınırlar oluştur
            padding: const EdgeInsets.all(80), // Sınırlara 80 piksel boşluk bırak
          ),
        );
      } catch (e) { /* Harita henüz tam olarak hazır değilse oluşabilecek hatayı sessizce yoksay */ }
    }
  }

  // Arama TextField'larından focus'u kaldırır ve arama sonuçları sheet'ini gizler
  void _unfocusAndHideSearchSheet() {
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();
    if (_currentSheet == SheetType.searchResults && mounted) {
      setState(() {
        _currentSheet = SheetType.none;
        _searchResults = []; // Arama sonuçlarını temizle
      });
    }
  }

  // Arama sonuçları listesindeki her bir öğeyi oluşturur
  Widget _buildLocationResultListItem(BuildContext context, LocationResult result) {
    // Aktif arama TextField'ına göre ikon ve renk belirle
    IconData leadingIcon = _isStartSearchActive ? Icons.location_on : Icons.flag;
    Color iconColor = _isStartSearchActive
        ? Theme.of(context).colorScheme.primary // Başlangıç için ana renk
        : Theme.of(context).colorScheme.error; // Varış için hata rengi (kırmızı)

    return ListTile(
      leading: Icon(leadingIcon, color: iconColor),
      title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis), // Konum adı
      subtitle: Text(result.type, style: TextStyle(fontSize: 12, color: Colors.grey[600])), // Konum tipi (örn: city, road)
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]), // Sağda ok ikonu
      onTap: () => _selectLocation(result), // Tıklandığında konumu seç
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }

  // Rota seçenekleri listesindeki her bir öğeyi (kartı) oluşturur
  Widget _buildRouteOptionListItem({
    required BuildContext context,
    required RouteOption route,
    required bool isSelected, // Bu rota seçili mi?
    required VoidCallback onTap, // Tıklandığında çalışacak fonksiyon
  }) {
    final routeDetails = route.routeDetails ?? {};
    final bool hasToll = routeDetails['hasTollRoadSectionVisible'] ?? false; // Ücretli yol var mı?
    final bool costUnknown = routeDetails['tollCostUnknown'] ?? false; // Gişe maliyeti bilinmiyor mu?
    final double tollCost = routeDetails['additionalTollCost'] ?? 0.0; // Tahmini gişe maliyeti

    // Ücretli yol ikonu için tooltip mesajı
    String tooltip = 'Ücretli Yol İçerebilir';
    if (hasToll) {
      if (costUnknown) tooltip = 'Ücretli Yol (Maliyet Bilgisi Yok)';
      else if (tollCost > 0) tooltip = 'Ücretli Yol (Tahmini Gişe: ${tollCost.toStringAsFixed(2)} ₺)';
      else tooltip = 'Ücretli Yol (Gişe Tespit Edildi/Ücretsiz?)';
    }

    return Card(
      elevation: isSelected ? 4 : 1, // Seçiliyse daha belirgin gölge
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide( // Seçiliyse kenarlık rengi farklı
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
      child: InkWell( // Tıklanabilir alan
        borderRadius: BorderRadius.circular(10),
        onTap: onTap, // Rota seçimi için
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row( // Rota adı ve ikonlar
                children: [
                  Expanded(
                    child: Text(
                      route.name, // Rota adı (örn: En Hızlı Rota)
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasToll) // Ücretli yol varsa ikon göster
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Tooltip(
                        message: tooltip, // İkon üzerine gelince açıklama
                        child: Icon(Icons.toll,
                            size: 20,
                            // İkon rengi duruma göre değişir
                            color: costUnknown ? Colors.orange : (tollCost > 0 ? Colors.redAccent : Colors.grey)),
                      ),
                    ),
                  if (isSelected) // Seçiliyse onay ikonu göster
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row( // Süre, mesafe ve maliyet bilgileri
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRouteInfoItem(Icons.schedule, 'Süre', route.duration, isSelected, context),
                  _buildRouteInfoItem(Icons.directions_car, 'Mesafe', route.distance, isSelected, context),
                  _buildRouteInfoItem(
                      Icons.local_gas_station,
                      'Maliyet',
                      route.costRange != null // Maliyet aralığı varsa göster
                          ? '${route.costRange!['minCost']!.toStringAsFixed(0)} - ${route.costRange!['maxCost']!.toStringAsFixed(0)} ₺'
                          : '-', // Yoksa tire göster
                      isSelected,
                      context,
                      highlight: true), // Maliyeti vurgula
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rota bilgi öğesi (ikon, etiket, değer) için yardımcı widget
  Widget _buildRouteInfoItem(IconData icon, String label, String value,
      bool isSelected, BuildContext context,
      {bool highlight = false}) { // `highlight` maliyet gibi önemli bilgileri vurgulamak için
    return Expanded( // Eşit genişlikte dağıtmak için
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])), // Etiket (Süre, Mesafe, vs.)
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value, // Değer (örn: 30 dk, 100 km)
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlight // Vurgulanacaksa ana renk, değilse siyah
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // OSRM'den gelen manevra tipi ve değiştiricisine göre uygun ikonu döndürür
  IconData _getManeuverIcon(String type, String? modifier) {
    // OSRM dökümantasyonuna göre çeşitli manevra tipleri için ikon eşleştirmesi
    switch (type) {
      case 'turn': return Icons.turn_right; // Genel dönüş (sağa varsayalım, modifier ile netleşir)
      case 'new name': return Icons.merge_type; // Yeni yol adı
      case 'depart': return Icons.outbound; // Başlangıç
      case 'arrive': return Icons.flag; // Varış
      case 'fork': return Icons.call_split; // Yol ayrımı
      case 'merge': return Icons.merge_type; // Yola birleşme
      case 'ramp': return Icons.ramp_right; // Rampa (sağa varsayalım)
      case 'roundabout': return Icons.roundabout_right; // Döner kavşak (sağa varsayalım)
      case 'end of road': return Icons.block; // Yol sonu
      case 'continue': return Icons.straight; // Düz devam et
      default: // Modifier (örn: "left", "slight right") varsa ona göre ikon seç
        if (modifier?.contains('left') ?? false) return Icons.turn_left;
        if (modifier?.contains('right') ?? false) return Icons.turn_right;
        if (modifier == 'straight') return Icons.straight;
        if (modifier == 'uturn') return Icons.u_turn_right; // U dönüşü (sağa veya sola olabilir, genel bir ikon)
        return Icons.arrow_forward; // Varsayılan ileri ikonu
    }
  }

  // Seçilen rotanın detaylarını gösteren kartı oluşturur
  Widget _buildRouteDetailedCard(BuildContext context, RouteOption route) {
    final startText = _startController.text.isNotEmpty ? _startController.text : "Başlangıç"; // Başlangıç noktası adı
    final endText = _endController.text.isNotEmpty ? _endController.text : "Varış"; // Varış noktası adı
    final vehicle = Provider.of<VehicleProvider>(context, listen: false).selectedVehicle; // Seçili araç
    final details = route.routeDetails ?? {}; // Rota detayları (maliyet, yakıt vs.)

    // Detaylardan ilgili bilgileri çek
    final double? fuelLiters = details['totalFuelConsumption'] as double?;
    final double? fuelCost = details['calculatedFuelCost'] as double?;
    final double tollCostVal = details['additionalTollCost'] as double? ?? 0.0;
    final bool costUnknown = details['tollCostUnknown'] as bool? ?? false;
    final bool hasTollSection = details['hasTollRoadSectionVisible'] as bool? ?? false;
    final List<String> segments = (details['identifiedTollSegments'] as List<dynamic>? ?? []).cast<String>(); // Ücretli segmentler
    final Map<String, double>? totalCostRange = route.costRange; // Toplam maliyet aralığı

    // Gişe durumu metni ve rengini belirle
    String tollStatusText;
    Color tollColor = Colors.black87;
    if (hasTollSection) { // Ücretli yol varsa
      if (costUnknown) { // Maliyeti bilinmiyorsa
        tollStatusText = 'Tahmini Gişe: Bilgi Yok';
        tollColor = Colors.orange.shade800;
      } else if (tollCostVal > 0) { // Maliyeti biliniyor ve 0'dan büyükse
        tollStatusText = 'Tahmini Gişe: ${tollCostVal.toStringAsFixed(2)} ₺';
        tollColor = Colors.redAccent;
      } else { // Maliyeti biliniyor ve 0 veya daha azsa (ücretsiz veya hata)
        tollStatusText = 'Tahmini Gişe: 0.00 ₺ / Ücretsiz?';
        tollColor = Colors.grey.shade700;
      }
    } else { // Ücretli yol yoksa
      tollStatusText = 'Ücretli Yol Bulunmuyor';
      tollColor = Colors.grey.shade700;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
          children: [
            // Başlangıç -> Varış başlığı
            Text('$startText → $endText', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Divider(height: 20),

            // Genel rota bilgileri (süre, mesafe, araç)
            _buildDetailRow(Icons.schedule, 'Süre', route.duration),
            _buildDetailRow(Icons.directions_car, 'Mesafe', route.distance),
            _buildDetailRow(Icons.speed, 'Araç', vehicle != null ? '${vehicle.marka} ${vehicle.model}' : 'Seçilmedi'),
            const SizedBox(height: 8),

            // Araç seçiliyse yakıt ve maliyet detayları
            if (vehicle != null) ...[
              _buildDetailRow(Icons.local_gas_station, 'Yakıt Tüketimi', fuelLiters != null ? '${fuelLiters.toStringAsFixed(1)} lt' : '-'),
              _buildDetailRow(Icons.monetization_on_outlined, 'Yakıt Maliyeti', fuelCost != null ? '${fuelCost.toStringAsFixed(2)} ₺' : '-', color: Theme.of(context).colorScheme.secondary),
              _buildDetailRow(Icons.toll, 'Gişe Durumu', tollStatusText, color: tollColor), // Gişe durumu
              if (hasTollSection && segments.isNotEmpty) // Ücretli segmentler varsa listele
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4), // İçeriden başla
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments.map((s) => Text("• $s", style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis,)).toList(),
                  ),
                ),
              const Divider(height: 20),
              // Toplam maliyet (vurgulu)
              _buildDetailRow(Icons.account_balance_wallet, 'Toplam Maliyet',
                  totalCostRange != null ? '${totalCostRange['minCost']!.toStringAsFixed(2)} - ${totalCostRange['maxCost']!.toStringAsFixed(2)} ₺' : 'Hesaplanamadı',
                  color: Theme.of(context).colorScheme.primary, isBold: true),
            ] else ...[
              // Araç seçilmemişse uyarı göster
              Card(
                color: Colors.orange[50], // Hafif turuncu arka plan
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Yakıt/toplam maliyet için araç seçimi gerekli.', style: TextStyle(color: Colors.orange[800], fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Araç olmasa da gişe durumunu göster
              _buildDetailRow(Icons.toll, 'Gişe Durumu', tollStatusText, color: tollColor),
              if (hasTollSection && segments.isNotEmpty) // Ücretli segmentler
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments.map((s) => Text("• $s", style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis,)).toList(),
                  ),
                ),
            ],

            // Geçilen şehirler özelliği kaldırıldığı için ilgili kod yorumlandı/kaldırıldı.

            const Divider(height: 24),
            // Rota adımları başlığı ve Göster/Gizle butonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Yol Tarifi Adımları', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                if (route.steps.isNotEmpty) // Adım varsa Göster/Gizle butonu
                  TextButton(
                    onPressed: () => setState(() => _showRouteStepsDetails = !_showRouteStepsDetails), // Durumu tersine çevir
                    child: Text(_showRouteStepsDetails ? 'Gizle' : 'Göster (${route.steps.length})'), // Buton metni
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact), // Kompakt stil
                  ),
              ],
            ),

            // Rota adımları listesi (gösteriliyorsa)
            if (_showRouteStepsDetails && route.steps.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200), // Maksimum yükseklik sınırı
                child: ListView.builder( // Kaydırılabilir liste
                  shrinkWrap: true, // İçeriğe göre boyutlan
                  itemCount: route.steps.length,
                  itemBuilder: (context, index) {
                    final step = route.steps[index]; // Mevcut adım
                    final icon = _getManeuverIcon(step.maneuverType, step.maneuverModifier); // Adım için ikon
                    // Adım talimatını oluştur: OSRM'den gelen 'instruction' veya 'name' alanlarını kullan
                    String instruction = step.instruction ?? step.name;
                    if (step.instruction != null && step.instruction == step.name) {
                      instruction = step.instruction!;
                    } else if (step.instruction != null && step.name.isNotEmpty && !step.instruction!.contains(step.name)) {
                      // Eğer instruction ve name farklıysa, ikisini birleştir (örn: "Sağa dön (Ana Cadde)")
                      instruction = '${step.instruction} (${step.name})';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0, right: 8.0),
                            child: Icon(icon, size: 18, color: Colors.blueGrey), // Manevra ikonu
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(instruction, style: const TextStyle(fontSize: 13.5)), // Talimat metni
                                Text('${(step.distance / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontSize: 11, color: Colors.grey)), // Adım mesafesi
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),
            // Navigasyonu Başlat butonu
            SizedBox(
              width: double.infinity, // Tam genişlik
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigasyonu Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary, // Ana renk
                  foregroundColor: Colors.white, // Beyaz metin/ikon
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _launchNavigation(route), // Tıklandığında harici navigasyon uygulamasını başlat
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Detay satırı (ikon, etiket, değer) için yardımcı widget
  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey[700])), // Etiket
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value, // Değer
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal, // Kalınlık
                  color: color ?? Colors.black87), // Renk
              textAlign: TextAlign.right, // Sağa yasla
              overflow: TextOverflow.ellipsis, // Sığmazsa ... ile bitir
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Verilen rota için harici bir navigasyon uygulaması (Google Maps) başlatır
  void _launchNavigation(RouteOption route) async {
    if (route.points.isEmpty) { // Rota noktası yoksa hata göster
      _showErrorSnackBar('Navigasyon başlatılamadı: Rota bilgisi eksik.', isWarning: true);
      return;
    }
    // Başlangıç ve varış koordinatlarını al
    final start = route.points.first;
    final end = route.points.last;
    final origin = '${start.latitude},${start.longitude}';
    final destination = '${end.latitude},${end.longitude}';
    // Google Maps URL'ini oluştur
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUrl)) { // URL açılabilir mi kontrol et
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication); // Harici uygulamada aç
      } else {
        throw 'Harita uygulaması açılamadı.'; // Açılamazsa hata fırlat
      }
    } catch (e) {
      _showErrorSnackBar('Harita başlatılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = Provider.of<RouteProvider>(context);
    final LatLng? currentLocation = routeProvider.startLocation; // Sağlayıcıdan mevcut konumu al (eğer varsa)
    // Haritanın başlangıç merkezini ve zoom seviyesini belirle
    final initialCenter = currentLocation ?? const LatLng(39.9334, 32.8597); // Mevcut konum yoksa Ankara
    final initialZoom = currentLocation != null ? 13.0 : 7.0; // Mevcut konum varsa daha yakın zoom

    List<Widget> sheetChildren = []; // DraggableScrollableSheet'in çocukları
    String sheetTitle = ''; // Sheet başlığı
    bool showLoaderInSheet = false; // Sheet içinde yükleme göstergesi aktif mi?
    Widget? headerWidget; // Sheet için özel başlık widget'ı

    // Alt sheet'in içeriğini ve başlığını _currentSheet durumuna göre ayarla
    if (_currentSheet != SheetType.none) { // Eğer bir sheet gösterilecekse
      if (_currentSheet == SheetType.searchResults) { // Arama sonuçları sheet'i
        sheetTitle = 'Arama Sonuçları (${_isStartSearchActive ? "Başlangıç" : "Varış"})';
        showLoaderInSheet = _isSearchingLocation; // Arama yapılıyorsa yükleme göster
      } else if (_currentSheet == SheetType.routeOptions) { // Rota seçenekleri sheet'i
        sheetTitle = 'Rota Seçenekleri';
        showLoaderInSheet = _isCalculatingRoute; // Rota hesaplanıyorsa yükleme göster
      }

      // Sheet için genel başlık ve kapatma butonu
      headerWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet'i sürüklemek için tutamaç
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 5,
            width: 40,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(sheetTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis,)),
                // Kapatma butonu
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Kapat',
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        if (_currentSheet == SheetType.routeOptions) {
                          // Rota seçenekleri sheet'i kapatılıyorsa tüm rota verilerini temizle
                          routeProvider.clearAllRouteData();
                          _startController.clear();
                          _endController.clear();
                          _showRouteStepsDetails = false;
                        }
                        // Genel temizlik
                        _searchResults = [];
                        _isCalculatingRoute = false;
                        _isSearchingLocation = false;
                        _currentSheet = SheetType.none; // Sheet'i kapat
                      });
                    }
                    _startFocusNode.unfocus(); // Inputlardan focus'u kaldır
                    _endFocusNode.unfocus();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1), // Başlık altına ayırıcı çizgi
        ],
      );
    }

    // Sheet içeriğini doldur
    if (_currentSheet == SheetType.searchResults) { // Arama sonuçları
      if (!showLoaderInSheet) { // Yükleme yoksa
        if (_searchResults.isNotEmpty) { // Sonuç varsa listele
          sheetChildren.addAll(_searchResults.map((r) => _buildLocationResultListItem(context, r)));
        } else { // Sonuç yoksa
          // Ve arama yapılmışsa (input boş değilse) "Sonuç bulunamadı" mesajı göster
          if (!_isSearchingLocation && (_isStartSearchActive ? _startController.text.isNotEmpty : _endController.text.isNotEmpty)) {
            sheetChildren.add(const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text('Sonuç bulunamadı.'))));
          }
        }
      }
    } else if (_currentSheet == SheetType.routeOptions) { // Rota seçenekleri
      if (!showLoaderInSheet && routeProvider.routeOptionsList.isNotEmpty) { // Yükleme yoksa ve rota seçenekleri varsa
        // Rota seçeneklerini listele
        sheetChildren.addAll(routeProvider.routeOptionsList.map((route) =>
            _buildRouteOptionListItem(
                context: context,
                route: route,
                isSelected: routeProvider.selectedRouteOption == route, // Seçili rota mı?
                onTap: () { // Rota seçildiğinde
                  if (routeProvider.selectedRouteOption != route) { // Zaten seçili değilse
                    routeProvider.selectRouteOption(route); // Rotayı seç
                    _fitMapToRoute(route.points); // Haritayı rotaya sığdır
                    if (_showRouteStepsDetails) { // Detaylar açıksa kapat (yeni rota seçildi)
                      setState(() => _showRouteStepsDetails = false);
                    }
                  }
                }))
            .toList());

        // Seçili bir rota varsa, detay kartını da ekle
        if (routeProvider.selectedRouteOption != null) {
          sheetChildren.add(_buildRouteDetailedCard(context, routeProvider.selectedRouteOption!));
        }
      } else if (!showLoaderInSheet && routeProvider.routeOptionsList.isEmpty) { // Yükleme yoksa ve rota bulunamadıysa
        sheetChildren.add(const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text('Rota bulunamadı.'))));
      }
    }

    // Eğer yükleme göstergesi aktifse, sheet'e ekle
    if (showLoaderInSheet) {
      sheetChildren.add(const Padding(padding: EdgeInsets.symmetric(vertical: 30.0), child: Center(child: CircularProgressIndicator())));
    }

    // Sheet'in en altına boşluk ekle (sistem navigasyon çubuğu vs. için)
    sheetChildren.add(SizedBox(height: MediaQuery.of(context).padding.bottom + 20));

    // DraggableScrollableSheet için boyut ayarları
    const double minSheetSize = 0.15; // Minimum yükseklik (ekranın %15'i)
    const double midSheetSize = 0.45; // Orta yükseklik (ekranın %45'i)
    const double maxSheetSize = 0.88; // Maksimum yükseklik (ekranın %88'i)
    final List<double> snapSizes = [minSheetSize, midSheetSize, maxSheetSize]; // Sıçrama noktaları
    double initialSheetSize = midSheetSize; // Başlangıç yüksekliği
    if (_currentSheet == SheetType.routeOptions) initialSheetSize = maxSheetSize; // Rota seçenekleri için daha yüksek başla
    if (showLoaderInSheet) initialSheetSize = minSheetSize; // Yükleme sırasında daha alçak başla

    return Scaffold(
      resizeToAvoidBottomInset: false, // Klavye açıldığında ekranın yeniden boyutlanmasını engelle
      body: Stack( // Widget'ları üst üste bindirmek için
        children: [
          // Arka planda harita
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              minZoom: 5,
              maxZoom: 18,
              onTap: (_, __) => _unfocusAndHideSearchSheet(), // Haritaya tıklanınca arama sheet'ini kapat
            ),
            children: [
              // OpenStreetMap karo katmanı
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.rotaapp', // Kendi paket adınızı kullanın (OSM politikası)
              ),
              // Seçili rota varsa, haritada çiz
              if (routeProvider.selectedRouteOption != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeProvider.selectedRouteOption!.points, // Rota noktaları
                      strokeWidth: 5, // Çizgi kalınlığı
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8), // Rota rengi
                    ),
                  ],
                ),
              // Başlangıç ve varış noktası işaretçileri
              MarkerLayer(
                markers: [
                  if (routeProvider.startLocation != null) // Başlangıç noktası varsa
                    Marker(
                      point: routeProvider.startLocation!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter, // İkonun alt ortasını noktaya hizala
                      child: Icon(Icons.location_on, size: 40, color: Theme.of(context).colorScheme.primary),
                    ),
                  if (routeProvider.endLocation != null) // Varış noktası varsa
                    Marker(
                      point: routeProvider.endLocation!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.flag, size: 40, color: Colors.redAccent),
                    ),
                ],
              ),
            ],
          ),
          // Üstte konum arama giriş kartı
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, // Sistem durum çubuğunun altına
            left: 10,
            right: 10,
            child: Card(
              elevation: 6, // Gölge
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlangıç noktası TextField'ı
                    Row(
                      children: [
                        Icon(Icons.trip_origin, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            focusNode: _startFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Başlangıç',
                              isDense: true, // Kompakt görünüm
                              border: InputBorder.none, // Kenarlık yok
                              suffixIconConstraints: const BoxConstraints(maxHeight: 24), // Temizleme ikonu için boyut sınırı
                              suffixIcon: _startController.text.isNotEmpty // Metin varsa temizleme ikonu
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _startController.clear();
                                        routeProvider.setStartLocation(null); // Global state'i de temizle
                                        if (mounted) setState(() => _searchResults = []);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  : (currentLocation != null && routeProvider.startLocation != currentLocation) // Mevcut konum butonu (eğer farklıysa)
                                      ? IconButton(
                                          icon: const Icon(Icons.my_location, size: 18),
                                          tooltip: 'Mevcut Konum',
                                          onPressed: () {
                                            if (mounted) setState(() => _isStartSearchActive = true);
                                            _performSearch('Mevcut Konum'); // "Mevcut Konum" için arama yap
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        )
                                      : null,
                            ),
                            textInputAction: TextInputAction.search, // Klavye "Ara" butonu
                            onSubmitted: (query) { // "Ara" butonuna basılınca
                              if (query.isNotEmpty) _performSearch(query);
                            },
                            onChanged: (query) { // Metin değiştikçe (eğer boş ise başlangıç noktasını temizle)
                              if (query.isEmpty && _isStartSearchActive) {
                                if (mounted) setState(() => _searchResults = []);
                                routeProvider.setStartLocation(null);
                              }
                            },
                            onTap: () { // Tıklandığında bu TextField'ı aktif yap
                              if (mounted) setState(() => _isStartSearchActive = true);
                            },
                          ),
                        ),
                      ],
                    ),
                    // Başlangıç ve varış arası değiştirme butonu ve ayırıcı
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Row(
                        children: [
                          Container(height: 25, width: 1, color: Colors.grey[300]), // Sol dikey çizgi
                          IconButton(
                            icon: const Icon(Icons.swap_vert, size: 22),
                            tooltip: 'Değiştir',
                            onPressed: _swapStartEndLocations, // Değiştirme fonksiyonu
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(child: Divider(height: 1, color: Colors.grey[300])), // Sağ yatay çizgi
                        ],
                      ),
                    ),
                    // Varış noktası TextField'ı
                    Row(
                      children: [
                        Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            focusNode: _endFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Varış',
                              isDense: true,
                              border: InputBorder.none,
                              suffixIconConstraints: const BoxConstraints(maxHeight: 24),
                              suffixIcon: _endController.text.isNotEmpty // Metin varsa temizleme ikonu
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _endController.clear();
                                        routeProvider.setEndLocation(null);
                                        if (mounted) setState(() => _searchResults = []);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  : null,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (query) {
                              if (query.isNotEmpty) _performSearch(query);
                            },
                            onChanged: (query) { // Metin değiştikçe (eğer boş ise varış noktasını temizle)
                              if (query.isEmpty && !_isStartSearchActive) {
                                if (mounted) setState(() => _searchResults = []);
                                routeProvider.setEndLocation(null);
                              }
                            },
                            onTap: () { // Tıklandığında bu TextField'ı aktif yap (başlangıç değil)
                              if (mounted) setState(() => _isStartSearchActive = false);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Rota Bul butonu
                    SizedBox(
                      width: double.infinity, // Tam genişlik
                      child: ElevatedButton.icon(
                        icon: _isCalculatingRoute // Rota hesaplanıyorsa yükleme ikonu
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.directions, size: 20), // Değilse yön ikonu
                        label: Text(_isCalculatingRoute ? 'Hesaplanıyor...' : 'Rota Bul'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                        ),
                        // Buton sadece rota hesaplanmıyorken VE başlangıç/varış noktaları seçiliyken aktif olur
                        onPressed: (_isCalculatingRoute || routeProvider.startLocation == null || routeProvider.endLocation == null)
                            ? null // Pasif
                            : _onRouteSearchRequested, // Aktif
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Altta açılır/kapanır sheet (arama sonuçları veya rota seçenekleri için)
          if (_currentSheet != SheetType.none) // Sadece bir sheet gösterilecekse
            LayoutBuilder(builder: (context, constraints) { // Sheet boyutlarını dinamik ayarlamak için
              return DraggableScrollableSheet(
                initialChildSize: initialSheetSize, // Başlangıç yüksekliği
                minChildSize: minSheetSize, // Minimum yükseklik
                maxChildSize: maxSheetSize, // Maksimum yükseklik
                expand: false, // Tam ekranı kaplamaz
                snap: true, // Belirli boyutlara sıçrar
                snapSizes: snapSizes, // Sıçrama noktaları
                builder: (BuildContext context, ScrollController scrollController) { // Sheet içeriğini oluşturur
                  return Card( // Kenarları yuvarlak ve gölgeli
                    elevation: 8.0,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    margin: EdgeInsets.zero, // Kenar boşluğu yok
                    clipBehavior: Clip.antiAlias, // İçeriği kart sınırlarına göre kes
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor, // Arka plan rengi
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Üst kenarlar yuvarlak
                      ),
                      child: ListView( // Kaydırılabilir içerik
                          controller: scrollController, // DraggableSheet'in verdiği scroll controller
                          padding: EdgeInsets.zero,
                          children: [
                            if (headerWidget != null) headerWidget, // Başlık widget'ı (varsa)
                            ...sheetChildren, // Asıl içerik (arama sonuçları veya rota seçenekleri)
                          ]),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }
}