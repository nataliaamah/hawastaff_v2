import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'staff_login_page.dart'; // Import your login screen here

class StaffProfileOverlay extends StatelessWidget {
  final String staffId;
  final String staffName;

  StaffProfileOverlay({required this.staffId, required this.staffName});

  Future<Map<String, dynamic>> _getStaffDetails() async {
    try {
      final staffSnapshot = await FirebaseFirestore.instance.collection('staff').doc(staffId).get();
      if (staffSnapshot.exists) {
        return staffSnapshot.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching staff details: $e');
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getStaffDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Error fetching staff details'));
        }
        final staffData = snapshot.data!;
        return AlertDialog(
          title: Text('Staff Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${staffData['name']}'),
              Text('Staff Code: ${staffData['staffNumber']}'),
              Text('Position: ${staffData['position']}'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Add your logout logic here
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => StaffLoginPage()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text('Logout'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
