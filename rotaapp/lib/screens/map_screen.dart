import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  void setStartLocation(LatLng location) {
    startLocation = location;
    notifyListeners();
  }

  void setEndLocation(LatLng location) {
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
}

class RouteOption {
  final String name;
  final String distance;
  final String duration;
  final bool isTollRoad;
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
  bool _isLoading = true;
  String? _error;
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  bool _showRouteOptions = false;
  List<LocationResult> _startSearchResults = [];
  List<LocationResult> _endSearchResults = [];
  bool _isStartSearching = false;
  bool _isEndSearching = false;
  FocusNode _startFocusNode = FocusNode();
  FocusNode _endFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startFocusNode.addListener(() {
      setState(() {
        _isStartSearching = _startFocusNode.hasFocus;
      });
    });
    _endFocusNode.addListener(() {
      setState(() {
        _isEndSearching = _endFocusNode.hasFocus;
      });
    });
  }

  Future<void> _initializeMap() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!isLocationEnabled) {
          throw Exception('Konum servisleri kapalı. Lütfen açın.');
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _isLoading = false;
          });
          Provider.of<RouteProvider>(
            context,
            listen: false,
          ).setStartLocation(_currentLocation!);
        }
      } else {
        throw Exception('Konum izni reddedildi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Harita yüklenirken bir hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchLocations(String query, bool isStart) async {
    if (query.isEmpty) {
      setState(() {
        if (isStart) {
          _startSearchResults = [];
        } else {
          _endSearchResults = [];
        }
      });
      return;
    }

    try {
      // Türkiye'ye öncelik vermek için viewbox parametresi ekliyoruz
      // Bu parametre İstanbul merkezli geniş bir alanı kapsıyor
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5&countrycodes=tr&viewbox=28.5,41.0,29.5,41.2&bounded=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RotaApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        // Sonuçları önceliklendir
        final List<Map<String, dynamic>> sortedResults =
            results.map((result) {
                // Türkiye'deki sonuçları önceliklendir
                final bool isInTurkey =
                    result['address']?['country'] == 'Türkiye';
                final int priority = isInTurkey ? 0 : 1;

                return {
                  'location': LocationResult(
                    displayName: result['display_name'],
                    coordinates: LatLng(
                      double.parse(result['lat']),
                      double.parse(result['lon']),
                    ),
                    type: result['type'],
                  ),
                  'priority': priority,
                };
              }).toList()
              ..sort(
                (a, b) =>
                    (a['priority'] as int).compareTo(b['priority'] as int),
              );

        final List<LocationResult> locations =
            sortedResults
                .map((item) => item['location'] as LocationResult)
                .toList();

        setState(() {
          if (isStart) {
            _startSearchResults = locations;
          } else {
            _endSearchResults = locations;
          }
        });
      }
    } catch (e) {
      print('Arama hatası: $e');
    }
  }

  void _selectLocation(LocationResult location, bool isStart) {
    final controller = isStart ? _startController : _endController;
    controller.text = location.displayName;

    if (isStart) {
      Provider.of<RouteProvider>(
        context,
        listen: false,
      ).setStartLocation(location.coordinates);
    } else {
      Provider.of<RouteProvider>(
        context,
        listen: false,
      ).setEndLocation(location.coordinates);
    }

    setState(() {
      if (isStart) {
        _startSearchResults = [];
        _isStartSearching = false;
      } else {
        _endSearchResults = [];
        _isEndSearching = false;
      }
    });
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    final routeProvider = Provider.of<RouteProvider>(context, listen: false);

    try {
      // OSRM API endpoint with alternatives
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<RouteOption> routeOptions = [];

        for (var i = 0; i < data['routes'].length; i++) {
          final route = data['routes'][i];

          // Convert GeoJSON coordinates to LatLng points
          final List<dynamic> coordinates = route['geometry']['coordinates'];
          final List<LatLng> points =
              coordinates.map((coord) {
                return LatLng(coord[1], coord[0]);
              }).toList();

          // Calculate distance in kilometers and duration in minutes
          final distance = (route['distance'] / 1000).toStringAsFixed(1);
          final duration = (route['duration'] / 60).round();

          // Check if route uses toll roads (this is a simplified check)
          final bool hasTollRoads = route['legs'].any((leg) {
            final steps = leg['steps'];
            if (steps is List) {
              return steps.any(
                (step) =>
                    (step['name']?.toString().toLowerCase() ?? '').contains(
                      'otoyol',
                    ) ||
                    (step['name']?.toString().toLowerCase() ?? '').contains(
                      'otoban',
                    ),
              );
            }
            return false;
          });

          routeOptions.add(
            RouteOption(
              name: i == 0 ? 'En Hızlı Rota' : 'Alternatif Rota ${i + 1}',
              distance: '$distance km',
              duration: '$duration dk',
              isTollRoad: hasTollRoads,
              points: points,
            ),
          );
        }

        routeProvider.routeOptions = routeOptions;
        routeProvider.routePoints = routeOptions[0].points;
        routeProvider.routeDistance = routeOptions[0].distance;
        routeProvider.routeDuration = routeOptions[0].duration;
        routeProvider.notifyListeners();

        // Zoom to fit the route
        final bounds = LatLngBounds.fromPoints(routeOptions[0].points);
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
        );

        setState(() {
          _showRouteOptions = true;
        });
      } else {
        throw Exception('Rota hesaplanırken bir hata oluştu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rota hesaplanırken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchSubmitted() {
    if (_startController.text.isNotEmpty && _endController.text.isNotEmpty) {
      // Örnek koordinatlar
      _calculateRoute(
        _currentLocation ?? const LatLng(41.0082, 28.9784),
        const LatLng(41.0082, 28.9784),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Harita"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed:
                _currentLocation == null
                    ? null
                    : () {
                      _mapController.move(_currentLocation!, 15);
                    },
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _initializeMap,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              )
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _currentLocation ?? const LatLng(41.0082, 28.9784),
                  initialZoom: 13,
                  maxZoom: 18,
                  minZoom: 5,
                  keepAlive: true,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.rotaapp',
                    maxZoom: 19,
                  ),
                  if (_currentLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation!,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  Consumer<RouteProvider>(
                    builder: (context, routeProvider, child) {
                      if (routeProvider.routePoints != null) {
                        return PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routeProvider.routePoints!,
                              strokeWidth: 4,
                              color: Colors.blue,
                            ),
                          ],
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            focusNode: _startFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Başlangıç noktası',
                              prefixIcon: const Icon(Icons.location_on),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: () {
                                  if (_currentLocation != null) {
                                    _startController.text = 'Mevcut Konum';
                                    Provider.of<RouteProvider>(
                                      context,
                                      listen: false,
                                    ).setStartLocation(_currentLocation!);
                                  }
                                },
                              ),
                            ),
                            onChanged: (value) => _searchLocations(value, true),
                            onSubmitted: (_) => _onSearchSubmitted(),
                          ),
                        ),
                      ],
                    ),
                    if (_isStartSearching && _startSearchResults.isNotEmpty)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            focusNode: _endFocusNode,
                            decoration: const InputDecoration(
                              hintText: 'Varış noktası',
                              prefixIcon: Icon(Icons.flag),
                            ),
                            onChanged:
                                (value) => _searchLocations(value, false),
                            onSubmitted: (_) => _onSearchSubmitted(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _onSearchSubmitted,
                          icon: const Icon(Icons.search),
                          label: const Text('Rota Bul'),
                        ),
                      ],
                    ),
                    if (_isEndSearching && _endSearchResults.isNotEmpty)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
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
          if (_showRouteOptions)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Consumer<RouteProvider>(
                builder: (context, routeProvider, child) {
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tahmini Varış',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${routeProvider.routeDistance} • ${routeProvider.routeDuration}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _showRouteOptions = false;
                                  });
                                  routeProvider.clearRoute();
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
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
                              final isSelected =
                                  routeProvider.routeDistance ==
                                  option.distance;
                              return Container(
                                width: 150,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                          : null,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    routeProvider.routePoints = option.points;
                                    routeProvider.routeDistance =
                                        option.distance;
                                    routeProvider.routeDuration =
                                        option.duration;
                                    routeProvider.notifyListeners();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              option.isTollRoad
                                                  ? Icons.attach_money
                                                  : Icons.route,
                                              color:
                                                  isSelected
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                option.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isSelected
                                                          ? Theme.of(
                                                            context,
                                                          ).colorScheme.primary
                                                          : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option.distance,
                                              style: TextStyle(
                                                color:
                                                    isSelected
                                                        ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                        : Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              option.duration,
                                              style: TextStyle(
                                                color:
                                                    isSelected
                                                        ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                        : Colors.grey,
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }
}
