import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc; // Use 'loc' as a prefix for the location package
import 'package:geocoding/geocoding.dart'; // Import geocoding package
import 'emergencyview.dart'; // Import the view page

class StaffMainPage extends StatefulWidget {
  final String userId;
  final String fullName;
  final bool isAuthenticated;

  StaffMainPage({
    required this.userId,
    required this.fullName,
    required this.isAuthenticated,
  });

  @override
  _StaffMainPageState createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage> {
  bool _isVibrating = false;
  late StreamSubscription _subscription;
  Timer? _vibrationTimer;
  List<DocumentSnapshot> emergencyDocs = [];
  String _currentLocation = 'Fetching...'; // Placeholder for the current location

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('staff_emergency')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        emergencyDocs = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          return data['resolved'] == false;
        }).toList();
        emergencyDocs.sort((a, b) {
          Timestamp aTimestamp = a['timestamp'];
          Timestamp bTimestamp = b['timestamp'];
          return bTimestamp.compareTo(aTimestamp);
        });
      });

      if (emergencyDocs.isNotEmpty && !_isVibrating) {
        _startVibrating();
      } else if (emergencyDocs.isEmpty && _isVibrating) {
        _stopVibrating();
      }
    });

    // Fetch the current location
    _getCurrentLocation().then((location) {
      _convertCoordinatesToAddress(location.latitude!, location.longitude!);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  Future<loc.LocationData> _getCurrentLocation() async {
    loc.Location location = new loc.Location();

    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        throw Exception('Location service not enabled');
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    }

    _locationData = await location.getLocation();
    return _locationData;
  }

  void _convertCoordinatesToAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];
      setState(() {
        _currentLocation = '${place.subLocality}, ${place.locality}';
      });
    } catch (e) {
      print('Error occurred while converting coordinates to address: $e');
      setState(() {
        _currentLocation = 'Unknown location';
      });
    }
  }

  void _startVibrating() {
    _isVibrating = true;
    _vibrate();
  }

  void _vibrate() async {
    if (_isVibrating) {
      try {
        if (await Vibrate.canVibrate) {
          _vibrationTimer = Timer.periodic(Duration(seconds: 2), (_) {
            Vibrate.vibrateWithPauses([
              Duration(milliseconds: 1500),
              Duration(milliseconds: 500)
            ]);
          });
        }
      } catch (e) {
        print('Error while vibrating: $e');
      }
    }
  }

  void _stopVibrating() {
    _isVibrating = false;
    _vibrationTimer?.cancel();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Unknown Time';
    }
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (date.year != now.year) {
      return DateFormat('d/MM/yyyy').format(date);
    }
    return DateFormat('d/MM').format(date);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Unknown Time';
    }
    final date = timestamp.toDate();
    return DateFormat('h:mm a').format(date);
  }

  Widget _buildEmergencyList(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No new emergencies',
          style: TextStyle(color: Colors.black, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>?;
        if (data == null) return SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StaffEmergencyViewPage(emergencyData: docs[index]),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(248, 51, 60, 0.6),
                  spreadRadius: 10,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(data['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                      Icon(
                        Icons.warning,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(data['userId']).get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                        return Text(
                          'Unknown User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        );
                      }
                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      return Text(
                        userData['fullName'] ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Emergency',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Image.asset(
          'assets/hawa_name.png',
          height: 200,
          width: 200,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_pin, color: Colors.red),
                Text(
                  _currentLocation, // Placeholder for user location
                  style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.fullName, // Placeholder for user name
                  style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Emergency Alerts',
              style: GoogleFonts.quicksand(
                textStyle: TextStyle(fontSize: 27, color: const Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'New Emergencies',
              style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(child: _buildEmergencyList(emergencyDocs)),
          ],
        ),
      ),
    );
  }
}
