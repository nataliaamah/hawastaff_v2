import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'staff_login_page.dart'; // Import your login page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StaffLoginPage(),
    );
  }
}
