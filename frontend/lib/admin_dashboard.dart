import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_center.dart'; 
import 'admin_analytics.dart'; // Naya Import for Financials

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const CameraPosition _initialLocation = CameraPosition(
    target: LatLng(24.8607, 67.0011),
    zoom: 12.0,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchMarkers();
  }

  void _fetchMarkers() {
    FirebaseFirestore.instance.collection('MeterReadings').snapshots().listen((snapshot) {
      Set<Marker> tempMarkers = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('lat') && data.containsKey('lng')) {
          tempMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(
                (data['lat'] as num).toDouble(), 
                (data['lng'] as num).toDouble()
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                data['status'] == 'Theft' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure
              ),
              infoWindow: InfoWindow(
                title: "Meter: ${data['meterId'] ?? 'Unknown'}",
                snippet: "Load: ${data['currentLoad'] ?? '0'} kW",
              ),
            ),
          );
        }
      }
      if (mounted) {
        setState(() => _markers = tempMarkers);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("GridEye Admin", style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 18)),
        actions: [
          // Professional Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Switch Role',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/roleSelection');
            },
          ),
          IconButton(icon: const Icon(Icons.notifications_active, color: Colors.redAccent), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("System Overview", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // --- Stat Cards ---
            Row(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('MeterReadings').snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData ? snapshot.data!.docs.length.toString().padLeft(2, '0') : "--";
                    return _buildStatCard("Active Grids", count, Icons.bolt, Colors.greenAccent);
                  },
                ),
                const SizedBox(width: 15),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Alerts').snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData ? snapshot.data!.docs.length.toString().padLeft(2, '0') : "--";
                    return _buildStatCard("Theft Alerts", count, Icons.warning, Colors.redAccent);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 25), 

            // --- BUTTON 1: VIEW ALL ALERTS ---
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AlertCenter())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt_rounded, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text("VIEW ALL ALERTS", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- NEW BUTTON 2: FINANCIAL ANALYTICS ---
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminAnalytics())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00E5FF).withOpacity(0.1), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics_outlined, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 10),
                    Text(
                      "VIEW SYSTEM FINANCIALS", 
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF00E5FF), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 1.1
                      )
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text("Live Geospatial Feed", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 10),
            
            // --- Map Section ---
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3))),
                  child: GoogleMap(
                    initialCameraPosition: _initialLocation,
                    mapType: MapType.normal,
                    onMapCreated: (GoogleMapController controller) {},
                    markers: _markers,
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}