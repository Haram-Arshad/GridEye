import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminAnalytics extends StatelessWidget {
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
        title: Text("System Analytics", style: GoogleFonts.orbitron(fontSize: 16, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP CHART SECTION ---
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text("OVERALL RECOVERY RATE", 
                    style: GoogleFonts.orbitron(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
                  const SizedBox(height: 30),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 180,
                          width: 180,
                          child: CircularProgressIndicator(
                            value: 0.74, // 74% Recovery
                            strokeWidth: 12,
                            color: const Color(0xFF00E5FF),
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                          ),
                        ),
                        Column(
                          children: [
                            Text("74%", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                            const Text("Efficiency", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- FINANCIAL STATS ---
            const Text("Financial Metrics", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildMetricTile(
              "Total Grid Loss", 
              "52,400 units", 
              "Potential leakage detected", 
              Icons.trending_down, 
              Colors.redAccent
            ),
            
            const SizedBox(height: 12),

            _buildMetricTile(
              "Revenue Recovered", 
              "Rs. 1,240,500", 
              "Fines collected this month", 
              Icons.account_balance_wallet_outlined, 
              const Color(0xFF00E5FF)
            ),

            const SizedBox(height: 12),

            _buildMetricTile(
              "Active Investigations", 
              "18 Cases", 
              "High-priority theft alerts", 
              Icons.gavel_rounded, 
              Colors.orangeAccent
            ),

            const SizedBox(height: 30),

            // --- REVENUE BAR (SMALL INDICATOR) ---
            const Text("Monthly Comparison", style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 15),
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.8, // 80% growth
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Last Month: 62%", style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text("This Month: 80%", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(sub, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}