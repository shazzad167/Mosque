import 'dart:convert'; // Import for JSON decoding
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // Import http package

import '../models/mosque.dart';
import 'mosque_details_screen_general.dart';
import 'mosque_details_screen_authorized.dart';

class MapScreen extends StatefulWidget {
  final bool isAuthorized;
  const MapScreen({super.key, required this.isAuthorized});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ---------------------------------------------------------
  // ⚠️ REPLACE THIS WITH YOUR ACTUAL GOOGLE MAPS API KEY ⚠️
  // ---------------------------------------------------------
  final String _googleApiKey = "AIzaSyBh1KiebHeDpxSdO-RDWtHtg1EOiIIQLTA";

  LatLng? userLocation;
  bool loading = true;
  String? errorMessage;

  final Set<Marker> _markers = {};
  BitmapDescriptor? _mosqueMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcons();
    _startFlow();
  }

  // Load custom marker icons from assets
  Future<void> _loadCustomMarkerIcons() async {
    try {
      _mosqueMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(40, 40)),
        'assets/icons/mosque_marker.png',
      );
      _userMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(35, 35)),
        'assets/icons/user_marker.png',
      );
    } catch (e) {
      debugPrint('Error loading custom marker icons: $e');
      // Fallback to default icons
      _mosqueMarkerIcon = BitmapDescriptor.defaultMarker;
      _userMarkerIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _startFlow() async {
    try {
      await _ensureLocationEnabled();
      await _getUserLocation();

      // Load from BOTH sources concurrently
      await Future.wait([
        _loadMosquesFromFirestore(),
        _fetchNearbyPlacesFromGoogle(),
      ]);
    } catch (e) {
      debugPrint('Error in flow: $e');
      errorMessage = e.toString();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  // ---------------- LOCATION ----------------

  Future<void> _ensureLocationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
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

    // Add user location marker
    if (mounted && _userMarkerIcon != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: userLocation!,
            icon: _userMarkerIcon!,
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        );
      });
    }
  }

  // ---------------- LOAD FIRESTORE MOSQUES ----------------

  Future<void> _loadMosquesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mosque')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final lat = data['latitude'];
        final lng = data['longitude'];

        if (lat == null || lng == null) continue;

        final latDouble = (lat as num).toDouble();
        final lngDouble = (lng as num).toDouble();

        final double distance = Geolocator.distanceBetween(
          userLocation!.latitude,
          userLocation!.longitude,
          latDouble,
          lngDouble,
        );

        // Filter: Only show Firestore mosques within 3km (adjustable)
        if (distance > 3000) continue;

        final mosque = Mosque(
          id: doc.id,
          name: data['name'] ?? 'Unknown Mosque',
          latitude: latDouble,
          longitude: lngDouble,
          fajr: data['Fajr'],
          dhuhr: data['Dhuhr'],
          asr: data['Asr'],
          maghrib: data['Maghrib'],
          isha: data['Isha'],
          distanceMeters: distance,
        );

        _addMarker(mosque, isFromFirestore: true);
      }
    } catch (e) {
      debugPrint("Error loading Firestore mosques: $e");
    }
  }

  // ---------------- LOAD GOOGLE PLACES MOSQUES ----------------
  Future<void> _fetchNearbyPlacesFromGoogle() async {
    if (userLocation == null) return;

    final lat = userLocation!.latitude;
    final lng = userLocation!.longitude;

    // 1. Using the "New" Places API Endpoint (POST request)
    final String url = 'https://places.googleapis.com/v1/places:searchNearby';

    // 2. Define the Request Body
    final Map<String, dynamic> body = {
      "includedTypes": ["mosque"], // Standard category for mosques
      "maxResultCount": 15,
      "locationRestriction": {
        "circle": {
          "center": {"latitude": lat, "longitude": lng},
          "radius": 2500.0, // 2.5km search radius
        },
      },
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
          // 3. FieldMask is REQUIRED for the New API. It tells Google exactly what data to return.
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.location,places.formattedAddress',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? places = data['places'];

        if (places != null && places.isNotEmpty) {
          for (var place in places) {
            final String placeId = place['id'];
            final String name =
                place['displayName']['text'] ?? 'Unnamed Mosque';
            final double latDouble = place['location']['latitude'];
            final double lngDouble = place['location']['longitude'];

            final double distance = Geolocator.distanceBetween(
              lat,
              lng,
              latDouble,
              lngDouble,
            );

            final mosque = Mosque(
              id: placeId,
              name: name,
              latitude: latDouble,
              longitude: lngDouble,
              fajr: 'N/A',
              dhuhr: 'N/A',
              asr: 'N/A',
              maghrib: 'N/A',
              isha: 'N/A',
              distanceMeters: distance,
            );

            _addMarker(mosque, isFromFirestore: false);
          }
        } else {
          debugPrint("No nearby mosques found from Google.");
        }
      } else {
        // This will print the exact reason Google is denying you (e.g., Billing disabled)
        debugPrint(
          'Places API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception fetching Google Places: $e');
    }
  }

  // ---------------- HELPER TO ADD MARKERS ----------------

  void _addMarker(Mosque mosque, {required bool isFromFirestore}) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(mosque.id),
          position: LatLng(mosque.latitude, mosque.longitude),
          // Use custom mosque marker icon
          icon: _mosqueMarkerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(title: mosque.name),
          onTap: () {
            // Navigate to Authorized screen if user is logged in, otherwise General
            if (widget.isAuthorized) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MosqueDetailsScreenAuthorized(mosque: mosque),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MosqueDetailsScreenGeneral(mosque: mosque),
                ),
              );
            }
          },
        ),
      );
    });
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
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: userLocation!, zoom: 15),
        // Disable the built-in blue 'my location' dot so only our custom marker shows
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
      // Provide our own button to recenter the map on the user's custom marker
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (userLocation != null) {
            _mapController.animateCamera(
              CameraUpdate.newLatLngZoom(userLocation!, 15),
            );
          }
        },
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
