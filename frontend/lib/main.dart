import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // New Import

void main() async {
  // 1. Ensure Flutter is ready for native calls
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase (This uses your google-services.json)
  await Firebase.initializeApp(); 
  
  runApp(const GridEyeApp());
}

class GridEyeApp extends StatelessWidget {
  const GridEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'GridEye Initialized & Firebase Connected! 🚀',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}