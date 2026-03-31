import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class SafeRoutePlanner extends StatefulWidget {
  @override
  State<SafeRoutePlanner> createState() => _SafeRoutePlannerState();
}

class _SafeRoutePlannerState extends State<SafeRoutePlanner> {
  final TextEditingController _searchController = TextEditingController();
  late MapController _mapController;
  LatLng? _origin;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  List<Place> _suggestions = [];
  List<Crime> _crimes = [];
  bool _isLoading = false;

  // 🔑 YOUR DEVELOPER EMAIL (replace this!)
  static const String _developerEmail = 'dkm12305@gmail.com';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Location Services')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Go to settings to enable location')),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _origin = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_origin!, 14.0);
      }
    } catch (e) {
      // Fallback only if absolutely necessary
      if (mounted) {
        setState(() {
          _origin = LatLng(28.6139, 77.2090); // Delhi
        });
        _mapController.move(_origin!, 14.0);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    _getPlaceSuggestions(query);
  }

  Future<void> _getPlaceSuggestions(String query) async {
    if (query.trim().isEmpty) return;

    try {
      // 🔥 KEY FIX: Use viewbox around user's location
      String viewbox = '';
      if (_origin != null) {
        final lat = _origin!.latitude;
        final lng = _origin!.longitude;
        // ±0.3° ≈ 33 km radius (better for city-level)
        final minLat = (lat - 0.3).toStringAsFixed(6);
        final maxLat = (lat + 0.3).toStringAsFixed(6);
        final minLng = (lng - 0.3).toStringAsFixed(6);
        final maxLng = (lng + 0.3).toStringAsFixed(6);
        viewbox = '&viewbox=$minLng%2C$maxLat%2C$maxLng%2C$minLat&bounded=1';
      }

      final encodedQuery = Uri.encodeComponent(query);
      // 🔥 FIXED: Removed extra spaces in URL
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$encodedQuery&format=json&limit=5&addressdetails=1'
        '$viewbox&countrycodes=IN',
      );

      final response = await http.get(
        url,
        headers: {
          // 🔥 Use YOUR email
          'User-Agent': 'SafeSprout/1.0 ($_developerEmail)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as List;
        if (data.isEmpty) {
          setState(() {
            _suggestions = [Place.empty('No places found')];
          });
        } else {
          final places = data.map((item) => Place.fromJson(item)).toList();
          setState(() {
            _suggestions = places;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectDestination(Place place) async {
    if (place.lat == 0 && place.lon == 0) return; // Skip "No results"

    final newDestination = LatLng(place.lat, place.lon);
    if (mounted) {
      setState(() {
        _destination = newDestination;
        _suggestions = [];
        _searchController.text = place.displayName;
      });
      _mapController.move(newDestination, 14.0);
    }
    await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    if (_origin == null || _destination == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final route = await _getWalkingRoute(_origin!, _destination!);
      final crimes = await _getCrimesNearRoute(_origin!, _destination!);
      if (mounted) {
        setState(() {
          _routePoints = route;
          _crimes = crimes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Route error: ${e.toString()}')));
      }
    }
  }

  Future<List<LatLng>> _getWalkingRoute(LatLng start, LatLng end) async {
    // 🔥 FIXED: Removed extra spaces in URL
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}?'
      'overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final coords = routes[0]['geometry']['coordinates'] as List;
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      }
    }
    return [start, end];
  }

  Future<List<Crime>> _getCrimesNearRoute(LatLng start, LatLng end) async {
    final centerLat = (start.latitude + end.latitude) / 2;
    final centerLng = (start.longitude + end.longitude) / 2;
    final minLat = centerLat - 0.01;
    final maxLat = centerLat + 0.01;
    final minLng = centerLng - 0.01;
    final maxLng = centerLng + 0.01;

    try {
      // 🔥 FIXED: Removed extra spaces in URL
      final url = Uri.parse(
        'https://api.spotcrime.com/v2/crimes?'
        'lat1=$minLat&lat2=$maxLat&lon1=$minLng&lon2=$maxLng',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final crimes = data['crimes'] as List?;
        if (crimes != null) {
          return crimes.map((crime) {
            return Crime(
              type: crime['type'],
              location: LatLng(
                double.parse(crime['lat']),
                double.parse(crime['lon']),
              ),
              date: DateTime.parse(crime['date']),
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Safe Route'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _origin ?? LatLng(28.6139, 77.2090),
              initialZoom: 14,
            ),
            children: [
              // 🔥 BETTER TILE SERVER (faster, no rate limits)
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourcompany.safesprout',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.green,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_origin != null)
                    Marker(
                      point: _origin!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 36,
                      ),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ..._crimes.map(
                    (crime) => Marker(
                      point: crime.location,
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.warning,
                        color: crime.isViolent ? Colors.red : Colors.orange,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black), // 🔥 Readable text
                decoration: const InputDecoration(
                  hintText: 'Where to?',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                ),
              ),
            ),
          ),

          if (_suggestions.isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final place = _suggestions[index];
                    return ListTile(
                      // 🔥 Readable text styles
                      title: Text(
                        place.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        place.address,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () => _selectDestination(place),
                    );
                  },
                ),
              ),
            ),

          // 🔥 CENTERED LOADING INDICATOR
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),

          if (_destination != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE57171),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Journey',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Models ---
class Place {
  final String displayName;
  final String address;
  final double lat;
  final double lon;

  Place({
    required this.displayName,
    required this.address,
    required this.lat,
    required this.lon,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>?;
    final parts = <String>[
      if (addr?['road'] != null) addr!['road'],
      if (addr?['city'] != null) addr!['city'],
      if (addr?['state'] != null) addr!['state'],
      if (addr?['country'] != null) addr!['country'],
    ];
    return Place(
      displayName: json['display_name'],
      address: parts.join(', '),
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }

  factory Place.empty(String name) =>
      Place(displayName: name, address: '', lat: 0, lon: 0);
}

class Crime {
  final String type;
  final LatLng location;
  final DateTime date;

  Crime({required this.type, required this.location, required this.date});

  bool get isViolent =>
      ['Assault', 'Arrest', 'Robbery', 'Shooting', 'Theft'].contains(type);
}
