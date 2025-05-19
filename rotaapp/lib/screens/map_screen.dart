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
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart'; // debugPrint için

import '../models/location_result.dart';
import '../models/route_option.dart';
import '../models/fuel_cost_calculator.dart';
import '../models/vehicle.dart';
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
      final routeProvider = Provider.of<RouteProvider>(context, listen: false);
      if (routeProvider.startLocation != null &&
          _startController.text.isEmpty) {
        _startController.text = 'Mevcut Konum';
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            try {
              _mapController.move(routeProvider.startLocation!, 13);
            } catch (e) {/* Silent error */}
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
    ScaffoldMessenger.of(context)
        .removeCurrentSnackBar(); // Önceki snackbar'ı kaldır
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning ? Colors.orangeAccent : Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final bool isStart = _isStartSearchActive;

    if (isStart && query.trim().toLowerCase() == 'mevcut konum') {
      final currentLocation = routeProvider.startLocation;
      if (currentLocation != null) {
        _startController.text = 'Mevcut Konum';
        routeProvider.setStartLocation(currentLocation);
        _startFocusNode.unfocus();
        if (mounted) {
          setState(() {
            _searchResults = [];
            _currentSheet = SheetType.none;
          });
          try {
            _mapController.move(currentLocation, 13);
          } catch (_) {}
        }
      } else {
        _showErrorSnackBar('Mevcut konum bilgisi alınamadı.', isWarning: true);
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
        'User-Agent': 'FuelEstimateApp/1.0'
      }).timeout(const Duration(seconds: 10));

      List<LocationResult> results = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        results = data
            .map((item) {
              final double? lat =
                  double.tryParse(item['lat']?.toString() ?? '');
              final double? lon =
                  double.tryParse(item['lon']?.toString() ?? '');
              final String name = item['display_name']?.toString() ?? '';
              if (lat != null && lon != null && name.isNotEmpty) {
                return LocationResult(
                    displayName: name,
                    coordinates: LatLng(lat, lon),
                    type: item['type']?.toString() ?? '');
              }
              return null;
            })
            .whereType<LocationResult>()
            .toList();
      } else {
        _showErrorSnackBar('Arama sunucusu hatası: ${response.statusCode}',
            isWarning: true);
      }

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearchingLocation = false;
        _currentSheet =
            results.isNotEmpty ? SheetType.searchResults : SheetType.none;
        if (results.isEmpty && query.isNotEmpty) {
          _showErrorSnackBar('Arama sonucu bulunamadı.', isWarning: true);
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
      _showErrorSnackBar(
          'Arama sırasında bir hata oluştu.'); // ${e.toString()} kaldırıldı
    }
  }

  void _selectLocation(LocationResult location) {
    final controller = _isStartSearchActive ? _startController : _endController;
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
      });
    }
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();
  }

  void _onRouteSearchRequested() async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);
    final start = routeProvider.startLocation;
    final end = routeProvider.endLocation;

    _startFocusNode.unfocus();
    _endFocusNode.unfocus();

    if (start == null || end == null) {
      _showErrorSnackBar('Lütfen başlangıç ve varış noktalarını seçin.',
          isWarning: true);
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
      debugPrint(
          "OSRM ClientException in _onRouteSearchRequested: ${e.message}");
      if (!mounted) return;
      setState(() {
        _isCalculatingRoute = false;
        _currentSheet = SheetType.none;
      });
      _showErrorSnackBar(
          'Rota sunucusuna ulaşılamadı. İnternet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.');
    } catch (e) {
      debugPrint("Rota hesaplama sırasında genel hata: ${e.toString()}");
      if (!mounted) return;
      setState(() {
        _isCalculatingRoute = false;
        _currentSheet = SheetType.none;
      });
      _showErrorSnackBar('Rota hesaplanırken bir sorun oluştu.');
    }
  }

  Future<List<RouteOption>> _fetchRouteOptions(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true&steps=true&annotations=true');

    http.Response response;
    try {
      response = await http.get(url).timeout(
          const Duration(seconds: 30)); // Zaman aşımı biraz daha artırıldı
    } on TimeoutException catch (_) {
      debugPrint("OSRM Request Timed Out after 30 seconds for URL: $url");
      throw http.ClientException("Rota sunucusu zaman aşımına uğradı.", url);
    } catch (e) {
      debugPrint(
          "OSRM Request failed before getting response for URL: $url. Error: $e");
      throw http.ClientException("Rota sunucusuna bağlanılamadı.", url);
    }

    if (response.statusCode != 200) {
      debugPrint('OSRM API Error: ${response.statusCode} - ${response.body}');
      String errorMessage = 'Rota sunucusu hatası (${response.statusCode}).';
      if (response.statusCode == 400) {
        if (response.body.toLowerCase().contains("too big") ||
            response.body.toLowerCase().contains("retaillimit")) {
          // OSRM bazen retaillimit hatası verebilir
          errorMessage =
              'Seçilen rota çok uzun veya karmaşık. Daha kısa bir mesafe deneyin.';
        } else {
          errorMessage = 'Rota isteği geçersiz veya hatalı (400).';
        }
      } else if (response.statusCode == 429) {
        errorMessage =
            'Çok fazla istek gönderildi. Lütfen biraz bekleyip tekrar deneyin (429).';
      }
      _showErrorSnackBar(errorMessage);
      return [];
    }

    final data = json.decode(response.body);
    if (data['routes'] == null || data['routes'].isEmpty) {
      _showErrorSnackBar('Belirtilen noktalar arasında rota bulunamadı.',
          isWarning: true);
      return [];
    }

    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    final selectedVehicle = vehicleProvider.selectedVehicle;
    const double cityPercentageForFuel = 50.0;
    final calculator = selectedVehicle != null
        ? FuelCostCalculator(
            vehicle: selectedVehicle,
            fuelPricePerLiter: _sampleFuelPricePerLiter,
            cityPercentage: cityPercentageForFuel)
        : null;

    List<RouteOption> routeOptions = [];

    for (var routeIndex = 0; routeIndex < data['routes'].length; routeIndex++) {
      final routeData = data['routes'][routeIndex];
      final String routeName = routeIndex == 0
          ? 'En Hızlı Rota'
          : 'Alternatif Rota ${routeIndex + 1}';

      final List<LatLng> points =
          (routeData['geometry']['coordinates'] as List<dynamic>? ?? [])
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

      final double distanceMeters =
          (routeData['distance'] as num?)?.toDouble() ?? 0.0;
      final double durationSeconds =
          (routeData['duration'] as num?)?.toDouble() ?? 0.0;
      final double distanceKm = distanceMeters / 1000;
      final int durationMinutes = (durationSeconds / 60).round();

      List<RouteStep> routeSteps = [];
      if (routeData['legs'] != null &&
          routeData['legs'].isNotEmpty &&
          routeData['legs'][0]['steps'] != null) {
        routeSteps = (routeData['legs'][0]['steps'] as List<dynamic>)
            .map((stepData) => RouteStep.fromJson(stepData))
            .toList();
      }

      final tollResult = _calculateDetailedToll(routeSteps);
      final double calculatedTollCost = tollResult['totalCost'] as double;
      final bool hasTollSection =
          tollResult['hasTollRoadSectionVisible'] as bool;
      final List<String> tollSegmentsDescriptions =
          tollResult['segments'] as List<String>;

      Map<String, dynamic> costDetails = {};
      Map<String, double>? costRange;
      if (calculator != null) {
        costDetails = calculator.calculateRouteDetails(distanceKm,
            additionalTollCost: calculatedTollCost);
        costRange = calculator.calculateRouteCost(distanceKm,
            additionalTollCost: calculatedTollCost);
      } else {
        costDetails['additionalTollCost'] = calculatedTollCost;
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
        intermediatePlaces: const [], // Kaldırıldı
      ));
    }
    return routeOptions;
  }

  TollGate? _findClosestGate(
      LatLng coordinate, List<TollGate> gates, double thresholdMeters) {
    TollGate? closestGate;
    double minDistance = double.infinity;

    //  debugPrint('DEBUG: _findClosestGate: Searching near coord (${coordinate.latitude.toStringAsFixed(5)}, ${coordinate.longitude.toStringAsFixed(5)}) with threshold ${thresholdMeters}m.');

    if (gates.isEmpty) {
      return null;
    }

    for (final gate in gates) {
      final distance = _distanceCalculator(coordinate, gate.coordinates);
      if (distance < minDistance) {
        minDistance = distance;
        closestGate = gate;
      }
    }

    if (closestGate != null) {
      //  debugPrint('DEBUG: _findClosestGate: Closest gate found is "${closestGate.name}" at distance ${minDistance.toStringAsFixed(1)}m.');
      //  debugPrint('DEBUG: _findClosestGate:   (Search Coord: ${coordinate.latitude.toStringAsFixed(5)}, ${coordinate.longitude.toStringAsFixed(5)})');
      //  debugPrint('DEBUG: _findClosestGate:   (Closest Gate "${closestGate.name}" Coords: ${closestGate.coordinates.latitude.toStringAsFixed(5)}, ${closestGate.coordinates.longitude.toStringAsFixed(5)})');

      if (minDistance <= thresholdMeters) {
        //  debugPrint('DEBUG: _findClosestGate:   -> SUCCESS: Distance is within threshold. Gate Matched.');
        return closestGate;
      } else {
        //  debugPrint('DEBUG: _findClosestGate:   -> FAILURE: Distance (${minDistance.toStringAsFixed(1)}m) exceeds threshold (${thresholdMeters}m). No Match.');
        return null;
      }
    } else {
      return null;
    }
  }

  Map<String, dynamic> _calculateDetailedToll(List<RouteStep> steps) {
    double totalTollCost = 0.0;
    List<String> identifiedTollSegments = [];
    bool tollCostUnknown = false; // Genel bir bilinmeyenlik durumu için
    bool hasTollRoadSectionVisible = false;
    bool isOnOtoyolSegment = false;
    int potentialOtoyolEntryStepIndex = -1;

    // debugPrint('\n--- DEBUG: Starting _calculateDetailedToll ---');

    for (int i = 0; i < steps.length; i++) {
      final currentStep = steps[i];
      final previousStep = i > 0 ? steps[i - 1] : null;
      final currentRoadName = currentStep.name.toLowerCase();
      final previousRoadName = previousStep?.name.toLowerCase() ?? '';
      final bool isCurrentOtoyol = currentRoadName.contains('otoyol');
      final bool isPreviousOtoyol = previousRoadName.contains('otoyol');

      if (isCurrentOtoyol && !isOnOtoyolSegment) {
        if (!isPreviousOtoyol || i == 0) {
          isOnOtoyolSegment = true;
          potentialOtoyolEntryStepIndex = i;
        }
      } else if (!isCurrentOtoyol && isPreviousOtoyol && isOnOtoyolSegment) {
        if (potentialOtoyolEntryStepIndex < 0) {
          isOnOtoyolSegment = false;
          potentialOtoyolEntryStepIndex = -1;
          continue;
        }

        RouteStep actualEntryReferenceStep;
        int actualEntryReferenceStepIndex;
        if (potentialOtoyolEntryStepIndex > 0 &&
            !steps[potentialOtoyolEntryStepIndex - 1]
                .name
                .toLowerCase()
                .contains('otoyol')) {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex - 1];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex - 1;
        } else {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex;
        }
        final RouteStep actualExitReferenceStep = currentStep;
        final int actualExitReferenceStepIndex = i;

        final closestEntryGate = _findClosestGate(
            actualEntryReferenceStep.location,
            allTollGates,
            _gateMatchThresholdMeters);
        final closestExitGate = _findClosestGate(
            actualExitReferenceStep.location,
            allTollGates,
            _gateMatchThresholdMeters);

        String segmentDesc;
        double? segmentCost;
        bool currentSegmentCostUnknown = false;

        if (closestEntryGate != null && closestExitGate != null) {
          // ***** YENİ KONTROL: Aynı gişeden giriş çıkış yapılıyorsa atla *****
          if (closestEntryGate.name == closestExitGate.name) {
            debugPrint(
                'DEBUG:       -> SKIPPED: Entry and Exit gates are the same: "${closestEntryGate.name}".');
            // Bu segmenti hiç listeye ekleme ve maliyete katma
          } else {
            final entryName = closestEntryGate.name;
            final exitName = closestExitGate.name;
            segmentDesc = "$entryName -> $exitName";

            if (tollCostsMatrix.containsKey(entryName) &&
                tollCostsMatrix[entryName]!.containsKey(exitName)) {
              segmentCost = tollCostsMatrix[entryName]![exitName]!;
            } else if (tollCostsMatrix.containsKey(exitName) &&
                tollCostsMatrix[exitName]!.containsKey(entryName)) {
              segmentCost = tollCostsMatrix[exitName]![entryName]!;
            } else {
              currentSegmentCostUnknown =
                  true; // Bu spesifik segmentin maliyeti bilinmiyor
              tollCostUnknown = true; // Genel olarak bilinmeyen bir maliyet var
            }

            if (segmentCost != null) {
              totalTollCost += segmentCost;
              identifiedTollSegments
                  .add("$segmentDesc (${segmentCost.toStringAsFixed(2)} ₺)");
            } else {
              identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
            }
            hasTollRoadSectionVisible =
                true; // Bir segment bulundu (aynı olsalar bile)
          }
        } else {
          // Gişelerden biri veya ikisi bulunamadı
          segmentDesc =
              "Ücretli Yol Segmenti (Referans Adımlar: $actualEntryReferenceStepIndex-${actualExitReferenceStepIndex})";
          if (closestEntryGate != null)
            segmentDesc += " (Giriş: ${closestEntryGate.name}?)";
          else if (closestExitGate != null)
            segmentDesc += " (Çıkış: ${closestExitGate.name}?)";
          else
            segmentDesc += " (Gişeler Belirlenemedi)";

          identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
          hasTollRoadSectionVisible = true;
          tollCostUnknown = true;
        }
        isOnOtoyolSegment = false;
        potentialOtoyolEntryStepIndex = -1;
      }
    }

    if (isOnOtoyolSegment && potentialOtoyolEntryStepIndex != -1) {
      if (potentialOtoyolEntryStepIndex < 0) {/*...*/} else {
        RouteStep actualEntryReferenceStep;
        int actualEntryReferenceStepIndex;
        if (potentialOtoyolEntryStepIndex > 0 &&
            !steps[potentialOtoyolEntryStepIndex - 1]
                .name
                .toLowerCase()
                .contains('otoyol')) {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex - 1];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex - 1;
        } else {
          actualEntryReferenceStep = steps[potentialOtoyolEntryStepIndex];
          actualEntryReferenceStepIndex = potentialOtoyolEntryStepIndex;
        }
        final RouteStep actualExitReferenceStep = steps.last;
        final int actualExitReferenceStepIndex = steps.length - 1;

        final closestEntryGate = _findClosestGate(
            actualEntryReferenceStep.location,
            allTollGates,
            _gateMatchThresholdMeters);
        final closestExitGate = _findClosestGate(
            actualExitReferenceStep.location,
            allTollGates,
            _gateMatchThresholdMeters);

        String segmentDesc;
        double? segmentCost;
        bool currentSegmentCostUnknown = false;

        if (closestEntryGate != null && closestExitGate != null) {
          // ***** YENİ KONTROL: Aynı gişeden giriş çıkış yapılıyorsa atla *****
          if (closestEntryGate.name == closestExitGate.name) {
            debugPrint(
                'DEBUG:       -> SKIPPED (End of Route): Entry and Exit gates are the same: "${closestEntryGate.name}".');
          } else {
            final entryName = closestEntryGate.name;
            final exitName = closestExitGate.name;
            segmentDesc = "$entryName -> $exitName (Rota Sonu)";
            if (tollCostsMatrix.containsKey(entryName) &&
                tollCostsMatrix[entryName]!.containsKey(exitName)) {
              segmentCost = tollCostsMatrix[entryName]![exitName]!;
            } else if (tollCostsMatrix.containsKey(exitName) &&
                tollCostsMatrix[exitName]!.containsKey(entryName)) {
              segmentCost = tollCostsMatrix[exitName]![entryName]!;
            } else {
              currentSegmentCostUnknown = true;
              tollCostUnknown = true;
            }
            if (segmentCost != null) {
              totalTollCost += segmentCost;
              identifiedTollSegments
                  .add("$segmentDesc (${segmentCost.toStringAsFixed(2)} ₺)");
            } else {
              identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
            }
            hasTollRoadSectionVisible = true;
          }
        } else {
          segmentDesc =
              "Ücretli Yol Segmenti (Referans Adımlar: $actualEntryReferenceStepIndex-${actualExitReferenceStepIndex} - Rota Sonu)";
          // ...
          identifiedTollSegments.add("$segmentDesc (Maliyet Bilinmiyor)");
          hasTollRoadSectionVisible = true;
          tollCostUnknown = true;
        }
      }
    }
    return {
      'totalCost': totalTollCost,
      'segments': identifiedTollSegments
          .toSet()
          .toList(), // ***** TEKRARLARI KALDIR *****
      'tollCostUnknown': tollCostUnknown,
      'hasTollRoadSectionVisible': hasTollRoadSectionVisible,
    };
  }

  // _getSignificantPlaceName ve _getIntermediatePlaceNames fonksiyonları kaldırıldı.

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isNotEmpty && mounted) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(80),
        ));
      } catch (e) {/* Silent error */}
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

  Widget _buildLocationResultListItem(
      BuildContext context, LocationResult result) {
    IconData leadingIcon =
        _isStartSearchActive ? Icons.location_on : Icons.flag;
    Color iconColor = _isStartSearchActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return ListTile(
      leading: Icon(leadingIcon, color: iconColor),
      title: Text(result.displayName,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(result.type,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: () => _selectLocation(result),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
    String tooltip = 'Ücretli Yol İçerebilir';
    if (hasToll) {
      if (costUnknown)
        tooltip = 'Ücretli Yol (Maliyet Bilgisi Yok)';
      else if (tollCost > 0)
        tooltip =
            'Ücretli Yol (Tahmini Gişe: ${tollCost.toStringAsFixed(2)} ₺)';
      else
        tooltip = 'Ücretli Yol (Gişe Tespit Edildi/Ücretsiz?)';
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
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
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasToll)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Tooltip(
                        message: tooltip,
                        child: Icon(Icons.toll,
                            size: 20,
                            color: costUnknown
                                ? Colors.orange
                                : (tollCost > 0
                                    ? Colors.redAccent
                                    : Colors.grey)),
                      ),
                    ),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check_circle_outline,
                          size: 20, color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRouteInfoItem(Icons.schedule, 'Süre', route.duration,
                      isSelected, context),
                  _buildRouteInfoItem(Icons.directions_car, 'Mesafe',
                      route.distance, isSelected, context),
                  _buildRouteInfoItem(
                      Icons.local_gas_station,
                      'Maliyet',
                      route.costRange != null
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
      bool isSelected, BuildContext context,
      {bool highlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodyMedium?.color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getManeuverIcon(String type, String? modifier) {
    switch (type) {
      case 'turn':
        return Icons.turn_right;
      case 'new name':
        return Icons.merge_type;
      case 'depart':
        return Icons.outbound;
      case 'arrive':
        return Icons.flag;
      case 'fork':
        return Icons.call_split;
      case 'merge':
        return Icons.merge_type;
      case 'ramp':
        return Icons.ramp_right;
      case 'roundabout':
        return Icons.roundabout_right;
      case 'end of road':
        return Icons.block;
      case 'continue':
        return Icons.straight;
      default:
        if (modifier?.contains('left') ?? false) return Icons.turn_left;
        if (modifier?.contains('right') ?? false) return Icons.turn_right;
        if (modifier == 'straight') return Icons.straight;
        if (modifier == 'uturn') return Icons.u_turn_right;
        return Icons.arrow_forward;
    }
  }

  Widget _buildRouteDetailedCard(BuildContext context, RouteOption route) {
    final startText =
        _startController.text.isNotEmpty ? _startController.text : "Başlangıç";
    final endText =
        _endController.text.isNotEmpty ? _endController.text : "Varış";
    final vehicle =
        Provider.of<VehicleProvider>(context, listen: false).selectedVehicle;
    final details = route.routeDetails ?? {};

    final double? fuelLiters = details['totalFuelConsumption'] as double?;
    final double? fuelCost = details['calculatedFuelCost'] as double?;
    final double tollCostVal = details['additionalTollCost'] as double? ?? 0.0;
    final bool costUnknown = details['tollCostUnknown'] as bool? ?? false;
    final bool hasTollSection =
        details['hasTollRoadSectionVisible'] as bool? ?? false;
    final List<String> segments =
        (details['identifiedTollSegments'] as List<dynamic>? ?? [])
            .cast<String>();
    final Map<String, double>? totalCostRange = route.costRange;

    String tollStatusText;
    Color tollColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600]!;
    if (hasTollSection) {
      if (costUnknown) {
        tollStatusText = 'Tahmini Gişe: Bilgi Yok';
        tollColor =
            Theme.of(context).colorScheme.error; // Hata rengi veya uyarı rengi
      } else if (tollCostVal > 0) {
        tollStatusText = 'Tahmini Gişe: ${tollCostVal.toStringAsFixed(2)} ₺';
        tollColor = Theme.of(context).textTheme.bodyLarge?.color ??
            Colors.black87; // Koyu/Açık metin rengi
      } else {
        tollStatusText = 'Tahmini Gişe: 0.00 ₺ / Ücretsiz?';
        tollColor = Colors.grey.shade700;
      }
    } else {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$startText → $endText',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Divider(height: 20),

            _buildDetailRow(Icons.schedule, 'Süre', route.duration,
                color: Theme.of(context).textTheme.bodyLarge?.color),
            _buildDetailRow(Icons.directions_car, 'Mesafe', route.distance,
                color: Theme.of(context).textTheme.bodyLarge?.color),
            _buildDetailRow(
                Icons.speed,
                'Araç',
                vehicle != null
                    ? '${vehicle.brand} ${vehicle.model}'
                    : 'Seçilmedi',
                color: Theme.of(context).textTheme.bodyLarge?.color),
            const SizedBox(height: 8),

            if (vehicle != null) ...[
              _buildDetailRow(
                  Icons.local_gas_station,
                  'Yakıt Tüketimi',
                  fuelLiters != null
                      ? '${fuelLiters.toStringAsFixed(1)} lt'
                      : '-',
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              _buildDetailRow(Icons.monetization_on_outlined, 'Yakıt Maliyeti',
                  fuelCost != null ? '${fuelCost.toStringAsFixed(2)} ₺' : '-',
                  color: Theme.of(context).colorScheme.primary),
              _buildDetailRow(Icons.toll, 'Gişe Durumu', tollStatusText,
                  color: tollColor),
              if (hasTollSection && segments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments
                        .map((s) => Text(
                              "• $s",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ))
                        .toList(),
                  ),
                ),
              const Divider(
                  height: 20,
                  color: Color(0xFF3C4043)), // Divider rengi tema ile uyumlu
              _buildDetailRow(
                  Icons.account_balance_wallet,
                  'Toplam Maliyet',
                  totalCostRange != null
                      ? '${totalCostRange['minCost']!.toStringAsFixed(2)} - ${totalCostRange['maxCost']!.toStringAsFixed(2)} ₺'
                      : 'Hesaplanamadı',
                  color: Theme.of(context).colorScheme.primary,
                  isBold: true),
            ] else ...[
              Card(
                color: Colors.orange[50],
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yakıt/toplam maliyet için araç seçimi gerekli.',
                          style: TextStyle(
                              color: Colors.orange[800], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.toll, 'Gişe Durumu', tollStatusText,
                  color: tollColor),
              if (hasTollSection && segments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments
                        .map((s) => Text(
                              "• $s",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ))
                        .toList(),
                  ),
                ),
            ],

            const Divider(
                height: 24,
                color: Color(0xFF3C4043)), // Divider rengi tema ile uyumlu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Yol Tarifi Adımları',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                if (route.steps.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(
                        () => _showRouteStepsDetails = !_showRouteStepsDetails),
                    child: Text(_showRouteStepsDetails
                        ? 'Gizle'
                        : 'Göster (${route.steps.length})'),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .primary), // TextButton rengi tema ile uyumlu
                  ),
              ],
            ),

            if (_showRouteStepsDetails && route.steps.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: route.steps.length,
                  itemBuilder: (context, index) {
                    final step = route.steps[index];
                    final icon = _getManeuverIcon(
                        step.maneuverType, step.maneuverModifier);
                    String instruction = step.instruction ?? step.name;
                    if (step.instruction != null &&
                        step.instruction == step.name) {
                      instruction = step.instruction!;
                    } else if (step.instruction != null &&
                        step.name.isNotEmpty &&
                        !step.instruction!.contains(step.name)) {
                      instruction = '${step.instruction} (${step.name})';
                    }

                    return ListTile(
                      leading: Icon(icon,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.color), // İkon rengi tema ile uyumlu
                      title: Text(
                        instruction,
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigasyonu Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _launchNavigation(route),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color), // İkon rengi tema ile uyumlu
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ??
                    Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color, // Belirtilmediyse tema rengi
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _launchNavigation(RouteOption route) async {
    if (route.points.isEmpty) {
      _showErrorSnackBar('Navigasyon başlatılamadı: Rota bilgisi eksik.',
          isWarning: true);
      return;
    }
    final start = route.points.first;
    final end = route.points.last;
    final origin = '${start.latitude},${start.longitude}';
    final destination = '${end.latitude},${end.longitude}';
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Harita uygulaması açılamadı.';
      }
    } catch (e) {
      _showErrorSnackBar('Harita başlatılamadı.'); // ${e.toString()} kaldırıldı
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = Provider.of<RouteProvider>(context);
    final LatLng? currentLocation = routeProvider.startLocation;
    final initialCenter = currentLocation ?? const LatLng(39.9334, 32.8597);
    final initialZoom = currentLocation != null ? 13.0 : 7.0;

    List<Widget> sheetChildren = [];
    String sheetTitle = '';
    bool showLoaderInSheet = false;
    Widget? headerWidget;

    if (_currentSheet != SheetType.none) {
      if (_currentSheet == SheetType.searchResults) {
        sheetTitle =
            'Arama Sonuçları (${_isStartSearchActive ? "Başlangıç" : "Varış"})';
        showLoaderInSheet = _isSearchingLocation;
      } else if (_currentSheet == SheetType.routeOptions) {
        sheetTitle = 'Rota Seçenekleri';
        showLoaderInSheet = _isCalculatingRoute;
      }

      headerWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 5,
            width: 40,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 8.0, top: 0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(
                  sheetTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
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
                          routeProvider.clearAllRouteData();
                          _startController.clear();
                          _endController.clear();
                          _showRouteStepsDetails = false;
                        }
                        _searchResults = [];
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
          sheetChildren.addAll(_searchResults
              .map((r) => _buildLocationResultListItem(context, r)));
        } else {
          if (!_isSearchingLocation &&
              (_isStartSearchActive
                  ? _startController.text.isNotEmpty
                  : _endController.text.isNotEmpty)) {
            sheetChildren.add(const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text('Sonuç bulunamadı.'))));
          }
        }
      }
    } else if (_currentSheet == SheetType.routeOptions) {
      if (!showLoaderInSheet && routeProvider.routeOptionsList.isNotEmpty) {
        sheetChildren.addAll(routeProvider.routeOptionsList
            .map((route) => _buildRouteOptionListItem(
                context: context,
                route: route,
                isSelected: routeProvider.selectedRouteOption == route,
                onTap: () {
                  if (routeProvider.selectedRouteOption != route) {
                    routeProvider.selectRouteOption(route);
                    _fitMapToRoute(route.points);
                    if (_showRouteStepsDetails) {
                      setState(() => _showRouteStepsDetails = false);
                    }
                  }
                }))
            .toList());

        if (routeProvider.selectedRouteOption != null) {
          sheetChildren.add(_buildRouteDetailedCard(
              context, routeProvider.selectedRouteOption!));
        }
      } else if (!showLoaderInSheet && routeProvider.routeOptionsList.isEmpty) {
        sheetChildren.add(const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text('Rota bulunamadı.'))));
      }
    }

    if (showLoaderInSheet) {
      sheetChildren.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 30.0),
          child: Center(child: CircularProgressIndicator())));
    }

    sheetChildren
        .add(SizedBox(height: MediaQuery.of(context).padding.bottom + 20));

    const double minSheetSize = 0.15;
    const double midSheetSize = 0.45;
    const double maxSheetSize = 0.88;
    final List<double> snapSizes = [minSheetSize, midSheetSize, maxSheetSize];
    double initialSheetSize = midSheetSize;
    if (_currentSheet == SheetType.routeOptions)
      initialSheetSize = maxSheetSize;
    if (showLoaderInSheet) initialSheetSize = minSheetSize;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              minZoom: 5,
              maxZoom: 18,
              onTap: (_, __) => _unfocusAndHideSearchSheet(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.rotaapp', // Kendi paket adınızla değiştirin
              ),
              if (routeProvider.selectedRouteOption != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeProvider.selectedRouteOption!.points,
                      strokeWidth: 5,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.8),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (routeProvider.startLocation != null)
                    Marker(
                      point: routeProvider.startLocation!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  if (routeProvider.endLocation != null)
                    Marker(
                      point: routeProvider.endLocation!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child:
                          Icon(Icons.flag, size: 40, color: Colors.redAccent),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trip_origin,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            focusNode: _startFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Başlangıç',
                              isDense: true,
                              border: InputBorder.none,
                              suffixIconConstraints:
                                  const BoxConstraints(maxHeight: 24),
                              suffixIcon: _startController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _startController.clear();
                                        routeProvider.setStartLocation(null);
                                        if (mounted)
                                          setState(() => _searchResults = []);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  : (currentLocation != null &&
                                          routeProvider.startLocation !=
                                              currentLocation)
                                      ? IconButton(
                                          icon: const Icon(Icons.my_location,
                                              size: 18),
                                          tooltip: 'Mevcut Konum',
                                          onPressed: () {
                                            if (mounted)
                                              setState(() =>
                                                  _isStartSearchActive = true);
                                            _performSearch('Mevcut Konum');
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
                            onChanged: (query) {
                              if (query.isEmpty && _isStartSearchActive) {
                                if (mounted)
                                  setState(() => _searchResults = []);
                                routeProvider.setStartLocation(null);
                              }
                            },
                            onTap: () {
                              if (mounted)
                                setState(() => _isStartSearchActive = true);
                            },
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Row(
                        children: [
                          Container(
                              height: 25, width: 1, color: Colors.grey[300]),
                          IconButton(
                            icon: const Icon(Icons.swap_vert, size: 22),
                            tooltip: 'Değiştir',
                            onPressed: _swapStartEndLocations,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(
                              child:
                                  Divider(height: 1, color: Colors.grey[300])),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.flag_outlined,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            focusNode: _endFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Varış',
                              isDense: true,
                              border: InputBorder.none,
                              suffixIconConstraints:
                                  const BoxConstraints(maxHeight: 24),
                              suffixIcon: _endController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _endController.clear();
                                        routeProvider.setEndLocation(null);
                                        if (mounted)
                                          setState(() => _searchResults = []);
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
                            onChanged: (query) {
                              if (query.isEmpty && !_isStartSearchActive) {
                                if (mounted)
                                  setState(() => _searchResults = []);
                                routeProvider.setEndLocation(null);
                              }
                            },
                            onTap: () {
                              if (mounted)
                                setState(() => _isStartSearchActive = false);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isCalculatingRoute
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.directions, size: 20),
                        label: Text(_isCalculatingRoute
                            ? 'Hesaplanıyor...'
                            : 'Rota Bul'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                        ),
                        onPressed: (_isCalculatingRoute ||
                                routeProvider.startLocation == null ||
                                routeProvider.endLocation == null)
                            ? null
                            : _onRouteSearchRequested,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_currentSheet != SheetType.none)
            LayoutBuilder(builder: (context, constraints) {
              return DraggableScrollableSheet(
                initialChildSize: initialSheetSize,
                minChildSize: minSheetSize,
                maxChildSize: maxSheetSize,
                expand: false,
                snap: true,
                snapSizes: snapSizes,
                builder:
                    (BuildContext context, ScrollController scrollController) {
                  return Card(
                    elevation: 8.0,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            if (headerWidget != null) headerWidget,
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
