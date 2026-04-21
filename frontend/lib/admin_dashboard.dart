import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_center.dart'; 
import 'admin_analytics.dart'; 
import 'profile_screen.dart';

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
        centerTitle: false, // Consistency with Profile Screen
        title: Text("GridEye Admin", style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 18)),
        actions: [
          // 1. Profile Button
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white70),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
            },
          ),
          // 2. Notifications Button (LOGIC: Recent/Unread Alerts Only)
        // Purana IconButton hata kar ye StreamBuilder wala logic paste karein
StreamBuilder<QuerySnapshot>(
 // Firestore se wo alerts dhoond raha hai jo abhi tak nahi parhay gaye
stream: FirebaseFirestore.instance
 .collection('Alerts')
 .where('isRead', isEqualTo: false)
 .snapshots(),
 builder: (context, snapshot) {
 // Unread alerts ki ginti
 int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
 bool hasUnread = unreadCount > 0;

 return Stack(
 alignment: Alignment.center,
 children: [
 IconButton(
 icon: Icon(
 Icons.notifications_active, 
 // Agar 1 ya us se zyada alerts hain toh Red, warna White
 color: hasUnread ? Colors.redAccent : Colors.white70
 ),
 tooltip: 'Recent Alerts',
 onPressed: () {
 Navigator.push(
 context, 
 MaterialPageRoute(builder: (context) => AlertCenter(showOnlyUnread: true))
 );
 },
 ),
 
 // AGAR UNREAD ALERTS HAIN TOH NUMBER WALA BADGE DIKHAO
 if (hasUnread)
 Positioned(
 right: 4, // Thora adjust kiya taake number pura aaye
 top: 4,
 child: Container(
 padding: const EdgeInsets.all(2),
 decoration: BoxDecoration(
 color: Colors.red,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFF0D1B2A), width: 1.5),
 ),
 // Size thora barha diya taake number fit aa sakay
 constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
 child: Center(
 child: Text(
 '$unreadCount',
 style: const TextStyle(
 color: Colors.white, 
 fontSize: 10, 
 fontWeight: FontWeight.bold
 ),
 ),
 ),
 ),
),
          ],
 );
},
),
          // 3. Logout/Switch Role Button
          IconButton(
  icon: const Icon(Icons.logout_rounded, color: Colors.white70), // Aapki original UI
  onPressed: () {
  if (Navigator.canPop(context)) {
    // Ye aapko wapis Role Selection par le jayega
    Navigator.pop(context); 
  } else {
    // Agar koi direct login hai (multi nahi hai), toh login par jaye
    Navigator.pushReplacementNamed(context, '/login');
  }
},
),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("System Overview", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
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
  // Yahan humne .where filter add kiya hai jo sirf 'Theft' status wale docs uthayega
  stream: FirebaseFirestore.instance
      .collection('Alerts')
      .where('status', isEqualTo: 'Theft') 
      .snapshots(),
  builder: (context, snapshot) {
    // Debugging ke liye: Agar card empty ho jaye toh check karein spelling 'Theft' hi hai na
    if (snapshot.hasError) return _buildStatCard("Theft Alerts", "Err", Icons.warning, Colors.redAccent);
    
    String count = snapshot.hasData ? snapshot.data!.docs.length.toString().padLeft(2, '0') : "00";
    return _buildStatCard("Theft Alerts", count, Icons.warning, Colors.redAccent);
  },
),
              ],
            ),
            
            const SizedBox(height: 25), 

            // LOGIC: View All History
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => AlertCenter(showOnlyUnread: false)
              )),
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