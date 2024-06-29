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

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('staff_emergency')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        unresolvedDocs = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          return data['status'] == 'unresolved' && data['assignedTo'] == null;
        }).toList();

        assignedDocs = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          return data['status'] == 'assigned';
        }).toList();

        completedDocs = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          return data['status'] == 'resolved';
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
      });

      if (unresolvedDocs.isNotEmpty && !_isVibrating) {
        _startVibrating();
      } else if (unresolvedDocs.isEmpty && _isVibrating) {
        _stopVibrating();
      }
    });

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

  Color _getRandomColor(List<Color> colorSet) {
    final random = Random();
    return colorSet[random.nextInt(colorSet.length)];
  }

  Widget _buildEmergencyList(List<DocumentSnapshot> docs, bool isAssigned, bool isCompleted) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No emergencies',
          style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      shrinkWrap: true,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>?;
        if (data == null) return SizedBox.shrink();

        Color cardColor;
        if (isAssigned) {
          cardColor = _getRandomColor(_yellowOrangeColors);
        } else if (isCompleted) {
          cardColor = _getRandomColor(_greenColors);
        } else {
          cardColor = _getRandomColor(_redColors);
        }

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
            width: 250,  // Fixed width
            height: 300,  // Adjusted height
            margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: cardColor,
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
                        _formatTime(data['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                      if (!isCompleted)
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
                      child : ElevatedButton(
                      onPressed: () => _assignToEmergency(context, docs[index]),
                      child: Text('Assign to Emergency', style: TextStyle(color: Colors.black),),
                    ),
                    ),
                  if (isAssigned)
                    Text(
                      'Assigned to: ${data['assignedToName'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _assignToEmergency(BuildContext context, DocumentSnapshot emergencyDoc) async {
    await FirebaseFirestore.instance.collection('staff_emergency').doc(emergencyDoc.id).update({
      'assignedTo': widget.userId,
      'assignedToName': widget.fullName,
      'status': 'assigned',
    });
    setState(() {});
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
                  textStyle: TextStyle(fontSize: 27, color: const Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'New Emergencies',
                style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                height: 250.0,  // Adjusted height for new emergencies
                child: _buildEmergencyList(unresolvedDocs, false, false),
              ),
              SizedBox(height: 20),
              Text(
                'In Investigation',
                style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                height: 240.0,  // Adjusted height for in investigation
                child: _buildEmergencyList(assignedDocs, true, false),
              ),
              SizedBox(height: 20),
              Text(
                'Completed',
                style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                height: 300.0,  // Adjusted height for completed
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: completedDocs.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 250,  // Fixed width
                      child: _buildEmergencyList([completedDocs[index]], false, true),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
