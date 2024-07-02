import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'emergencyview.dart';
import 'viewcompleted.dart';
import 'fcm_service.dart';
import 'staffprofileoverlay.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late String staffName;

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

  final Map<String, dynamic> serviceAccountKey = {
    "type": "service_account",
    "project_id": "hawa-24",
    "private_key_id": "f7a5778be61ef25c70490a78baf00b840709a1be",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDBohnaO5qp9stX\nYyWEp1jACqNtJorWu9k1ZKDADg/3mnEZoKQFyt+ti1TMAya6inszbjzxj6tVSvhe\ncTV1ujfS9BgBwA/XFJ9IOSgE+is5FP2bzgGrUreCRp1vwYLO7rBIz79P6Vr/6irw\nwJ7gADBHSO22NI17h7ddPBT//Rsq7hXecTjOPkHPBoLEmMovrwVtg63p4mySdrgE\nBWcUaSzHgEOFvbqNUjMtdTFd/4s3AZckXbKITba25Y1m8OPx+tm3Z4afhVTG7m2L\nxQb+EyvgO4YKimN80CcEjP0DFdqVpvJ+ZKXg5q+IUa68gDh9ji3zIAefbx6Dd5qz\n7Ujml9FNAgMBAAECggEAFbMlY4wXdqG2QwpU64tXiloG25YcrBjsLCwlSbCpwG1Z\n7G3Qw+dq7sd1DtHxlqkrSmW5xbZ8lHfs4qScQZ/HXshFInkULV3dxdnF7tzcWC7O\nhxXsoPcJortoLFyK3MbqEZbakUmNDa3/9vAXPfI3dt2o6ij0jBn3BidUESYb09Ed\nztrv4ai4Q0tNMkkCczSv+yUt8FMBgwvTIXWm6m/5DZoyYcMt88Uaj+tx5m1shjon\nQUH1q14ddOvbBiCs2oQ5UQjmTBbGU7J69T1mnHc996ePKjNcfb7J2jO2blhBR1mh\n3eTdikpssvollDEb36GDJ0OFd0nNwU1QB550xE6SDwKBgQDj1q33oKoPZBCktL9L\nCq5d2aVGzrIDQTB1YgHyQLS/1Ex9bYq03JBDPwDlanORv5fznU222LxpQU1ogDuN\nUf86EhtqQTwRIB89o3KtQYo38c/J+ob51yQcXNfneGdPtWDVTdmkH2vccRp/BUqA\nbub9c8E1EM83HZ0f9sUzTpXtcwKBgQDZkRY9D8p4cWyI+bEA0Z9HHpKa/T/tk6nW\ndvlRTjpBbf3D1I8fLAYfF0DEsnEeniGpZ2fbkm97HpUzYmw+9+wDkaGIBYFiqDFf\nAfsKmbyB2eg6qv/rnxv+6LGyz2BkGFfHSTr60GHH58O02pUHzKg+HdrHp2FjXA55\nGmElyuuWPwKBgQC2axQux7xhRkTtGqpucsbY7YGfB68PXApocWgNhjExxdDYO/Rq\nio4WyUL2bBzL/RK0QqYOV8nCnD5WBRWpOJWY8RZyJHjrXUSmHU+b2HXKBRnRJX0c\nXFzVOKDE+2n8L8SwA/zVozLA9O259YqI+kKHez6eNi8yectr5DBPvAPecQKBgCLU\ns3a7HHMD1ZhoQQochR9hqZ7ehGmIhlwrV+bIW1M2RLYhRXh8F87KbjgPSUTZlBIG\n1/2zB93yG3jKfQHntwUrP20DVJ9yxdSsAIDF9APl2uPplGcoZdb9cdVqlcfwjbz9\n4E9fJQhX9mDxzYIeJaEsLmZgSZsalcaVjo/6WJUJAoGBALCt+cfvMuPKLuMbFRpr\nJX6c8To4Ey0mJ/977/YjeWfjl4dug9KgUSwZ7RwEswTcNqK3psNmt+dQVTC4Bi6P\nkzbAhcUIH35auBcaxMI/Hg4HkUgzQaYaJdmK1S6p3ATzpKxgr96b7aA+XCP8pujc\ngc4otDfF0Vf5RlAB2N+iDcrS\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-2qfvg@hawa-24.iam.gserviceaccount.com",
    "client_id": "110037181356922537592",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-2qfvg@hawa-24.iam.gserviceaccount.com"
  };

  late final FCMService fcmService;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndData();
    staffName = widget.fullName; // Initialize staffName with the value passed to the widget
    fcmService = FCMService(projectId: 'hawa-24', serviceAccountKey: serviceAccountKey); // Initialize FCMService

    _firebaseMessaging.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: Text(notification.title ?? 'New Emergency'),
              content: Text(notification.body ?? 'An emergency has been reported.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    });

    _firebaseMessaging.getToken().then((String? token) {
      assert(token != null);
      print("FCM Token: $token");
      saveTokenToDatabase(token);
    });
  }

  void saveTokenToDatabase(String? token) async {
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('user_tokens')
          .doc(widget.userId)
          .set({
        'token': token,
      });
    }
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
          return _isWithinRange(emergencyLocation, _staffLocation!) 
                 && data['status'] == 'unresolved' 
                 && data['assignedTo'] == null
                 && (data['retracted'] == null || data['retracted'] == false); // Filter out retracted = true
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
          _sendPushNotification(unresolvedDocs.first);
        } else if (unresolvedDocs.isEmpty && _isVibrating) {
          _stopVibrating();
        }
      });
    });
  } catch (e) {
    print('Error initializing location and data: $e');
  }
}


  void _sendPushNotification(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null) {
      final payload = {
        'notification': {
          'title': 'New Emergency',
          'body': 'An emergency has been reported at ${data['location']}.',
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'id': '1',
          'status': 'done'
        }
      };

      try {
        final tokens = await FirebaseFirestore.instance.collection('user_tokens').get();

        for (var tokenDoc in tokens.docs) {
          final token = tokenDoc.data()['token'];
          if (token != null) {
            payload['token'] = token;
            await fcmService.sendPushNotification(payload);
          }
        }
      } catch (e) {
        print('Error sending FCM request: $e');
      }
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

    final cardColor = isCompleted
        ? _getRandomColor(_greenColors)
        : isAssigned
            ? _getRandomColor(_yellowOrangeColors)
            : _getRandomColor(_redColors);

    final IconData categoryIcon = isCompleted
        ? Icons.check_circle
        : isAssigned
            ? Icons.assignment
            : Icons.warning;

    final Color iconColor = isCompleted
        ? Colors.green
        : isAssigned
            ? Colors.orange
            : Colors.red;

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
        width: 250, // Fixed width
        height: 350, // Adjusted height
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
                    _formatTimestamp(data['timestamp']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                  Icon(
                    categoryIcon,
                    color: iconColor,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(
                      'Completed On: ${_formatTimestamp(data['completedAt'])}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ],
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_pin, color: Colors.red),
              SizedBox(width: 5),
              Text(
                _currentLocation,
                style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.person, color: Colors.orange),
              SizedBox(width: 5),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return StaffProfileOverlay(staffId: widget.userId, staffName: staffName);
                    },
                  );
                },
                child: Text(
                  staffName,
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Color.fromRGBO(226, 192, 68, 1),
                    decorationThickness: 2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Center(
            child : Text(
            'Emergency Alerts',
            style: GoogleFonts.quicksand(
              textStyle: TextStyle(
                fontSize: 27,
                color: const Color.fromRGBO(226, 192, 68, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              painter: PersonalInfoPainter(),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(
                          'New Emergencies',
                          style: TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 1),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        height: 250.0, // Adjusted height for new emergencies
                        child: unresolvedDocs.isEmpty
                            ? Center(
                                child: Text(
                                  'No new emergencies',
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 91, 91, 91),
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : ListView(
                                scrollDirection: Axis.horizontal,
                                children: unresolvedDocs.map((doc) {
                                  return _buildEmergencyCard(doc, false, false);
                                }).toList(),
                              ),
                      ),
                      Divider(
                        height: 10,
                        thickness: 0.5,
                        color: const Color.fromARGB(255, 91, 91, 91),
                        indent: 30,
                        endIndent: 30,
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(
                          'In Investigation',
                          style: TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 1),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        height: 240.0, // Adjusted height for in investigation
                        child: assignedDocs.isEmpty
                            ? Center(
                                child: Text(
                                  'No emergencies in investigation',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 91, 91, 91),
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : ListView(
                                scrollDirection: Axis.horizontal,
                                children: assignedDocs.map((doc) {
                                  return _buildEmergencyCard(doc, true, false);
                                }).toList(),
                              ),
                      ),
                      Divider(
                        height: 10,
                        thickness: 0.5,
                        color: const Color.fromARGB(255, 91, 91, 91),
                        indent: 30,
                        endIndent: 30,
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              'Completed',
                              style: TextStyle(
                                color: Color.fromRGBO(255, 255, 255, 1),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (completedDocs.length > 5)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewCompletedPage(
                                      userId: widget.userId,
                                      fullName: staffName,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'See More',
                                style: TextStyle(
                                  color: Color.fromRGBO(226, 192, 68, 1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Container(
                        height: 280.0, // Adjusted height for completed
                        child: completedDocs.isEmpty
                            ? Center(
                                child: Text(
                                  'No completed emergencies',
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 91, 91, 91),
                                    fontSize: 18,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalInfoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(43, 43, 45, 1)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = Radius.circular(40);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius,
      topRight: radius,
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
