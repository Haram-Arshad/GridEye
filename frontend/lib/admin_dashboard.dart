import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const CameraPosition _initialLocation = CameraPosition(
    target: LatLng(24.8607, 67.0011),
    zoom: 12.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("GridEye Admin", style: GoogleFonts.orbitron(color: Color(0xFF00E5FF))),
        actions: [
          IconButton(icon: Icon(Icons.notifications_active, color: Colors.redAccent), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("System Overview", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            
            Row(
              children: [
                // --- LIVE ACTIVE GRIDS ---
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('MeterReadings').snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData ? snapshot.data!.docs.length.toString().padLeft(2, '0') : "--";
                    return _buildStatCard("Active Grids", count, Icons.bolt, Colors.greenAccent);
                  },
                ),
                SizedBox(width: 15),
                
                // --- LIVE THEFT ALERTS ---
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Alerts').snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData ? snapshot.data!.docs.length.toString().padLeft(2, '0') : "--";
                    return _buildStatCard("Theft Alerts", count, Icons.warning, Colors.redAccent);
                  },
                ),
              ],
            ),
            
            SizedBox(height: 30),
            Text("Live Geospatial Feed", style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 10),
            
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.3)),
                  ),
                  child: GoogleMap(
                    initialCameraPosition: _initialLocation,
                    mapType: MapType.normal,
                    onMapCreated: (GoogleMapController controller) {},
                    markers: {
                      Marker(
                        markerId: MarkerId('grid_1'),
                        position: LatLng(24.8607, 67.0011),
                        infoWindow: InfoWindow(title: "Transformer 01", snippet: "Load: 85%"),
                      ),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}