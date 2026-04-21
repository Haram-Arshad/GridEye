import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Step 1: Technical Metrics Stream
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('system_stats').doc('overall_metrics').snapshots(),
        builder: (context, systemSnapshot) {
          
          // Step 2: Financial Metrics Stream (Nested)
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('financials').doc('current_metrics').snapshots(),
            builder: (context, financialSnapshot) {
              
              if (systemSnapshot.connectionState == ConnectionState.waiting || financialSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
              }

              if (!systemSnapshot.hasData || !systemSnapshot.data!.exists) {
                return const Center(child: Text("Technical stats not found", style: TextStyle(color: Colors.white)));
              }

              // Data Extraction
              var systemData = systemSnapshot.data!.data() as Map<String, dynamic>;
              var financialData = financialSnapshot.hasData && financialSnapshot.data!.exists 
                  ? financialSnapshot.data!.data() as Map<String, dynamic> 
                  : {};

              // Technical Variables (system_stats)
              int efficiency = systemData['efficiency'] ?? 0;
              double gridLoss = (systemData['gridLoss'] ?? 0).toDouble();
              int activeCases = systemData['activeCases'] ?? 0;
              int lastMonth = systemData['lastMonthEff'] ?? 0;

              // Financial Variables (financials)
              double revenue = (financialData['totalRevenue'] ?? 0).toDouble();

              return SingleChildScrollView(
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
                                  height: 180, width: 180,
                                  child: CircularProgressIndicator(
                                    value: efficiency / 100,
                                    strokeWidth: 12,
                                    color: const Color(0xFF00E5FF),
                                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("$efficiency%", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
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
                    const Text("System Metrics", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    _buildMetricTile(
                      "Total Grid Loss", 
                      "${gridLoss.toStringAsFixed(0)} units", 
                      "Potential leakage detected", 
                      Icons.trending_down, 
                      Colors.redAccent
                    ),
                    
                    const SizedBox(height: 12),

                    // LIVE FROM FINANCIALS COLLECTION
                    _buildMetricTile(
                      "Revenue Recovered", 
                      "Rs. ${revenue.toStringAsFixed(0)}", 
                      "Fines collected this month", 
                      Icons.account_balance_wallet_outlined, 
                      const Color(0xFF00E5FF)
                    ),

                    const SizedBox(height: 12),

                    _buildMetricTile(
                      "Active Investigations", 
                      "$activeCases Cases", 
                      "High-priority theft alerts", 
                      Icons.gavel_rounded, 
                      Colors.orangeAccent
                    ),

                    const SizedBox(height: 30),

                    // --- COMPARISON BAR ---
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
                        widthFactor: efficiency / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Last Month: $lastMonth%", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        Text("This Month: $efficiency%", style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
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