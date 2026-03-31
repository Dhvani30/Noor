import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
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

  @override
  void initState() {
    super.initState();
    accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (accessToken != null) {
      MapboxOptions.setAccessToken(accessToken!);
    }
    _init();
  }

  Future<void> _init() async {
    await Permission.locationWhenInUse.request();
    await _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      geo.Position pos = await geo.Geolocator.getCurrentPosition();
      setState(() {
        origin = Point(coordinates: Position(pos.longitude, pos.latitude));
      });
      _moveCamera();
    } catch (e) {
      debugPrint("Location error: $e");
      // Fallback: SFIT, Borivali/Kandivali area
      setState(() {
        origin = Point(coordinates: Position(72.8561, 19.2435));
      });
    }
  }

  void _onMapCreated(MapboxMap map) {
    mapboxMap = map;
    _moveCamera();
  }

  void _moveCamera() {
    if (mapboxMap != null && origin != null) {
      mapboxMap!.flyTo(
        CameraOptions(center: origin, zoom: 14.0),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  Future<void> _drawRoute(Point start, Point end) async {
    if (mapboxMap == null || accessToken == null) return;

    setState(() => isLoading = true);

    try {
      final startLng = start.coordinates.lng;
      final startLat = start.coordinates.lat;
      final endLng = end.coordinates.lng;
      final endLat = end.coordinates.lat;

      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/walking/'
        '$startLng,$startLat;$endLng,$endLat?'
        'geometries=geojson&access_token=$accessToken',
      );

      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['routes'] == null || data['routes'].isEmpty) return;

      final coords = data['routes'][0]['geometry']['coordinates'];

      final geoJson = jsonEncode({
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {"type": "LineString", "coordinates": coords},
            "properties": {},
          },
        ],
      });

      final style = await mapboxMap!.style;

      // Safe cleanup of old layers/sources
      if (await style.styleLayerExists("route-layer")) {
        await style.removeStyleLayer("route-layer");
      }
      if (await style.styleSourceExists("route-source")) {
        await style.removeStyleSource("route-source");
      }

      await style.addSource(GeoJsonSource(id: "route-source", data: geoJson));

      await style.addLayer(
        LineLayer(
          id: "route-layer",
          sourceId: "route-source",
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
    } catch (e) {
      debugPrint("Route error: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Safe Route Finder")),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            onTapListener: (MapContentGestureContext gestureContext) async {
              if (mapboxMap == null) return;

              try {
                // ✅ FIX: In v1.1.0, gestureContext.point is a geographic Point.
                // We need to extract the raw X/Y values into a ScreenCoordinate.
                final screenCoords = ScreenCoordinate(
                  x: gestureContext
                      .point
                      .coordinates
                      .lng.toDouble(), // lng field stores the X pixel
                  y: gestureContext
                      .point
                      .coordinates
                      .lat.toDouble(), // lat field stores the Y pixel
                );

                // Now convert those pixels back into a proper Geographic Point
                final Point tappedGeoPoint = await mapboxMap!
                    .coordinateForPixel(screenCoords);

                setState(() {
                  destination = tappedGeoPoint;
                });

                if (origin != null && destination != null) {
                  _drawRoute(origin!, destination!);
                }
              } catch (e) {
                debugPrint("Tap logic error: $e");
              }
            },
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (destination != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "Destination: ${destination!.coordinates.lat.toStringAsFixed(5)}, ${destination!.coordinates.lng.toStringAsFixed(5)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
