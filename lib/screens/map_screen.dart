import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mosque.dart';
import 'mosque_details_screen.dart';

// ---------------- OSM Mosque Model ----------------

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

// ---------------- MAP SCREEN ----------------

class MapScreen extends StatefulWidget {
  final bool isAuthorized;
  const MapScreen({super.key, required this.isAuthorized});

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

  // ---------------- LOCATION ----------------

  Future<void> _ensureLocationEnabled() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await _showLocationDialog();
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

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    userLocation = LatLng(position.latitude, position.longitude);
  }

  Future<void> _showLocationDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text(
          'Location is required to find nearby mosques.\n\nPlease enable device location.',
        ),
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

  // ---------------- FETCH MOSQUES ----------------

  Future<void> _fetchOSMMosques() async {
    if (userLocation == null) return;

    final url =
        'https://overpass-api.de/api/interpreter?data=[out:json];'
        'node["amenity"="place_of_worship"]["religion"="muslim"]'
        '(around:2000,${userLocation!.latitude},${userLocation!.longitude});out;';

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

  // ---------------- MOSQUE WITH DISTANCE ----------------

  Future<Mosque> _buildMosque(OSMMosque osm) async {
    final distance = Geolocator.distanceBetween(
      userLocation!.latitude,
      userLocation!.longitude,
      osm.lat,
      osm.lon,
    );

    final doc = await FirebaseFirestore.instance
        .collection('mosque')
        .doc(osm.osmId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      return Mosque(
        osmId: osm.osmId,
        name: osm.name,
        latitude: osm.lat,
        longitude: osm.lon,
        fajr: data['Fajr'],
        dhuhr: data['Dhuhr'],
        asr: data['Asr'],
        maghrib: data['Maghrib'],
        isha: data['Isha'],
        distanceMeters: distance,
      );
    }

    return Mosque(
      osmId: osm.osmId,
      name: osm.name,
      latitude: osm.lat,
      longitude: osm.lon,
      distanceMeters: distance,
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage != null) {
      return Scaffold(body: Center(child: Text(errorMessage!)));
    }

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
                    onTap: () async {
                      final mosque = await _buildMosque(osm);
                      if (!mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MosqueDetailsScreen(
                            mosque: mosque,
                            isAuthorized: widget.isAuthorized,
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
              }),
            ],
          ),
        ],
      ),
    );
  }
}
