import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui; // ✅ MUST be imported as 'ui'
import 'dart:typed_data';
import 'dart:math' as math; // ✅ For sqrt and pow
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// Helper class for risk data
class _RiskPoint {
  final double lat;
  final double lng;
  final double risk;
  _RiskPoint(this.lat, this.lng, this.risk);
}

class SafeRouteMap extends StatefulWidget {
  const SafeRouteMap({super.key});

  @override
  State<SafeRouteMap> createState() => _SafeRouteMapState();
}

class _SafeRouteMapState extends State<SafeRouteMap> {
  final MapController _mapController = MapController();

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  // ✅ FIX 1: Explicitly type as ui.Image? (NOT just Image?)
  // This tells Dart we want the raw canvas image, not the Widget.
  ui.Image? _heatmapImage;
  LatLngBounds? _heatmapBounds;
  List<_RiskPoint> _riskPoints = [];

  LatLng? _currentLocation;
  LatLng? _destinationLocation;

  // Mumbai Bounds
  static const double _minLat = 18.8;
  static const double _maxLat = 19.3;
  static const double _minLng = 72.7;
  static const double _maxLng = 73.1;
  static const LatLng _mumbaiCenter = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _loadRiskGrid();
    _getCurrentLocation();
  }

  // 1. Load AI-Generated JSON
  Future<void> _loadRiskGrid() async {
    try {
      debugPrint("📂 Loading AI risk data...");
      final String jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/data/mumbai_risk_grid.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      for (var point in jsonData) {
        double? latRaw = (point['Latitude'] as num?)?.toDouble();
        double? lngRaw = (point['Longitude'] as num?)?.toDouble();
        double? riskRaw = (point['risk'] as num?)?.toDouble();

        if (latRaw == null || lngRaw == null) continue;

        if (latRaw < _minLat ||
            latRaw > _maxLat ||
            lngRaw < _minLng ||
            lngRaw > _maxLng)
          continue;

        _riskPoints.add(_RiskPoint(latRaw, lngRaw, riskRaw ?? 0.5));
      }

      debugPrint(
        "✅ Loaded ${_riskPoints.length} AI points. Generating Smooth Heatmap...",
      );
      await _generateSmoothHeatmap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Heatmap Ready (${_riskPoints.length} zones)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error loading JSON: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 2. Generate Smooth Heatmap Image
  Future<void> _generateSmoothHeatmap() async {
    if (_riskPoints.isEmpty) return;

    const int width = 800;
    const int height = 800;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final latRange = _maxLat - _minLat;
    final lngRange = _maxLng - _minLng;

    for (var point in _riskPoints) {
      double x = ((point.lng - _minLng) / lngRange) * width;
      double y = ((_maxLat - point.lat) / latRange) * height;

      if (x < -50 || x > width + 50 || y < -50 || y > height + 50) continue;

      Color baseColor = _getRiskColor(point.risk);
      double radius = 35.0;

      final paint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [baseColor.withOpacity(0.8), baseColor.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius))
        ..blendMode = ui.BlendMode.srcOver;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    final picture = recorder.endRecording();

    // ✅ FIX 2: Explicitly type the result as ui.Image
    final ui.Image img = await picture.toImage(width, height);

    setState(() {
      // Now assigning ui.Image to ui.Image? variable (Types match!)
      _heatmapImage = img;
      _heatmapBounds = LatLngBounds(
        LatLng(_minLat, _minLng),
        LatLng(_maxLat, _maxLng),
      );
    });
  }

  Color _getRiskColor(double risk) {
    if (risk < 0.25) return const Color(0xFF00E676);
    if (risk < 0.50) return const Color(0xFFFFEB3B);
    if (risk < 0.75) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  // 3. Get Location
  Future<void> _getCurrentLocation() async {
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.removeWhere((m) => m.point == _currentLocation);
        _markers.add(
          Marker(
            width: 40,
            height: 40,
            point: _currentLocation!,
            child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
          ),
        );
      });
      _mapController.move(_currentLocation!, 12.0);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  // 4. Handle Tap & Route
  void _onMapTap(LatLng tappedPoint) {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Waiting for GPS...')));
      return;
    }

    setState(() {
      _destinationLocation = tappedPoint;
      _markers.removeWhere((m) => m.point == _destinationLocation);
      _markers.add(
        Marker(
          width: 40,
          height: 40,
          point: tappedPoint,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );

      _polylines.clear();
      _polylines.add(
        Polyline(
          points: [_currentLocation!, tappedPoint],
          strokeWidth: 5.0,
          color: Colors.blueAccent,
        ),
      );
    });

    double risk = _getRiskAtLocation(tappedPoint);
    String label = risk < 0.3
        ? "Safe Route"
        : (risk < 0.6 ? "Caution" : "High Risk");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label (Risk: ${(risk * 100).toStringAsFixed(0)}%)'),
        backgroundColor: risk < 0.3
            ? Colors.green
            : (risk < 0.6 ? Colors.orange : Colors.red),
      ),
    );
  }

  double _getRiskAtLocation(LatLng location) {
    double minDist = double.infinity;
    double risk = 0.5;

    for (var point in _riskPoints) {
      double dist = math.sqrt(
        math.pow(point.lat - location.latitude, 2) +
            math.pow(point.lng - location.longitude, 2),
      );

      if (dist < minDist) {
        minDist = dist;
        risk = point.risk;
      }
      if (dist < 0.001) break;
    }
    return risk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Sprout: AI Heatmap'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.red, size: 30),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('SOS Activated'),
                  content: const Text(
                    'Sending location to Priti & trusted contacts...',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mumbaiCenter,
              initialZoom: 11.0,
              onTap: (_, point) => _onMapTap(point),
              onPositionChanged: (position, hasGesture) {
                if (_heatmapImage != null) setState(() {});
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.noor',
              ),
              MarkerLayer(markers: _markers),
              PolylineLayer(polylines: _polylines),
            ],
          ),

          if (_heatmapImage != null && _heatmapBounds != null)
            _HeatmapOverlay(
              image: _heatmapImage!,
              bounds: _heatmapBounds!,
              mapController: _mapController,
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem("Safe", const Color(0xFF00E676)),
                    _buildLegendItem("Moderate", const Color(0xFFFF9800)),
                    _buildLegendItem("Danger", const Color(0xFFF44336)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ✅ FIX 3: The Overlay Widget explicitly expects ui.Image
class _HeatmapOverlay extends StatelessWidget {
  // Explicitly typed as ui.Image to match the generated data
  final ui.Image image;
  final LatLngBounds bounds;
  final MapController mapController;

  const _HeatmapOverlay({
    required this.image,
    required this.bounds,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    final camera = mapController.camera;
    if (camera == null) return const SizedBox.shrink();

    final northWest = LatLng(bounds.north, bounds.west);
    final southEast = LatLng(bounds.south, bounds.east);

    final point1 = camera.project(northWest);
    final point2 = camera.project(southEast);

    final width = point2.x - point1.x;
    final height = point2.y - point1.y;

    return Positioned(
      left: point1.x,
      top: point1.y,
      width: width,
      height: height,
      child: Opacity(
        opacity: 0.7,
        child: ClipRect(
          // RawImage expects dart:ui.Image. We are passing ui.Image. They match perfectly.
          child: RawImage(image: image, fit: BoxFit.fill),
        ),
      ),
    );
  }
}
