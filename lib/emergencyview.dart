import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class StaffEmergencyViewPage extends StatefulWidget {
  final DocumentSnapshot emergencyData;

  StaffEmergencyViewPage({required this.emergencyData});

  @override
  _StaffEmergencyViewPageState createState() => _StaffEmergencyViewPageState();
}

class _StaffEmergencyViewPageState extends State<StaffEmergencyViewPage> {
  bool _isMapLoading = true;
  String _locationAddress = 'Fetching address...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _openInGoogleMaps(double latitude, double longitude) async {
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  void _markAsResolved(BuildContext context) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot staffDoc = await FirebaseFirestore.instance.collection('staff').doc(currentUser.uid).get();
      String staffName = staffDoc['name'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('staff_emergency').doc(widget.emergencyData.id).update({
        'status': 'completed',
        'completedBy': currentUser.uid,
        'completedByName': staffName,
        'completedAt': Timestamp.now(),
      });
      Navigator.pop(context);
    }
  }

  void _assignToEmergency(BuildContext context) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot staffDoc = await FirebaseFirestore.instance.collection('staff').doc(currentUser.uid).get();
      String staffName = staffDoc['fullName'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('staff_emergency').doc(widget.emergencyData.id).update({
        'status': 'assigned',
        'assignedTo': currentUser.uid,
        'assignedToName': staffName,
      });
      Navigator.pop(context);
    }
  }

  Future<Map<String, dynamic>> _fetchUserDetails(String userId) async {
    print('Fetching user details for userId: $userId');
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      print('User document exists: ${userDoc.exists}');
      print('User data: ${userDoc.data()}');
    } else {
      print('User document does not exist');
    }
    return userDoc.exists ? userDoc.data() as Map<String, dynamic> : {};
  }

  Future<Map<String, dynamic>> _fetchStaffDetails(String staffId) async {
    print('Fetching staff details for staffId: $staffId');
    DocumentSnapshot staffDoc = await FirebaseFirestore.instance.collection('staff').doc(staffId).get();
    if (staffDoc.exists) {
      print('Staff document exists: ${staffDoc.exists}');
      print('Staff data: ${staffDoc.data()}');
    } else {
      print('Staff document does not exist');
    }
    return staffDoc.exists ? staffDoc.data() as Map<String, dynamic> : {};
  }

  Future<String> _fetchAddress(double latitude, double longitude) async {
    final googleMapsUrl = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=AIzaSyBbgGgnpr_kbshLxOL7GuY28xqd7EtX1dw';
    final response = await http.get(Uri.parse(googleMapsUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }
    }
    return 'Unknown location';
  }

  void _initialize() async {
    final Map<String, dynamic>? data = widget.emergencyData.data() as Map<String, dynamic>?;
    if (data != null && data['location'] != null) {
      final GeoPoint location = data['location'];
      final double latitude = location.latitude;
      final double longitude = location.longitude;

      final address = await _fetchAddress(latitude, longitude);

      if (mounted) {
        setState(() {
          _locationAddress = address;
        });
      }
    }
  }

  int _calculateAge(String dateOfBirth) {
    if (dateOfBirth.isEmpty) {
      return -1; // Invalid age
    }
    final dob = DateFormat('dd/MM/yyyy').parse(dateOfBirth);
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? data = widget.emergencyData.data() as Map<String, dynamic>?;
    if (data == null) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
          elevation: 0,
          centerTitle: true,
          title: Image.asset(
            'assets/hawa_name.png',
            height: 200,
            width: 200,
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(child: Text('Invalid Emergency Data', style: TextStyle(color: Colors.white))),
      );
    }

    final String userId = data['userId'] ?? '';
    final GeoPoint location = data['location'] ?? GeoPoint(0, 0);
    final double latitude = location.latitude;
    final double longitude = location.longitude;
    final String assignedTo = data['assignedTo'] ?? '';
    final String assignedToName = data['assignedToName'] ?? 'Unknown';
    final String completedBy = data['completedBy'] ?? '';
    final String completedByName = data['completedByName'] ?? 'Unknown';

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (assignedTo == FirebaseAuth.instance.currentUser!.uid)
            IconButton(
              icon: Icon(Icons.check, color: Colors.white),
              onPressed: () => _markAsResolved(context),
            )
          else
            IconButton(
              icon: Icon(Icons.check, color: Colors.grey),
              onPressed: null,
            ),
        ],
      ),
      body: userId.isEmpty
          ? Center(child: Text('Invalid User ID', style: TextStyle(color: Colors.white)))
          : FutureBuilder<Map<String, dynamic>>(
              future: _fetchUserDetails(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final userDetails = snapshot.data!;
                final String senderName = userDetails['fullName'] ?? '-';
                final String age = userDetails['dateOfBirth'] != null
                    ? _calculateAge(userDetails['dateOfBirth']).toString()
                    : '-';
                final String bloodType = userDetails['bloodType'] ?? '-';
                final String phoneNumber = userDetails['phoneNumber'] ?? '-';
                final String medication = userDetails['medication'] ?? '-';
                final String allergies = userDetails['allergies'] ?? '-';

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            '$senderName\'s Emergency',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUserInfoRow('Full Name', senderName),
                              _buildUserInfoRow('Age', age),
                              _buildUserInfoRow('Phone Number', phoneNumber),
                              _buildUserInfoRow('Blood Type', bloodType),
                              _buildUserInfoRow('Medication', medication),
                              _buildUserInfoRow('Allergies', allergies),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Shared Location',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color.fromRGBO(226, 192, 68, 1),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: Container(
                            height: 200,
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(latitude, longitude),
                                    zoom: 14.0,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: MarkerId('emergencyLocation'),
                                      position: LatLng(latitude, longitude),
                                    ),
                                  },
                                  onMapCreated: (GoogleMapController controller) {
                                    setState(() {
                                      _isMapLoading = false;
                                    });
                                  },
                                  onTap: (_) => _openInGoogleMaps(latitude, longitude),
                                ),
                                if (_isMapLoading)
                                  Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          _locationAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        if (data['status'] == 'assigned') ...[
                          SizedBox(height: 20),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _fetchStaffDetails(assignedTo),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(child: Text('Error fetching staff details'));
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(child: Text('Assigned to: $assignedToName (Code: Unknown, Position: Unknown)'));
                              }

                              final staffDetails = snapshot.data!;
                              final String staffCode = staffDetails['staffNumber'] ?? 'Unknown';
                              final String position = staffDetails['position'] ?? 'Unknown';

                              return Center(
                                child: Text(
                                  'Assigned to: $assignedToName (Code: $staffCode, Position: $position)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ] else if (data['status'] == 'completed') ...[
                          SizedBox(height: 20),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _fetchStaffDetails(completedBy),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(child: Text('Error fetching staff details'));
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(child: Text('Completed by: $completedByName (Code: Unknown, Position: Unknown)'));
                              }

                              final staffDetails = snapshot.data!;
                              final String staffCode = staffDetails['staffNumber'] ?? 'Unknown';
                              final String position = staffDetails['position'] ?? 'Unknown';

                              return Center(
                                child: Text(
                                  'Completed by: $completedByName (Code: $staffCode, Position: $position)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ] else if (assignedTo.isEmpty) ...[
                          SizedBox(height: 20),
                          Center(
                            child: ElevatedButton(
                              onPressed: () => _assignToEmergency(context),
                              child: Text('Assign to Emergency'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
