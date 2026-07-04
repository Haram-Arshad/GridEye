import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_center.dart';
import 'admin_analytics.dart';
import 'profile_screen.dart';
import 'fault_management_screen.dart'; // Fault Management Screen import

// ─────────────────────────────────────────────────────────────────────────────
// AdminDashboard
// Main screen for the Utility Admin role.
// Displays real-time grid overview, alert counts, geospatial map,
// and navigation to all admin sub-screens.
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  // ── Initial camera position for Google Maps ───────────────────────────────
  // Centered on Pakistan with a national-level zoom
  static const CameraPosition _initialLocation = CameraPosition(
    target: LatLng(30.3753, 69.3451), // Center of Pakistan
    zoom: 5.5,                         // National view
  );

  // ── Set of map markers fetched from Firestore ─────────────────────────────
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchMarkers(); // Start real-time marker stream on screen load
  }

  // ── Fetches live meter readings from Firestore and renders map markers ─────
  // Color coding:
  //   Red    → Theft detected
  //   Orange → Fault detected
  //   Azure  → Normal operation
  void _fetchMarkers() {
    FirebaseFirestore.instance
        .collection('MeterReadings')
        .snapshots()
        .listen((snapshot) {
      Set<Marker> tempMarkers = {};

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Only add marker if lat/lng fields exist in the document
        if (data.containsKey('lat') && data.containsKey('lng')) {
          tempMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(
                (data['lat'] as num).toDouble(),
                (data['lng'] as num).toDouble(),
              ),
              // Marker color based on ML-predicted meter status
              icon: BitmapDescriptor.defaultMarkerWithHue(
                data['status'] == 'Theft'
                    ? BitmapDescriptor.hueRed
                    : (data['status'] == 'Fault'
                        ? BitmapDescriptor.hueOrange
                        : BitmapDescriptor.hueAzure),
              ),
              // Tap on marker shows meter ID and current load
              infoWindow: InfoWindow(
                title: "Meter: ${data['meterId'] ?? 'Unknown'}",
                snippet: "Load: ${data['currentLoad'] ?? '0'} kW",
              ),
            ),
          );
        }
      }

      // Update markers only if widget is still mounted
      if (mounted) {
        setState(() => _markers = tempMarkers);
      }
    });
  }

  // ── Main build method ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,

        // GridEye brand logo — two-tone text (GRID white + EYE cyan)
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'GRID',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              TextSpan(
                text: 'EYE',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00E5FF),
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),

        actions: [

          // ── Action 1: Admin Profile Button ──────────────────────────────
          // Navigates to ProfileScreen (role-aware: shows admin view)
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white70,
            ),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),

          // ── Action 2: Notification Bell with Unread Badge ────────────────
          // Streams unread alerts from Firestore in real-time.
          // Shows red badge with count when unread alerts exist.
          // Tapping navigates to AlertCenter filtered for unread only.
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Alerts')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.hasData
                  ? snapshot.data!.docs.length
                  : 0;
              bool hasUnread = unreadCount > 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_active,
                      // Red when unread alerts exist, white otherwise
                      color: hasUnread
                          ? Colors.redAccent
                          : Colors.white70,
                    ),
                    tooltip: 'Recent Alerts',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AlertCenter(showOnlyUnread: true),
                        ),
                      );
                    },
                  ),

                  // Red circular badge showing unread count
                  if (hasUnread)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0D1B2A),
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // ── Action 3: Logout / Switch Role Button ───────────────────────
          // Pops back to Role Selection if navigable,
          // otherwise redirects to Login screen
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white70,
            ),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Section Header ────────────────────────────────────────────
            const Text(
              "System Overview",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ── Stat Cards Row ────────────────────────────────────────────
            // Three real-time stat cards: Active Grids, Theft Alerts, Fault Alerts
            // Each uses a StreamBuilder to fetch live counts from Firestore
            Row(
              children: [

                // Card 1: Active Grids
                // Counts total documents in MeterReadings collection
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('MeterReadings')
                      .snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData
                        ? snapshot.data!.docs.length
                            .toString()
                            .padLeft(2, '0')
                        : "00";
                    return _buildStatCard(
                      "Active Grids",
                      count,
                      Icons.bolt,
                      Colors.greenAccent,
                    );
                  },
                ),
                const SizedBox(width: 10),

                // Card 2: Theft Alerts
                // Counts Alerts where status == "Theft"
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Alerts')
                      .where('status', isEqualTo: 'Theft')
                      .snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData
                        ? snapshot.data!.docs.length
                            .toString()
                            .padLeft(2, '0')
                        : "00";
                    return _buildStatCard(
                      "Theft Alerts",
                      count,
                      Icons.warning,
                      Colors.redAccent,
                    );
                  },
                ),
                const SizedBox(width: 10),

                // Card 3: Fault Alerts
                // Counts Alerts where status == "Fault"
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Alerts')
                      .where('status', isEqualTo: 'Fault')
                      .snapshots(),
                  builder: (context, snapshot) {
                    String count = snapshot.hasData
                        ? snapshot.data!.docs.length
                            .toString()
                            .padLeft(2, '0')
                        : "00";
                    return _buildStatCard(
                      "Fault Alerts",
                      count,
                      Icons.build_circle_outlined,
                      Colors.orangeAccent,
                    );
                  },
                ),
              ],
            ),
  // ── Navigation Buttons Section ────────────────────────
// Three action buttons with identical height and styling.
// Each navigates to a different admin sub-screen.
const SizedBox(height: 25),

// Button 1: View All Alerts
// Opens AlertCenter showing complete alert history
_buildNavButton(
  context,
  label: "ALL ALERTS",
  icon: Icons.list_alt_rounded,
  color: Colors.redAccent,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AlertCenter(showOnlyUnread: false),
    ),
  ),
),
const SizedBox(height: 12),

// Button 2: View System Financials
// Opens AdminAnalytics — live efficiency, grid loss, revenue
_buildNavButton(
  context,
  label: "SYSTEM FINANCIALS",
  icon: Icons.analytics_outlined,
  color: const Color(0xFF00E5FF),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AdminAnalytics(),
    ),
  ),
),
const SizedBox(height: 12),

// Button 3: Manage Fault Reports
// Opens FaultManagementScreen — Pending/Resolved tabs
// Label does NOT show count — clean consistent appearance
_buildNavButton(
  context,
  label: "MANAGE REPORTS",
  icon: Icons.build_circle_outlined,
  color: Colors.orangeAccent,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FaultManagementScreen(),
    ),
  ),
),
const SizedBox(height: 20),

            // ── Live Geospatial Feed Label ─────────────────────────────────
            const Text(
              "Live Geospatial Feed",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),

            // ── Google Map ────────────────────────────────────────────────
            // Displays real-time meter locations from MeterReadings.
            // Markers are color-coded by ML-predicted status:
            //   Red = Theft | Orange = Fault | Blue = Normal
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.3),
                    ),
                  ),
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

  // ── Stat Card Widget ──────────────────────────────────────────────────────
  // Reusable card for displaying a single metric (count, icon, label).
  // Used for Active Grids, Theft Alerts, and Fault Alerts.
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  )
   {
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
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Navigation Button Widget ──────────────────────────────────────────────
// Reusable full-width button with consistent height (52px),
// icon, label, and color theming. Used for all three action buttons.
// ── Navigation Button Widget ──────────────────────────────────────────────
// Reusable full-width button with consistent height (52px),
// icon, label, and color theming. Used for all three action buttons.
Widget _buildNavButton(
  BuildContext context, {
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52, // Fixed height — ensures all buttons same size
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.30),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14, // Consistent clean text size
              fontWeight: FontWeight.bold, // Same weight structure as overview labels
            ),
          ),
        ],
      ),
    ),
  );
}