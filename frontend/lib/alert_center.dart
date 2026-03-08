import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'meter_analytics_history.dart'; // <--- NAYA IMPORT

class AlertCenter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Alert Center", 
          style: GoogleFonts.orbitron(color: Colors.redAccent, fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Alerts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No Alerts Found", style: TextStyle(color: Colors.white54))
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var alertData = doc.data() as Map<String, dynamic>;

              String meterId = alertData.containsKey('meterId') ? alertData['meterId'].toString() : "Unknown ID";
              String address = alertData.containsKey('address') ? alertData['address'].toString() : "Location not specified";

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
                  title: Text(
                    "Meter: $meterId", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(
                    address, 
                    style: const TextStyle(color: Colors.white70, fontSize: 13)
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MeterDetailPage(alertData: doc),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// METER DETAIL PAGE
// ==========================================
class MeterDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot alertData;
  const MeterDetailPage({super.key, required this.alertData});

  @override
  Widget build(BuildContext context) {
    var data = alertData.data() as Map<String, dynamic>;
    String meterId = data.containsKey('meterId') ? data['meterId'].toString() : "N/A";
    String address = data.containsKey('address') ? data['address'].toString() : "Address not found";

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text("Meter Analytics", style: GoogleFonts.orbitron(fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [const Color(0xFF1B263B), const Color(0xFF0D1B2A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.location_searching_rounded, color: Color(0xFF00E5FF), size: 40),
                    const SizedBox(height: 15),
                    Text(
                      "METER SCAN ACTIVE",
                      style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 12, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),

              // Detail Info Cards
              _buildPremiumInfoTile(Icons.fingerprint, "METER IDENTIFICATION", meterId, Colors.white),
              _buildPremiumInfoTile(Icons.map_outlined, "GEOSPATIAL LOCATION", address, Colors.white70),
              _buildPremiumInfoTile(Icons.gpp_bad_outlined, "CURRENT STATUS", "Theft Detected", Colors.redAccent),

              const Spacer(),

              // The Iconic Blue Premium Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MeterAnalyticsHistory()),
                  );
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF00B2CC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics_outlined, color: Colors.black, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          "VIEW ANALYTICS HISTORY",
                          style: GoogleFonts.orbitron(
                            color: Colors.black, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            letterSpacing: 1
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumInfoTile(IconData icon, String label, String value, Color valueColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E5FF).withOpacity(0.7), size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}