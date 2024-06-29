import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'emergencyview.dart';
import 'viewcompleted.dart';

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
  List<DocumentSnapshot> unresolvedDocs = [];
  List<DocumentSnapshot> assignedDocs = [];
  List<DocumentSnapshot> completedDocs = [];
  String _currentLocation = 'Fetching...';
  loc.LocationData? _staffLocation;

  final List<Color> _redColors = [
    Colors.red.shade100,
    Colors.red.shade200,
    Colors.red.shade300,
    Colors.red.shade400,
    Colors.red.shade500,
  ];

  final List<Color> _yellowOrangeColors = [
    Colors.orange.shade100,
    Colors.orange.shade200,
    Colors.orange.shade300,
    Colors.orange.shade400,
    Colors.orange.shade500,
  ];

  final List<Color> _greenColors = [
    Colors.green.shade100,
    Colors.green.shade200,
    Colors.green.shade300,
    Colors.green.shade400,
    Colors.green.shade500,
  ];

  final double _range = 10.0; // Range in kilometers

  @override
  void initState() {
    super.initState();
    _initializeLocationAndData();
  }

  void _initializeLocationAndData() async {
    try {
      _staffLocation = await _getCurrentLocation();
      _convertCoordinatesToAddress(_staffLocation!.latitude!, _staffLocation!.longitude!);

      _subscription = FirebaseFirestore.instance
          .collection('staff_emergency')
          .snapshots()
          .listen((snapshot) {
        setState(() {
          unresolvedDocs = snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data['location'] == null) return false;
            final GeoPoint emergencyLocation = data['location'];
            return _isWithinRange(emergencyLocation, _staffLocation!) && data['status'] == 'unresolved' && data['assignedTo'] == null;
          }).toList();

          assignedDocs = snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data['location'] == null) return false;
            final GeoPoint emergencyLocation = data['location'];
            return _isWithinRange(emergencyLocation, _staffLocation!) && data['status'] == 'assigned';
          }).toList();

          completedDocs = snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null || data['location'] == null) return false;
            final GeoPoint emergencyLocation = data['location'];
            return _isWithinRange(emergencyLocation, _staffLocation!) && data['status'] == 'completed';
          }).toList();

          unresolvedDocs.sort((a, b) {
            Timestamp aTimestamp = a['timestamp'];
            Timestamp bTimestamp = b['timestamp'];
            return bTimestamp.compareTo(aTimestamp);
          });
          assignedDocs.sort((a, b) {
            Timestamp aTimestamp = a['timestamp'];
            Timestamp bTimestamp = b['timestamp'];
            return bTimestamp.compareTo(aTimestamp);
          });
          completedDocs.sort((a, b) {
            Timestamp aTimestamp = a['timestamp'];
            Timestamp bTimestamp = b['timestamp'];
            return bTimestamp.compareTo(aTimestamp);
          });

          if (unresolvedDocs.isNotEmpty && !_isVibrating) {
            _startVibrating();
          } else if (unresolvedDocs.isEmpty && _isVibrating) {
            _stopVibrating();
          }
        });
      });
    } catch (e) {
      print('Error initializing location and data: $e');
    }
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
        _currentLocation = '${place.street},\n${place.locality}';
      });
    } catch (e) {
      print('Error occurred while converting coordinates to address: $e');
      setState(() {
        _currentLocation = 'Unknown location';
      });
    }
  }

  Future<String> _convertGeoPointToAddress(GeoPoint geoPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(geoPoint.latitude, geoPoint.longitude);
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      print('Error occurred while converting geopoint to address: $e');
      return 'Unknown location';
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
    return DateFormat('d/MM/yyyy').format(date) + ' ' + DateFormat('h:mm a').format(date);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Unknown Time';
    }
    final date = timestamp.toDate();
    return DateFormat('h:mm a').format(date);
  }

  Color _getRandomColor(List<Color> colorSet) {
    final random = Random();
    return colorSet[random.nextInt(colorSet.length)];
  }

  bool _isWithinRange(GeoPoint emergencyLocation, loc.LocationData staffLocation) {
    const double earthRadius = 6371.0; // Radius of the Earth in kilometers
    double dLat = _degreesToRadians(emergencyLocation.latitude - staffLocation.latitude!);
    double dLon = _degreesToRadians(emergencyLocation.longitude - staffLocation.longitude!);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(staffLocation.latitude!)) * cos(_degreesToRadians(emergencyLocation.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance <= _range;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<String> _getStaffDetails(String staffId) async {
    try {
      final staffSnapshot = await FirebaseFirestore.instance.collection('staff').doc(staffId).get();
      if (staffSnapshot.exists) {
        final staffData = staffSnapshot.data() as Map<String, dynamic>;
        return '${staffData['name']} (Code: ${staffData['staffNumber']}, Position: ${staffData['position']})';
      }
      return 'Unknown Staff';
    } catch (e) {
      print('Error fetching staff details: $e');
      return 'Unknown Staff';
    }
  }

  void _assignToEmergency(BuildContext context, DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('staff_emergency').doc(doc.id).update({
      'assignedTo': widget.userId,
      'assignedToName': widget.fullName,
      'status': 'assigned',
    });
    setState(() {});
  }

  Widget _buildEmergencyCard(DocumentSnapshot doc, bool isAssigned, bool isCompleted) {
  final data = doc.data() as Map<String, dynamic>?;
  if (data == null) return SizedBox.shrink();

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StaffEmergencyViewPage(emergencyData: doc),
        ),
      );
    },
    child: Container(
      width: 250,  // Fixed width
      height: 350,  // Adjusted height
      margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(16.0),
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
                  _formatTimestamp(data['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
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
            FutureBuilder<String>(
              future: _convertGeoPointToAddress(data['location']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text(
                    'Fetching location...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'Unknown location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  );
                }
                return Text(
                  snapshot.data ?? 'Unknown location',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            SizedBox(height: 20),
            if (!isAssigned && !isCompleted)
              Center(
                child: ElevatedButton(
                  onPressed: () => _assignToEmergency(context, doc),
                  child: Text('Assign to Emergency', style: TextStyle(color: Colors.black)),
                ),
              ),
            if (isAssigned)
              FutureBuilder<String>(
                future: _getStaffDetails(data['assignedTo']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Assigned to: Unknown Staff',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  return Text(
                    'Assigned to: ${snapshot.data}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  );
                },
              ),
            if (isCompleted)
              FutureBuilder<String>(
                future: data['completedBy'] != null ? _getStaffDetails(data['completedBy']) : Future.value('Unknown Staff'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Completed by: Unknown Staff',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  return Text(
                    'Completed by: ${snapshot.data}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_pin, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    _currentLocation,
                    style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.fullName,
                    style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Emergency Alerts',
                style: GoogleFonts.quicksand(
                  textStyle: TextStyle(fontSize: 27, color: const Color.fromRGBO(226, 192, 68, 1), fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'New Emergencies',
                style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                height: 250.0, // Adjusted height for new emergencies
                child: unresolvedDocs.isEmpty
                    ? Center(
                        child: Text(
                          'No new emergencies',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: unresolvedDocs.map((doc) {
                          return _buildEmergencyCard(doc, false, false);
                        }).toList(),
                      ),
              ),
              SizedBox(height: 20),
              Text(
                'In Investigation',
                style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                height: 240.0, // Adjusted height for in investigation
                child: assignedDocs.isEmpty
                    ? Center(
                        child: Text(
                          'No emergencies in investigation',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: assignedDocs.map((doc) {
                          return _buildEmergencyCard(doc, true, false);
                        }).toList(),
                      ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Completed',
                    style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewCompletedPage(
                            userId: widget.userId,
                            fullName: widget.fullName,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'See More',
                      style: TextStyle(color: Color.fromRGBO(226, 192, 68, 1), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Container(
                height: 250.0, // Adjusted height for completed
                child: completedDocs.isEmpty
                    ? Center(
                        child: Text(
                          'No completed emergencies',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: completedDocs.take(5).map((doc) {
                          return _buildEmergencyCard(doc, false, true);
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
