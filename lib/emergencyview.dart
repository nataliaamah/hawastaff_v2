import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffEmergencyViewPage extends StatelessWidget {
  final DocumentSnapshot emergencyData;

  StaffEmergencyViewPage({required this.emergencyData});

  void _openInGoogleMaps(double latitude, double longitude) async {
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  void _markAsResolved(BuildContext context) async {
    await FirebaseFirestore.instance.collection('staff_emergency').doc(emergencyData.id).update({
      'status': 'completed',
    });
    Navigator.pop(context);
  }

  void _assignToEmergency(BuildContext context) async {
    await FirebaseFirestore.instance.collection('staff_emergency').doc(emergencyData.id).update({
      'status': 'assigned',
      'assignedTo': FirebaseAuth.instance.currentUser!.uid,
      'assignedToName': FirebaseAuth.instance.currentUser!.displayName,
    });
    Navigator.pop(context);
  }

  Future<Map<String, dynamic>> _fetchUserDetails(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc.data() as Map<String, dynamic> : {};
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
    final Map<String, dynamic>? data = emergencyData.data() as Map<String, dynamic>?;
    final String userId = data?['userId'] ?? ''; // Ensure userId field exists
    final GeoPoint location = data?['location'] ?? GeoPoint(0, 0);
    final double latitude = location.latitude;
    final double longitude = location.longitude;
    final String assignedTo = data?['assignedTo'] ?? '';

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
                            child: GoogleMap(
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
                              onTap: (_) => _openInGoogleMaps(latitude, longitude),
                            ),
                          ),
                        ),
                        if (assignedTo.isEmpty) ...[
                          SizedBox(height: 20),
                          Center(
                          child: ElevatedButton(
                            onPressed: () => _assignToEmergency(context),
                            child: Text('Assign to Emergency'),
                          ),
                          ),
                        ] else ...[
                          SizedBox(height: 20),
                          Center(
                          child : Text(
                            'Assigned to: ${data?['assignedToName'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
