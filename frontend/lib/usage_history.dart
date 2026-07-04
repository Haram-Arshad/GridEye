import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsageHistory extends StatelessWidget {
  final String meterID;
  const UsageHistory({super.key, required this.meterID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF008CAB)],
          ).createShader(bounds),
          child: Text(
            "Usage History",
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
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
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF00E5FF)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined,
                      color: Colors.white.withOpacity(0.15),
                      size: 48),
                  const SizedBox(height: 14),
                  Text(
                    "No history found",
                    style: GoogleFonts.orbitron(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs      = snapshot.data!.docs;
          final graphData = docs.take(3).toList().reversed.toList();

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ___AI Badge ___


                const SizedBox(height: 6),
                const Text(
                  "Consumption Trend",
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                // ____Graph____
                _buildConsumptionGraph(graphData),
                const SizedBox(height: 30),

                const Text(
                  "Billing & ML Risk Analysis",
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                //____List____
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data()
                          as Map<String, dynamic>;

                      final bool   isPaid     = data['isPaid'] ?? false;
                      final String theftRisk  =
                          data['theft_risk'] ?? 'Low';
                      final int    confidence =
                          data['confidence'] ?? 0;
                      final String label      =
                          data['label'] ?? data['month'] ?? '—';
                      final double units      =
                          (data['units'] ?? 0).toDouble();
                      final int    amount     =
                          (data['amount'] ?? 0).toInt();

                      return _buildHistoryCard(
                        label:      label,
                        units:      units,
                        amount:     amount,
                        isPaid:     isPaid,
                        theftRisk:  theftRisk,
                        confidence: confidence,
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
  //---------------------------
  // History Card
  //---------------------------
  Widget _buildHistoryCard({
    required String label,
    required double units,
    required int    amount,
    required bool   isPaid,
    required String theftRisk,
    required int    confidence,
  }) {
    final bool   isHighRisk  = theftRisk == "High";
    final Color  riskColor   = isHighRisk
        ? const Color(0xFFFF5252)
        : const Color(0xFF69F0AE);
    final IconData riskIcon  = isHighRisk
        ? Icons.warning_amber_rounded
        : Icons.verified_outlined;
    final String riskLabel   = isHighRisk
        ? "HIGH RISK"
        : "LOW RISK";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighRisk
              ? const Color(0xFFFF5252).withOpacity(0.25)
              : const Color(0xFF00E5FF).withOpacity(0.15),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // ----Row 1: Month + Amount + Paid ------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Rs. $amount",
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPaid ? "Paid" : "Unpaid",
                        style: TextStyle(
                          color: isPaid
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ----Row 2: Units consumed ------------
            Row(
              children: [
                const Icon(Icons.electric_bolt,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 5),
                Text(
                  "${units.toStringAsFixed(1)} kWh consumed",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 8),

            //----Row 3: ML Risk Badge ------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Risk badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: riskColor.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(riskIcon, color: riskColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        riskLabel,
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Confidence
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined,
                        color: Colors.white38, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      "Confidence: $confidence%",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //-------------------------
  //Consumption Graph 
  //-------------------------
  Widget _buildConsumptionGraph(
      List<QueryDocumentSnapshot> docs) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.1),
        ),
      ),
      child: docs.isEmpty
          ? const Center(
              child: Text("No data",
                  style: TextStyle(color: Colors.white24)))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: docs.map((doc) {
                final data =
                    doc.data() as Map<String, dynamic>;
                final double units =
                    (data['units'] ?? 0).toDouble();
                final String month =
                    data['month'] ?? '—';
                final String risk =
                    data['theft_risk'] ?? 'Low';
                final double factor =
                    (units / 500).clamp(0.1, 1.0);
                final Color barColor = risk == "High"
                    ? const Color(0xFFFF5252)
                    : const Color(0xFF00E5FF);
                return _buildBar(month, factor, barColor);
              }).toList(),
            ),
    );
  }

  Widget _buildBar(
      String label, double heightFactor, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 90 * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}