import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsageHistory extends StatelessWidget {
  final String meterID;
  UsageHistory({required this.meterID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
  shaderCallback: (bounds) => const LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF008CAB)],
  ).createShader(bounds),
  child: Text(
    "Usage History", 
    style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.white)
  ),
),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meters')
            .doc(meterID)
            .collection('usage_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No history found", style: TextStyle(color: Colors.white38)));
          }

          var docs = snapshot.data!.docs;
          var graphData = docs.take(6).toList().reversed.toList();

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Consumption Trend",
                  style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                
                // Graph (Original Design)
                _buildConsumptionGraph(graphData),
                
                const SizedBox(height: 30),
                const Text(
                  "Billing & Consumption Log",
                  style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      bool isPaid = data['isPaid'] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03), // Thora aur dark
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.2), // Light neon border
                          width: 1.5,
                              ),
                                ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['month'] ?? "N/A", 
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Text("${data['units']} Units Consumed", 
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("Rs. ${data['amount']}", 
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPaid ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isPaid ? "Paid" : "Unpaid",
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
          );
        },
      ),
    );
  }

  Widget _buildConsumptionGraph(List<QueryDocumentSnapshot> docs) {
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
        children: docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          double units = (data['units'] ?? 0).toDouble();
          double factor = (units / 500).clamp(0.1, 1.0); 
          return _buildBar(data['month'] ?? "", factor);
        }).toList(),
      ),
    );
  }

  Widget _buildBar(String label, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 25,
          height: 100 * heightFactor,
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}