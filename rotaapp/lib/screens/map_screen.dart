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
import 'package:url_launcher/url_launcher.dart';

// Kendi modellerimizi import ediyoruz
import '../models/location_result.dart';
import '../models/route_option.dart';
import '../models/vehicle.dart'; // Eğer Vehicle modelin varsa
import '../models/fuel_cost_calculator.dart';
// Kendi provider'ımızı import ediyoruz
import '../providers/route_provider.dart';
import '../providers/vehicle_provider.dart'; // Eğer VehicleProvider'ın varsa

// Diğer servisleri buraya import edeceğiz
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

  // Türkiye'yi kapsayan yaklaşık bir viewbox (sol_lon, alt_lat, sağ_lon, üst_lat)
  static const String turkeyViewBox = '25.5,35.5,45.0,42.0';

  // Rota maliyeti hesaplaması için örnek yakıt fiyatı (litre/TL)
  // Bu bilgi Araç Bilgilerim'den veya kullanıcıdan alınabilir.
  double _sampleFuelPricePerLiter = 42.0; // Örnek fiyat

  @override
  void initState() {
    super.initState();
    _initializeMap();
    // Odak dinleyicileri: Arama sonuçlarını göstermek/gizlemek için
    _startFocusNode.addListener(_handleFocusChange);
    _endFocusNode.addListener(_handleFocusChange);
    // Metin değişim dinleyicileri: Arama yapmak için
    _startController.addListener(
      () => _searchLocations(_startController.text, true),
    );
    _endController.addListener(
      () => _searchLocations(_endController.text, false),
    );
  }

  // Odak değiştiğinde UI'ı güncellemek için
  void _handleFocusChange() {
    if (mounted) {
      setState(
        () {},
      ); // TextField'ların odak durumu değiştiğinde arama sonuç listesinin görünürlüğünü tetikler
    }
  }

  Future<void> _initializeMap() async {
    if (!mounted) return;

    try {
      final status = await Permission.location.request();
      if (!mounted) return;

      if (status.isGranted) {
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;

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

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Konum alınırken zaman aşımı oluştu.');
          },
        );

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
            _error =
                'Konum izni reddedildi. Uygulamayı kullanmak için ayarlardan izin vermeniz gerekebilir.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Konum alınırken hata: $e');
        setState(() {
          _error = 'Konum alınırken bir hata oluştu: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<LocationResult>> _fetchLocationSearchResults(String query) async {
    // Bu metod API çağrısını yapacak ve LocationResult listesi döndürecek.
    // Service katmanına taşınabilir.
    if (query.isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=10&viewbox=$turkeyViewBox&accept-language=tr',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RotaApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results
            .map((result) {
              final double lat =
                  double.tryParse(result['lat']?.toString() ?? '') ?? 0.0;
              final double lon =
                  double.tryParse(result['lon']?.toString() ?? '') ?? 0.0;

              final String displayName =
                  result['display_name']?.toString() ?? '';
              if (displayName.isEmpty) {
                return null;
              }

              return LocationResult(
                displayName: displayName,
                coordinates: LatLng(lat, lon),
                type: result['type']?.toString() ?? '',
              );
            })
            .where((loc) => loc != null)
            .cast<LocationResult>()
            .toList();
      } else {
        debugPrint(
          'Arama API hatası: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Arama sırasında network veya parse hatası: $e');
      return [];
    }
  }

  void _searchLocations(String query, bool isStart) async {
    if ((isStart && !_startFocusNode.hasFocus) ||
        (!isStart && !_endFocusNode.hasFocus)) {
      return; // Odaklanmamışsa arama yapma
    }

    // setState(() { _isSearching = true; }); // İsteğe bağlı spinner için

    final results = await _fetchLocationSearchResults(query);

    if (!mounted) return;

    setState(() {
      if (isStart) {
        _startSearchResults = results;
      } else {
        _endSearchResults = results;
      }
      // setState(() { _isSearching = false; }); // İsteğe bağlı spinner için
    });
  }

  void _selectLocation(LocationResult location, bool isStart) {
    final controller = isStart ? _startController : _endController;
    controller.text = location.displayName;

    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    if (isStart) {
      routeProvider.setStartLocation(location.coordinates);
      _startFocusNode.unfocus();
    } else {
      routeProvider.setEndLocation(location.coordinates);
      _endFocusNode.unfocus();
    }

    if (mounted) {
      setState(() {
        if (isStart) {
          _startSearchResults = [];
        } else {
          _endSearchResults = [];
        }
      });
    }
  }

  Future<List<RouteOption>> _fetchRouteOptions(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<RouteOption> routeOptions = [];
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

          for (var i = 0; i < data['routes'].length; i++) {
            final route = data['routes'][i];

            final List<dynamic> coordinates = route['geometry']['coordinates'];
            final List<LatLng> points =
                coordinates
                    .map((coord) {
                      if (coord is List && coord.length >= 2) {
                        final double? lon = (coord[0] as num?)?.toDouble();
                        final double? lat = (coord[1] as num?)?.toDouble();
                        if (lat != null && lon != null) {
                          return LatLng(lat, lon);
                        }
                      }
                      return null;
                    })
                    .where((point) => point != null)
                    .cast<LatLng>()
                    .toList();

            if (points.isEmpty) continue;

            final double distanceInMeters =
                (route['distance'] as num?)?.toDouble() ?? 0.0;
            final double durationInSeconds =
                (route['duration'] as num?)?.toDouble() ?? 0.0;

            final distance = (distanceInMeters / 1000).toStringAsFixed(1);
            final durationInMinutes = (durationInSeconds / 60).round();

            // Detaylı rota bilgilerini hesapla
            final routeDetails = calculator.calculateRouteDetails(
              distanceInMeters / 1000,
            );

            // Maliyet aralığını hesapla
            final costRange = calculator.calculateRouteCost(
              distanceInMeters / 1000,
            );

            routeOptions.add(
              RouteOption(
                name: i == 0 ? 'En Hızlı Rota' : 'Alternatif Rota ${i + 1}',
                distance: '$distance km',
                duration: '$durationInMinutes dk',
                isTollRoad: false,
                points: points,
                costRange: costRange,
                routeDetails: routeDetails,
              ),
            );
          }
          return routeOptions;
        } else {
          return [];
        }
      } else {
        debugPrint(
          'Rota hesaplama API hatası: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Rota hesaplama API hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Rota API çağrısı sırasında hata: $e');
      throw Exception('Rota API çağrısı sırasında bir hata oluştu: $e');
    }
  }

  void _onRouteSearchRequested() async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    if (start != null && end != null) {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = true;
          _showRouteOptions = false; // Önceki seçenekleri gizle
        });
        // Arama sonuçlarını temizle
        _startSearchResults = [];
        _endSearchResults = [];
      }

      try {
        final routeOptions = await _fetchRouteOptions(start, end);
        if (!mounted) return;

        if (routeOptions.isNotEmpty) {
          routeProvider.setRouteOptions(
            routeOptions,
          ); // Provider'a seçenekleri kaydet ve ilkini seçtir

          if (routeOptions[0].points.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints(routeOptions[0].points);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
              ),
            );
          }

          if (mounted) {
            setState(() {
              _showRouteOptions = true; // Rota seçenek kartını göster
            });
          }
        } else {
          // Rota bulunamadıysa
          routeProvider.clearRoute(); // Provider'ı temizle
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belirtilen noktalar arasında rota bulunamadı.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        // Hata zaten _fetchRouteOptions içinde loglandı. Burada sadece kullanıcıya gösterelim.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rota hesaplanırken bir hata oluştu: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        routeProvider.clearRoute(); // Hata olursa rotayı temizle
      } finally {
        if (mounted) {
          setState(() {
            _isCalculatingRoute = false; // Hesaplama bitti
          });
        }
      }

      // Klavyeyi kapat
      _startFocusNode.unfocus();
      _endFocusNode.unfocus();
    } else {
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
    // Provider'dan araç bilgisini dinliyoruz (maliyet gösterimi için)
    final vehicleProvider = Provider.of<VehicleProvider>(context);

    return Scaffold(
      // AppBar Bottom Nav Bar'a taşınacaksa burası boş kalır veya farklı bir AppBar olur.
      // Figma'da AppBar gibi bir şey var, ama map üzerinde. Onu Stack içine yerleştirelim.
      // AppBar yerine özel bir widget kullanalım.

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
                      const LatLng(41.0082, 28.9784), // İstanbul
                  initialZoom: _currentLocation != null ? 13 : 8,
                  maxZoom: 18,
                  minZoom: 3,
                  keepAlive: true,
                  // Tıklanan yere marker ekleme veya konum seçme özelliği eklenebilir.
                  // onTap: (tapPosition, latlng) { ... }
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.rotaapp', // Kendi paket adınız
                    maxZoom: 19,
                  ),
                  // Mevcut konum marker'ı (Eğer başlangıç olarak seçilmediyse)
                  if (_currentLocation != null &&
                      routeProvider.startLocation != _currentLocation)
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
                          borderColor: const Color.fromARGB(
                            128,
                            0,
                            0,
                            0,
                          ), // Black with 50% opacity
                        ),
                      ],
                    ),
                ],
              ),

          // Arama ve Rota Bul Kartı (Harita üzerinde)
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
                        suffixIcon:
                            _currentLocation != null
                                ? IconButton(
                                  icon: const Icon(Icons.my_location),
                                  tooltip: 'Mevcut Konumu Başlangıç Yap',
                                  onPressed: () {
                                    _startController.text = 'Mevcut Konum';
                                    Provider.of<RouteProvider>(
                                      context,
                                      listen: false,
                                    ).setStartLocation(_currentLocation!);
                                    if (mounted) {
                                      setState(() {
                                        _startSearchResults = [];
                                      });
                                    }
                                    _startFocusNode.unfocus();
                                  },
                                )
                                : null,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (_startSearchResults.isNotEmpty &&
                            _startFocusNode.hasFocus) {
                          _selectLocation(_startSearchResults.first, true);
                        } else {
                          _onRouteSearchRequested();
                        }
                      },
                    ),
                    // Başlangıç Arama Sonuçları Listesi
                    if (_startFocusNode.hasFocus &&
                        _startSearchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(
                                25,
                                0,
                                0,
                                0,
                              ), // Black with 10% opacity
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
                              suffixIconConstraints: BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                            ),
                            onSubmitted: (_) {
                              if (_endSearchResults.isNotEmpty &&
                                  _endFocusNode.hasFocus) {
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
                          onPressed:
                              _isCalculatingRoute
                                  ? null
                                  : _onRouteSearchRequested,
                          icon:
                              _isCalculatingRoute
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.search),
                          label: Text(
                            _isCalculatingRoute
                                ? 'Hesaplanıyor...'
                                : 'Rota Bul',
                          ),
                        ),
                      ],
                    ),
                    // Varış Arama Sonuçları Listesi
                    if (_endFocusNode.hasFocus && _endSearchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(
                                25,
                                0,
                                0,
                                0,
                              ), // Black with 10% opacity
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

          // Rota Seçenekleri Kartı (Harita üzerinde)
          // Figma'daki Rota Maliyeti ekranı, hesaplanmış rotanın detayını gösteren bu kart olabilir.
          if (_showRouteOptions && routeProvider.routeOptions.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                // Kartın dışına Container ekleyip yeşil arka plan ve rounded corner verebiliriz
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF0D8), // Figma'daki yeşil tonu
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    // Hafif bir gölge eklenebilir
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Üstteki tutma çubuğu
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      height: 5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // Rota Maliyeti Başlığı (Figma'ya göre)
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
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Rotayı Temizle',
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  _showRouteOptions = false;
                                });
                              }
                              routeProvider.clearRoute();
                              _startController.clear();
                              _endController.clear();
                              _mapController.move(
                                _currentLocation ??
                                    const LatLng(41.0082, 28.9784),
                                _currentLocation != null ? 13 : 8,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Colors.grey),

                    // Seçilen Rota Özeti (Figma'daki kart yapısı)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildRouteSummaryCard(
                        context,
                        routeProvider.selectedRouteOption,
                      ), // Seçili rotayı gönder
                    ),

                    // Alternatif Rota Seçenekleri Listesi (Kaydırılabilir)
                    // Bu kısım Figma'da yok ama önceki mantıktan kaldı.
                    // Figma'daki Rota Maliyeti ekranı sadece tek bir rotayı gösteriyor gibi.
                    // Alternatif rotalar alt alta listelenebilir veya bu kart sadece seçili rotayı gösterir.
                    // Eğer alternatifler gösterilmeyecekse aşağıdaki SizedBox kaldırılabilir.
                    // Alternatifleri ayrı bir sayfada veya modalda göstermek de bir seçenek.
                    // SizedBox(
                    //    height: 120, // Yatay liste için sabit yükseklik
                    //    child: ListView.separated( ... ), // Önceki koddan kopyalanabilir
                    // ),
                  ],
                ),
              ),
            ),

          // Araç Bilgilerim / Araç Ekle Kartı (Harita üzerinde)
          // Figma'daki diğer kartlar Bottom Sheet veya modal olarak gösterilebilir.
          // Şimdilik yer tutucuları ekleyelim. Bunlar Positioned yerine DraggableScrollableSheet
          // veya showModalBottomSheet ile daha iyi yönetilebilir.
          // if (_showVehicleInfo) Positioned(...)
          // if (_showAddVehicle) Positioned(...)
        ],
      ),
      // Figma'ya göre Bottom Navigation Bar buraya gelecek
    );
  }

  // Rota Özet Kartı Widget'ı (Figma'daki yapıya benzer)
  Widget _buildRouteSummaryCard(BuildContext context, RouteOption? route) {
    if (route == null) return const SizedBox(); // Rota yoksa boş döner

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Harita önizlemesi (Seçili rotanın bir önizlemesi)
            Container(
              height: 100,
              color: Colors.grey[300],
              alignment: Alignment.center,
              child: Text(
                "Seçili Rota Önizlemesi",
              ), // Seçili rotanın önizlemesi gösterilebilir
              margin: EdgeInsets.only(bottom: 8),
            ),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _startController.removeListener(
      () => _searchLocations(_startController.text, true),
    );
    _endController.removeListener(
      () => _searchLocations(_endController.text, false),
    );
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
