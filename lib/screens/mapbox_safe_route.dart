import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart'
    as geo
    show Geolocator, Position, LocationAccuracy, LocationSettings;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class MapboxSafeRoute extends StatefulWidget {
  const MapboxSafeRoute({super.key});

  @override
  State<MapboxSafeRoute> createState() => _MapboxSafeRouteState();
}

class _MapboxSafeRouteState extends State<MapboxSafeRoute> {
  MapboxMap? mapboxMap;
  String? accessToken;

  Point? origin;
  Point? destination;
  bool isLoading = false;

  String? _routeDistance;
  String? _routeDuration;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destSuggestions = [];
  bool _showSourceSuggestions = false;
  bool _showDestSuggestions = false;

  bool _isSelectingSuggestion = false;
  String _profile = 'walking';

  final String _routeSourceId = 'route-source';
  final String _routeLayerId = 'route-layer';
  final String _originMarkerId = 'origin-marker';
  final String _destMarkerId = 'dest-marker';

  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (accessToken != null) {
      MapboxOptions.setAccessToken(accessToken!);
    }
    _init();

    _sourceController.addListener(() {
      if (!_isSelectingSuggestion &&
          _sourceController.text.length > 2 &&
          _sourceController.text != 'Current Location') {
        _debouncedSearch(_sourceController.text, true);
      }
    });

    _destController.addListener(() {
      if (!_isSelectingSuggestion && _destController.text.length > 2) {
        _debouncedSearch(_destController.text, false);
      }
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await Permission.locationWhenInUse.request();
    await _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      geo.Position pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        origin = Point(
          coordinates: Position(
            pos.longitude.toDouble(),
            pos.latitude.toDouble(),
          ),
        );
        _sourceController.text = 'Current Location';
      });
      _moveCamera();
      _addOriginMarker();
    } catch (e) {
      debugPrint("Location error: $e");
      if (!mounted) return;
      setState(() {
        origin = Point(coordinates: Position(72.8561, 19.2435));
        _sourceController.text = 'SFIT, Borivali';
      });
      _moveCamera();
      _addOriginMarker();
    }
  }

  void _onMapCreated(MapboxMap map) {
    mapboxMap = map;
    _moveCamera();
  }

  // ✅ v11 FIX: addOnStyleLoadedListener is replaced by onStyleLoadedListener in MapWidget
  // or a subscription here. We will use the async style check for _add3DBuildings.
  Future<void> _add3DBuildings() async {
    if (mapboxMap == null) return;
    final style = mapboxMap!.style;

    if (!(await style.styleLayerExists('3d-buildings'))) {
      await style.addLayer(
        FillExtrusionLayer(
          id: '3d-buildings',
          sourceId: 'composite',
          sourceLayer: 'building',
          minZoom: 15.0,
          // ✅ Set these to null or a default double first to satisfy the compiler
          fillExtrusionHeight: null,
          fillExtrusionBase: null,
          fillExtrusionColor: Colors.grey.toARGB32(),
          fillExtrusionOpacity: 0.6,
        ),
      );

      // ✅ Apply the data-driven expressions here
      // This tells Mapbox to pull 'height' and 'min_height' from the vector tiles
      await style.setStyleLayerProperty(
        '3d-buildings',
        'fill-extrusion-height',
        ["get", "height"],
      );
      await style.setStyleLayerProperty('3d-buildings', 'fill-extrusion-base', [
        "get",
        "min_height",
      ]);
    }
  }

  void _moveCamera() {
    if (mapboxMap != null && origin != null) {
      mapboxMap!.flyTo(
        CameraOptions(center: origin, zoom: 16.0, pitch: 45.0),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _debouncedSearch(String query, bool isSource) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _onSearchChanged(query, isSource);
    });
  }

  void _onSearchChanged(String query, bool isSource) async {
    if (accessToken == null) return;
    try {
      final String proximity = origin != null
          ? "&proximity=${origin!.coordinates.lng},${origin!.coordinates.lat}"
          : "";

      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
        '?access_token=$accessToken&limit=6&country=in$proximity&types=poi,address,neighborhood,place',
      );

      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final List features = data['features'];

        final suggestions = features
            .map(
              (f) => {
                'display_name': f['place_name'],
                'lat': f['geometry']['coordinates'][1].toString(),
                'lon': f['geometry']['coordinates'][0].toString(),
              },
            )
            .toList();

        if (!mounted) return;
        setState(() {
          if (isSource) {
            _sourceSuggestions = suggestions.cast<Map<String, dynamic>>();
            _showSourceSuggestions = true;
          } else {
            _destSuggestions = suggestions.cast<Map<String, dynamic>>();
            _showDestSuggestions = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> place, bool isSource) {
    final lat = double.parse(place['lat']);
    final lng = double.parse(place['lon']);

    FocusScope.of(context).unfocus();
    _isSelectingSuggestion = true;

    if (!mounted) return;
    setState(() {
      if (isSource) {
        origin = Point(coordinates: Position(lng, lat));
        _sourceController.text = place['display_name'].split(',').first;
        _showSourceSuggestions = false;
        _sourceSuggestions = [];
        _addOriginMarker();
      } else {
        destination = Point(coordinates: Position(lng, lat));
        _destController.text = place['display_name'].split(',').first;
        _showDestSuggestions = false;
        _destSuggestions = [];
        _addDestMarker();
      }
    });

    _isSelectingSuggestion = false;
    _moveCamera();
    if (origin != null && destination != null) {
      _drawRoute(origin!, destination!);
    }
  }

  Future<void> _addOriginMarker() async {
    if (mapboxMap == null || origin == null) return;
    final style = mapboxMap!.style;

    // ✅ v11 FIX: Async checks and block syntax
    if (await style.styleLayerExists(_originMarkerId)) {
      await style.removeStyleLayer(_originMarkerId);
    }
    if (await style.styleSourceExists(_originMarkerId)) {
      await style.removeStyleSource(_originMarkerId);
    }

    await style.addSource(
      GeoJsonSource(
        id: _originMarkerId,
        data: jsonEncode({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [origin!.coordinates.lng, origin!.coordinates.lat],
          },
        }),
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _originMarkerId,
        sourceId: _originMarkerId,
        circleRadius: 10.0,
        circleColor: Colors.blue.toARGB32(),
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
  }

  Future<void> _addDestMarker() async {
    if (mapboxMap == null || destination == null) return;
    final style = mapboxMap!.style;

    if (await style.styleLayerExists(_destMarkerId)) {
      await style.removeStyleLayer(_destMarkerId);
    }
    if (await style.styleSourceExists(_destMarkerId)) {
      await style.removeStyleSource(_destMarkerId);
    }

    await style.addSource(
      GeoJsonSource(
        id: _destMarkerId,
        data: jsonEncode({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [
              destination!.coordinates.lng,
              destination!.coordinates.lat,
            ],
          },
        }),
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _destMarkerId,
        sourceId: _destMarkerId,
        circleRadius: 10.0,
        circleColor: Colors.red.toARGB32(),
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
  }

  Future<void> _drawRoute(Point start, Point end) async {
    if (mapboxMap == null || accessToken == null) return;
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/$_profile/'
        '${start.coordinates.lng},${start.coordinates.lat};'
        '${end.coordinates.lng},${end.coordinates.lat}?'
        'geometries=geojson&overview=full&access_token=$accessToken',
      );

      final res = await http.get(url);
      if (!mounted) return;

      final data = jsonDecode(res.body);
      if (data['routes'] == null || data['routes'].isEmpty) return;

      final route = data['routes'][0];
      final geometry = route['geometry'];

      if (!mounted) return;
      setState(() {
        _routeDistance = '${(route['distance'] / 1000).toStringAsFixed(2)} km';
        _routeDuration = '${(route['duration'] / 60).toStringAsFixed(0)} min';
      });

      final style = mapboxMap!.style;

      if (await style.styleLayerExists(_routeLayerId)) {
        await style.removeStyleLayer(_routeLayerId);
      }
      if (await style.styleSourceExists(_routeSourceId)) {
        await style.removeStyleSource(_routeSourceId);
      }

      await style.addSource(
        GeoJsonSource(id: _routeSourceId, data: jsonEncode(geometry)),
      );
      await style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineColor: Colors.teal.toARGB32(),
          lineWidth: 5.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
    } catch (e) {
      debugPrint("Route error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _clearRoute() async {
    if (mapboxMap == null) return;
    final style = mapboxMap!.style;

    if (await style.styleLayerExists(_routeLayerId)) {
      await style.removeStyleLayer(_routeLayerId);
    }
    if (await style.styleSourceExists(_routeSourceId)) {
      await style.removeStyleSource(_routeSourceId);
    }

    if (!mounted) return;
    setState(() {
      destination = null;
      _destController.clear();
      _routeDistance = null;
      _routeDuration = null;
      _showDestSuggestions = false;
      _destSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Safe Sprout Navigation",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.red, size: 30),
            onPressed: () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🚨 SOS Activated!')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
            // ✅ v11 FIX: This is the correct place to trigger 3D buildings
            onStyleLoadedListener: (StyleLoadedEventData data) {
              _add3DBuildings();
            },
          ),

          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.teal)),

          Positioned(
            top: 20,
            left: 15,
            right: 15,
            child: Column(
              children: [
                _buildSearchBox(
                  controller: _sourceController,
                  hint: "Starting point",
                  suggestions: _sourceSuggestions,
                  visible: _showSourceSuggestions,
                  onSelect: (p) => _selectSuggestion(p, true),
                  onClear: () {
                    if (!mounted) return;
                    setState(() {
                      _showSourceSuggestions = false;
                      _sourceSuggestions = [];
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSearchBox(
                  controller: _destController,
                  hint: "Destination building/place",
                  suggestions: _destSuggestions,
                  visible: _showDestSuggestions,
                  onSelect: (p) => _selectSuggestion(p, false),
                  onClear: () {
                    if (!mounted) return;
                    setState(() {
                      _showDestSuggestions = false;
                      _destSuggestions = [];
                    });
                    _clearRoute();
                  },
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 110,
            left: 25,
            right: 25,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _modeButton(Icons.directions_walk, "walking"),
                  _modeButton(Icons.directions_bike, "cycling"),
                  _modeButton(Icons.directions_car, "driving"),
                ],
              ),
            ),
          ),

          if (destination != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57171),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🚶 Journey started! Stay safe.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(
                    "Start Journey • ${_routeDistance ?? ''} (${_routeDuration ?? ''})",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeButton(IconData icon, String mode) {
    bool active = _profile == mode;
    return IconButton(
      icon: Icon(icon, color: active ? Colors.teal : Colors.black45, size: 28),
      onPressed: () {
        if (!mounted) return;
        setState(() => _profile = mode);
        if (origin != null && destination != null) {
          _drawRoute(origin!, destination!);
        }
      },
    );
  }

  Widget _buildSearchBox({
    required TextEditingController controller,
    required String hint,
    required List<Map<String, dynamic>> suggestions,
    required bool visible,
    required Function(Map<String, dynamic>) onSelect,
    required VoidCallback onClear,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        if (visible && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(
                  suggestions[i]['display_name'],
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                ),
                onTap: () => onSelect(suggestions[i]),
              ),
            ),
          ),
      ],
    );
  }
}
