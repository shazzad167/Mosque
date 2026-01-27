import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'mosque_details_screen.dart';

class OSMMosque {
  final String osmId;
  final String name;
  final double lat;
  final double lon;

  OSMMosque({
    required this.osmId,
    required this.name,
    required this.lat,
    required this.lon,
  });
}

class MapScreen extends StatefulWidget {
  final bool isAuthorized;
  const MapScreen({super.key, this.isAuthorized = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? userLocation;
  List<OSMMosque> osmMosques = [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    try {
      await _ensureLocationEnabled();
      await _getUserLocation();
      await _fetchOSMMosques();
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _ensureLocationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showLocationDialog();
      while (!await Geolocator.isLocationServiceEnabled()) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    userLocation = LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _showLocationDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text('Location is required to find nearby mosques.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('TURN ON LOCATION'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOSMMosques() async {
    if (userLocation == null) return;

    final url =
        'https://overpass-api.de/api/interpreter?data=[out:json];node["amenity"="place_of_worship"]["religion"="muslim"](around:2000,${userLocation!.latitude},${userLocation!.longitude});out;';

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    final List<OSMMosque> loaded = [];
    for (var e in data['elements']) {
      if (e['tags'] != null && e['tags']['name'] != null) {
        loaded.add(
          OSMMosque(
            osmId: e['id'].toString(),
            name: e['tags']['name'],
            lat: e['lat'],
            lon: e['lon'],
          ),
        );
      }
    }

    osmMosques = loaded;
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null)
      return Scaffold(
        body: Center(child: Text(errorMessage!, textAlign: TextAlign.center)),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Mosques')),
      body: FlutterMap(
        options: MapOptions(initialCenter: userLocation!, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.mosque_finder',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.person_pin_circle,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              ...osmMosques.map((osm) {
                return Marker(
                  point: LatLng(osm.lat, osm.lon),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MosqueDetailsScreen(
                            osmId: osm.osmId,
                            mosqueName: osm.name,
                            isAdmin: widget.isAuthorized,
                          ),
                        ),
                      );
                    },
                    child: Image.asset(
                      'assets/icons/mosque_marker.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }
}
