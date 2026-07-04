import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeterAnalyticsHistory extends StatelessWidget {
  final String meterId;
  final String address;

  const MeterAnalyticsHistory({
    super.key,
    required this.meterId,
    required this.address,
  });

  // ── Month names — no more hardcoded "April" ────────
  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatTime(dynamic ts) {
    if (ts == null || ts is! Timestamp) return 'N/A';
    final dt   = ts.toDate();
    final h    = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min  = dt.minute.toString().padLeft(2, '0');
    // ✅ FIX: dynamic month from datetime
    return "${dt.day} ${_months[dt.month]}, $h:$min $ampm";
  }

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
          "Meter Archive",
          style: GoogleFonts.orbitron(
              fontSize: 16, color: Colors.white),
        ),
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
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00E5FF)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(
                      color: Colors.white24),
                ),
              );
            }

            final docs        = snapshot.data?.docs ?? [];
            final totalEvents = docs.length;

            // ── Stats calculations ─────────────────────
            double sumLoad = 0.0;
            int    theftCount = 0;

            for (var doc in docs) {
              final d = doc.data() as Map<String, dynamic>;
              final val = d['loadValue'];
              if (val != null) {
                sumLoad += val is num
                    ? val.toDouble()
                    : double.tryParse(val.toString()) ?? 0.0;
              }
              if ((d['status'] ?? '') == 'Theft') theftCount++;
            }

            final avgLoad    = totalEvents > 0
                ? sumLoad / totalEvents : 0.0;
            final meterStatus = totalEvents > 0
                ? "Active" : "Offline";

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header card ──────────────────────────
                _buildMeterHeader(meterId, address),
                const SizedBox(height: 20),

                // ── Stats row ────────────────────────────
                Row(
                  children: [
                    _buildMiniStat(
                      "Total Events",
                      totalEvents.toString().padLeft(2, '0'),
                      Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    _buildMiniStat(
                      "Avg Load",
                      "${avgLoad.toStringAsFixed(1)}kW",
                      Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    _buildMiniStat(
                      "Status",
                      meterStatus,
                      Colors.greenAccent,
                    ),
                  ],
                ),



                const SizedBox(height: 20),
                const Text(
                  "Recent Incident Logs",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Logs list ─────────────────────────────
                Expanded(
                  child: totalEvents == 0
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: Colors.white
                                    .withOpacity(0.12),
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No logs yet",
                                style: GoogleFonts.orbitron(
                                  color: Colors.white
                                      .withOpacity(0.20),
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics:
                              const BouncingScrollPhysics(),
                          itemCount: totalEvents,
                          itemBuilder: (context, index) {
                            final log = docs[index].data()
                                as Map<String, dynamic>;
                            final isCritical =
                                log['isCritical'] ?? false;
                            final status =
                                log['status'] ?? 'Normal';
                            final confidence =
                                log['ml_confidence'] ?? 0;
                            final timeStr =
                                _formatTime(log['time']);

                            return _buildIncidentTile(
                              title:      log['title'] ?? "Incident",
                              time:       timeStr,
                              desc:       log['desc'] ?? "",
                              isCritical: isCritical,
                              status:     status,
                              confidence: confidence,
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

  // ── Meter Header ──────────────────────────────────────
  Widget _buildMeterHeader(String id, String loc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Colors.redAccent,
            child: Icon(Icons.history_toggle_off,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  loc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mini Stat ─────────────────────────────────────────
  Widget _buildMiniStat(String label, String value,
      Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Incident Tile ─────────────────────────────────────
  Widget _buildIncidentTile({
    required String title,
    required String time,
    required String desc,
    required bool   isCritical,
    required String status,
    required int    confidence,
  }) {
    // Color + icon based on status
    Color    tileColor;
    IconData tileIcon;

    switch (status) {
      case 'Theft':
        tileColor = Colors.redAccent;
        tileIcon  = Icons.warning_rounded;
        break;
      case 'Fault':
        tileColor = Colors.orangeAccent;
        tileIcon  = Icons.build_circle_outlined;
        break;
      default:
        tileColor = const Color(0xFF00E5FF);
        tileIcon  = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCritical
              ? Colors.redAccent.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Icon(tileIcon, color: tileColor, size: 20),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + time
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                // ✅ ML Confidence badge (only if > 0)
                if (confidence > 0 && status != 'Normal') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        color: tileColor.withOpacity(0.7),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "ML Confidence: $confidence%",
                        style: TextStyle(
                          color: tileColor.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}