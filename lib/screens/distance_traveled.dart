import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added this

class DistanceTraveledScreen extends StatefulWidget {
  const DistanceTraveledScreen({super.key});

  @override
  State<DistanceTraveledScreen> createState() => _DistanceTraveledScreenState();
}

class _DistanceTraveledScreenState extends State<DistanceTraveledScreen> {
  double totalDistance = 0.0;
  Position? lastPosition;
  String userCity = "Locating...";
  StreamSubscription<Position>? positionStream;

  @override
  void initState() {
    super.initState();
    _loadPersistedDistance(); // Load saved data first
    _initLocationTracking();
  }

  // --- Persistence Logic ---
  
  Future<void> _loadPersistedDistance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Retrieve the saved distance, default to 0.0 if not found
      totalDistance = prefs.getDouble('total_distance') ?? 0.0;
    });
  }

  Future<void> _saveDistance(double distance) async {
    print("coming to save distance: $distance");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_distance', distance);
  }

  Future<void> _resetDistance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('total_distance');
    setState(() {
      totalDistance = 0.0;
    });
  }

  // --- Location Logic ---

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.whileInUse) {
      await _showPermissionDialog();
      await Geolocator.openAppSettings();
      permission = await Geolocator.checkPermission();
    }

    if (permission == LocationPermission.always) {
      _updateCityName();
      _startTracking();
    }
  }

  Future<void> _showPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Background Access Required"),
        content: const Text("Please select 'Allow all the time' to track distance while your screen is off."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _updateCityName() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() {
          userCity = placemarks[0].locality ?? "Unknown";
        });
      }
    } catch (e) {
      debugPrint("City Error: $e");
    }
  }

  void _startTracking() {
    late LocationSettings locationSettings;

    if (Theme.of(context).platform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "Tracking your movement...",
            notificationTitle: "Distance Tracker Active",
            enableWakeLock: true,
          ));
    }
    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Drift filtering
      if (position.accuracy > 15) return;

      if (lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          lastPosition!.latitude, lastPosition!.longitude,
          position.latitude, position.longitude,
        );

        if (distance > 2.5) { 
          setState(() {
            totalDistance += distance;
          });
          _saveDistance(totalDistance); // PERSIST DATA HERE
          lastPosition = position;
        }
      } else {
        lastPosition = position;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.green[300]),
        title: const Text("Distance Traveled"),
        actions: [
          IconButton(
            color: Colors.green[300],
            icon: const Icon(Icons.refresh),
            onPressed: _resetDistance,
            tooltip: "Reset Distance",
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_walk, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              "Traveled ${totalDistance.toStringAsFixed(2)} meters",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Current City: $userCity", style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}