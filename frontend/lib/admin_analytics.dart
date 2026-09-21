import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class AdminAnalytics extends StatelessWidget {
  const AdminAnalytics({super.key});

  // ── (NEW) Build the System Analytics report PDF bytes ──
  Future<Uint8List> _buildPdfBytes({
    required int efficiency,
    required int lastMonthEff,
    required int normalCount,
    required int theftCount,
    required int faultCount,
    required int gridLoss,
    required double revenue,
    required int activeCases,
  }) async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'GridEye System Analytics Report',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated: ${DateTime.now().toString().split('.').first}'),
          pw.SizedBox(height: 16),
          pw.Text('Overall Recovery Rate',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 4),
          pw.Text('This Month: $efficiency%   |   Last Month: $lastMonthEff%'),
          pw.SizedBox(height: 16),
          pw.Text('Meter Breakdown',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Normal', 'Theft', 'Fault'],
            data: [
              [normalCount.toString(), theftCount.toString(), faultCount.toString()],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 16),
          pw.Text('System Metrics',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 4),
          pw.Bullet(text: 'Total Grid Loss: ${gridLoss.abs()} units'),
          pw.Bullet(text: 'Revenue Recovered: Rs. ${revenue.toStringAsFixed(0)}'),
          pw.Bullet(text: 'Active Investigations: $activeCases cases'),
        ],
      ),
    );

    return pdfDoc.save();
  }

  // ── (NEW) Save the PDF directly to device storage ───────
  Future<void> _savePdf(BuildContext context,
      {required Future<Uint8List> Function() buildBytes}) async {
    try {
      final bytes = await buildBytes();
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'GridEye_System_Analytics_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

  // ── (NEW) Share the PDF via the OS share sheet ──────────
  Future<void> _sharePdf(BuildContext context,
      {required Future<Uint8List> Function() buildBytes}) async {
    try {
      final bytes = await buildBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'GridEye_System_Analytics_Report.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF share failed: $e')),
        );
      }
    }
  }

  // ── (NEW) View the PDF in the native preview screen ─────
  Future<void> _viewPdf(BuildContext context,
      {required Future<Uint8List> Function() buildBytes}) async {
    try {
      final bytes = await buildBytes();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'GridEye_System_Analytics_Report.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF preview failed: $e')),
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

                            // ── (NEW) Save / View / Share report ──
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _savePdf(
                                      context,
                                      buildBytes: () => _buildPdfBytes(
                                        efficiency: efficiency,
                                        lastMonthEff: lastMonthEff,
                                        normalCount: normalCount,
                                        theftCount: theftCount,
                                        faultCount: faultCount,
                                        gridLoss: gridLoss,
                                        revenue: revenue,
                                        activeCases: activeCases,
                                      ),
                                    ),
                                    icon: const Icon(Icons.download_rounded,
                                        color: Color(0xFF00E5FF), size: 16),
                                    label: const Text("Save",
                                        style: TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFF00E5FF), width: 1),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _viewPdf(
                                      context,
                                      buildBytes: () => _buildPdfBytes(
                                        efficiency: efficiency,
                                        lastMonthEff: lastMonthEff,
                                        normalCount: normalCount,
                                        theftCount: theftCount,
                                        faultCount: faultCount,
                                        gridLoss: gridLoss,
                                        revenue: revenue,
                                        activeCases: activeCases,
                                      ),
                                    ),
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: Color(0xFF00E5FF), size: 16),
                                    label: const Text("View",
                                        style: TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFF00E5FF), width: 1),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _sharePdf(
                                      context,
                                      buildBytes: () => _buildPdfBytes(
                                        efficiency: efficiency,
                                        lastMonthEff: lastMonthEff,
                                        normalCount: normalCount,
                                        theftCount: theftCount,
                                        faultCount: faultCount,
                                        gridLoss: gridLoss,
                                        revenue: revenue,
                                        activeCases: activeCases,
                                      ),
                                    ),
                                    icon: const Icon(Icons.ios_share_rounded,
                                        color: Color(0xFF00E5FF), size: 16),
                                    label: const Text("Share",
                                        style: TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFF00E5FF), width: 1),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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