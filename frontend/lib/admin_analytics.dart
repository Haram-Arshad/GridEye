import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnalytics extends StatelessWidget {
  const AdminAnalytics({super.key});

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
        title: Text(
          "System Analytics",
          style: GoogleFonts.orbitron(
              fontSize: 16, color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ── LIVE: MeterReadings se efficiency + gridLoss ──
        stream: FirebaseFirestore.instance
            .collection('MeterReadings')
            .snapshots(),
        builder: (context, meterSnap) {

          return StreamBuilder<QuerySnapshot>(
            // ── LIVE: Active theft cases ──────────────────
            stream: FirebaseFirestore.instance
                .collection('Alerts')
                .where('status', isEqualTo: 'Theft')
                .snapshots(),
            builder: (context, alertSnap) {

              return StreamBuilder<DocumentSnapshot>(
                // ── financials: Revenue ───────────────────
                stream: FirebaseFirestore.instance
                    .collection('financials')
                    .doc('current_metrics')
                    .snapshots(),
                builder: (context, finSnap) {

                  return StreamBuilder<DocumentSnapshot>(
                    // ── system_stats: lastMonthEff ────────
                    stream: FirebaseFirestore.instance
                        .collection('system_stats')
                        .doc('overall_metrics')
                        .snapshots(),
                    builder: (context, statsSnap) {

                      if (meterSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00E5FF)),
                        );
                      }

                      // ── LIVE CALCULATIONS ─────────────────

                      // 1. Efficiency from MeterReadings
                      final allReadings =
                          meterSnap.data?.docs ?? [];
                      final totalMeters = allReadings.length;

                      int normalCount = 0;
                      int theftCount  = 0;
                      int faultCount  = 0;
                      double theftLoadSum = 0.0;

                      for (var doc in allReadings) {
                        final d = doc.data()
                            as Map<String, dynamic>;
                        final s = (d['status'] ?? '')
                            .toString();
                        final load = double.tryParse(
                            d['currentLoad']?.toString()
                            ?? '0') ?? 0.0;

                        if (s == 'Normal') normalCount++;
                        else if (s == 'Theft') {
                          theftCount++;
                          theftLoadSum += load;
                        }
                        else if (s == 'Fault') faultCount++;
                      }

                      // Efficiency = Normal% of total
                      final efficiency = totalMeters > 0
                          ? ((normalCount / totalMeters)
                              * 100).round()
                          : 0;

                      // Grid loss estimate:
                      // Theft meters should have used
                      // normal load (avg 5kW) but showed low
                      // Loss = (5 - actual) per theft meter
                      const avgNormalLoad = 5.0;
                      final gridLoss = theftCount > 0
                          ? ((avgNormalLoad - 
                              (theftLoadSum / theftCount))
                              * theftCount * 720).round()
                          : 0;
                      // 720 = hours in a month

                      // 2. Active cases from Alerts
                      final theftAlerts =
                          alertSnap.data?.docs ?? [];
                      final activeCases = theftAlerts.length;

                      // 3. Revenue from financials
                      double revenue = 0;
                      if (finSnap.hasData &&
                          finSnap.data!.exists) {
                        final f = finSnap.data!.data()
                            as Map<String, dynamic>;
                        revenue = (f['totalRevenue'] ?? 0)
                            .toDouble();
                      }

                      // 4. Last month efficiency
                      int lastMonthEff = 62;
                      if (statsSnap.hasData &&
                          statsSnap.data!.exists) {
                        final s = statsSnap.data!.data()
                            as Map<String, dynamic>;
                        lastMonthEff =
                            s['lastMonthEff'] ?? 62;
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            // ── Efficiency donut ──────────
                            Container(
                              padding:
                                const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(0.03),
                                borderRadius:
                                  BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white
                                    .withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    "OVERALL RECOVERY RATE",
                                    style: GoogleFonts
                                      .orbitron(
                                      color: Colors
                                        .white38,
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 30),
                                  Center(
                                    child: Stack(
                                      alignment:
                                        Alignment.center,
                                      children: [
                                        SizedBox(
                                          height: 180,
                                          width: 180,
                                          child:
                                            CircularProgressIndicator(
                                            value: efficiency
                                                / 100,
                                            strokeWidth: 12,
                                            color: const Color(
                                              0xFF00E5FF),
                                            backgroundColor:
                                              Colors
                                                .redAccent
                                                .withOpacity(
                                                  0.1),
                                          ),
                                        ),
                                        Column(
                                          mainAxisAlignment:
                                            MainAxisAlignment
                                              .center,
                                          children: [
                                            Text(
                                              "$efficiency%",
                                              style:
                                                GoogleFonts
                                                  .orbitron(
                                                color:
                                                  Colors
                                                    .white,
                                                fontSize:
                                                  32,
                                                fontWeight:
                                                  FontWeight
                                                    .bold,
                                              ),
                                            ),
                                            const Text(
                                              "Efficiency",
                                              style:
                                                TextStyle(
                                                color: Color(
                                                  0xFF00E5FF),
                                                fontSize:
                                                  12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── Meter breakdown ───
                                  const SizedBox(
                                      height: 20),
                                  Row(
                                    mainAxisAlignment:
                                      MainAxisAlignment
                                        .spaceEvenly,
                                    children: [
                                      _buildMiniCount(
                                        "Normal",
                                        normalCount,
                                        Colors.greenAccent,
                                      ),
                                      _buildMiniCount(
                                        "Theft",
                                        theftCount,
                                        Colors.redAccent,
                                      ),
                                      _buildMiniCount(
                                        "Fault",
                                        faultCount,
                                        Colors.orangeAccent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            const Text(
                              "System Metrics",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),

                            // ── Grid Loss ─────────────────
                            _buildMetricTile(
                              "Total Grid Loss",
                              "${gridLoss.abs()} units",
                              gridLoss > 0
                                ? "Potential leakage from $theftCount theft meters"
                                : "No significant loss detected",
                              Icons.trending_down,
                              Colors.redAccent,
                            ),
                            const SizedBox(height: 12),

                            // ── Revenue ───────────────────
                            _buildMetricTile(
                              "Revenue Recovered",
                              "Rs. ${revenue.toStringAsFixed(0)}",
                              "Fines collected this month",
                              Icons.account_balance_wallet_outlined,
                              const Color(0xFF00E5FF),
                            ),
                            const SizedBox(height: 12),

                            // ── Active Cases ──────────────
                            _buildMetricTile(
                              "Active Investigations",
                              "$activeCases Cases",
                              "High-priority theft alerts",
                              Icons.gavel_rounded,
                              Colors.orangeAccent,
                            ),
                            const SizedBox(height: 30),

                            // ── Monthly Comparison ────────
                            const Text(
                              "Monthly Comparison",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Container(
                              height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius:
                                  BorderRadius.circular(10),
                              ),
                              child: FractionallySizedBox(
                                alignment:
                                  Alignment.centerLeft,
                                widthFactor:
                                  efficiency / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF00E5FF),
                                    borderRadius:
                                      BorderRadius
                                        .circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                MainAxisAlignment
                                  .spaceBetween,
                              children: [
                                Text(
                                  "Last Month: $lastMonthEff%",
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  "This Month: $efficiency%",
                                  style: const TextStyle(
                                    color:
                                      Color(0xFF00E5FF),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── Mini count widget (Normal/Theft/Fault) ────────────
  Widget _buildMiniCount(
      String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString().padLeft(2, '0'),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ── Metric tile ───────────────────────────────────────
  Widget _buildMetricTile(
    String title,
    String value,
    String sub,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}