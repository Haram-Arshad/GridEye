import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MeterAnalyticsHistory extends StatelessWidget {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section 1: Meter Identity Card ---
            _buildMeterHeader("MTR-9901", "Gulshan-e-Iqbal, Block 4, Karachi"),
            
            const SizedBox(height: 30),

            // --- Section 2: Quick Stats ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat("Total Thefts", "04", Colors.redAccent),
                _buildMiniStat("Avg Load", "2.4kW", Colors.orangeAccent),
                _buildMiniStat("Status", "Active", Colors.greenAccent),
              ],
            ),

            const SizedBox(height: 30),

            // --- Section 3: Incident Timeline ---
            const Text(
              "Recent Incident Logs", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 15),
            
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildIncidentTile("Theft Detected", "05 March, 11:20 PM", "High Voltage Bypass detected by AI model."),
                  _buildIncidentTile("Anomalous Load", "01 March, 02:15 AM", "Load spiked to 8.5kW suddenly."),
                  _buildIncidentTile("Maintenance Reset", "24 Feb, 10:00 AM", "Manual reset by Field Technician (ID: 442)."),
                  _buildIncidentTile("Theft Detected", "15 Feb, 08:45 PM", "Shunt wire connection suspected."),
                  _buildIncidentTile("System Online", "01 Feb, 09:00 AM", "Smart Meter successfully synchronized."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Meter Info Header
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
                Text(id, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(loc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mini Stats Widget
  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  // Incident Tile
  Widget _buildIncidentTile(String title, String time, String desc) {
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
            title.contains("Theft") ? Icons.warning_rounded : Icons.info_outline,
            color: title.contains("Theft") ? Colors.redAccent : Color(0xFF00E5FF),
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
                    Text(time.split(',')[0], style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(time.split(',')[1], style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}