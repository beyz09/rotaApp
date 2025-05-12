import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

// Kendi modellerimizi import ediyoruz
import '../models/location_result.dart';
import '../models/route_option.dart';
import '../models/fuel_cost_calculator.dart';
import '../providers/route_provider.dart';
import '../providers/vehicle_provider.dart';

// Enum Tanımı
enum SheetType {
  none,
  searchResults,
  routeOptions,
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool _isCalculatingRoute = false;
  final MapController _mapController = MapController();

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  SheetType _currentSheet = SheetType.none;

  List<LocationResult> _startSearchResults = [];
  List<LocationResult> _endSearchResults = [];

  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();

  static const String turkeyViewBox = '25.5,35.5,45.0,42.0';
  double _sampleFuelPricePerLiter = 42.0;
  static const double _fixedTollCostPlaceholder = 75.0;

  @override
  void initState() {
    super.initState();

    _startFocusNode.addListener(_handleFocusChange);
    _endFocusNode.addListener(_handleFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
       final routeProvider = Provider.of<RouteProvider>(context, listen: false);
       if (routeProvider.startLocation != null && _startController.text.isEmpty) {
         _startController.text = 'Mevcut Konum';
         if (mounted) {
            _mapController.move(routeProvider.startLocation!, 13);
         }
       }
    });
  }

  Future<List<LocationResult>> _fetchLocationSearchResults(String query) async {
    if (query.isEmpty) {
      return [];
    }
     try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=10&viewbox=$turkeyViewBox&accept-language=tr');
      final response = await http.get(url, headers: {'User-Agent': 'FuelEstimateApp/1.0'});
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results
            .map((result) {
              final double? lat = double.tryParse(result['lat']?.toString() ?? '');
              final double? lon = double.tryParse(result['lon']?.toString() ?? '');
              final String displayName = result['display_name']?.toString() ?? '';
              if (lat == null || lon == null || displayName.isEmpty) {
                 return null;
              }
              return LocationResult(displayName: displayName, coordinates: LatLng(lat, lon), type: result['type']?.toString() ?? '');
            })
            .where((loc) => loc != null)
            .cast<LocationResult>()
            .toList();
      } else {
        debugPrint('Arama API hatası: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Arama sırasında network veya parse hatası: $e');
      return [];
    }
  }

  void _selectLocation(LocationResult location, bool isStart) {
    final controller = isStart ? _startController : _endController;
    controller.text = location.displayName;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    if (isStart) {
      routeProvider.setStartLocation(location.coordinates);
      _startFocusNode.unfocus();
      if (mounted) {
         setState(() { _startSearchResults = []; });
      }
    } else {
      routeProvider.setEndLocation(location.coordinates);
      _endFocusNode.unfocus();
      if (mounted) {
         setState(() { _endSearchResults = []; });
      }
    }

     if (mounted) {
        setState(() { _currentSheet = SheetType.none; });
     }
  }

  void _handleFocusChange() {
     if (!mounted) {
        return;
     }

     if (!_startFocusNode.hasFocus && !_endFocusNode.hasFocus) {
       if (_currentSheet == SheetType.searchResults) {
          setState(() {
            _startSearchResults = [];
            _endSearchResults = [];
            _currentSheet = SheetType.none;
          });
       } else {
           setState(() {
            _startSearchResults = [];
            _endSearchResults = [];
          });
       }
     }
  }

  Future<void> _performSearch(String query, bool isStart) async {
     if (isStart && query == 'Mevcut Konum') {
        if (isStart) { _startFocusNode.unfocus(); } else { _endFocusNode.unfocus(); }
        if (_currentSheet == SheetType.searchResults) {
             if (mounted) {
                setState(() { _currentSheet = SheetType.none; });
             }
        }
        return;
     }

     if (query.isEmpty) {
        setState(() {
          if (isStart) { _startSearchResults = []; } else { _endSearchResults = []; }
           if (_currentSheet == SheetType.searchResults) {
             _currentSheet = SheetType.none;
           }
        });
        return;
     }

     if (mounted) {
        setState(() { _isCalculatingRoute = true; });
     }

     try {
        final results = await _fetchLocationSearchResults(query);

        if (!mounted) {
           return;
        }

        setState(() {
          if (isStart) {
            _startSearchResults = results;
            _endSearchResults = [];
          } else {
            _endSearchResults = results;
            _startSearchResults = [];
          }
          if (results.isNotEmpty) {
             _currentSheet = SheetType.searchResults;
          } else {
             _currentSheet = SheetType.none;
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Arama sonucu bulunamadı.'),
                  backgroundColor: Colors.orange,
               ),
             );
          }
          _isCalculatingRoute = false;
        });

        if (isStart) { _startFocusNode.unfocus(); } else { _endFocusNode.unfocus(); }

     } catch (e) {
        debugPrint('Arama sırasında hata: $e');
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Arama yapılırken bir hata oluştu: ${e.toString()}'),
               backgroundColor: Colors.red,
              ),
           );
           setState(() {
             _isCalculatingRoute = false;
             _startSearchResults = [];
             _endSearchResults = [];
             _currentSheet = SheetType.none;
           });
         }
     }
  }

   Future<List<RouteOption>> _fetchRouteOptions(LatLng start, LatLng end) async {
      try {
       final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true&steps=false');
       debugPrint('OSRM API Çağrısı: $url');
       final response = await http.get(url);
       debugPrint('OSRM API Yanıt Kodu: ${response.statusCode}');

       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         debugPrint('API\'den gelen rota sayısı: ${data['routes']?.length ?? 0}');

         if (data['routes'] != null && data['routes'].isNotEmpty) {
           final List<RouteOption> routeOptions = [];
           final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
           final selectedVehicle = vehicleProvider.selectedVehicle;

           const double cityPercentage = 50.0;

           final calculator = selectedVehicle != null
               ? FuelCostCalculator(vehicle: selectedVehicle, fuelPricePerLiter: _sampleFuelPricePerLiter, cityPercentage: cityPercentage)
               : null;

           for (var i = 0; i < data['routes'].length; i++) {
             final route = data['routes'][i];
             final List<dynamic> coordinates = route['geometry']['coordinates'];
             final List<LatLng> points = coordinates.map((coord) { if (coord is List && coord.length >= 2) { final double? lon = (coord[0] as num?)?.toDouble(); final double? lat = (coord[1] as num?)?.toDouble(); if (lat != null && lon != null) { return LatLng(lat, lon); } } return null; }).where((point) => point != null).cast<LatLng>().toList();

             if (points.isEmpty) {
                 continue;
             }

             final double distanceInMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
             final double durationInSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;
             final double distanceInKm = distanceInMeters / 1000;
             final int durationInMinutes = (durationInSeconds / 60).round();

            final bool isTollRoute = i == 0;
            final double additionalCostForRoute = isTollRoute ? _fixedTollCostPlaceholder : 0.0;

            Map<String, double>? costRange;
            Map<String, dynamic>? routeDetails;

            if (calculator != null) {
                routeDetails = calculator.calculateRouteDetails(distanceInKm, additionalTollCost: additionalCostForRoute);
                costRange = calculator.calculateRouteCost(distanceInKm, additionalTollCost: additionalCostForRoute);
            } else {
               routeDetails = null;
               costRange = null;
            }

            routeOptions.add(
              RouteOption(
                 name: i == 0 ? 'En Hızlı Rota' : 'Alternatif Rota ${i + 1}',
                distance: '${distanceInKm.toStringAsFixed(1)} km',
                duration: '$durationInMinutes dk',
                isTollRoad: isTollRoute,
                points: points,
                costRange: costRange,
                routeDetails: routeDetails,
              ),
            );
          }
          return routeOptions;
        } else {
          debugPrint('API\'den routes listesi boş geldi.');
          return [];
        }
       } else {
         debugPrint('Rota hesaplama API hatası: ${response.statusCode} - ${response.body}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rota hesaplama servisi hatası: ${response.statusCode}'), backgroundColor: Colors.red,));
          }
         return [];
       }
     } catch (e) {
       debugPrint('Rota API çağrısı sırasında hata: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rota hesaplanırken bir hata oluştu: ${e.toString()}'), backgroundColor: Colors.red,));
        }
       return [];
     }
   }

  void _onRouteSearchRequested() async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    _startSearchResults = [];
    _endSearchResults = [];
     if (_currentSheet == SheetType.searchResults) {
        if (mounted) {
            setState(() { _currentSheet = SheetType.none; });
        }
     }

    if (start != null && end != null) {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = true;
          _currentSheet = SheetType.none;
          routeProvider.clearRouteResults();
        });
      }

      final routeOptions = await _fetchRouteOptions(start, end);

      if (!mounted) {
        return;
      }

      if (routeOptions.isNotEmpty) {
        routeProvider.setRouteOptions(routeOptions);

        if (routeProvider.selectedRouteOption != null && routeProvider.selectedRouteOption!.points.isNotEmpty) {
           _fitMapToRoute(routeProvider.selectedRouteOption!.points);
        }

        setState(() { _currentSheet = SheetType.routeOptions; });

      } else {
        routeProvider.clearRouteResults();
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belirtilen noktalar arasında rota bulunamadı.'), backgroundColor: Colors.orange,),
         );
         setState(() { _currentSheet = SheetType.routeOptions; });
      }

      setState(() { _isCalculatingRoute = false; });

      _startFocusNode.unfocus();
      _endFocusNode.unfocus();
    } else {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen başlangıç ve varış noktalarını seçin.'), backgroundColor: Colors.orange,),
        );
       }
    }
  }

   void _fitMapToRoute(List<LatLng> points) {
    if (points.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(50)));
      } catch (e) {
        debugPrint('Haritayı rotaya odaklama hatası: $e');
      }
    }
  }

  // Arama Sonucu Liste Öğesi Widget'ı
  Widget _buildLocationResultListItem(BuildContext context, LocationResult result, bool isStartSearch) {
     return ListTile(
        title: Text(result.displayName),
        subtitle: Text(result.type),
        leading: Icon(isStartSearch ? Icons.location_on : Icons.flag, color: isStartSearch ? Theme.of(context).colorScheme.primary : Colors.redAccent),
        onTap: () {
           _selectLocation(result, isStartSearch);
        },
     );
  }

  // Rota Seçeneği Liste Öğesi Widget'ı (Dikey Liste İçin)
  Widget _buildRouteOptionListItem(BuildContext context, RouteOption route, bool isSelected) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2) : BorderSide.none,
      ),
      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Provider.of<RouteProvider>(context, listen: false).selectRouteOption(route);
          _fitMapToRoute(route.points);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (route.isTollRoad)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.toll, size: 20, color: isSelected ? Colors.amberAccent : Colors.orange),
                    ),
                   if (isSelected)
                     Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.check_circle, size: 20, color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary),
                     ),
                ],
              ),
              const SizedBox(height: 8),
              // DÜZELTME: Bu Row içindeki Expanded/Column yapısı yeniden düzenlendi
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('Süre', style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text(route.duration, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                         ],
                       ),
                    ),
                    Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('Mesafe', style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text(route.distance, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                         ],
                       ),
                    ),
                    Expanded(
                       child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          const Text('Maliyet (Tahmini)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            route.costRange != null
                                ? '${route.costRange!['minCost']!.toStringAsFixed(1)} - ${route.costRange!['maxCost']!.toStringAsFixed(1)} ₺'
                                : '-',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : (route.costRange != null ? Theme.of(context).colorScheme.primary : Colors.grey),
                            ),
                          ),
                       ],
                    ),
                    ),
                 ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rota Detay Kartı Widget'ı (DraggableSheet içinde gösterilecek)
  Widget _buildRouteDetailedCard(BuildContext context, RouteOption route, String startText, String endText) {
     final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
     final selectedVehicle = vehicleProvider.selectedVehicle;
     final routeDetails = route.routeDetails;
     final double? totalFuelConsumption = routeDetails?['totalFuelConsumption'];
     final double? additionalTollCost = routeDetails?['additionalTollCost'];

     if (routeDetails == null) {
         // Araç bilgisi eksikse veya maliyet hesaplanamamışsa gösterilecek kart
         return Card(
            elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: Colors.white,
            child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Text('$startText - $endText', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis,), const SizedBox(height: 8),
                 // DÜZELTME: Bu Row içindeki Expanded/Column yapısı yeniden düzenlendi
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('Mesafe', style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text(route.distance, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                         ],
                       ),
                     ),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('Süre', style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text(route.duration, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                         ],
                       ),
                     ),
                     Expanded(child: Container()), // Boşluk bırak
                   ],
                 ),
                 const SizedBox(height: 16),
                 // Uyarı Kartı
                 Card( color: Colors.red[50], child: Padding( padding: const EdgeInsets.all(8.0), child: Row( children: [ const Icon(Icons.warning_amber, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text('Yakıt maliyeti tahmini için araç bilgileri eksik. Lütfen Ayarlar sayfasından bir araç seçin.', style: TextStyle(color: Colors.red[700]),),), ], ), ), ),
                 const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { final start = route.points.first; final end = route.points.last; final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&travelmode=driving'); launchUrl(url, mode: LaunchMode.externalApplication).catchError((e){ if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Harita uygulaması başlatılamadı: $e'), backgroundColor: Colors.red,),); } return false; }); }, icon: const Icon(Icons.directions_car), label: const Text('Yolculuğa Başla'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),),),), ], ), ), );
     } else {
        // Araç bilgisi ve routeDetails varsa detaylı kart
        return Card(
          elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Text('$startText - $endText', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis,), const SizedBox(height: 8),
             // DÜZELTME: Bu Row içindeki Expanded/Column yapısı yeniden düzenlendi
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mesafe', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(route.distance, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                 ),
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Süre', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(route.duration, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                 ),
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Yakıt', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(totalFuelConsumption != null ? '${totalFuelConsumption.toStringAsFixed(1)} lt' : '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                 ),
               ],
             ),
             const SizedBox(height: 8),
             // DÜZELTME: Bu Row içindeki Expanded/Column yapısı yeniden düzenlendi
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Maliyet (Tahmini)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(route.costRange != null ? '${route.costRange!['minCost']!.toStringAsFixed(2)} - ${route.costRange!['maxCost']!.toStringAsFixed(2)} ₺' : '-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: route.costRange != null ? Theme.of(context).colorScheme.primary : Colors.grey,),),
                      ],
                    ),
                 ),
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ek Maliyet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(additionalTollCost != null && additionalTollCost > 0 ? '${additionalTollCost.toStringAsFixed(2)} ₺' : 'Yok', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: additionalTollCost != null && additionalTollCost > 0 ? Colors.deepOrange : Colors.black87,),),
                      ],
                    ),
                 ),
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Araç', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(selectedVehicle != null ? '${selectedVehicle.brand} ${selectedVehicle.model}' : 'Yok', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis,),
                      ],
                    ),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { final start = route.points.first; final end = route.points.last; final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&travelmode=driving'); launchUrl(url, mode: LaunchMode.externalApplication).catchError((e){ if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Harita uygulaması başlatılamadı: $e'), backgroundColor: Colors.red,),); } return false; }); }, icon: const Icon(Icons.directions_car), label: const Text('Yolculuğa Başla'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),),),),
            ],
           ),
         ),
        );
     }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final routeProvider = Provider.of<RouteProvider>(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final selectedVehicle = vehicleProvider.selectedVehicle;

    final LatLng? currentLocation = routeProvider.startLocation;
    final List<RouteOption> routeOptions = routeProvider.routeOptionsList;

    final initialMapCenter = currentLocation ?? const LatLng(41.0082, 28.9784);
    final initialMapZoom = currentLocation != null ? 13.0 : 8.0;

    // Sheet içeriğini oluşturma mantığı
    List<Widget> sheetContentChildren = [];

    // Her zaman sabit başlık kısmını ekle
     sheetContentChildren.add(Column( mainAxisSize: MainAxisSize.min, children: [ Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 5, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),),
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 _currentSheet == SheetType.searchResults ? 'Arama Sonuçları' : 'Rota Maliyeti',
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
               ),
               IconButton(
                 icon: const Icon(Icons.close),
                 tooltip: 'Kapat',
                 onPressed: () {
                   if (_currentSheet == SheetType.routeOptions) {
                     Provider.of<RouteProvider>(context, listen: false).clearAllRouteData();
                     _startController.clear();
                     _endController.clear();
                     _mapController.move(const LatLng(41.0082, 28.9784), 8);
                   } else if (_currentSheet == SheetType.searchResults) {
                     _startSearchResults = [];
                     _endSearchResults = [];
                   }
                   if (mounted) {
                     setState(() { _currentSheet = SheetType.none; });
                   }
                 },
               ),
             ],
           ),
         ),
         const Divider(height: 1, thickness: 1, color: Colors.grey),
       ],
     ));


    // Dinamik içeriği (Arama Sonuçları veya Rota Seçenekleri) koşula göre ekle
    if (_currentSheet == SheetType.searchResults) {
      // Hangi listeden geldiğini belirleme (_performSearch sadece birini doldurur)
      final bool isStartSearchActiveField = _startFocusNode.hasFocus; // Veya _startSearchResults dolu mu kontrolü
      final List<LocationResult> displayedSearchResults = _startSearchResults.isNotEmpty ? _startSearchResults : _endSearchResults;


      if (displayedSearchResults.isNotEmpty) {
        sheetContentChildren.addAll(
          displayedSearchResults.map(
            // isStartSearch bilgisi, sonuç hangi listeden geliyorsa o listeden mi geldiği kontrolü
            (result) => _buildLocationResultListItem(context, result, _startSearchResults.contains(result)),
          ).toList(),
        );
      } else {
         sheetContentChildren.add(
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Arama sonucu bulunamadı.', style: TextStyle(fontSize: 16, color: Colors.black54))),
            )
         );
      }
    } else if (_currentSheet == SheetType.routeOptions) {
        if (routeOptions.isNotEmpty) {
          sheetContentChildren.add(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Alternatif Rotalar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: routeOptions.map(
                    (route) => _buildRouteOptionListItem(
                      context,
                      route,
                      routeProvider.selectedRouteOption == route,
                    ),
                  ).toList(),
                ),
                const Divider(height: 1, thickness: 1, color: Colors.grey),
                // Seçili rota detay kartını göster (eğer bir rota seçiliyse)
                if (routeProvider.selectedRouteOption != null)
                  _buildRouteDetailedCard(
                    context,
                    routeProvider.selectedRouteOption!,
                    _startController.text.isEmpty ? 'Başlangıç Noktası' : _startController.text,
                    _endController.text.isEmpty ? 'Varış Noktası' : _endController.text,
                  ),
              ],
            )
          );
        } else if (!_isCalculatingRoute) {
           sheetContentChildren.add(
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Rota bulunamadı.', style: TextStyle(fontSize: 16, color: Colors.black54))),
              )
           );
        }
    }

    // BottomNavigationBar'ın kapladığı alan kadar boşluk ekle
    sheetContentChildren.add(SizedBox(height: MediaQuery.of(context).padding.bottom + 60));

    // initialChildSize ve snapSizes hesaplamaları için gerekli değişkenler burada tanımlandı
    final bool isStartSearchSheetActive = (_currentSheet == SheetType.searchResults);
    final int searchResultCount = isStartSearchSheetActive ? (_startSearchResults.isNotEmpty ? _startSearchResults.length : _endSearchResults.length) : 0;
    final int routeOptionCount = _currentSheet == SheetType.routeOptions ? routeOptions.length : 0;

    final double initialSheetSize = _currentSheet == SheetType.routeOptions
       ? (routeOptionCount > 1 ? 0.3 : (routeOptionCount == 1 ? 0.25 : 0.15))
       : (searchResultCount > 0 ? 0.4 : 0.15);

    final List<double> sheetSnapSizes = _currentSheet == SheetType.routeOptions
        ? (routeOptionCount > 1 ? [0.1, 0.3, 0.8] : (routeOptionCount == 1 ? [0.1, 0.25, 0.8] : [0.1, 0.15, 0.8]))
        : (searchResultCount > 0 ? [0.1, 0.4, 0.8] : [0.1, 0.15, 0.8]);


    return Scaffold(
      body: Stack(
        children: [
          // Harita
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: initialMapCenter, initialZoom: initialMapZoom, maxZoom: 18, minZoom: 3, keepAlive: true),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.rotaapp', maxZoom: 19,),
              // Mevcut konum marker'ı
              if (currentLocation != null) MarkerLayer(markers: [Marker(point: currentLocation, width: 40, height: 40, child: const Icon(Icons.my_location, color: Colors.cyan, size: 30),),],),
              // Başlangıç marker'ı
              if (routeProvider.startLocation != null) MarkerLayer(markers: [Marker(point: routeProvider.startLocation!, width: 50, height: 50, child: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 40),),],),
              // Varış marker'ı
              if (routeProvider.endLocation != null) MarkerLayer(markers: [Marker(point: routeProvider.endLocation!, width: 50, height: 50, child: const Icon(Icons.flag, color: Colors.redAccent, size: 40),),],),
              // Rota çizgisi
              if (routeProvider.routePoints != null && routeProvider.routePoints!.isNotEmpty) PolylineLayer(polylines: [Polyline(points: routeProvider.routePoints!, strokeWidth: 5, color: Theme.of(context).colorScheme.primary,),],),
            ],
          ),

          // Arama ve Rota Bul Kartı
          Positioned(
            top: 10, left: 10, right: 10,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Başlangıç Noktası Arama Alanı
                    TextField(
                      controller: _startController, focusNode: _startFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Başlangıç noktası', prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: currentLocation != null ? IconButton(icon: const Icon(Icons.my_location), tooltip: 'Mevcut Konumu Başlangıç Yap', onPressed: () { _startController.text = 'Mevcut Konum'; Provider.of<RouteProvider>(context, listen: false).setStartLocation(currentLocation); if (mounted) { setState(() { _startSearchResults = []; _endSearchResults = []; _currentSheet = SheetType.none; }); } _startFocusNode.unfocus(); },) : null,
                        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none,),
                        filled: true, fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
                      ),
                       onSubmitted: (query) { _performSearch(query, true); },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _endController, focusNode: _endFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Varış noktası', prefixIcon: const Icon(Icons.flag),
                              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0,),
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none,),
                               filled: true, fillColor: Colors.grey[200],
                               contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
                            ),
                            onSubmitted: (query) { _performSearch(query, false); },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(onPressed: _isCalculatingRoute ? null : _onRouteSearchRequested, icon: _isCalculatingRoute ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) : const Icon(Icons.search), label: Text(_isCalculatingRoute ? 'Hesaplanıyor...' : 'Rota Bul'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0),),),),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dinamik Olarak Açılan DraggableScrollableSheet (Arama Sonuçları veya Rota Seçenekleri)
          if (_currentSheet != SheetType.none)
            DraggableScrollableSheet(
              initialChildSize: initialSheetSize,
              minChildSize: 0.1,
              maxChildSize: 0.8,
              expand: false, snap: true,
              snapSizes: sheetSnapSizes,
              builder: (BuildContext context, ScrollController scrollController) {
                return Card(
                   elevation: 8.0,
                   shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                   margin: EdgeInsets.zero,
                   child: Container(
                     decoration: const BoxDecoration(
                       color: Color(0xFFDCF0D8),
                       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                     ),
                     child: ListView(
                       controller: scrollController,
                       padding: EdgeInsets.zero,
                       children: sheetContentChildren,
                     ),
                   ),
                 );
              },
            ),

           // Yükleniyor göstergesi (Rota veya Arama hesaplanırken)
           if (_isCalculatingRoute)
             const Positioned.fill(
               child: ColoredBox(
                color: Colors.black54,
                child: Center(
                 child: CircularProgressIndicator(
                     strokeWidth: 2,
                 ),
                ),
               ),
             ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _startFocusNode.removeListener(_handleFocusChange);
    _endFocusNode.removeListener(_handleFocusChange);

    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _mapController.dispose();

    super.dispose();
  }
}