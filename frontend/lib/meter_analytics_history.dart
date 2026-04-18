import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeterAnalyticsHistory extends StatelessWidget {
  final String meterId;
  final String address;

  const MeterAnalyticsHistory({super.key, required this.meterId, required this.address});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Meter Archive", style: GoogleFonts.orbitron(fontSize: 16, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('MeterLogs')
              .where('meterId', isEqualTo: meterId)
              .orderBy('time', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white24)));
            }

            // --- Calculation Logic Start ---
            final docs = snapshot.data?.docs ?? [];
            int totalEvents = docs.length;
            
            double sumLoad = 0.0;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              var val = data['loadValue'];

              if (val != null) {
                if (val is num) {
                  sumLoad += val.toDouble();
                } else if (val is String) {
                  // Agar ghalti se String ho to convert karo
                  sumLoad += double.tryParse(val) ?? 0.0;
                }
              }
            }
            
            double avgLoad = totalEvents > 0 ? sumLoad / totalEvents : 0.0;
            String meterStatus = totalEvents > 0 ? "Active" : "Offline";
            // --- Calculation Logic End ---

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMeterHeader(meterId, address),
                const SizedBox(height: 30),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat("Total Events", totalEvents.toString().padLeft(2, '0'), Colors.redAccent),
                    _buildMiniStat("Avg Load", "${avgLoad.toStringAsFixed(1)}kW", Colors.orangeAccent),
                    _buildMiniStat("Status", meterStatus, Colors.greenAccent),
                  ],
                ),

                const SizedBox(height: 30),
                const Text(
                  "Recent Incident Logs", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 15),
                
                Expanded(
                  child: totalEvents == 0 
                    ? const Center(child: Text("No history logs found.", style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: totalEvents,
                        itemBuilder: (context, index) {
                          var log = docs[index].data() as Map<String, dynamic>;
                          
                          String formattedTime = "N/A";
                          if (log['time'] != null && log['time'] is Timestamp) {
                            DateTime dt = (log['time'] as Timestamp).toDate();
                            String hour = dt.hour > 12 ? (dt.hour - 12).toString() : dt.hour.toString();
                            if(hour == "0") hour = "12";
                            formattedTime = "${dt.day} April, $hour:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
                          }

                          return _buildIncidentTile(
                            log['title'] ?? "Incident", 
                            formattedTime, 
                            log['desc'] ?? "",
                            log['isCritical'] ?? false,
                          );
                        },
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // UI Components (Same as before)
  Widget _buildMeterHeader(String id, String loc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.redAccent.withOpacity(0.15), Colors.transparent]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Colors.redAccent,
            child: Icon(Icons.history_toggle_off, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(loc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      width: 100, padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
    );
  }

  Widget _buildIncidentTile(String title, String time, String desc, bool isCritical) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.warning_rounded : Icons.info_outline,
            color: isCritical ? Colors.redAccent : const Color(0xFF00E5FF),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(time, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}