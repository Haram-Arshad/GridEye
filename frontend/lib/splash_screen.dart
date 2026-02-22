import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 seconds ka pakka timer
    Timer(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Force background color taake black screen ka sawal hi paida na ho
      backgroundColor: Color(0xFF0D1B2A), 
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: Color(0xFF0D1B2A)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo load karne ki koshish, agar error aaye toh Bolt Icon dikhaye
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.bolt, size: 100, color: Color(0xFF00E5FF));
              },
            ),
            SizedBox(height: 30),
            Text(
              "GridEye",
              style: GoogleFonts.orbitron(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
            ),
          ],
        ),
      ),
    );
  }
}