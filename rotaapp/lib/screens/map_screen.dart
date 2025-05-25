// lib/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' as l; // Alias for Distance
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // TimeoutException için
import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter/foundation.dart'; // Kaldırıldı, material.dart içinde var

import '../models/location_result.dart';
import '../models/route_option.dart';
import '../models/fuel_cost_calculator.dart';
// import '../models/vehicle.dart'; // Kaldırıldı, VehicleProvider üzerinden erişiliyor
import '../models/route_step.dart';
import '../data/predefined_tolls.dart';
import '../providers/route_provider.dart';
import '../providers/vehicle_provider.dart';

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

class _MapScreenState extends State<MapScreen> {
  bool _isCalculatingRoute = false;
  bool _isSearchingLocation = false;
  SheetType _currentSheet = SheetType.none;
  List<LocationResult> _searchResults = [];
  bool _isStartSearchActive = true;
  bool _showRouteStepsDetails = false;

  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();

  static const String turkeyViewBox = '25.5,35.5,45.0,42.0';
  final double _sampleFuelPricePerLiter = 42.0;
  final l.Distance _distanceCalculator = const l.Distance();
  static const double _gateMatchThresholdMeters = 50000;

  @override
  void initState() {
    super.initState();
    _startFocusNode.addListener(_onFocusChange);
    _endFocusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Güvenlik için eklendi
      final routeProvider = Provider.of<RouteProvider>(context, listen: false);
      if (routeProvider.startLocation != null &&
          _startController.text.isEmpty) {
        _startController.text = 'Mevcut Konum';
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            try {
              _mapController.move(routeProvider.startLocation!, 13);
            } catch (e) {
              debugPrint("Error moving map in initState: $e");
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _startFocusNode.removeListener(_onFocusChange);
    _endFocusNode.removeListener(_onFocusChange);
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _startController.dispose();
    _endController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_startFocusNode.hasFocus && !_endFocusNode.hasFocus) {
      if (_currentSheet == SheetType.searchResults && mounted) {
        setState(() {
          _currentSheet = SheetType.none;
          _searchResults = [];
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isStartSearchActive = _startFocusNode.hasFocus;
          if (_currentSheet == SheetType.searchResults) {
            _searchResults = [];
          }
        });
      }
    }
  }

  void _showErrorSnackBar(String message, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning ? Colors.orangeAccent : Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final bool isStart = _isStartSearchActive;

    if (isStart && query.trim().toLowerCase() == 'mevcut konum') {
      final currentLocation = routeProvider.startLocation;
      if (currentLocation != null) {
        _startController.text = 'Mevcut Konum';
        _startFocusNode.unfocus();
        if (mounted) {
          setState(() {
            _searchResults = [];
            _currentSheet = SheetType.none;
          });
          try {
            _mapController.move(currentLocation, 13);
          } catch (e) {
            debugPrint("Error moving map in _performSearch (current location): $e");
          }
        }
      } else {
        if (mounted) _showErrorSnackBar('Mevcut konum bilgisi alınamadı.', isWarning: true);
      }
      return;
    }

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

    if (routeProvider.routeOptionsList.isNotEmpty) {
      routeProvider.clearRouteResults();
      if (mounted && _currentSheet == SheetType.routeOptions) {
        setState(() {
          _currentSheet = SheetType.none;
          _showRouteStepsDetails = false;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isSearchingLocation = true;
        _searchResults = [];
        _currentSheet = SheetType.searchResults;
      });
    }

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=10&viewbox=$turkeyViewBox&bounded=1&accept-language=tr');
      final response = await http.get(url, headers: {
        'User-Agent': 'RotaApp/1.0 (your.email@example.com)'
      }).timeout(const Duration(seconds: 10));

      if (!mounted) return; // Async sonrası kontrol

      List<LocationResult> results = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        results = data
            .map((item) {
              final double? lat = double.tryParse(item['lat']?.toString() ?? '');
              final double? lon = double.tryParse(item['lon']?.toString() ?? '');
              final String name = item['display_name']?.toString() ?? '';
              if (lat != null && lon != null && name.isNotEmpty) {
                return LocationResult(
                    displayName: name,
                    coordinates: LatLng(lat, lon),
                    type: item['type']?.toString() ?? 'Bilinmiyor');
              }
              return null;
            })
            .whereType<LocationResult>()
            .toList();
      } else {
        _showErrorSnackBar('Arama sunucusu hatası: ${response.statusCode}', isWarning: true);
      }

      setState(() {
        _searchResults = results;
        _isSearchingLocation = false;
        _currentSheet = results.isNotEmpty ? SheetType.searchResults : SheetType.none;
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
      _showErrorSnackBar('Arama sırasında bir hata oluştu: ${e.toString()}');
    }
  }

  void _selectLocation(LocationResult location) {
    final controller = _isStartSearchActive ? _startController : _endController;
    if (!mounted) return;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    controller.text = location.displayName;
    if (_isStartSearchActive) {
      routeProvider.setStartLocation(location.coordinates);
      _startFocusNode.unfocus();
    } else {
      routeProvider.setEndLocation(location.coordinates);
      _endFocusNode.unfocus();
    }

    if (mounted) {
      setState(() {
        _searchResults = [];
        _currentSheet = SheetType.none;
      });
      // location.coordinates null olamayacağı için ! gereksiz
      try {
        _mapController.move(location.coordinates, 13);
      } catch (e) {
        debugPrint("Error moving map in _selectLocation: $e");
      }
    }
  }

  void _swapStartEndLocations() {
    if (!mounted) return;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    final tempStartLoc = routeProvider.startLocation;
    final tempEndLoc = routeProvider.endLocation;
    final tempStartText = _startController.text;
    final tempEndText = _endController.text;

    _startController.text = tempEndText;
    _endController.text = tempStartText;
    routeProvider.setStartLocation(tempEndLoc);
    routeProvider.setEndLocation(tempStartLoc);

    if (mounted) {
      setState(() {
        _searchResults = [];
        _currentSheet = SheetType.none;
        _showRouteStepsDetails = false;
        if (routeProvider.selectedRouteOption != null) {
          routeProvider.clearRouteResults(); // Veya clearAllRouteData()
        }
      });
    }
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();
  }

  void _onRouteSearchRequested() async {
    if (!mounted) return;
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    _startFocusNode.unfocus();
    _endFocusNode.unfocus();

    if (start == null || end == null) {
      _showErrorSnackBar('Lütfen başlangıç ve varış noktalarını seçin.', isWarning: true);
      return;
    }
    if (start == end) {
      _showErrorSnackBar('Başlangıç ve varış noktaları aynı olamaz.', isWarning: true);
      return;
    }

    if (mounted) {
      setState(() {
        _isCalculatingRoute = true;
        _currentSheet = SheetType.none;
        routeProvider.clearRouteResults();
        _showRouteStepsDetails = false;
        _searchResults = [];
      });
    }

    try {
      final routeOptions = await _fetchRouteOptions(start, end);
      if (!mounted) return;

      routeProvider.setRouteOptions(routeOptions);

      setState(() {
        _isCalculatingRoute = false;
        if (routeOptions.isNotEmpty) {
          _currentSheet = SheetType.routeOptions;
          if (routeProvider.selectedRouteOption != null) {
            _fitMapToRoute(routeProvider.selectedRouteOption!.points);
          }
        } else {
          _currentSheet = SheetType.none;
        }
      });
    } on http.ClientException catch (e) {
      if (!mounted) return;
      debugPrint("OSRM ClientException in _onRouteSearchRequested: ${e.message}");
      setState(() { _isCalculatingRoute = false; _currentSheet = SheetType.none; });
      _showErrorSnackBar('Rota sunucusuna ulaşılamadı. İnternet bağlantınızı kontrol edin.');
    } catch (e) {
      if (!mounted) return;
      debugPrint("Rota hesaplama sırasında genel hata: ${e.toString()}");
      setState(() { _isCalculatingRoute = false; _currentSheet = SheetType.none; });
      _showErrorSnackBar('Rota hesaplanırken bir sorun oluştu.');
    }
  }

  Future<List<RouteOption>> _fetchRouteOptions(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true&steps=true&annotations=true');

    http.Response response;
    try {
      response = await http.get(url).timeout(const Duration(seconds: 20));
    } on TimeoutException catch (_) {
      throw http.ClientException("Rota sunucusu zaman aşımına uğradı.", url);
    } catch (e) {
      throw http.ClientException("Rota sunucusuna bağlanılamadı: ${e.toString()}", url);
    }

    if (!mounted) return []; // Async sonrası kontrol

    if (response.statusCode != 200) {
      String errorMessage = 'Rota sunucusu hatası (${response.statusCode}).';
      try {
        final errorData = json.decode(response.body);
        if (errorData['message'] != null) {
          errorMessage += ' ${errorData['message']}';
        }
        if (response.statusCode == 400 && (errorData['code'] == 'TooBig' || errorData['code'] == 'NoRoute')) {
          errorMessage = 'Seçilen noktalar arasında rota bulunamadı veya rota çok uzun.';
        }
      } catch (e) { /* JSON parse error */ }
      _showErrorSnackBar(errorMessage, isWarning: true);
      return [];
    }

    final data = json.decode(response.body);
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      _showErrorSnackBar('Belirtilen noktalar arasında rota bulunamadı.', isWarning: true);
      return [];
    }
    if (!mounted) return []; // Async sonrası kontrol
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final selectedVehicle = vehicleProvider.selectedVehicle;
    const double cityPercentageForFuel = 50.0;
    
    FuelCostCalculator? calculator;
    if (selectedVehicle != null) {
        calculator = FuelCostCalculator(
            vehicle: selectedVehicle,
            fuelPricePerLiter: _sampleFuelPricePerLiter,
            cityPercentage: cityPercentageForFuel);
    }

    List<RouteOption> routeOptions = [];
    int routeDisplayIndex = 1;

    for (var routeData in data['routes']) {
      final String routeName = data['routes'].length > 1 && routeData == data['routes'][0]
          ? 'En Hızlı Rota'
          : (data['routes'].length > 1 ? 'Alternatif Rota $routeDisplayIndex' : 'Rota');

      final List<LatLng> points = (routeData['geometry']['coordinates'] as List<dynamic>? ?? [])
          .map((coord) {
            if (coord is List && coord.length >= 2) {
              final double? lon = (coord[0] as num?)?.toDouble();
              final double? lat = (coord[1] as num?)?.toDouble();
              if (lat != null && lon != null) return LatLng(lat, lon);
            }
            return null;
          })
          .whereType<LatLng>()
          .toList();

      if (points.isEmpty) continue;

      final double distanceMeters = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
      final double durationSeconds = (routeData['duration'] as num?)?.toDouble() ?? 0.0;
      final double distanceKm = distanceMeters / 1000;
      final int durationMinutes = (durationSeconds / 60).round();

      List<RouteStep> routeSteps = [];
      if (routeData['legs'] != null &&
          (routeData['legs'] as List).isNotEmpty &&
          routeData['legs'][0]['steps'] != null) {
        routeSteps = (routeData['legs'][0]['steps'] as List<dynamic>)
            .map((stepData) => RouteStep.fromJson(stepData))
            .toList();
      }

      final tollResult = _calculateDetailedToll(routeSteps);
      final double calculatedTollCost = tollResult['totalCost'] as double;
      final bool hasTollSection = tollResult['hasTollRoadSectionVisible'] as bool;
      final List<String> tollSegmentsDescriptions = (tollResult['segments'] as List).cast<String>();

      Map<String, dynamic> costDetails = {};
      Map<String, double>? costRange;

      if (calculator != null) {
        costDetails = calculator.calculateRouteDetails(distanceKm, additionalTollCost: calculatedTollCost);
        costRange = {'minCost': costDetails['minCost'], 'maxCost': costDetails['maxCost']};
      } else {
        costDetails['additionalTollCost'] = calculatedTollCost;
        costDetails['calculatedFuelCost'] = 0.0;
        costDetails['totalFuelConsumption'] = 0.0;
        costRange = {'minCost': calculatedTollCost, 'maxCost': calculatedTollCost};
      }
      
      costDetails['identifiedTollSegments'] = tollSegmentsDescriptions;
      costDetails['tollCostUnknown'] = tollResult['tollCostUnknown'] as bool;
      costDetails['hasTollRoadSectionVisible'] = hasTollSection;

      routeOptions.add(RouteOption(
        name: routeName,
        distance: '${distanceKm.toStringAsFixed(1)} km',
        duration: '$durationMinutes dk',
        isTollRoad: hasTollSection,
        points: points,
        costRange: costRange,
        routeDetails: costDetails,
        steps: routeSteps,
      ));
      if (data['routes'].length > 1) routeDisplayIndex++;
    }
    return routeOptions;
  }

  TollGate? _findClosestGate(LatLng coordinate, List<TollGate> gates, double thresholdMeters) {
    if (gates.isEmpty) return null;
    TollGate? closestGate;
    double minDistance = double.infinity;

    for (final gate in gates) {
      final distance = _distanceCalculator(coordinate, gate.coordinates);
      if (distance < minDistance) {
        minDistance = distance;
        closestGate = gate;
      }
    }
    return (closestGate != null && minDistance <= thresholdMeters) ? closestGate : null;
  }

  Map<String, dynamic> _calculateDetailedToll(List<RouteStep> steps) {
    double totalTollCost = 0.0;
    List<String> identifiedTollSegments = [];
    bool tollCostUnknownForAnySegment = false;
    bool hasVisibleTollRoad = false;
    bool isOnOtoyolSegment = false;
    int otoyolEntryStepIndex = -1;

    for (int i = 0; i < steps.length; i++) {
      final currentStep = steps[i];
      final prevStepName = i > 0 ? steps[i - 1].name.toLowerCase() : '';
      final currentStepName = currentStep.name.toLowerCase();
      final bool isCurrentOtoyol = currentStepName.contains('otoyol') || currentStepName.contains("ücretli");
      // final bool wasPreviousOtoyol = prevStepName.contains('otoyol') || prevStepName.contains("ücretli"); // KALDIRILDI (unused)

      if (isCurrentOtoyol && !isOnOtoyolSegment) {
        isOnOtoyolSegment = true;
        otoyolEntryStepIndex = i;
      } else if ((!isCurrentOtoyol || i == steps.length - 1) && isOnOtoyolSegment) {
        final actualEntryIndex = (otoyolEntryStepIndex > 0 && !steps[otoyolEntryStepIndex -1].name.toLowerCase().contains('otoyol'))
            ? otoyolEntryStepIndex -1
            : otoyolEntryStepIndex;
        
        // final actualExitIndex = !isCurrentOtoyol ? i : steps.length -1; // KALDIRILDI (unused)

        final entryRefStep = steps[actualEntryIndex];
        final exitRefStep = !isCurrentOtoyol && i > 0 ? steps[i-1] : steps.last;

        final closestEntryGate = _findClosestGate(entryRefStep.location, allTollGates, _gateMatchThresholdMeters);
        final closestExitGate = _findClosestGate(exitRefStep.location, allTollGates, _gateMatchThresholdMeters);
        
        hasVisibleTollRoad = true;

        if (closestEntryGate != null && closestExitGate != null) {
          if (closestEntryGate.name == closestExitGate.name) {
            // Aynı gişe
          } else {
            final entryName = closestEntryGate.name;
            final exitName = closestExitGate.name;
            double? segmentCost;
            if (tollCostsMatrix.containsKey(entryName) && tollCostsMatrix[entryName]!.containsKey(exitName)) {
              segmentCost = tollCostsMatrix[entryName]![exitName]!;
            } else if (tollCostsMatrix.containsKey(exitName) && tollCostsMatrix[exitName]!.containsKey(entryName)) {
              segmentCost = tollCostsMatrix[exitName]![entryName]!;
            }

            if (segmentCost != null) {
              totalTollCost += segmentCost;
              identifiedTollSegments.add("$entryName → $exitName (${segmentCost.toStringAsFixed(2)} ₺)");
            } else {
              identifiedTollSegments.add("$entryName → $exitName (Maliyet Bilinmiyor)");
              tollCostUnknownForAnySegment = true;
            }
          }
        } else {
          String segmentDesc = "Ücretli Yol Bölümü";
          if (closestEntryGate != null) { // DÜZELTİLDİ (curly braces)
            segmentDesc += " (Giriş: ${closestEntryGate.name}?)";
          } else if (closestExitGate != null) { // DÜZELTİLDİ (curly braces)
            segmentDesc += " (Çıkış: ${closestExitGate.name}?)";
          } else { // DÜZELTİLDİ (curly braces)
            segmentDesc += " (Gişeler Belirlenemedi)";
          }
          identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
          tollCostUnknownForAnySegment = true;
        }
        isOnOtoyolSegment = false;
        otoyolEntryStepIndex = -1;
      }
    }
     if (isOnOtoyolSegment && otoyolEntryStepIndex != -1) {
        final actualEntryIndex = (otoyolEntryStepIndex > 0 && !steps[otoyolEntryStepIndex -1].name.toLowerCase().contains('otoyol'))
            ? otoyolEntryStepIndex -1
            : otoyolEntryStepIndex;
        final entryRefStep = steps[actualEntryIndex];
        final exitRefStep = steps.last;

        final closestEntryGate = _findClosestGate(entryRefStep.location, allTollGates, _gateMatchThresholdMeters);
        final closestExitGate = _findClosestGate(exitRefStep.location, allTollGates, _gateMatchThresholdMeters);
        
        hasVisibleTollRoad = true;

        if (closestEntryGate != null && closestExitGate != null) {
          if (closestEntryGate.name != closestExitGate.name) {
            final entryName = closestEntryGate.name;
            final exitName = closestExitGate.name;
            double? segmentCost;
            if (tollCostsMatrix.containsKey(entryName) && tollCostsMatrix[entryName]!.containsKey(exitName)) {
              segmentCost = tollCostsMatrix[entryName]![exitName]!;
            } else if (tollCostsMatrix.containsKey(exitName) && tollCostsMatrix[exitName]!.containsKey(entryName)) {
              segmentCost = tollCostsMatrix[exitName]![entryName]!;
            }
            if (segmentCost != null) {
              totalTollCost += segmentCost;
              identifiedTollSegments.add("$entryName → $exitName (Rota Sonu) (${segmentCost.toStringAsFixed(2)} ₺)");
            } else {
              identifiedTollSegments.add("$entryName → $exitName (Rota Sonu) (Maliyet Bilinmiyor)");
              tollCostUnknownForAnySegment = true;
            }
          }
        } else {
            identifiedTollSegments.add("Ücretli Yol Bölümü (Rota Sonu) (Maliyet Bilinmiyor)");
            tollCostUnknownForAnySegment = true;
        }
    }

    return {
      'totalCost': totalTollCost,
      'segments': identifiedTollSegments.toSet().toList(),
      'tollCostUnknown': tollCostUnknownForAnySegment,
      'hasTollRoadSectionVisible': hasVisibleTollRoad,
    };
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isNotEmpty && mounted) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(80.0),
        ));
      } catch (e) {
         debugPrint("Error fitting map to route: $e");
      }
    }
  }

  void _unfocusAndHideSearchSheet() {
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();
    if (_currentSheet == SheetType.searchResults && mounted) {
      setState(() {
        _currentSheet = SheetType.none;
        _searchResults = [];
      });
    }
  }

  Widget _buildLocationResultListItem(BuildContext context, LocationResult result) {
    IconData leadingIcon = _isStartSearchActive ? Icons.location_on : Icons.flag;
    Color iconColor = _isStartSearchActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;

    return ListTile(
      leading: Icon(leadingIcon, color: iconColor),
      title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(result.type, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: () => _selectLocation(result),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }

  Widget _buildRouteOptionListItem({
    required BuildContext context,
    required RouteOption route,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final routeDetails = route.routeDetails ?? {};
    final bool hasToll = routeDetails['hasTollRoadSectionVisible'] ?? false;
    final bool costUnknown = routeDetails['tollCostUnknown'] ?? false;
    final double tollCost = routeDetails['additionalTollCost'] ?? 0.0;
    
    String tooltipMessage = 'Ücretli Yol İçermiyor';
    IconData tollIconData = Icons.money_off;
    Color tollIconColor = Colors.grey;

    if (hasToll) {
        if (costUnknown) {
            tooltipMessage = 'Ücretli Yol (Maliyet Bilgisi Yok)';
            tollIconData = Icons.toll;
            tollIconColor = Colors.orange;
        } else if (tollCost > 0) {
            tooltipMessage = 'Ücretli Yol (Tahmini Gişe: ${tollCost.toStringAsFixed(2)} ₺)';
            tollIconData = Icons.toll;
            tollIconColor = Colors.redAccent;
        } else {
            tooltipMessage = 'Ücretli Yol (Gişe Tespit Edildi/Ücretsiz?)';
            tollIconData = Icons.toll;
            tollIconColor = Colors.green;
        }
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.titleLarge?.color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasToll)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Tooltip(
                        message: tooltipMessage,
                        child: Icon(tollIconData, size: 20, color: tollIconColor),
                      ),
                    ),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check_circle, size: 20, color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRouteInfoItem(Icons.schedule, 'Süre', route.duration, isSelected, context),
                  _buildRouteInfoItem(Icons.directions_car, 'Mesafe', route.distance, isSelected, context),
                  _buildRouteInfoItem(
                      Icons.local_gas_station,
                      'Maliyet',
                      route.costRange != null && route.costRange!['minCost'] != null && route.costRange!['maxCost'] != null
                          ? '${route.costRange!['minCost']!.toStringAsFixed(0)} - ${route.costRange!['maxCost']!.toStringAsFixed(0)} ₺'
                          : '-',
                      isSelected,
                      context,
                      highlight: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfoItem(IconData icon, String label, String value,
      bool isSelected, BuildContext context, {bool highlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlight ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.titleMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getManeuverIcon(String type, String? modifier) {
    if (type == 'depart') return Icons.departure_board;
    if (type == 'arrive') return Icons.flag_circle;
    if (modifier?.contains('left') ?? false) return Icons.turn_left;
    if (modifier?.contains('right') ?? false) return Icons.turn_right;
    if (modifier == 'straight') return Icons.straight;
    if (modifier == 'uturn') return Icons.u_turn_right;
    return Icons.arrow_forward;
  }

  Widget _buildRouteDetailedCard(BuildContext context, RouteOption route) {
    final startText = _startController.text.isNotEmpty ? _startController.text : "Başlangıç";
    final endText = _endController.text.isNotEmpty ? _endController.text : "Varış";
    if (!mounted) return const SizedBox.shrink(); // Async sonrası kontrol
    final vehicle = Provider.of<VehicleProvider>(context, listen: false).selectedVehicle;
    final details = route.routeDetails ?? {};

    final double? fuelLiters = details['totalFuelConsumption'] as double?;
    final double? fuelCost = details['calculatedFuelCost'] as double?;
    final double tollCostVal = details['additionalTollCost'] as double? ?? 0.0;
    final bool costUnknown = details['tollCostUnknown'] as bool? ?? false;
    final bool hasTollSection = details['hasTollRoadSectionVisible'] as bool? ?? false;
    final List<String> segments = (details['identifiedTollSegments'] as List<dynamic>? ?? []).cast<String>();
    final Map<String, double>? totalCostRange = route.costRange;

    String tollStatusText;
    Color tollColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600]!;

    if (hasTollSection) {
      if (costUnknown) {
        tollStatusText = 'Tahmini Gişe: Bilgi Yok';
        tollColor = Theme.of(context).colorScheme.error;
      } else if (tollCostVal > 0) {
        tollStatusText = 'Tahmini Gişe: ${tollCostVal.toStringAsFixed(2)} ₺';
        tollColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
      } else {
        tollStatusText = 'Tahmini Gişe: 0.00 ₺ / Ücretsiz?';
        tollColor = Colors.green.shade700;
      }
    } else {
      tollStatusText = 'Ücretli Yol Bulunmuyor';
      tollColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[700]!;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$startText → $endText', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Divider(height: 20),

            _buildDetailRow(Icons.schedule, 'Süre', route.duration),
            _buildDetailRow(Icons.directions_car, 'Mesafe', route.distance),
            _buildDetailRow(
                Icons.speed,
                'Araç',
                vehicle != null
                    ? '${vehicle.marka} ${vehicle.model}'
                    : 'Seçilmedi'),
            const SizedBox(height: 8),

            if (vehicle != null) ...[
              _buildDetailRow(Icons.local_gas_station, 'Yakıt Tüketimi',
                  fuelLiters != null ? '${fuelLiters.toStringAsFixed(1)} lt' : '-'),
              _buildDetailRow(Icons.monetization_on_outlined, 'Yakıt Maliyeti',
                  fuelCost != null ? '${fuelCost.toStringAsFixed(2)} ₺' : '-',
                  color: Theme.of(context).colorScheme.primary),
              _buildDetailRow(Icons.toll, 'Gişe Durumu', tollStatusText, color: tollColor),
              if (hasTollSection && segments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments.map((s) => Text("• $s",
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                        maxLines: 2, overflow: TextOverflow.ellipsis)).toList(),
                  ),
                ),
              const Divider(height: 20),
              _buildDetailRow(
                  Icons.account_balance_wallet,
                  'Toplam Maliyet',
                  totalCostRange != null && totalCostRange['minCost'] != null && totalCostRange['maxCost'] != null
                      ? '${totalCostRange['minCost']!.toStringAsFixed(2)} - ${totalCostRange['maxCost']!.toStringAsFixed(2)} ₺'
                      : (tollCostVal > 0 ? '${tollCostVal.toStringAsFixed(2)} ₺ (Sadece Gişe)' : 'Hesaplanamadı'),
                  color: Theme.of(context).colorScheme.primary,
                  isBold: true),
            ] else ...[
               Card(
                color: Theme.of(context).colorScheme.secondaryContainer.withAlpha((0.5 * 255).round()), // DÜZELTİLDİ (withOpacity)
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSecondaryContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yakıt ve toplam maliyet tahmini için araç seçimi yapın.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.toll, 'Gişe Durumu', tollStatusText, color: tollColor),
               if (hasTollSection && segments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments.map((s) => Text("• $s",
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                        maxLines: 2, overflow: TextOverflow.ellipsis)).toList(),
                  ),
                ),
            ],

            if(route.steps.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text('Yol Tarifi Adımları', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleMedium?.color)),
                    TextButton(
                    onPressed: () => setState(() => _showRouteStepsDetails = !_showRouteStepsDetails),
                    child: Text(_showRouteStepsDetails ? 'Gizle' : 'Göster (${route.steps.length})'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    ),
                ],
                ),
                if (_showRouteStepsDetails)
                AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    constraints: BoxConstraints(maxHeight: _showRouteStepsDetails ? 200 : 0),
                    child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: route.steps.length,
                    itemBuilder: (context, index) {
                        final step = route.steps[index];
                        final icon = _getManeuverIcon(step.maneuverType, step.maneuverModifier);
                        String instruction = step.instruction ?? step.name;
                         if (step.instruction != null && step.name.isNotEmpty && step.instruction != step.name && !step.instruction!.contains(step.name)) {
                            instruction = '${step.instruction} (${step.name})';
                        }

                        return ListTile(
                        leading: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color),
                        title: Text(instruction, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        );
                    },
                    ),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigasyonu Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _launchNavigation(route),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color, bool isBold = false}) {
    Color iconActualColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    // Satır 983'teki olası withOpacity kullanımı için (eğer Theme'dan gelen renk null değilse)
    // if (Theme.of(context).textTheme.bodyMedium?.color != null) {
    //   iconActualColor = Theme.of(context).textTheme.bodyMedium!.color.withAlpha((0.7 * 255).round());
    // }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconActualColor),
          const SizedBox(width: 12),
          Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _launchNavigation(RouteOption route) async {
    if (route.points.isEmpty) {
      if (mounted) _showErrorSnackBar('Navigasyon başlatılamadı: Rota bilgisi eksik.', isWarning: true);
      return;
    }
    final start = route.points.first;
    final end = route.points.last;
    final origin = '${start.latitude},${start.longitude}';
    final destination = '${end.latitude},${end.longitude}';
    
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Harita uygulaması açılamadı.';
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Harita başlatılamadı: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = Provider.of<RouteProvider>(context);
    final LatLng? userCurrentLocation = routeProvider.startLocation;
    final initialMapCenter = userCurrentLocation ?? const LatLng(39.9334, 32.8597);
    final initialMapZoom = userCurrentLocation != null ? 13.0 : 6.0;

    List<Widget> sheetChildren = [];
    String sheetTitle = '';
    bool showLoaderInSheet = false;
    Widget? headerWidgetForSheet;

    if (_currentSheet != SheetType.none) {
      if (_currentSheet == SheetType.searchResults) {
        sheetTitle = 'Arama Sonuçları (${_isStartSearchActive ? "Başlangıç" : "Varış"})';
        showLoaderInSheet = _isSearchingLocation;
      } else if (_currentSheet == SheetType.routeOptions) {
        sheetTitle = 'Rota Seçenekleri';
        showLoaderInSheet = _isCalculatingRoute;
      }

      headerWidgetForSheet = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                IconButton(
                  icon: const Icon(Icons.close), tooltip: 'Kapat', iconSize: 24, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        if (_currentSheet == SheetType.routeOptions) {
                           // routeProvider.clearSelectedRouteOption(); // Bu metodun olmadığını varsayıyoruz, ya ekleyin ya da alternatif kullanın
                           routeProvider.clearRouteResults(); // Örnek alternatif
                           _showRouteStepsDetails = false;
                        } else if (_currentSheet == SheetType.searchResults) {
                            _searchResults = [];
                        }
                        _isCalculatingRoute = false;
                        _isSearchingLocation = false;
                        _currentSheet = SheetType.none;
                      });
                    }
                    _startFocusNode.unfocus();
                    _endFocusNode.unfocus();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
        ],
      );
    }

    if (_currentSheet == SheetType.searchResults) {
      if (!showLoaderInSheet) {
        if (_searchResults.isNotEmpty) {
          sheetChildren.addAll(_searchResults.map((r) => _buildLocationResultListItem(context, r)));
        } else {
          if ((_isStartSearchActive ? _startController.text.isNotEmpty : _endController.text.isNotEmpty) && !_isSearchingLocation) {
            sheetChildren.add(const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text('Sonuç bulunamadı.'))));
          }
        }
      }
    } else if (_currentSheet == SheetType.routeOptions) {
      if (!showLoaderInSheet && routeProvider.routeOptionsList.isNotEmpty) {
        sheetChildren.addAll(routeProvider.routeOptionsList.map((route) => _buildRouteOptionListItem(
            context: context,
            route: route,
            isSelected: routeProvider.selectedRouteOption == route,
            onTap: () {
              if (routeProvider.selectedRouteOption != route) {
                routeProvider.selectRouteOption(route);
                _fitMapToRoute(route.points);
                if (_showRouteStepsDetails) setState(() => _showRouteStepsDetails = false);
              }
            }))
        .toList());

        if (routeProvider.selectedRouteOption != null) {
          sheetChildren.add(_buildRouteDetailedCard(context, routeProvider.selectedRouteOption!));
        }
      } else if (!showLoaderInSheet && routeProvider.routeOptionsList.isEmpty && !_isCalculatingRoute) {
        sheetChildren.add(const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text('Rota bulunamadı veya hesaplanamadı.'))));
      }
    }
    
    if (showLoaderInSheet) {
        sheetChildren.add(const Padding( padding: EdgeInsets.symmetric(vertical: 30.0), child: Center(child: CircularProgressIndicator())));
    }

    sheetChildren.add(SizedBox(height: MediaQuery.of(context).padding.bottom + 20));

    const double minSheetSize = 0.1;
    const double midSheetSize = 0.45;
    const double maxSheetSize = 0.9;
    final List<double> snapSizes = [minSheetSize, midSheetSize, maxSheetSize];
    double initialSheetSize = minSheetSize;

    if (_currentSheet == SheetType.searchResults && _searchResults.isNotEmpty) initialSheetSize = midSheetSize;
    if (_currentSheet == SheetType.routeOptions && routeProvider.routeOptionsList.isNotEmpty) initialSheetSize = midSheetSize;
    if (showLoaderInSheet) initialSheetSize = 0.25;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialMapCenter,
              initialZoom: initialMapZoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) => _unfocusAndHideSearchSheet(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.rotaapp',
              ),
              if (routeProvider.selectedRouteOption != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeProvider.selectedRouteOption!.points,
                      strokeWidth: 5,
                      color: Theme.of(context).colorScheme.primary.withAlpha((0.8 * 255).round()), // DÜZELTİLDİ (withOpacity)
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (routeProvider.startLocation != null && _startController.text.isNotEmpty)
                    Marker(
                      point: routeProvider.startLocation!,
                      width: 40, height: 40, alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, size: 40, color: Theme.of(context).colorScheme.primary),
                    ),
                  if (routeProvider.endLocation != null && _endController.text.isNotEmpty)
                    Marker(
                      point: routeProvider.endLocation!,
                      width: 40, height: 40, alignment: Alignment.topCenter,
                      child: Icon(Icons.flag, size: 40, color: Theme.of(context).colorScheme.error),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Card( // DÜZELTİLDİ (child sona alındı)
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                              isDense: true,
                              border: InputBorder.none,
                              suffixIconConstraints: const BoxConstraints(maxHeight: 24),
                              suffixIcon: _startController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _startController.clear();
                                        routeProvider.setStartLocation(null);
                                        if (mounted) setState(() => _searchResults = []);
                                      },
                                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                    )
                                  : (userCurrentLocation != null && routeProvider.startLocation != userCurrentLocation)
                                      ? IconButton(
                                          icon: const Icon(Icons.my_location, size: 18),
                                          tooltip: 'Mevcut Konum',
                                          onPressed: () {
                                            if (mounted) setState(() => _isStartSearchActive = true);
                                            _performSearch('Mevcut Konum');
                                          },
                                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                        )
                                      : null,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (query) { if (query.isNotEmpty) _performSearch(query); },
                            onChanged: (query) {
                              if (query.isEmpty && _isStartSearchActive) {
                                if (mounted) setState(() => _searchResults = []);
                                routeProvider.setStartLocation(null);
                              } else if (query.isNotEmpty && _isStartSearchActive) {
                                _performSearch(query);
                              }
                            },
                            onTap: () { if (mounted) setState(() => _isStartSearchActive = true);},
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Row(
                        children: [
                          Container(height: 25, width: 1, color: Colors.grey[300]),
                          IconButton(
                            icon: const Icon(Icons.swap_vert, size: 22),
                            tooltip: 'Değiştir',
                            onPressed: _swapStartEndLocations,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(child: Divider(height: 1, color: Colors.grey[300])),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.error, size: 20),
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
                              suffixIcon: _endController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _endController.clear();
                                        routeProvider.setEndLocation(null);
                                        if (mounted) setState(() => _searchResults = []);
                                      },
                                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                    )
                                  : null,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (query) { if (query.isNotEmpty) _performSearch(query); },
                             onChanged: (query) {
                              if (query.isEmpty && !_isStartSearchActive) {
                                if (mounted) setState(() => _searchResults = []);
                                routeProvider.setEndLocation(null);
                              } else if (query.isNotEmpty && !_isStartSearchActive) {
                                _performSearch(query);
                              }
                            },
                            onTap: () { if (mounted) setState(() => _isStartSearchActive = false);},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isCalculatingRoute
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.directions, size: 20),
                        label: Text(_isCalculatingRoute ? 'Hesaplanıyor...' : 'Rota Bul'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                        ),
                        onPressed: (_isCalculatingRoute || routeProvider.startLocation == null || routeProvider.endLocation == null)
                            ? null
                            : _onRouteSearchRequested,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_currentSheet != SheetType.none || _isCalculatingRoute || _isSearchingLocation)
            LayoutBuilder(builder: (context, constraints) {
              return DraggableScrollableSheet(
                initialChildSize: initialSheetSize,
                minChildSize: minSheetSize,
                maxChildSize: maxSheetSize,
                expand: false,
                snap: true,
                snapSizes: snapSizes,
                builder: (BuildContext context, ScrollController scrollController) {
                  return Card(
                    elevation: 8.0,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            if (headerWidgetForSheet != null) headerWidgetForSheet,
                            ...sheetChildren,
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