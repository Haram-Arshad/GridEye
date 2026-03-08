import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UsageHistory extends StatelessWidget {
  // Dummy data (Baad mein Areeba isay Firestore se link karengi)
  final List<Map<String, String>> historyData = [
    {"month": "February 2026", "units": "340", "amount": "12,400", "status": "Paid"},
    {"month": "January 2026", "units": "410", "amount": "15,800", "status": "Paid"},
    {"month": "December 2025", "units": "280", "amount": "9,200", "status": "Paid"},
    {"month": "November 2025", "units": "520", "amount": "22,100", "status": "Unpaid"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Usage History", style: GoogleFonts.orbitron(fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NEW: Consumption Graph Section ---
            const Text(
              "Consumption Trend",
              style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildConsumptionGraph(),
            const SizedBox(height: 30),

            // --- Billing Log Section ---
            const Text(
              "Billing & Consumption Log",
              style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: historyData.length,
                itemBuilder: (context, index) {
                  var item = historyData[index];
                  bool isPaid = item['status'] == "Paid";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['month']!, 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text("${item['units']} Units Consumed", 
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Rs. ${item['amount']}", 
                              style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                item['status']!,
                                style: TextStyle(
                                  color: isPaid ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget: Consumption Graph ---
  Widget _buildConsumptionGraph() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar("Sep", 0.4),
          _buildBar("Oct", 0.7),
          _buildBar("Nov", 0.9),
          _buildBar("Dec", 0.5),
          _buildBar("Jan", 0.8),
          _buildBar("Feb", 0.6),
        ],
      ),
    );
  }

  // --- Helper Widget: Individual Bar ---
  Widget _buildBar(String label, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 25,
          height: 100 * heightFactor, // Scale height based on factor
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF008CAB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}