import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // debugPrint için
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/flutter_map.dart'
    show
        MapOptions,
        TileLayer,
        PolylineLayer,
        MarkerLayer,
        Polyline,
        Marker,
        LatLngBounds,
        CameraFit; // fitCamera ve CameraFit için
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
<<<<<<< Updated upstream
import 'package:url_launcher/url_launcher.dart';
=======
import 'dart:math'; // min fonksiyonu için
import 'dart:async'; // Timer için
import 'package:flutter/foundation.dart' show kIsWeb; // Web platform kontrolü için
>>>>>>> Stashed changes

// Kendi modellerimizi import ediyoruz
import '../models/location_result.dart';
import '../models/route_option.dart';
<<<<<<< Updated upstream
import '../models/vehicle.dart'; // Eğer Vehicle modelin varsa
import '../models/fuel_cost_calculator.dart';
=======
import '../models/vehicle.dart';
>>>>>>> Stashed changes
// Kendi provider'ımızı import ediyoruz
import '../providers/route_provider.dart';
import '../providers/vehicle_provider.dart'; // Eğer VehicleProvider'ın varsa

// Diğer servisleri buraya import edeceğiz (şimdilik doğrudan API çağrıları yapılıyor)
// import '../services/nominatim_service.dart'; // Arama servisi
// import '../services/osrm_service.dart'; // Rota servisi
// import '../services/location_service.dart'; // Konum servisi

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true; // Harita ve başlangıç konumu yükleniyor durumu
  bool _isCalculatingRoute = false; // Rota hesaplanıyor durumu
  String? _error; // Genel hata mesajı
  final MapController _mapController = MapController();
  LatLng? _currentLocation; // Mevcut konum
  final TextEditingController _startController =
      TextEditingController(); // Başlangıç TextField
  final TextEditingController _endController =
      TextEditingController(); // Varış TextField
  bool _showRouteOptions = false; // Rota seçenekleri kartını göster/gizle
  List<LocationResult> _startSearchResults = []; // Başlangıç arama sonuçları
  List<LocationResult> _endSearchResults = []; // Varış arama sonuçları
  final FocusNode _startFocusNode =
      FocusNode(); // Başlangıç TextField odak takibi
  final FocusNode _endFocusNode = FocusNode(); // Varış TextField odak takibi

  // "Daha Fazla Sonuç Göster" fonksiyonelliği için state değişkenleri
  bool _showAllStartResults = false;
  bool _showAllEndResults = false;
  static const int _initialSearchLimit =
      5; // Başlangıçta gösterilecek sonuç sayısı

  // Debounce için timer'lar
  Timer? _startSearchTimer;
  Timer? _endSearchTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 400); // 400ms bekleme süresi

  // Türkiye'yi kapsayan yaklaşık bir viewbox (sol_lon, alt_lat, sağ_lon, üst_lat)
  // Arama sonuçlarını Türkiye içine odaklamak için
  static const String turkeyViewBox = '25.5,35.5,45.0,42.0';

  // Rota maliyeti hesaplaması için örnek yakıt fiyatı (litre/TL)
  // Bu bilgi Araç Bilgilerim'den veya kullanıcıdan alınabilir.
  // Şimdilik sabit bir örnek değer kullanıyoruz.
  // Araç provider'ından alınırken araç türüne göre farklı fiyatlar olabilir.
  double _sampleFuelPricePerLiter = 42.0; // Örnek fiyat TL/Litre

  // !!! WEB ÜZERİNDE TEST AMAÇLI CORS PROXY ÖN EKİ !!!
  // !!! ÜRETİMDE KULLANILMAMALIDIR !!!
  // Yerine kendi backend proxy'nizi veya API Gateway kullanmalısınız.
  // Bu proxy sadece geliştirme ortamında tarayıcı kaynaklı CORS hatalarını aşmaya yarar.
  // Herhangi bir CORS proxy kullanabilirsiniz, bu bir örnektir.
  static const String _corsProxy = 'https://corsproxy.io/?'; // Örnek bir proxy

  @override
  void initState() {
    super.initState();
    _initializeMap();
    // Odak dinleyicileri: Arama sonuçlarını göstermek/gizlemek için
    _startFocusNode.addListener(_handleFocusChange);
    _endFocusNode.addListener(_handleFocusChange);
    // Metin değişim dinleyicileri: Arama yapmak için Debounce uygulandı.
    _startController.addListener(
      () => _debounceSearch(_startController.text, true),
    );
    _endController.addListener(
      () => _debounceSearch(_endController.text, false),
    );
  }

  // Debounce fonksiyonu: Kullanıcı yazmayı bıraktıktan sonra arama işlemini başlatır.
  void _debounceSearch(String query, bool isStart) {
    if (isStart) {
      _startSearchTimer?.cancel(); // Önceki timer'ı iptal et
      _startSearchTimer = Timer(_debounceDuration, () {
        _searchLocations(query, isStart); // Belirtilen süre sonra aramayı başlat
      });
    } else {
      _endSearchTimer?.cancel(); // Önceki timer'ı iptal et
      _endSearchTimer = Timer(_debounceDuration, () {
        _searchLocations(query, isStart); // Belirtilen süre sonra aramayı başlat
      });
    }
  }


  // Odak değiştiğinde UI'ı güncellemek ve arama sonuçlarını gizlemek/göstermek için
  void _handleFocusChange() {
    // Eğer widget hala mounted durumdaysa setState çağrısı güvenlidir.
    if (mounted) {
      setState(() {
        // TextField'ların odak durumu değiştiğinde arama sonuç listesinin görünürlüğünü tetikler
        // Odağın kalktığı TextField'ın "show all" bayrağını sıfırla.
        if (!_startFocusNode.hasFocus) {
          _showAllStartResults = false;
          // Odağı kaybetmişse, sonuçları temizle (UI'dan gizle)
          if (_startSearchResults.isNotEmpty) _startSearchResults = [];
           // Arama timer'ını da iptal et (aktif bir debounce beklemesi varsa)
           _startSearchTimer?.cancel();
        } else {
            // Odaklandıysa, text boş değilse yeniden arama yapabilir
             if (_startController.text.isNotEmpty && _startController.text.length >= 3) {
                _debounceSearch(_startController.text, true);
             }
        }

        if (!_endFocusNode.hasFocus) {
          _showAllEndResults = false;
           // Odağı kaybetmişse, sonuçları temizle (UI'dan gizle)
           if (_endSearchResults.isNotEmpty) _endSearchResults = [];
            // Arama timer'ını da iptal et (aktif bir debounce beklemesi varsa)
           _endSearchTimer?.cancel();
        } else {
            // Odaklandıysa, text boş değilse yeniden arama yapabilir
             if (_endController.text.isNotEmpty && _endController.text.length >= 3) {
                _debounceSearch(_endController.text, false);
             }
        }
         debugPrint('Odak değişti. Start: ${_startFocusNode.hasFocus}, End: ${_endFocusNode.hasFocus}');
      });
    }
  }

  // Uygulama başladığında veya tekrar denenince haritayı ve mevcut konumu başlatır.
  Future<void> _initializeMap() async {
    if (!mounted) return; // Widget hala ağaçta değilse hiçbir şey yapma

    try {
      debugPrint('Konum izni isteniyor...');
      // Konum iznini iste
      final status = await Permission.location.request();
      if (!mounted) return;
      debugPrint('Konum izni durumu: $status');

      // İzin verilmişse devam et
      if (status.isGranted) {
        debugPrint('Konum izni verildi. Servis durumunu kontrol ediliyor...');
        // Konum servislerinin açık olup olmadığını kontrol et
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;
        debugPrint('Konum servisleri açık mı? $isLocationEnabled');

        // Servisler kapalıysa hata göster
        if (!isLocationEnabled) {
          if (mounted) {
            setState(() {
              _error =
                  'Konum servisleri kapalı. Lütfen telefonunuzun ayarlarından açın.';
              _isLoading = false;
            });
          }
          return;
        }

        debugPrint('Konum servisleri açık. Mevcut konum alınıyor...');
        Position? position;
        try {
          // Mevcut konumu yüksek doğrulukla almaya çalış, 15 saniye zaman aşımı ile
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              // Zaman aşımında hata fırlatmak yerine null döndürerek bilinen son konumu denemeye geçeriz.
              debugPrint('Konum alınırken zaman aşımı oluştu (15s).');
              return Future.value(null); // veya throw Exception('Timeout');
            },
          );
        } on TimeoutException catch(_) {
            debugPrint('Geolocator getCurrentPosition zaman aşımı yakalandı.');
             if (!mounted) return;
             // Zaman aşımı durumunda bilinen son konumu dene
            position = await Geolocator.getLastKnownPosition();
             if (!mounted) return;
             if (position == null) {
                  if (mounted) {
                     setState(() {
                          _error = 'Konum alınamadı: Zaman aşımı. Lütfen tekrar deneyin.';
                          _isLoading = false;
                     });
                  }
                  return;
             }
              debugPrint('Zaman aşımı sonrası bilinen son konum kullanılıyor.');

        } catch (e) {
          // getCurrentPosition sırasında başka bir hata oluşursa (örneğin, konum servisi aniden kapanırsa)
          debugPrint('Geolocator getCurrentPosition beklenmedik hata: $e');
          // Hata durumunda bilinen son konumu dene
          if (!mounted) return;
          position = await Geolocator.getLastKnownPosition();
           if (!mounted) return;

          if (position == null) {
              if (mounted) {
                  setState(() {
                       _error = 'Konum alınamadı: ${e.toString()}. Lütfen tekrar deneyin.';
                       _isLoading = false;
                  });
              }
              return; // Konum alınamadı, fonksiyondan çık
          }
          debugPrint('Beklenmedik hata sonrası bilinen son konum kullanılıyor.');
        }

        // Konum başarıyla alındıysa (timeout olmadıysa veya son konum bulunduysa)
        if (mounted && position != null) {
          final currentLocation = LatLng(position.latitude, position.longitude);
          debugPrint('Mevcut konum alındı: $currentLocation');
          // Mevcut konum UI state'ini güncelle (haritada marker göstermek için)
          setState(() {
            _currentLocation = currentLocation;
            _isLoading = false;
          });

          // Başlangıç noktası olarak mevcut konumu provider'a kaydet
          // setStartLocation provider'ı notifyListeners ile güncelleyecektir.
          // UI güncellemeleri (setState) ve provider güncellemesi synchronous olarak yapılabilir.
          Provider.of<RouteProvider>(
            context,
            listen: false,
           ).setStartLocation(currentLocation);
           // TextField metnini güncelle (bu bir UI güncellemesidir)
           _startController.text = 'Mevcut Konum';
           // Haritayı mevcut konuma odakla
           _mapController.move(currentLocation, 13);
           debugPrint('Harita mevcut konuma merkezlendi ve Başlangıç Providera set edildi.');

        } else if (mounted && position == null) {
             // Eğer timeout oldu ve son konum da alınamadıysa
              setState(() {
                 _error = 'Konum alınamadı. Lütfen konum servislerini kontrol edin.';
                 _isLoading = false;
              });
               debugPrint('Konum alınamadı (timeout sonrası veya son konum yok).');
        }


      } else {
        // İzin reddedilmişse hata göster
        if (mounted) {
          setState(() {
            _error =
                'Konum izni reddedildi. Uygulamayı kullanmak için ayarlardan izin vermeniz gerekebilir.';
            _isLoading = false;
          });
           debugPrint('Konum izni reddedildi.');
        }
      }
    } catch (e) {
      // Beklenmedik bir genel hata oluşursa
      if (mounted) {
        debugPrint('Genel Konum alınırken hata: $e');
        setState(() {
          _error = 'Konum alınırken bir hata oluştu: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Nominatim API kullanarak yer arama (debounce sonrası _searchLocations tarafından çağrılır)
  Future<List<LocationResult>> _performSearch(String query) async {
    // Bu metod API çağrısını yapacak ve LocationResult listesi döndürecek.
    // Service katmanına taşınabilir.
    if (query.isEmpty || query.length < 3) {
       // Bu kontrol zaten _searchLocations'ta yapılıyor ama burada da emin olalım
       return [];
    }


    try {
      // Nominatim search API URL
      // format=json: JSON çıktı
      // q=query: Arama sorgusu (URL encode edildi)
      // limit=20: En fazla 20 sonuç (daha fazla "Daha Fazla" için)
      // viewbox: Türkiye'ye odaklanma
      // bounded=1: viewbox içine düşen sonuçlara öncelik ver (relevance'ı artırır)
      // accept-language=tr,en: Türkçe sonuçları tercih et
      final originalUrl = 'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=20&viewbox=$turkeyViewBox&bounded=1&accept-language=tr,en';

      // WEB İÇİN CORS PROXY KULLANIMI (TEST AMAÇLI)
      final url = Uri.parse(
          kIsWeb // Eğer web platformundaysak proxy kullan
              ? '$_corsProxy${Uri.encodeComponent(originalUrl)}'
              : originalUrl // Değilse direkt URL kullan (Android/iOS)
      );

       debugPrint('Nominatim arama URL: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RotaApp/1.0'}, // Kimlik için user agent ekle
      );
       debugPrint('Nominatim yanıt kodu: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        debugPrint('Nominatim ${results.length} sonuç döndürdü.');
        return results
            .map((result) {
              // JSON alanlarının null olup olmadığını ve tiplerini kontrol et
              final lat = double.tryParse(result['lat']?.toString() ?? '');
              final lon = double.tryParse(result['lon']?.toString() ?? '');
              final displayName = result['display_name']?.toString() ?? '';
              final type = result['type']?.toString() ?? '';

              // Koordinatlar geçerli ve display name boş değilse sonuç oluştur
              if (lat != null && lon != null && displayName.isNotEmpty) {
                return LocationResult(
                  displayName: displayName,
                  coordinates: LatLng(lat, lon),
                  type: type,
                );
              }
              // debugPrint('Geçersiz Nominatim sonucu atlandı: $result'); // Çok fazla log olabilir, kapalı kalsın
              return null; // Geçersiz sonuçları ele
            })
            .where((loc) => loc != null)
            .cast<LocationResult>() // null olmayanları LocationResult listesine çevir
            .toList();
      } else {
        debugPrint(
          'Arama API hatası: ${response.statusCode} - ${response.body}',
        );
        // Hata durumunda boş liste döndür
        return [];
      }
    } catch (e) {
      // ClientException (genellikle CORS), SocketException (network), FormatException (parse) vb.
      debugPrint('Arama sırasında network veya parse hatası: $e');
       // Hata durumunda kullanıcıya kısa bir bilgi verebiliriz
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Konum arama sırasında hata oluştu.'),
             backgroundColor: Colors.red,
             duration: Duration(seconds: 2),
           ),
         );
       }
      // Hata durumunda boş liste döndür
      return [];
    }
  }

    // Debounce sonrası arama sonuçlarını güncelleyen metod
    void _searchLocations(String query, bool isStart) async {
       // Sadece odaklanmış TextField için ve query boş değilse performSearch çağrılır
        if (!((isStart && _startFocusNode.hasFocus) || (!isStart && _endFocusNode.hasFocus))) {
           return; // Odaklanmamışsa arama yapma
        }
        // Query boşsa veya 3 karakterden azsa sonuçları temizler ve çıkar
        if (query.isEmpty || query.length < 3) {
             if (mounted) {
                setState(() {
                     if (isStart) _startSearchResults = [];
                     else _endSearchResults = [];
                      if (isStart) _showAllStartResults = false;
                     else _showAllEndResults = false;
                });
            }
            return;
        }


        final results = await _performSearch(query); // Perform the actual search

        if (!mounted) return; // Widget hala mounted değilse geri dön

        // Arama sonuçları geldiyse ve hala ilgili TextField odaklıysa listeyi güncelle
        // Bu kontrol, kullanıcı hızlıca başka bir alana tıklarsa stale sonuçların gösterilmesini engeller.
        if ((isStart && _startFocusNode.hasFocus) ||
            (!isStart && _endFocusNode.hasFocus)) {
            setState(() {
                if (isStart) {
                    _startSearchResults = results;
                    // Yeni arama yapıldığında "show all" bayrağını sıfırla
                    _showAllStartResults = false;
                } else {
                    _endSearchResults = results;
                     // Yeni arama yapıldığında "show all" bayrağını sıfırla
                    _showAllEndResults = false;
                }
                 debugPrint('${isStart ? "Başlangıç" : "Varış"} için ${results.length} arama sonucu güncellendi.');
            });
        } else {
             // Eğer sonuçlar gelene kadar odak kaybolduysa sonuçları gösterme/temizle
             debugPrint('Arama sonuçları geldi ancak odak kayboldu, sonuçlar temizleniyor.');
             setState(() {
                 if (isStart) _startSearchResults = [];
                 else _endSearchResults = [];
                 _showAllStartResults = false;
                 _showAllEndResults = false;
             });
        }
    }


  // Arama sonuçlarından bir yer seçildiğinde
  void _selectLocation(LocationResult location, bool isStart) {
    final controller = isStart ? _startController : _endController;
    final focusNode = isStart ? _startFocusNode : _endFocusNode;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

     // Provider'a seçilen konumu kaydet (UI güncellemelerinden önce yapmak daha tutarlı)
    if (isStart) {
      routeProvider.setStartLocation(location.coordinates);
      // İsterseniz burada LocationResult nesnesini de Provider'a kaydedebilirsiniz
      // routeProvider.setStartLocationResult(location);
      debugPrint('Başlangıç noktası seçildi ve Providera set edildi: ${location.coordinates}');
    } else {
      routeProvider.setEndLocation(location.coordinates);
       // İsterseniz burada LocationResult nesnesini de Provider'a kaydedebilirsiniz
       // routeProvider.setEndLocationResult(location);
       debugPrint('Varış noktası seçildi ve Providera set edildi: ${location.coordinates}');
    }

    // TextField'a seçilen yerin adını yaz
    controller.text = location.displayName;

    // Arama sonuçlarını temizle ve TextField odağını kaldır (klavyeyi gizle)
    // setState çağrısı, arama sonuçları listesinin gizlenmesini tetikler.
    if (mounted) {
      setState(() {
        if (isStart) {
          _startSearchResults = [];
          _showAllStartResults = false;
           _startSearchTimer?.cancel(); // Seçim yapıldı, debounce timer iptal
        } else {
          _endSearchResults = [];
          _showAllEndResults = false;
           _endSearchTimer?.cancel(); // Seçim yapıldı, debounce timer iptal
        }
         debugPrint('Seçim yapıldı, arama sonuçları temizlendi ve odak kaldırılıyor.');
      });
    }

    // Unfocus the text field to hide the keyboard and results list
    // Bu, _handleFocusChange listener'ını tetikleyerek state'in son kez güncellenmesini sağlar.
    focusNode.unfocus();


     // Seçim yapıldıktan sonra otomatik olarak rota aranmasını isterseniz burayı aktif edin
     // if (routeProvider.startLocation != null && routeProvider.endLocation != null) {
     //   _onRouteSearchRequested();
     // }
  }

  // OSRM API kullanarak rota seçeneklerini hesaplama
  Future<List<RouteOption>> _fetchRouteOptions(LatLng start, LatLng end) async {
    try {
       debugPrint('Rota hesaplama başlatıldı: ${start.latitude},${start.longitude} -> ${end.latitude},${end.longitude}');
      // OSRM route API URL
      // /route/v1/driving/ -> Sürüş profili
      // start.longitude,start.latitude;end.longitude,end.latitude -> Koordinatlar (Önce boylam, sonra enlem)
      // ?overview=full -> Tüm rota geometrisini döndür
      // &geometries=geojson -> Geometri formatı
      // &alternatives=true -> Alternatif rotaları da iste
      final originalUrl = 'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true';

       // WEB İÇİN CORS PROXY KULLANIMI (TEST AMAÇLI)
      final url = Uri.parse(
          kIsWeb // Eğer web platformundaysak proxy kullan
              ? '$_corsProxy${Uri.encodeComponent(originalUrl)}'
              : originalUrl // Değilse direkt URL kullan (Android/iOS)
      );

       debugPrint('OSRM rota URL: $url');

      final response = await http.get(url);
       debugPrint('OSRM yanıt kodu: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // debugPrint('OSRM yanıt verisi: $data'); // Debug için yanıtı yazdır

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<RouteOption> routeOptions = [];
<<<<<<< Updated upstream
          final vehicleProvider = Provider.of<VehicleProvider>(
            context,
            listen: false,
          );
          final selectedVehicle = vehicleProvider.selectedVehicle;

          if (selectedVehicle == null) {
            throw Exception('Lütfen önce bir araç seçin');
          }

          // Yakıt maliyeti hesaplayıcıyı oluştur
          final calculator = FuelCostCalculator(
            vehicle: selectedVehicle,
            fuelPricePerLiter: _sampleFuelPricePerLiter,
            // Şehir içi yüzdesini rota özelliklerine göre belirle
            cityPercentage:
                50.0, // Varsayılan değer, daha sonra rota özelliklerine göre güncellenebilir
          );
=======
          debugPrint('${data['routes'].length} rota bulundu.');
>>>>>>> Stashed changes

          for (var i = 0; i < data['routes'].length; i++) {
            final route = data['routes'][i];

            // Geometri formatını kontrol et
            if (route['geometry'] == null || route['geometry']['coordinates'] == null) {
                 debugPrint('Geçersiz rota geometrisi atlandı: Rota $i');
                 continue; // Bu rotayı atla
            }

            final List<dynamic> coordinates = route['geometry']['coordinates'];
            final List<LatLng> points = [];

<<<<<<< Updated upstream
            if (points.isEmpty) continue;
=======
            // GeoJSON formatında koordinatlar [boylam, enlem] şeklindedir.
            for (var coord in coordinates) {
                 if (coord is List && coord.length >= 2) {
                    final double? lon = (coord[0] as num?)?.toDouble();
                    final double? lat = (coord[1] as num?)?.toDouble();
                    if (lat != null && lon != null) {
                      points.add(LatLng(lat, lon));
                    } else {
                         debugPrint('Geçersiz koordinat değeri atlandı: $coord');
                    }
                 } else {
                     debugPrint('Geçersiz koordinat formatı atlandı: $coord');
                 }
            }
>>>>>>> Stashed changes

            if (points.isEmpty) {
                 debugPrint('Boş rota noktaları listesi atlandı: Rota $i');
                 continue; // Geçersiz rota
            }

            // Rota özet bilgileri (mesafe metre, süre saniye cinsinden)
            final double distanceInMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final double durationInSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

<<<<<<< Updated upstream
            // Detaylı rota bilgilerini hesapla
            final routeDetails = calculator.calculateRouteDetails(
              distanceInMeters / 1000,
            );

            // Maliyet aralığını hesapla
            final costRange = calculator.calculateRouteCost(
              distanceInMeters / 1000,
            );
=======
            // Kilometre ve dakika cinsine çevirme
            final distance = (distanceInMeters / 1000).toStringAsFixed(1); // Virgülden sonra 1 basama
            final durationInMinutes = (durationInSeconds / 60).round(); // En yakın dakikaya yuvarla

            // Yakıt maliyeti hesaplama
            final vehicleProvider = Provider.of<VehicleProvider>(
              context,
              listen: false, // Sadece okuma amaçlı
            );
            // Seçili araç null olabilir, maliyet hesaplanamayabilir.
            final selectedVehicle = vehicleProvider.selectedVehicle;
            double? routeCost; // Maliyet null olabilir

            // Seçili araç varsa ve tüketim bilgisi geçerliyse maliyet hesapla
            if (selectedVehicle != null && selectedVehicle.highwayConsumption != null && selectedVehicle.highwayConsumption! > 0) {
              // Basit maliyet hesaplaması: (Mesafe km) * (Litre/100km) / 100 * (Yakıt Fiyatı TL/Litre)
              // OSRM sadece sürüş profili kullanır, şehir içi/dışı tüketimi için ek mantık gerekir.
              // Şimdilik sadece highwayConsumption'ı kullanıyoruz. Bu yaklaşık bir değerdir.
              final double distanceInKm = distanceInMeters / 1000;
              final double consumptionPerKm = selectedVehicle.highwayConsumption! / 100; // L/km
              final double totalFuelNeeded = distanceInKm * consumptionPerKm; // Litre
               // Yakıt fiyatı varsayılan veya kullanıcıdan alınabilir. Araç türüne göre örnek fiyatlar.
               final double fuelPrice = selectedVehicle.fuelType == 'Benzin' ? 45.0 : selectedVehicle.fuelType == 'Dizel' ? 42.0 : selectedVehicle.fuelType == 'LPG' ? 20.0 : _sampleFuelPricePerLiter; // Örnek fiyatlar
              routeCost = totalFuelNeeded * fuelPrice; // Toplam maliyet TL
               debugPrint('Rota ${i+1} (${route['name'] ?? ''}) için maliyet hesaplandı: ${routeCost!.toStringAsFixed(2)} TL');

            } else if (selectedVehicle == null) {
                debugPrint('Araç seçili değil, maliyet hesaplanamadı.');
            } else if (selectedVehicle.highwayConsumption == null || selectedVehicle.highwayConsumption! <= 0) {
                 debugPrint('Seçili araç için tüketim bilgisi geçersiz (${selectedVehicle.highwayConsumption}), maliyet hesaplanamadı.');
            }
>>>>>>> Stashed changes


            routeOptions.add(
              RouteOption(
                // İlk rotayı "En Hızlı", diğerlerini "Alternatif Rota X" olarak adlandır
                name: route['name'] ?? (i == 0 ? 'En Hızlı Rota' : 'Alternatif Rota ${i + 1}'), // OSRM bazen rota adı dönebilir
                distance: '$distance km',
                duration: '$durationInMinutes dk',
<<<<<<< Updated upstream
                isTollRoad: false,
=======
                isTollRoad: false, // OSRM toll bilgisini net vermez, ek servis gerekir
>>>>>>> Stashed changes
                points: points,
                costRange: costRange,
                routeDetails: routeDetails,
              ),
            );
             debugPrint('Rota ${i+1} eklendi: ${routeOptions.last.name}, Mesafe: ${routeOptions.last.distance}, Süre: ${routeOptions.last.duration}, Maliyet: ${routeOptions.last.cost?.toStringAsFixed(2)}');
          }
          return routeOptions;
        } else {
<<<<<<< Updated upstream
          return [];
=======
           // data['routes'] boş veya null
           debugPrint('OSRM yanıtında routes verisi boş.');
          return []; // Rota bulunamadı
>>>>>>> Stashed changes
        }
      } else {
        // OSRM API hata döndürürse
        debugPrint(
          'Rota hesaplama API hatası: ${response.statusCode} - ${response.body}',
        );
         // Hata durumunda kullanıcıya kısa bir bilgi verebiliriz
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Rota hesaplama API hatası: ${response.statusCode}'),
               backgroundColor: Colors.red,
               duration: Duration(seconds: 2),
             ),
           );
         }
        // Hata durumunda boş liste döndür
         return [];
      }
    } catch (e) {
      // Ağ hatası veya parse hatası durumunda
      debugPrint('Rota API çağrısı sırasında genel hata: $e');
       // Hata durumunda kullanıcıya kısa bir bilgi verebiliriz
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Rota hesaplama sırasında bir hata oluştu.'),
             backgroundColor: Colors.red,
             duration: Duration(seconds: 2),
           ),
         );
       }
      // Hata durumunda boş liste döndür
       return [];
    }
  }

  // "Rota Bul" butonuna basıldığında veya otomatik olarak (varsa)
  void _onRouteSearchRequested() async {
    // Klavyeyi kapat ve arama sonuçlarını temizle
    // Odağı kaldırınca arama sonuçları da temizlenecektir (_handleFocusChange)
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();

    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    // Provider'dan güncel başlangıç ve bitiş noktalarını al
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    // Başlangıç ve bitiş noktaları seçili mi kontrol et
    if (start != null && end != null) {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = true; // Yükleniyor durumunu başlat
          _showRouteOptions = false; // Önceki seçenekleri gizle
           _error = null; // Önceki genel hatayı temizle
           // Rota hesaplanmaya başlamadan önceki rotayı ve seçenekleri temizle
           routeProvider.clearRoute(); // Provider'ı temizle (setState çağırır)
        });
         debugPrint('Rota hesaplama isteği başlatıldı: Başlangıç ve Bitiş noktaları providerda mevcut.');
      }

      try {
        // Rota seçeneklerini API'den al
        final routeOptions = await _fetchRouteOptions(start, end);

        if (!mounted) return; // İşlem sırasında widget dispose edildiyse geri dön

        if (routeOptions.isNotEmpty) {
           debugPrint('Rota seçenekleri başarıyla alındı: ${routeOptions.length}');
          // Provider'a seçenekleri kaydet ve ilkini seçtir
          // setRouteOptions provider'ı notifyListeners ile güncelleyecektir.
          routeProvider.setRouteOptions(routeOptions);

          // Seçilen (varsayılan olarak ilk) rotanın noktalarını kullanarak haritayı sığdır
          // Rota provider'ı set edildikten sonra routePoints güncellenmiş olmalı
          if (routeProvider.routePoints != null && routeProvider.routePoints!.isNotEmpty) {
            try {
                 final bounds = LatLngBounds.fromPoints(routeProvider.routePoints!);
                 debugPrint('Rotaya sığdırılacak sınırlar: $bounds');
                 _mapController.fitCamera(
                   CameraFit.bounds(
                     bounds: bounds,
                     padding: const EdgeInsets.all(70), // Arama kutusu ve rota kartı için boşluk bırak
                   ),
                 );
                 debugPrint('Harita rotaya sığdırıldı.');
            } catch (e) {
                 debugPrint('Haritayı rotaya sığdırırken hata: $e');
                 // Hata durumunda haritayı sadece başlangıç noktasına merkezleyebiliriz
                  _mapController.move(start, 12); // Başlangıç noktasına merkezle
            }
          } else {
             debugPrint('Rota noktaları boş (setRouteOptions sonrası kontrol), harita sığdırılamadı. Başlangıç noktasına merkezleniyor.');
             _mapController.move(start, 12); // Başlangıç noktasına merkezle
          }

          // Rota başarıyla bulunduysa rota seçenek kartını göster
          if (mounted) {
            setState(() {
              _showRouteOptions = true;
            });
             debugPrint('Rota seçenek kartı gösterildi.');
          }
           // Rota başarılı, varsa önceki SnackBar'ı kaldır
           ScaffoldMessenger.of(context).hideCurrentSnackBar();


        } else {
          // Rota bulunamadıysa
          // clearRoute zaten çağrılmıştı, sadece UI durumunu ayarla
           if (mounted) {
              setState(() {
                 _showRouteOptions = false; // Kartı gizle
              });
           }
           // Kullanıcıya bilgi mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belirtilen noktalar arasında rota bulunamadı.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
           debugPrint('Rota bulunamadı (API boş routes döndürdü).');
        }
      } catch (e) {
        // Rota hesaplama sırasında hata oluşursa (network, parse vb.)
        // Hata _fetchRouteOptions içinde loglandı. Burada kullanıcıya genel bir hata mesajı gösterelim.
         debugPrint('Rota hesaplama sırasında genel hata yakalandı: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rota hesaplanırken bir hata oluştu. Lütfen tekrar deneyin.', // Detaylı hata mesajını logda tuttuk
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        // Hata durumunda provider'ı temizle ve kartı gizle
        routeProvider.clearRoute(); // Provider'ı temizle (setState çağırır)
        if (mounted) {
           setState(() {
              _showRouteOptions = false; // Kartı gizle
           });
        }


      } finally {
        // İşlem tamamlandı (başarılı veya hatayla)
        if (mounted) {
          setState(() {
            _isCalculatingRoute = false; // Hesaplama bitti
          });
           debugPrint('Rota hesaplama işlemi tamamlandı.');
        }
      }
    } else {
      // Başlangıç veya varış eksikse
       ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Varsa önceki mesajı kaldır
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen başlangıç ve varış noktalarını seçin.'),
          backgroundColor: Colors.orange,
           duration: Duration(seconds: 3),
        ),
      );
       debugPrint('Rota hesaplama isteği iptal edildi: Başlangıç veya varış noktası providerda eksik.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provider'dan rota bilgilerini dinliyoruz
    // Provider'daki değişiklikler build metodunun tekrar çalışmasını sağlar.
    final routeProvider = Provider.of<RouteProvider>(context);
    // VehicleProvider'ı burada listen: true ile dinlemeye gerek yok
    // çünkü araç bilgisi sadece maliyet hesaplanırken _fetchRouteOptions içinde okunuyor.
    // Eğer Rota Maliyeti kartında seçili aracın adını veya detayını göstereceksek,
    // o zaman VehicleProvider'ı dinlemek gerekebilir.


    return Scaffold(
      // AppBar Figma'ya göre Bottom Nav Bar'a taşınacaksa burası boş kalır veya farklı bir AppBar olur.
      // Figma'da AppBar gibi bir şey harita üzerinde, onu Stack içine yerleştirelim.
      // body'de tüm içeriği (harita, arama kutusu, rota seçenekleri) yönet
      body: Stack(
        children: [
          // Harita Yükleniyor veya Hata Durumu
          _isLoading || _error != null
              ? Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _initializeMap,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
              )
              // Harita Görüntüsü
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _currentLocation ??
                      const LatLng(41.0082, 28.9784), // İstanbul fallback
                  initialZoom: _currentLocation != null ? 13 : 8, // Başlangıç yakınlaşma seviyesi
                  maxZoom: 19, // OSM Tile Layer maxZoom
                  minZoom: 3, // Minimum uzaklaştırma seviyesi
                  keepAlive: true, // Widget yeniden oluşturulsa bile harita durumunu koru
                  // Tıklama olaylarını dinlemek için:
                  // onTap: (tapPosition, latlng) {
                  //    debugPrint('Harita tıklandı: $latlng');
                  //    // Burada tıklanan konumu başlangıç veya bitiş yapabilirsiniz
                  //    // Örneğin, eğer başlangıç seçilmemişse tıkılanan yeri başlangıç yap:
                  //    // if (routeProvider.startLocation == null) {
                  //    //    // Nominatim API'den adres bilgisini alıp sonra seçmek daha iyi olur.
                  //    //    // Şimdilik sadece koordinatla seçelim:
                  //    //    // _selectLocation(LocationResult(displayName: 'Harita Konumu', coordinates: latlng, type: 'map_point'), true);
                  //    // } else if (routeProvider.endLocation == null) {
                  //    //     // Benzer şekilde bitiş noktası seçimi
                  //    //     // _selectLocation(LocationResult(displayName: 'Harita Konumu', coordinates: latlng, type: 'map_point'), false);
                  //    // }
                  //    // Eğer arama sonuçları görünüyorsa, haritaya tıklayınca gizleyebilirsiniz:
                  //    if (_startFocusNode.hasFocus || _endFocusNode.hasFocus) {
                  //         _startFocusNode.unfocus();
                  //         _endFocusNode.unfocus();
                  //         // _handleFocusChange listener'ı sonuçları temizler.
                  //    }
                  // },
                ),
                children: [
                  // OpenStreetMap harita katmanı
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.rotaapp', // Kendi paket adınızla değiştirin
                    maxZoom: 19, // Tile sağlayıcısının desteklediği max zoom
                  ),

                  // Mevcut konum marker'ı (Sadece bilgi amaçlı, başlangıç değilse)
                  if (_currentLocation != null &&
                      (routeProvider.startLocation == null ||
                       routeProvider.startLocation != _currentLocation)) // Başlangıç mevcut konum değilse veya seçilmemişse göster
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.cyan, // Mevcut konum için mavi tonu
                            size: 30,
                          ),
                        ),
                      ],
                    ),

                  // Başlangıç ve Bitiş markerları
                  MarkerLayer(
                    markers: [
                      // Başlangıç markerı
                      if (routeProvider.startLocation != null)
                        Marker(
                          point: routeProvider.startLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green, // Başlangıç için yeşil
                            size: 40,
                          ),
                        ),
                      // Bitiş markerı
                      if (routeProvider.endLocation != null)
                        Marker(
                          point: routeProvider.endLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.flag,
                            color: Colors.red, // Bitiş için kırmızı
                            size: 40,
                          ),
                        ),
                    ],
                  ),

                  // Rota çizgisi (seçili rota provider'dan alınır)
                  // routePoints null değilse ve boş değilse çiz
                  if (routeProvider.routePoints != null && routeProvider.routePoints!.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routeProvider.routePoints!,
                          strokeWidth: 5, // Çizgi kalınlığı
                           // deprecated withOpacity yerine Color.fromARGB kullan veya Colors.withOpacity
                          color: Theme.of(context).colorScheme.primary, // Tema ana rengi
                          borderStrokeWidth: 2, // Çizgiye border kalınlığı
                          borderColor: Colors.black54, // Yarı saydam siyah border
                        ),
                      ],
                    ),
                ],
              ),

          // Arama ve Rota Bul Kartı (Harita üzerinde sabit)
          // Bu widget _buildSearchBarCard metodu ile oluşturulur.
          _buildSearchBarCard(context),

          // Rota Seçenekleri/Maliyet Kartı (Harita üzerinde altta görünür)
          // Bu widget _buildRouteOptionsCard metodu ile oluşturulur.
          if (_showRouteOptions && routeProvider.routeOptions.isNotEmpty)
            _buildRouteOptionsCard(context, routeProvider.selectedRouteOption),

          // Rota hesaplanırken gösterilecek yükleniyor durumunu belirten overlay
          if (_isCalculatingRoute)
             const Positioned.fill( // Tüm ekranı kapla
                 child: ColoredBox( // Yarı saydam siyah arka plan
                     color: Colors.black12,
                     child: Center( // Ortaya yükleniyor simgesi koy
                         child: CircularProgressIndicator(),
                     ),
                 ),
             ),
        ],
      ),
      // Figma'ya göre Bottom Navigation Bar buraya gelecek
      // bottomNavigationBar: BottomNavigationBar(...),
    );
  }


   // --- Widget Building Methods ---

   // Arama Çubukları ve Rota Bul Butonunu içeren kartı oluşturan metod
   Widget _buildSearchBarCard(BuildContext context) {
     // Arama sonuçları gösterilecekse kartın yüksekliğini dinamik ayarlamak için
     bool showStartResultsList = _startFocusNode.hasFocus && _startSearchResults.isNotEmpty;
     bool showEndResultsList = _endFocusNode.hasFocus && _endSearchResults.isNotEmpty;

     // Başlangıç arama sonuçları listesinin boyutunu belirle (ilk 5 veya hepsi)
     int startResultsCountToShow = _showAllStartResults
         ? _startSearchResults.length // "Daha Fazla" tıklandıysa hepsi
         : min(_startSearchResults.length, _initialSearchLimit); // Yoksa ilk 5
     // "Daha Fazla" butonunun gösterilip gösterilmeyeceğini belirle
     bool showStartMoreButton = startResultsCountToShow < _startSearchResults.length;

     // Varış arama sonuçları listesinin boyutunu belirle
     int endResultsCountToShow = _showAllEndResults
         ? _endSearchResults.length // "Daha Fazla" tıklandıysa hepsi
         : min(_endSearchResults.length, _initialSearchLimit); // Yoksa ilk 5
      // "Daha Fazla" butonunun gösterilip gösterilmeyeceğini belirle
      bool showEndMoreButton = endResultsCountToShow < _endSearchResults.length;


     return Positioned(
       // AppBar yüksekliği ve üst boşluk kadar aşağıda başlat
       top: MediaQuery.of(context).padding.top + 10,
       left: 10,
       right: 10,
       child: Card(
         elevation: 4, // Kart gölgesi
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Köşe yuvarlatma
         child: Padding(
           padding: const EdgeInsets.all(8.0), // Kart içi boşluk
           child: Column(
             mainAxisSize: MainAxisSize.min, // İçeriği kadar minimum yer kapla
             children: [
               // Başlangıç Noktası Arama Alanı
               TextField(
                 controller: _startController,
                 focusNode: _startFocusNode,
                 decoration: InputDecoration(
                   hintText: 'Başlangıç noktası',
                   prefixIcon: const Icon(Icons.location_on), // Başlangıç ikonu
                   // TextField odaklı değilken mevcut konum butonu, odaklıyken temizleme butonu
                   suffixIcon:
                   _currentLocation != null && !_startFocusNode.hasFocus
                       ? IconButton(
                     icon: const Icon(Icons.my_location, color: Colors.blueGrey),
                     tooltip: 'Mevcut Konumu Başlangıç Yap',
                     onPressed: () {
                       // Mevcut Konumu seçme simgesine basınca
                       final currentLocation = _currentLocation;
                       if (currentLocation != null) {
                           // _selectLocation metodunu kullanmak hem provider'ı günceller
                           // hem de arama sonuçlarını ve odağı yönetir.
                           _selectLocation(LocationResult(displayName: 'Mevcut Konum', coordinates: currentLocation, type: 'current_location'), true);
                       } else {
                          // Mevcut konum henüz alınmadıysa bilgilendir
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mevcut konum henüz alınamadı.'),
                              backgroundColor: Colors.orange,
                               duration: Duration(seconds: 2),
                            ),
                          );
                       }
                     },
                   )
                       : _startController.text.isNotEmpty && _startFocusNode.hasFocus // Odaklıyken ve metin varken temizleme simgesi
                           ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                 _startController.clear(); // TextField'ı temizle
                                  // Provider'daki başlangıcı temizle (setStartLocation null clearRoute'u tetikler)
                                  Provider.of<RouteProvider>(context, listen: false).setStartLocation(null);
                                  // Arama sonuçlarını temizle ve "show all" bayrağını sıfırla
                                  if(mounted) {
                                      setState(() {
                                          _startSearchResults = [];
                                          _showAllStartResults = false;
                                      });
                                  }
                                  // Arama timer'ını da iptal et
                                  _startSearchTimer?.cancel();
                              },
                           )
                           : null, // Başka durumda ikon yok
                   suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40), // İkon boyutu kısıtlaması
                 ),
                 onSubmitted: (_) {
                   // Klavyede Enter'a basıldığında: Eğer sonuçlar görünüyorsa ilkini seç, yoksa rota ara.
                   // Eğer odaklı ve sonuç listesi görünüyorsa ve sonuç varsa ilkini seç
                   if (_startFocusNode.hasFocus && _startSearchResults.isNotEmpty) {
                        _selectLocation(_startSearchResults.first, true);
                   } else {
                     // Sonuç yoksa veya liste görünmüyorsa, doğrudan rota arama isteği yap
                     _onRouteSearchRequested();
                   }
                 },
               ),
               // Başlangıç Arama Sonuçları Listesi
               if (showStartResultsList) // Eğer odaklı ve sonuç varsa göster
                 Container(
                   constraints: BoxConstraints(
                       // Listenin maksimum yüksekliği: 5 sonuç * ~50 yükseklik veya "Daha Fazla" butonu varsa/hepsi gösteriliyorsa 300
                       maxHeight: showStartMoreButton || _showAllStartResults ? 300 : startResultsCountToShow * 50.0),
                   decoration: BoxDecoration(
                     color: Colors.white, // Arka plan beyaz
                     borderRadius: BorderRadius.circular(8), // Köşe yuvarlatma
                     boxShadow: [ // Hafif gölge
                       BoxShadow(
                         color: Colors.black.withOpacity(0.1),
                         blurRadius: 4,
                         offset: const Offset(0, 2),
                       ),
                     ],
                   ),
                   child: ListView.builder(
                     shrinkWrap: true, // İçeriği kadar yer kapla
                     primary: false, // ScrollView içinde nested iken scroll çakışmasını önler
                     padding: EdgeInsets.zero, // İç boşluk yok
                     // Gösterilecek sonuç sayısı + "Daha Fazla" butonu için 1 (eğer gösterilecekse)
                     itemCount: startResultsCountToShow + (showStartMoreButton ? 1 : 0),
                     itemBuilder: (context, index) {
                       if (index < startResultsCountToShow) {
                         // Normal arama sonucu öğesi
                         final location = _startSearchResults[index];
                         return ListTile(
                           title: Text(location.displayName, overflow: TextOverflow.ellipsis), // Uzun isimler için ellipsis
                           subtitle: Text(location.type, overflow: TextOverflow.ellipsis), // Uzun tipler için ellipsis
                           leading: const Icon(Icons.location_on_outlined), // İkon
                           onTap: () => _selectLocation(location, true), // Seçim callback'i
                         );
                       } else {
                         // "Daha Fazla" butonu
                         return ListTile(
                           title: Text('Daha Fazla Sonuç Göster (${_startSearchResults.length - startResultsCountToShow})'),
                           leading: const Icon(Icons.arrow_downward),
                           onTap: () {
                             // "Daha Fazla" butonuna basınca tüm sonuçları göster
                             if (mounted) {
                               setState(() {
                                 _showAllStartResults = true;
                               });
                             }
                           },
                         );
                       }
                     },
                   ),
                 ),
               const SizedBox(height: 8), // Alanlar arası boşluk

               // Varış Noktası Arama Alanı ve Rota Bul Butonu
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start, // Satır içindeki elemanları yukarı hizala
                 children: [
                   Expanded( // TextField'ın kalan alanı kaplamasını sağla
                     child: TextField(
                       controller: _endController,
                       focusNode: _endFocusNode,
                       decoration: InputDecoration(
                         hintText: 'Varış noktası',
                         prefixIcon: const Icon(Icons.flag), // Varış ikonu
                         // TextField odaklıyken ve metin varken temizleme simgesi
                         suffixIcon: _endController.text.isNotEmpty && _endFocusNode.hasFocus
                             ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                   _endController.clear(); // TextField'ı temizle
                                   // Provider'daki varışı temizle (setEndLocation null clearRoute'u tetikler)
                                   Provider.of<RouteProvider>(context, listen: false).setEndLocation(null);
                                    // Arama sonuçlarını temizle ve "show all" bayrağını sıfırla
                                    if(mounted) {
                                      setState(() {
                                          _endSearchResults = [];
                                          _showAllEndResults = false;
                                      });
                                  }
                                   // Arama timer'ını da iptal et
                                  _endSearchTimer?.cancel();
                                },
                             )
                             : null, // Başka durumda ikon yok
                         suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0), // İkon boyutu kısıtlaması
                       ),
                       onSubmitted: (_) {
                         // Klavyede Enter'a basıldığında: Eğer sonuçlar görünüyorsa ilkini seç, yoksa rota ara.
                          if (_endFocusNode.hasFocus && _endSearchResults.isNotEmpty) {
                               _selectLocation(_endSearchResults.first, false);
                          } else {
                             // Sonuç yoksa veya liste görünmüyorsa, doğrudan rota arama isteği yap
                              _onRouteSearchRequested();
                          }
                       },
                     ),
                   ),
                   const SizedBox(width: 8), // TextField ve buton arası boşluk
                   // Rota Bul Butonu
                   ElevatedButton.icon(
                     // Eğer rota hesaplanıyorsa butonu devre dışı bırak
                     onPressed: _isCalculatingRoute ? null : _onRouteSearchRequested,
                     icon: _isCalculatingRoute
                         ? const SizedBox( // Yükleniyor simgesi (spinner)
                             width: 16,
                             height: 16,
                             child: CircularProgressIndicator(
                               strokeWidth: 2,
                               color: Colors.white,
                             ),
                           )
                         : const Icon(Icons.search), // Arama ikonu
                     label: Text(_isCalculatingRoute ? 'Hesaplanıyor...' : 'Rota Bul'), // Buton metni
                   ),
                 ],
               ),
               // Varış Arama Sonuçları Listesi
                if (showEndResultsList) // Eğer odaklı ve sonuç varsa göster
                 Container(
                   constraints: BoxConstraints(
                        // Listenin maksimum yüksekliği
                       maxHeight: showEndMoreButton || _showAllEndResults ? 300 : endResultsCountToShow * 50.0),
                   decoration: BoxDecoration(
                     color: Colors.white, // Arka plan beyaz
                     borderRadius: BorderRadius.circular(8), // Köşe yuvarlatma
                     boxShadow: [ // Hafif gölge
                       BoxShadow(
                         color: Colors.black.withOpacity(0.1),
                         blurRadius: 4,
                         offset: const Offset(0, 2),
                       ),
                     ],
                   ),
                   child: ListView.builder(
                     shrinkWrap: true, // İçeriği kadar yer kapla
                     primary: false, // ScrollView içinde nested iken scroll çakışmasını önler
                     padding: EdgeInsets.zero, // İç boşluk yok
                     // Gösterilecek sonuç sayısı + "Daha Fazla" butonu için 1 (eğer gösterilecekse)
                     itemCount: endResultsCountToShow + (showEndMoreButton ? 1 : 0),
                     itemBuilder: (context, index) {
                       if (index < endResultsCountToShow) {
                         // Normal arama sonucu öğesi
                         final location = _endSearchResults[index];
                         return ListTile(
                           title: Text(location.displayName, overflow: TextOverflow.ellipsis), // Uzun isimler için ellipsis
                           subtitle: Text(location.type, overflow: TextOverflow.ellipsis), // Uzun tipler için ellipsis
                            leading: const Icon(Icons.location_on_outlined), // İkon
                           onTap: () => _selectLocation(location, false), // Seçim callback'i
                         );
                       } else {
                         // "Daha Fazla" butonu
                         return ListTile(
                           title: Text('Daha Fazla Sonuç Göster (${_endSearchResults.length - endResultsCountToShow})'),
                           leading: const Icon(Icons.arrow_downward),
                           onTap: () {
                             // "Daha Fazla" butonuna basınca tüm sonuçları göster
                             if (mounted) {
                               setState(() {
                                 _showAllEndResults = true;
                               });
                             }
                           },
                         );
                       }
                     },
                   ),
                 ),
             ],
           ),
         ),
       ),
     );
   }

  // Rota Seçenekleri (Maliyet vb.) Kartını oluşturan metod
  Widget _buildRouteOptionsCard(BuildContext context, RouteOption? route) {
    // Bu kart sadece seçili rotayı gösterir (Figma'daki yapıya benzer)
    // Alternatif rotalar için ayrı bir UI düşünülebilir.
    if (route == null) return const SizedBox(); // Rota yoksa boş döner

    // Provider'dan başlangıç ve bitiş adreslerini al
    // Not: Şu an LocationResult nesnesini provider'da tutmadığımız için
    // adres stringlerini TextController'lardan okuyoruz.
    // Daha iyi bir yapı için seçilen LocationResult nesnelerini provider'da tutabilirsiniz.
    final startAddress = _startController.text;
    final endAddress = _endController.text;

    // Provider'dan tüm rota seçeneklerini al
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final allRouteOptions = routeProvider.routeOptions; // Tüm bulunan rotalar

    // Mevcut seçili rota hariç diğer alternatif rotalar
    final alternativeRoutes = allRouteOptions.where((opt) => opt != route).toList();


    return Positioned(
      bottom: 0, // Ekranın altına hizala
      left: 0,
      right: 0,
      // DraggableScrollableSheet kullanılarak yukarı sürüklenebilir yapılabilir
      child: GestureDetector(
        // Kartı yukarı sürükleyerek tam ekran detay gösterme özelliği eklenebilir
        onVerticalDragUpdate: (details) {
           // Figma'daki detay ekranına geçiş veya DraggableScrollableSheet tetiklenebilir
           // Örneğin: if (details.primaryDelta! < -5) { showModalBottomSheet(...) }
        },
        child: Container(
          // Kartın dışına Container ekleyip yeşil arka plan ve rounded corner verelim
          decoration: BoxDecoration(
            color: const Color(0xFFDCF0D8), // Figma'daki yeşil tonu
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16), // Üst köşeleri yuvarla
            ),
<<<<<<< Updated upstream
            // Tarih ve Saat bilgisi (API'den gelmez, başlangıç zamanı vb. eklenebilir)
            Text(
              'Tarih/Saat Bilgisi',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ), // Placeholder
            const SizedBox(height: 4),
            // Başlangıç ve Bitiş isimleri (Provider'dan alınabilir)
            Text(
              '${_startController.text} - ${_endController.text}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mesafe',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      route.distance,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Süre',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      route.duration,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maliyet',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    // Maliyet aralığını göster
                    Text(
                      route.costRange != null
                          ? '${route.costRange!['minCost']!.toStringAsFixed(2)} - ${route.costRange!['maxCost']!.toStringAsFixed(2)} ₺'
                          : '-',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            route.costRange != null
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Yolculuğa Başla Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final routeProvider = Provider.of<RouteProvider>(
                    context,
                    listen: false,
                  );
                  final start = routeProvider.startLocation;
                  final end = routeProvider.endLocation;

                  if (start != null && end != null) {
                    // Varsayılan harita uygulamasını aç
                    final url = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&travelmode=driving',
                    );
                    launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.directions_car),
                label: const Text('Yolculuğa Başla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
=======
            boxShadow: [ // Hafif bir gölge ekle
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea( // Alt navigasyon çubuğu veya sistem UI'ı ile çakışmasını önler
             child: Column(
               mainAxisSize: MainAxisSize.min, // İçeriği kadar yer kapla
               children: [
                 // Üstteki tutma çubuğu (DraggableSheet'te kaydırma için kullanılır)
                 Container(
                   margin: const EdgeInsets.symmetric(vertical: 8),
                   height: 5,
                   width: 40,
                   decoration: BoxDecoration(
                     color: Colors.grey[300],
                     borderRadius: BorderRadius.circular(10),
                   ),
                 ),
                 // Rota Maliyeti Başlığı ve Kapat Butonu
                 Padding(
                   padding: const EdgeInsets.symmetric(
                     horizontal: 16.0,
                     vertical: 8.0,
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         'Rota Maliyeti', // Başlık Figma'ya göre
                         style: TextStyle(
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                           color: Colors.black87,
                         ),
                       ),
                       // Kapat butonu
                       IconButton(
                         icon: const Icon(Icons.close),
                         tooltip: 'Rotayı Temizle',
                         onPressed: () {
                           // Rotayı temizle, kartı gizle, text alanlarını temizle, haritayı başlangıca döndür
                           if (mounted) {
                             setState(() {
                               _showRouteOptions = false; // Kartı gizle
                             });
                           }
                           // Provider'ı temizle, bu provider'ı dinleyen widget'ları günceller
                           // clearRoute provider'ı notifyListeners ile güncelleyecektir.
                           Provider.of<RouteProvider>(context, listen: false).clearRoute();
                           _startController.clear(); // TextField'ları temizle
                           _endController.clear();
                            // Arama sonuçlarını da temizle
                            if(mounted) {
                                setState(() {
                                    _startSearchResults = [];
                                    _endSearchResults = [];
                                     _showAllStartResults = false;
                                    _showAllEndResults = false;
                                });
                            }
                           // Arama timer'larını da iptal et
                           _startSearchTimer?.cancel();
                           _endSearchTimer?.cancel();

                           // Haritayı mevcut konuma veya varsayılan merkeze döndür
                           _mapController.move(
                             _currentLocation ?? const LatLng(41.0082, 28.9784),
                             _currentLocation != null ? 13 : 8,
                           );
                            debugPrint('Rota temizlendi.');
                         },
                       ),
                     ],
                   ),
                 ),
                 const Divider(height: 1, thickness: 1, color: Colors.grey), // Ayırıcı çizgi

                 // Seçilen Rota Özeti Kartı (İçteki beyaz kart)
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Card(
                      elevation: 2, // Hafif gölge
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Köşe yuvarlatma
                      child: Padding(
                        padding: const EdgeInsets.all(12.0), // İç boşluk
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // Sola hizala
                          children: [
                            // Harita önizlemesi - Placeholder
                            Container(
                              height: 80, // Önizleme alanı yüksekliği
                              decoration: BoxDecoration(
                                 color: Colors.grey[200], // Arkaplan rengi
                                 borderRadius: BorderRadius.circular(8), // Köşe yuvarlatma
                              ),
                              alignment: Alignment.center, // Metni ortaya hizala
                              child: Text(
                                "Rota Önizlemesi (Placeholder)", // Gerçek bir önizleme widget'ı buraya eklenebilir
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              margin: const EdgeInsets.only(bottom: 8), // Alt boşluk
                            ),
                            // Tarih ve Saat bilgisi - Placeholder
                            Text(
                              'Bugün, ${TimeOfDay.now().format(context)}', // Örnek: Şimdiki zaman
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            // Başlangıç ve Bitiş isimleri/adresleri
                            Text(
                              startAddress.isNotEmpty ? startAddress : 'Başlangıç', // Adres boşsa placeholder
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                               overflow: TextOverflow.ellipsis, // Taşarsa üç nokta
                            ),
                             Text(
                              endAddress.isNotEmpty ? endAddress : 'Varış', // Adres boşsa placeholder
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                               overflow: TextOverflow.ellipsis, // Taşarsa üç nokta
                            ),
                            const SizedBox(height: 8), // Bilgi satırları arası boşluk
                            // Mesafe, Süre ve Maliyet bilgileri
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Alanları eşit aralıklarla dağıt
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Mesafe', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      route.distance,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Süre', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      route.duration,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Maliyet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    // Maliyet null ise '-' göster
                                    Text(
                                      route.cost != null
                                          ? '${route.cost!.toStringAsFixed(2)} TL' // Maliyeti TL olarak göster, virgülden sonra 2 basamak
                                          : '-',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: route.cost != null
                                            ? Theme.of(context).colorScheme.primary // Maliyet varsa tema rengi
                                            : Colors.grey, // Yoksa gri
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Alternatif rotalar için yatay kaydırılabilir liste (isteğe bağlı)
                             if (alternativeRoutes.isNotEmpty) ...[ // Eğer alternatif rota varsa göster
                                const SizedBox(height: 12), // Boşluk
                                const Text('Alternatif Rotalar:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8), // Boşluk
                                SizedBox(
                                  height: 70, // Alternatif rota kartları için sabit yükseklik
                                  child: ListView.separated(
                                      scrollDirection: Axis.horizontal, // Yatay kaydırma
                                      itemCount: alternativeRoutes.length, // Alternatif rota sayısı
                                      separatorBuilder: (context, index) => const SizedBox(width: 8), // Kartlar arası boşluk
                                      itemBuilder: (context, index) {
                                          final alternativeRoute = alternativeRoutes[index];

                                          return GestureDetector(
                                              onTap: () {
                                                  // Alternatif rotayı seçmek için Provider metodunu çağır
                                                  // Provider'daki selectRouteOption metodunu çağırıyoruz.
                                                  // Bu metod provider'ı notifyListeners ile güncelleyecektir.
                                                  routeProvider.selectRouteOption(alternativeRoute);

                                                  // Haritayı yeni seçilen rotaya sığdır
                                                   if (alternativeRoute.points.isNotEmpty) {
                                                       try {
                                                           final bounds = LatLngBounds.fromPoints(alternativeRoute.points);
                                                            _mapController.fitCamera(
                                                              CameraFit.bounds(
                                                                bounds: bounds,
                                                                padding: const EdgeInsets.all(70), // Haritaya sığdırırken boşluk bırak
                                                              ),
                                                            );
                                                       } catch (e) {
                                                            debugPrint('Alternatif rotayı sığdırırken hata: $e');
                                                       }
                                                   }
                                                  // Rota seçimi zaten provider'ı güncellediği için setState'e gerek kalmaz.
                                                  // Provider'ı dinleyen widget'lar (bu kartın kendisi dahil) otomatik güncellenecektir.
                                                   // if(mounted) setState((){}); // Bu satır kaldırıldı
                                              },
                                              child: Card( // Alternatif rota için küçük kart
                                                  elevation: 1, // Hafif gölge
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8), // Köşe yuvarlatma
                                                       // Seçili olanı vurgula
                                                       side: routeProvider.selectedRouteOption == alternativeRoute
                                                           ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                                                           : BorderSide.none, // Seçili değilse border yok
                                                  ),
                                                  child: Container( // Card'ın içindeki boyutlandırma ve boşluk için
                                                      width: 120, // Kart genişliği
                                                      padding: const EdgeInsets.all(8.0), // İç boşluk
                                                      child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center, // Ortaya hizala
                                                          crossAxisAlignment: CrossAxisAlignment.start, // Sola hizala
                                                          children: [
                                                              Text(alternativeRoute.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), // Rota adı
                                                              const SizedBox(height: 4), // Boşluk
                                                              Text('${alternativeRoute.distance} / ${alternativeRoute.duration}', style: TextStyle(fontSize: 10, color: Colors.grey[700])), // Mesafe / Süre
                                                               Text(
                                                                 alternativeRoute.cost != null
                                                                     ? '${alternativeRoute.cost!.toStringAsFixed(1)} TL' // Maliyet TL
                                                                     : '-', // Maliyet yoksa
                                                                 style: TextStyle(
                                                                   fontSize: 11,
                                                                   fontWeight: FontWeight.bold,
                                                                   color: alternativeRoute.cost != null ? Theme.of(context).colorScheme.primary : Colors.grey, // Maliyet varsa tema rengi
                                                                 ),
                                                               ),
                                                          ],
                                                      ),
                                                  ),
                                              ),
                                          );
                                      }
                                  ),
                                ),
                             ],
                        ],
                      ),
                    ),
                 ),
               ],
             ),
           ),
>>>>>>> Stashed changes
        ),
      ),
    );
  }


  @override
  void dispose() {
    // Listener'ları kaldır ve Controller/FocusNode/MapController'ları dispose et
    _startController.removeListener(
      () => _debounceSearch(_startController.text, true), // Debounce listener'ını kaldır
    );
    _endController.removeListener(
      () => _debounceSearch(_endController.text, false), // Debounce listener'ını kaldır
    );
    _startFocusNode.removeListener(_handleFocusChange);
    _endFocusNode.removeListener(_handleFocusChange);

    // Timer'ları dispose et
    _startSearchTimer?.cancel();
    _endSearchTimer?.cancel();

    _mapController.dispose();
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();

    // Provider'ı dispose etmeye gerek yok (genellikle), Flutter Provider paketi bunu yönetir.
    // Eğer tek bir yerde Provider(create: ...) kullanıyorsanız ve özel bir dispose logic'i varsa,
    // Provider'ı o widget'ın dispose metodunda provider.dispose() çağırarak yönetebilirsiniz.
    // Bu örnekte gerek yok.

    super.dispose();
  }
}