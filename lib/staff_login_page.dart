import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'staff_signup_page.dart'; // Import the staff signup page
import 'staffmain.dart'; // Import the staff main page
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffLoginPage extends StatefulWidget {
  @override
  _StaffLoginPageState createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _staffCodeController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isLoggedIn = prefs.getBool('isLoggedIn');
    String? userId = prefs.getString('userId');
    String? fullName = prefs.getString('fullName');

    if (isLoggedIn != null && isLoggedIn && userId != null && fullName != null) {
      // Request staff code
      _verifyStaffCode(userId, fullName);
    }
  }

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Fetch the staff data
      DocumentSnapshot staffDoc = await FirebaseFirestore.instance
          .collection('staff')
          .doc(userCredential.user!.uid)
          .get();
      String fullName = staffDoc['name'];

      // Request staff code
      _verifyStaffCode(userCredential.user!.uid, fullName);
      
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Error occurred")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyStaffCode(String userId, String fullName) async {
    bool verified = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog by tapping outside
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Staff Code'),
          content: TextField(
            controller: _staffCodeController,
            decoration: InputDecoration(
              labelText: 'Staff Code',
              labelStyle: TextStyle(color: Colors.black),
              filled: true,
              fillColor: Color.fromRGBO(255, 255, 255, 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              prefixIcon: Icon(Icons.code, color: Color.fromRGBO(226, 192, 68, 1)), // Yellow code icon
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String enteredCode = _staffCodeController.text.trim();
                DocumentSnapshot staffCodeDoc = await FirebaseFirestore.instance
                    .collection('staff_code')
                    .doc('police')
                    .get();

                if (staffCodeDoc.exists && staffCodeDoc['code'] == enteredCode) {
                  // Staff code is valid
                  verified = true;
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Invalid staff code")),
                  );
                }
              },
              child: Text('Submit', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );

    if (verified) {
      // Save login status to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('fullName', fullName);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StaffMainPage(
            userId: userId,
            fullName: fullName,
            isAuthenticated: true,
          ),
        ),
      );
    } else {
      _auth.signOut(); // Sign out the user if the staff code verification fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Column(
                children: [
                  Image.asset("assets/2.png", height: 200, width: 300),
                  Text("Hawa staff", style: GoogleFonts.quicksand(textStyle: TextStyle(fontSize: 27, color: const Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.w700),))
                ]
              ),
              SizedBox(height: 40.0),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Color.fromRGBO(255, 255, 255, 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.email, color: Color.fromRGBO(226, 192, 68, 1)), // Yellow email icon
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Color.fromRGBO(255, 255, 255, 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.lock, color: Color.fromRGBO(226, 192, 68, 1)), // Yellow lock icon
                ),
              ),
              SizedBox(height: 24.0),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(226, 192, 68, 1),
                        padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text('Login', style: TextStyle(color: Colors.white)),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StaffSignupPage()),
                  );
                },
                child: Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
