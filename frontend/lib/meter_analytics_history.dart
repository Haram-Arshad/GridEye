import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

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

  // ── (NEW) Build the PDF document bytes — shared by Save & Share ──
  Future<Uint8List> _buildPdfBytes(
    List<QueryDocumentSnapshot> docs,
    int totalEvents,
    double avgLoad,
    String meterStatus,
  ) async {
    final pdfDoc = pw.Document();

    final rows = docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final confidence = d['ml_confidence'] ?? 0;
      return [
        _formatTime(d['time']),
        (d['title'] ?? 'Incident').toString(),
        (d['status'] ?? 'Normal').toString(),
        confidence > 0 ? '$confidence%' : '-',
        (d['desc'] ?? '').toString(),
      ];
    }).toList();

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'GridEye Incident Report',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Meter ID: $meterId'),
          pw.Text('Location: $address'),
          pw.Text(
              'Generated: ${DateTime.now().toString().split('.').first}'),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Events: $totalEvents'),
              pw.Text('Avg Load: ${avgLoad.toStringAsFixed(1)} kW'),
              pw.Text('Status: $meterStatus'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Time', 'Title', 'Status', 'Confidence', 'Description'],
            data: rows,
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(2.5),
            },
          ),
        ],
      ),
    );

    return pdfDoc.save();
  }

  // ── (NEW) Share the PDF via the OS share sheet ──────────
  Future<void> _sharePdf(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    int totalEvents,
    double avgLoad,
    String meterStatus,
  ) async {
    try {
      final bytes =
          await _buildPdfBytes(docs, totalEvents, avgLoad, meterStatus);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'GridEye_Incident_Report_$meterId.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF share failed: $e')),
        );
      }
    }
  }

  // ── (NEW) Save the PDF directly to device storage ───────
  Future<void> _savePdf(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    int totalEvents,
    double avgLoad,
    String meterStatus,
  ) async {
    try {
      final bytes =
          await _buildPdfBytes(docs, totalEvents, avgLoad, meterStatus);

      // App's own document storage — no runtime permission needed,
      // works the same on Android and iOS.
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'GridEye_Incident_Report_${meterId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF save failed: $e')),
        );
      }
    }
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



                const SizedBox(height: 14),
                // ── (NEW) Save / Share PDF buttons ──────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _savePdf(
                          context,
                          docs,
                          totalEvents,
                          avgLoad,
                          meterStatus,
                        ),
                        icon: const Icon(Icons.download_rounded,
                            color: Color(0xFF00E5FF), size: 18),
                        label: const Text(
                          "Save Report",
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF00E5FF), width: 1),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _sharePdf(
                          context,
                          docs,
                          totalEvents,
                          avgLoad,
                          meterStatus,
                        ),
                        icon: const Icon(Icons.ios_share_rounded,
                            color: Color(0xFF00E5FF), size: 18),
                        label: const Text(
                          "Share Report",
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF00E5FF), width: 1),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
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