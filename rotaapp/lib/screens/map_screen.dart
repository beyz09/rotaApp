import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // debugPrint için
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/flutter_map.dart' show MapOptions, TileLayer, PolylineLayer, MarkerLayer, Polyline, Marker, LatLngBounds, FitBoundsOptions, CameraFit; // fitCamera ve CameraFit için eklendi/güncellendi
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelleri ayrı dosyalara taşımak iyi bir fikir olabilir.
// Şimdilik burada tutuluyor.
class LocationResult {
  final String displayName;
  final LatLng coordinates;
  final String type;

  LocationResult({
    required this.displayName,
    required this.coordinates,
    required this.type,
  });
}

class RouteProvider extends ChangeNotifier {
  LatLng? startLocation;
  LatLng? endLocation;
  List<LatLng>? routePoints;
  String? routeDistance;
  String? routeDuration;
  List<RouteOption> routeOptions = [];

  void setStartLocation(LatLng? location) {
    startLocation = location;
    notifyListeners();
  }

  void setEndLocation(LatLng? location) {
    endLocation = location;
    notifyListeners();
  }

  void clearRoute() {
    startLocation = null;
    endLocation = null;
    routePoints = null;
    routeDistance = null;
    routeDuration = null;
    routeOptions = [];
    notifyListeners();
  }

  void selectRouteOption(RouteOption option) {
    routePoints = option.points;
    routeDistance = option.distance;
    routeDuration = option.duration;
    // Alternatifler listesini değiştirmeye gerek yok, sadece görüntülenecek rotayı güncelliyoruz.
    notifyListeners();
  }
}

class RouteOption {
  final String name;
  final String distance;
  final String duration;
  final bool isTollRoad; // OSRM doğrudan geçiş ücreti bilgisi sağlamaz, bu tahminidir.
  final List<LatLng> points;

  RouteOption({
    required this.name,
    required this.distance,
    required this.duration,
    required this.isTollRoad,
    required this.points,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true; // Harita yükleniyor durumu (konum izni, ilk konum alma)
  bool _isCalculatingRoute = false; // Rota hesaplanıyor durumu
  String? _error; // Genel hata mesajı
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  bool _showRouteOptions = false; // Rota seçenekleri kartını göster/gizle
  List<LocationResult> _startSearchResults = []; // Başlangıç arama sonuçları
  List<LocationResult> _endSearchResults = []; // Varış arama sonuçları
  final FocusNode _startFocusNode = FocusNode(); // Başlangıç TextField odak takibi
  final FocusNode _endFocusNode = FocusNode(); // Varış TextField odak takibi


  // Türkiye'yi kapsayan yaklaşık bir viewbox (sol_lon, alt_lat, sağ_lon, üst_lat)
  // Nominatim'de viewbox sadece önceliklendirme için kullanılır, sınırlama yapmaz.
  static const String turkeyViewBox = '25.5,35.5,45.0,42.0';


  @override
  void initState() {
    super.initState();
    _initializeMap();
    // Odak dinleyicileri: Arama sonuçlarını göstermek/gizlemek için
    _startFocusNode.addListener(_handleFocusChange);
    _endFocusNode.addListener(_handleFocusChange);
    // Metin değişim dinleyicileri: Arama yapmak için
    _startController.addListener(() => _searchLocations(_startController.text, true));
    _endController.addListener(() => _searchLocations(_endController.text, false));
  }

   // Odak değiştiğinde arama sonuçlarının gösterilip gizlenmesini yöneten metot
  void _handleFocusChange() {
     // FocusNode'ların hasFocus özelliği değiştiğinde UI güncellenmesi gerekebilir
     // (Örn: sonuç listesinin görünürlüğü). Bu setState çağrısı UI'ı tetikler.
     // searchText alanlarının altındaki if (_startFocusNode.hasFocus...) kontrolleri
     // bu setState sayesinde çalışır.
     if(mounted) { // Widget hala hayatta mı kontrol et
        setState(() {});
     }
  }


  Future<void> _initializeMap() async {
     if (!mounted) return;

    try {
      final status = await Permission.location.request();
      if (!mounted) return; // İzin alınırken widget yok edilmiş olabilir

      if (status.isGranted) {
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
         if (!mounted) return;

        if (!isLocationEnabled) {
           if (mounted) {
              setState(() {
                _error = 'Konum servisleri kapalı. Lütfen telefonunuzun ayarlarından açın.';
                _isLoading = false;
              });
            }
           return;
        }

        // Konum alırken zaman aşımı eklemek istiyorsanız:
        // Geolocator'da 'timeout' direkt parametre değil, daha çok Future'a uygulanan bir şeydir.
        // Ya da GeolocatorOptions ile belirlenebilir ancak getCurrentPosition'da doğrudan yok.
        // Basitçe Future'a .timeout() uygulayabiliriz:
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
           // timeLimit: const Duration(seconds: 10), // flutter_geolocator v9.0.0 ve üzeri için
        ).timeout(const Duration(seconds: 10), onTimeout: () {
           throw Exception('Konum alınırken zaman aşımı oluştu.');
        });


        if (mounted) {
          final currentLocation = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLocation = currentLocation;
            _isLoading = false;
          });
          // Başlangıç noktası olarak mevcut konumu provider'a kaydet ve text alanını güncelle
          Provider.of<RouteProvider>(
            context,
            listen: false,
          ).setStartLocation(currentLocation);
          _startController.text = 'Mevcut Konum';
        }
      } else {
         if (mounted) {
            setState(() {
              _error = 'Konum izni reddedildi. Uygulamayı kullanmak için ayarlardan izin vermeniz gerekebilir.';
              _isLoading = false;
            });
          }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Konum alınırken hata: $e'); // print yerine debugPrint
        setState(() {
          _error = 'Konum alınırken bir hata oluştu: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchLocations(String query, bool isStart) async {
    // Eğer query boşsa arama yapma, sonuç listesini temizle ve çık.
    if (query.isEmpty) {
      if(mounted) {
        setState(() {
          if (isStart) {
            _startSearchResults = [];
          } else {
            _endSearchResults = [];
          }
           // _isSearching kaldırıldı, bu satıra gerek kalmadı.
        });
      }
      return;
    }

    // Sadece ilgili TextField odaklanmışsa arama yap.
    if ((isStart && !_startFocusNode.hasFocus) || (!isStart && !_endFocusNode.hasFocus)) {
        // debugPrint('Arama tetiklendi ama TextField odaklı değil.'); // debug
        return; // Odaklanmamışsa arama yapma
    }

    // İsteğe bağlı: Arama başladığını görsel olarak göstermek için state güncellenebilir.
    // setState(() { _isSearching = true; });


    try {
      // Nominatim URL'si güncellendi:
      // - countrycodes kaldırıldı (global arama için)
      // - viewbox eklendi (Türkiye önceliği için)
      // - bounded=1 kaldırıldı (viewbox ile sınırlamamak için)
      // - accept-language=tr eklendi (Türkçe sonuçlar için)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=10&viewbox=$turkeyViewBox&accept-language=tr',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RotaApp/1.0'}, // Kullanıcı Temsilcisi Gerekli
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        final List<LocationResult> locations = results.map((result) {
          // Koordinatları güvenli şekilde double'a dönüştür
          final double lat = double.tryParse(result['lat']?.toString() ?? '') ?? 0.0;
          final double lon = double.tryParse(result['lon']?.toString() ?? '') ?? 0.0;

           // Geçersiz koordinatları filtrele (Nominatim 0,0 döndürmez genellikle, ama hata önlemi)
           if (lat == 0.0 && lon == 0.0 && result['lat'] != null && result['lon'] != null && result['lat'].toString() != '0' && result['lon'].toString() != '0') {
              // Eğer gelen değer 0 değil ama parse edilemiyorsa hata logla
              debugPrint('Koordinat parse hatası: ${result['lat']}, ${result['lon']}'); // debugPrint
              return null; // Bu sonucu atla
           }

          // display_name null ise veya boşsa atla
          final String displayName = result['display_name']?.toString() ?? '';
          if (displayName.isEmpty) {
             return null;
          }


          return LocationResult(
            displayName: displayName,
            coordinates: LatLng(lat, lon),
            type: result['type']?.toString() ?? '', // type null olabilir
          );
        }).where((loc) => loc != null) // null olanları (parse edilemeyenleri/boş isimleri) filtrele
          .cast<LocationResult>() // Filtrelemeden sonra LocationResult listesi olduğunu belirt
          .toList();

        if(mounted) {
           setState(() {
             if (isStart) {
               _startSearchResults = locations;
             } else {
               _endSearchResults = locations;
             }
             // _isSearching kaldırıldı
           });
        }
      } else {
         debugPrint('Arama API hatası: ${response.statusCode} - ${response.body}'); // debugPrint
          if (mounted) {
             setState(() {
                 if (isStart) {
                   _startSearchResults = [];
                 } else {
                   _endSearchResults = [];
                 }
                 // _isSearching kaldırıldı
             });
          }
      }
    } catch (e) {
      debugPrint('Arama sırasında network veya parse hatası: $e'); // debugPrint
       if (mounted) {
          setState(() {
              if (isStart) {
                _startSearchResults = [];
              } else {
                _endSearchResults = [];
              }
              // _isSearching kaldırıldı
          });
       }
    }
  }

  void _selectLocation(LocationResult location, bool isStart) {
    final controller = isStart ? _startController : _endController;
    controller.text = location.displayName; // TextField'ı güncelle

    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    if (isStart) {
      routeProvider.setStartLocation(location.coordinates);
       _startFocusNode.unfocus(); // Klavyeyi kapat ve odağı kaldır
    } else {
      routeProvider.setEndLocation(location.coordinates);
       _endFocusNode.unfocus(); // Klavyeyi kapat ve odağı kaldır
    }

    // Seçim yapıldıktan sonra arama sonuçlarını temizle
    if(mounted) {
       setState(() {
         if (isStart) {
           _startSearchResults = [];
         } else {
           _endSearchResults = [];
         }
       });
    }
     // Seçim yapıldıktan sonra otomatik olarak rota hesaplama tetiklenebilir mi?
     // Hayır, kullanıcı Rota Bul butonuna basmalı (veya Enter'a basabilir, o kısım altta yönetiliyor).
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    if (!mounted) return;

     setState(() {
       _isCalculatingRoute = true; // Rota hesaplama başladı
       _showRouteOptions = false; // Önceki seçenekleri gizle
     });

    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    routeProvider.clearRoute(); // Önceki rota verilerini temizle

    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true',
      );

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
           final List<RouteOption> routeOptions = [];

           for (var i = 0; i < data['routes'].length; i++) {
             final route = data['routes'][i];

             final List<dynamic> coordinates = route['geometry']['coordinates'];
             final List<LatLng> points =
                 coordinates.map((coord) {
                   if (coord is List && coord.length >= 2) {
                      // OSRM [lon, lat] formatı kullanır, LatLng [lat, lon] ister.
                      final double? lon = (coord[0] as num?)?.toDouble(); // Güvenli dönüşüm
                      final double? lat = (coord[1] as num?)?.toDouble(); // Güvenli dönüşüm
                       if (lat != null && lon != null) { // null olmayanları kullan
                          return LatLng(lat, lon);
                       }
                   }
                   return null; // Geçersiz nokta
                 }).where((point) => point != null) // null olanları filtrele
                 .cast<LatLng>() // Filtrelemeden sonra LatLng listesi olduğunu belirt
                 .toList();

             // Mesafe ve süreyi güvenli şekilde al ve dönüştür
             final double distanceInMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
             final double durationInSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;


             final distance = (distanceInMeters / 1000).toStringAsFixed(1);
             final durationInMinutes = (durationInSeconds / 60).round();

             // Geçiş ücreti kontrolü (basit ve OSRM için sınırlı)
             // Alternatif olarak OSRM'in 'tags' veya başka özelliklerini kullanmayı araştırabilirsiniz.
             final bool hasTollRoads = route['legs']?.any((leg) {
               final steps = leg['steps'];
               if (steps is List) {
                 return steps.any(
                   (step) =>
                       (step['name']?.toString().toLowerCase() ?? '').contains('otoyol') ||
                       (step['name']?.toString().toLowerCase() ?? '').contains('otoban') ||
                       (step['name']?.toString().toLowerCase() ?? '').contains('toll'),
                 );
               }
               return false;
             }) ?? false; // legs null olabilir


             routeOptions.add(
               RouteOption(
                 name: i == 0 ? 'En Hızlı Rota' : 'Alternatif Rota ${i + 1}',
                 distance: '$distance km',
                 duration: '$durationInMinutes dk',
                 isTollRoad: hasTollRoads,
                 points: points,
               ),
             );
           }

           routeProvider.routeOptions = routeOptions;
           // İlk rotayı varsayılan olarak seç ve haritayı odakla
           if (routeOptions.isNotEmpty) {
              routeProvider.selectRouteOption(routeOptions[0]);

              if (routeOptions[0].points.isNotEmpty) {
                 final bounds = LatLngBounds.fromPoints(routeOptions[0].points);
                 // Deprecated fitBounds yerine fitCamera kullan
                 _mapController.fitCamera(
                   CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50),
                   ),
                 );
              }
           }


           if(mounted) {
              setState(() {
                _showRouteOptions = true; // Rota seçeneklerini göster
              });
           }


        } else {
           // routes dizisi boşsa rota bulunamadı
           throw Exception('Belirtilen noktalar arasında rota bulunamadı.');
        }

      } else {
        // API'den HTTP hata kodu döndüyse
        debugPrint('Rota hesaplama API hatası: ${response.statusCode} - ${response.body}'); // debugPrint
        throw Exception('Rota hesaplama API hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Rota hesaplanırken hata: $e'); // debugPrint
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rota hesaplanırken bir hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
         setState(() {
           _showRouteOptions = false; // Hata olursa rota seçeneklerini gizle
         });
         routeProvider.clearRoute(); // Hata olursa rotayı temizle
      }
    } finally {
       if (mounted) {
         setState(() {
            _isCalculatingRoute = false; // Rota hesaplama bitti
         });
       }
    }
  }

  void _onRouteSearchRequested() {
    // Rota hesaplama butonu veya klavye "Done" tuşuna basıldığında (TextField odaklı değilken)
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    // Seçilen başlangıç ve varış noktaları Provider'da kayıtlı mı kontrol et
    if (start != null && end != null) {
      // Evet ise, rota hesapla
      _calculateRoute(start, end);
       // Klavyeyi kapat
       _startFocusNode.unfocus();
       _endFocusNode.unfocus();
       // Arama sonuçlarını temizle
       if(mounted) {
          setState(() {
            _startSearchResults = [];
            _endSearchResults = [];
          });
       }


    } else {
      // Hayır ise, kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen başlangıç ve varış noktalarını seçin.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Provider'dan rota bilgilerini dinliyoruz
    final routeProvider = Provider.of<RouteProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Harita"),
        actions: [
          // Mevcut Konuma Odakla Butonu
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mevcut Konuma Odakla',
            onPressed:
                _currentLocation == null || _isLoading || _error != null // Konum yoksa veya hata varsa pasif yap
                    ? null
                    : () {
                      _mapController.move(_currentLocation!, 15); // Mevcut konuma odakla
                      // İsteğe bağlı: Mevcut konumu başlangıç noktası yapabilirsiniz.
                      // _startController.text = 'Mevcut Konum';
                      // Provider.of<RouteProvider>(context, listen: false).setStartLocation(_currentLocation!);
                    },
          ),
           // Rota varsa rotayı temizleme butonu
          if (routeProvider.routePoints != null)
             IconButton(
               icon: const Icon(Icons.clear),
               tooltip: 'Rotayı Temizle',
               onPressed: () {
                 routeProvider.clearRoute(); // Provider'ı temizle
                 _startController.clear(); // Text alanlarını da temizle
                 _endController.clear();
                 if(mounted) {
                    setState(() {
                       _showRouteOptions = false; // Rota seçeneklerini gizle
                    });
                 }
                 // Haritayı başlangıç konumuna veya varsayılana geri döndür
                 _mapController.move(_currentLocation ?? const LatLng(41.0082, 28.9784), _currentLocation != null ? 13 : 8);
               },
             ),
        ],
      ),
      body: Stack(
        children: [
          // Harita Yükleniyor veya Hata Durumu
          _isLoading || _error != null
              ? Center(
                child: _isLoading
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
                            _currentLocation ?? const LatLng(41.0082, 28.9784),
                        initialZoom: _currentLocation != null ? 13 : 8,
                        maxZoom: 18,
                        minZoom: 3,
                        keepAlive: true,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.rotaapp',
                          maxZoom: 19,
                        ),
                        // Mevcut konum marker'ı
                        if (_currentLocation != null && routeProvider.startLocation != _currentLocation)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.cyan,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                         // Başlangıç ve Bitiş markerları
                        MarkerLayer(
                          markers: [
                            if (routeProvider.startLocation != null)
                              Marker(
                                point: routeProvider.startLocation!,
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.green,
                                  size: 40,
                                ),
                              ),
                            if (routeProvider.endLocation != null)
                              Marker(
                                point: routeProvider.endLocation!,
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),

                        // Rota çizgisi
                        if (routeProvider.routePoints != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routeProvider.routePoints!,
                                strokeWidth: 4,
                                color: Theme.of(context).colorScheme.primary,
                                borderStrokeWidth: 1,
                                // deprecated withOpacity yerine Color.fromARGB kullan
                                borderColor: Color.fromARGB((255 * 0.5).round(), 0, 0, 0), // Black with 50% opacity
                                // veya daha basit:
                                // borderColor: Colors.black54,
                              ),
                            ],
                          ),
                      ],
                    ),

          // Arama ve Rota Bul Kartı
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlangıç Noktası Arama Alanı
                    TextField(
                      controller: _startController,
                      focusNode: _startFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Başlangıç noktası',
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: _currentLocation != null
                            ? IconButton(
                                icon: const Icon(Icons.my_location),
                                tooltip: 'Mevcut Konumu Başlangıç Yap',
                                onPressed: () {
                                  _startController.text = 'Mevcut Konum';
                                  Provider.of<RouteProvider>(
                                    context,
                                    listen: false,
                                  ).setStartLocation(_currentLocation!);
                                   if(mounted) {
                                     setState(() { _startSearchResults = []; });
                                   }
                                   _startFocusNode.unfocus();
                                },
                              )
                            : null,
                         suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      onSubmitted: (_) {
                         // Eğer arama sonuçları görünüyorsa ve Enter'a basıldıysa ilk sonucu seç
                         // Arama sonuçları sadece TextField odaklıyken gösteriliyor.
                         if (_startSearchResults.isNotEmpty && _startFocusNode.hasFocus) {
                           _selectLocation(_startSearchResults.first, true);
                         } else {
                           // Sonuç listesi açık değilse veya boşsa rota aramayı dene
                           _onRouteSearchRequested();
                         }
                      },
                    ),
                     // Başlangıç Arama Sonuçları Listesi
                    // Sadece TextField odaklıyken ve sonuç varsa göster
                    if (_startFocusNode.hasFocus && _startSearchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromARGB((255 * 0.1).round(), 0, 0, 0), // Black with 10% opacity
                              // veya daha basit:
                              // color: Colors.black.withOpacity(0.1), // Tekrar eski haline dönebilir veya Color.fromRGBO kullanın. Linter'ın ne kadar katı olduğuna bağlı. Color.fromRGBO daha modern.
                               // color: const Color.fromRGBO(0, 0, 0, 0.1), // Daha iyi yaklaşım
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                           shrinkWrap: true,
                           primary: false,
                           padding: EdgeInsets.zero,
                          itemCount: _startSearchResults.length,
                          itemBuilder: (context, index) {
                            final location = _startSearchResults[index];
                            return ListTile(
                              title: Text(location.displayName),
                              subtitle: Text(location.type),
                              onTap: () => _selectLocation(location, true),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Varış Noktası Arama Alanı ve Rota Bul Butonu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            focusNode: _endFocusNode,
                            decoration: const InputDecoration(
                              hintText: 'Varış noktası',
                              prefixIcon: Icon(Icons.flag),
                               suffixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                            ),
                             onSubmitted: (_) {
                                if (_endSearchResults.isNotEmpty && _endFocusNode.hasFocus) {
                                   _selectLocation(_endSearchResults.first, false);
                                 } else {
                                   _onRouteSearchRequested();
                                 }
                             },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rota Bul Butonu
                        ElevatedButton.icon(
                          onPressed: _isCalculatingRoute ? null : _onRouteSearchRequested, // Hesaplama yapılıyorsa pasif yap
                          icon: _isCalculatingRoute
                              ? const SizedBox( // Loading spinner ekle
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isCalculatingRoute ? 'Hesaplanıyor...' : 'Rota Bul'),
                        ),
                      ],
                    ),
                    // Varış Arama Sonuçları Listesi
                    // Sadece TextField odaklıyken ve sonuç varsa göster
                    if (_endFocusNode.hasFocus && _endSearchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                         decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromARGB((255 * 0.1).round(), 0, 0, 0), // Black with 10% opacity
                              // veya daha basit:
                              // color: Colors.black.withOpacity(0.1),
                              // color: const Color.fromRGBO(0, 0, 0, 0.1), // Daha iyi yaklaşım
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemCount: _endSearchResults.length,
                          itemBuilder: (context, index) {
                            final location = _endSearchResults[index];
                             return ListTile(
                              title: Text(location.displayName),
                              subtitle: Text(location.type),
                              onTap: () => _selectLocation(location, false),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Rota Seçenekleri Kartı
          if (_showRouteOptions && routeProvider.routeOptions.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Card(
                elevation: 8,
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rota Özet Başlığı
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tahmini Süre / Mesafe',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${routeProvider.routeDuration ?? '-'} • ${routeProvider.routeDistance ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Rotayı Temizle',
                            onPressed: () {
                              if(mounted) {
                                setState(() {
                                  _showRouteOptions = false;
                                });
                              }
                              routeProvider.clearRoute();
                              _startController.clear();
                              _endController.clear();
                              _mapController.move(_currentLocation ?? const LatLng(41.0082, 28.9784), _currentLocation != null ? 13 : 8);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Alternatif Rota Seçenekleri Listesi
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: routeProvider.routeOptions.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final option = routeProvider.routeOptions[index];
                           final isSelected = routeProvider.routePoints?.isNotEmpty == true &&
                                               option.points.isNotEmpty == true &&
                                               routeProvider.routePoints![0] == option.points[0];


                          return Container(
                            width: 160,
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : null,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                 width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                routeProvider.selectRouteOption(option);
                                // İsteğe bağlı: Seçilen rotaya haritayı odakla
                                if (option.points.isNotEmpty) {
                                  final bounds = LatLngBounds.fromPoints(option.points);
                                   // Deprecated fitBounds yerine fitCamera kullan
                                  _mapController.fitCamera(
                                     CameraFit.bounds(
                                        bounds: bounds,
                                        padding: const EdgeInsets.all(50),
                                     ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          option.isTollRoad ? Icons.attach_money : Icons.route,
                                          color:
                                              isSelected
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Colors.grey.shade600,
                                           size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            option.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isSelected
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Colors.black87,
                                               fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                     const SizedBox(height: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.distance,
                                          style: TextStyle(
                                            color:
                                                isSelected
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Colors.black54,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          option.duration,
                                          style: TextStyle(
                                            color:
                                                isSelected
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Colors.black54,
                                             fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Listenerları dispose etmeden önce kaldırın
    _startController.removeListener(() => _searchLocations(_startController.text, true));
    _endController.removeListener(() => _searchLocations(_endController.text, false));
    _startFocusNode.removeListener(_handleFocusChange);
    _endFocusNode.removeListener(_handleFocusChange);

    _mapController.dispose();
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();

    super.dispose();
  }
}