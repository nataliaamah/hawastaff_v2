import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staffmain.dart'; // Import the staff main page
import 'package:google_fonts/google_fonts.dart';

class StaffSignupPage extends StatefulWidget {
  @override
  _StaffSignupPageState createState() => _StaffSignupPageState();
}

class _StaffSignupPageState extends State<StaffSignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _staffNumberController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _staffCodeController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _showStaffCodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Staff Code'),
          content: TextField(
            controller: _staffCodeController,
            decoration: InputDecoration(
              hintText: 'Enter staff code',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _verifyStaffCodeAndSignup();
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyStaffCodeAndSignup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Verify the staff code
      String enteredCode = _staffCodeController.text.trim();
      DocumentSnapshot staffCodeDoc = await FirebaseFirestore.instance
          .collection('staff_code')
          .doc('police')
          .get();

      if (!staffCodeDoc.exists || staffCodeDoc['code'] != enteredCode) {
        throw FirebaseAuthException(
            message: "Invalid staff code", code: "invalid-staff-code");
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('staff')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'staffNumber': _staffNumberController.text.trim(),
        'position': _positionController.text.trim(),
        'email': _emailController.text.trim(),
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StaffMainPage(
            userId: userCredential.user!.uid,
            fullName: _nameController.text.trim(),
            isAuthenticated: true,
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
      appBar: AppBar(
        title: Image.asset(
          'assets/hawa_name.png',
          height: 300,
          width: 200,
        ),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                "Sign Up",
                style: GoogleFonts.quicksand(
                  textStyle: TextStyle(
                      fontSize: 27,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(height: 48.0),
              TextField(
                controller: _nameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Color.fromRGBO(255, 255, 255, 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.person, color: Color.fromRGBO(226, 192, 68, 1)),
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                controller: _staffNumberController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Staff Number',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Color.fromRGBO(255, 255, 255, 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.badge, color: Color.fromRGBO(226, 192, 68, 1)),
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                controller: _positionController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Position',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Color.fromRGBO(255, 255, 255, 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.work, color: Color.fromRGBO(226, 192, 68, 1)),
                ),
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
                  prefixIcon:
                      Icon(Icons.email, color: Color.fromRGBO(226, 192, 68, 1)),
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
                  prefixIcon:
                      Icon(Icons.lock, color: Color.fromRGBO(226, 192, 68, 1)),
                ),
              ),
              SizedBox(height: 24.0),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _showStaffCodeDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(226, 192, 68, 1),
                        padding: EdgeInsets.symmetric(
                            horizontal: 100, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text('Sign Up',
                          style: TextStyle(color: Colors.white)),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  "Already have an account? Login",
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
