import 'package:flutter/material.dart';

void main() {
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
            'GridEye Initialized',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}