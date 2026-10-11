import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bill_pdf_generator.dart';
import 'bill_report_screen.dart';
import 'jazzcash_payment_screen.dart';
import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────
// MY BILL SCREEN — Hero (2-column Amount Due / After Due Date +
// Pay Now) -> Bill Summary -> Meter Reading strip ->
// Collapsible Charges Breakdown. AppBar export icon opens a
// live, professional PDF bill report (with GridEye logo).
// Pay Now opens a SIMULATED JazzCash payment flow (see
// jazzcash_payment_screen.dart) — no real money moves; on
// success it sets meters/{meterID}.isPaid = true.
// ─────────────────────────────────────────────────────────────
class BillViewScreen extends StatelessWidget {
  final String meterID;
  const BillViewScreen({super.key, required this.meterID});

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m - 1];
  }

  Future<void> _openBillReport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      ),
    );

    try {
      final meterDoc = await FirebaseFirestore.instance
          .collection('meters')
          .doc(meterID)
          .get();
      final m = meterDoc.data() ?? {};

      final double units = (m['units'] ?? 0.0).toDouble();
      final double billEst = (m['billEst'] ?? 0.0).toDouble();
      final bool paid = m['isPaid'] == true;
      final dynamic ts = m['timestamp'];
      final String mID = m['meterId'] ?? meterID;
      final String area = (m['area'] ?? '').toString();
      final String city = (m['city'] ?? '').toString();

      DateTime issueDate = DateTime.now();
      if (ts is Timestamp) issueDate = ts.toDate();
      final dueDate = issueDate.add(const Duration(days: 15));

      final historySnap = await FirebaseFirestore.instance
          .collection('meters')
          .doc(meterID)
          .collection('usage_history')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      double previousUnits = 0;
      if (historySnap.docs.isNotEmpty) {
        previousUnits =
            (historySnap.docs.first.data()['units'] ?? 0.0).toDouble();
      }
      final double presentUnits = previousUnits + units;

      // Load app logo (already bundled via pubspec assets) for the PDF header
      Uint8List? logoBytes;
      try {
        final logoData = await rootBundle.load('assets/icon/icon.png');
        logoBytes = logoData.buffer.asUint8List();
      } catch (_) {
        logoBytes = null; // PDF still generates fine without the logo
      }

      final data = BillPdfData(
        meterID: mID,
        address: [area, city].where((s) => s.isNotEmpty).join(', '),
        billingMonth: "${_monthName(issueDate.month)} ${issueDate.year}",
        issueDate: issueDate,
        dueDate: dueDate,
        previousUnits: previousUnits,
        presentUnits: presentUnits,
        consumedUnits: units,
        costOfElectricity: billEst * 0.78,
        fuelAdjustment: billEst * 0.05,
        electricityDuty: billEst * 0.03,
        gst: billEst * 0.10,
        meterRent: billEst * 0.04,
        totalAmount: billEst,
        lateSurcharge: billEst * 0.05,
        paid: paid,
      );

      if (context.mounted) Navigator.pop(context); // close loading
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BillReportScreen(data: data, logoBytes: logoBytes)),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't generate report: $e")),
        );
      }
    }
  }

  Future<void> _openPayment(BuildContext context, double amount) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JazzCashPaymentScreen(
          meterID: meterID,
          amount: amount,
        ),
      ),
    );
    // No manual refresh needed — the meter StreamBuilder below picks up
    // isPaid: true automatically once the payment screen sets it.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(
            style: GoogleFonts.orbitron(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
            children: const [
              TextSpan(text: "MY ", style: TextStyle(color: Colors.white)),
              TextSpan(text: "BILL", style: TextStyle(color: Color(0xFF00E5FF))),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded,
                color: Color(0xFF00E5FF), size: 20),
            onPressed: () => _openBillReport(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meters')
            .doc(meterID)
            .snapshots(),
        builder: (context, meterSnap) {
          if (meterSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!meterSnap.hasData || !meterSnap.data!.exists) {
            return const Center(
              child: Text("Meter Not Found",
                  style: TextStyle(color: Colors.white)),
            );
          }

          final m = meterSnap.data!.data() as Map<String, dynamic>;
          final double units = (m['units'] ?? 0.0).toDouble();
          final double billEst = (m['billEst'] ?? 0.0).toDouble();
          final bool paid = m['isPaid'] == true;
          final dynamic ts = m['timestamp'];
          final String mID = m['meterId'] ?? meterID;
          final String area = (m['area'] ?? '').toString();
          final String city = (m['city'] ?? '').toString();

          DateTime issueDate = DateTime.now();
          if (ts is Timestamp) issueDate = ts.toDate();
          final dueDate = issueDate.add(const Duration(days: 15));

          final double costOfElectricity = billEst * 0.78;
          final double fuelAdjustment = billEst * 0.05;
          final double electricityDuty = billEst * 0.03;
          final double gst = billEst * 0.10;
          final double meterRent = billEst * 0.04;
          final double lateSurcharge = billEst * 0.05;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('meters')
                .doc(meterID)
                .collection('usage_history')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get()
                .asStream(),
            builder: (context, historySnap) {
              double previousUnits = 0;
              if (historySnap.hasData && historySnap.data!.docs.isNotEmpty) {
                final prevData = historySnap.data!.docs.first.data()
                    as Map<String, dynamic>;
                previousUnits = (prevData['units'] ?? 0.0).toDouble();
              }
              final double presentUnits = previousUnits + units;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroPayableCard(
                      billEst: billEst,
                      lateSurcharge: lateSurcharge,
                      paid: paid,
                      dueDate: dueDate,
                      onPayNow: () => _openPayment(context, billEst),
                    ),
                    const SizedBox(height: 16),
                    _BillSummaryCard(
                      meterID: mID,
                      area: area,
                      city: city,
                      issueDate: issueDate,
                    ),
                    const SizedBox(height: 14),
                    _MeterReadingStrip(
                      previousUnits: previousUnits,
                      presentUnits: presentUnits,
                      consumedUnits: units,
                    ),
                    const SizedBox(height: 14),
                    _ChargesBreakdownExpandable(
                      costOfElectricity: costOfElectricity,
                      fuelAdjustment: fuelAdjustment,
                      electricityDuty: electricityDuty,
                      gst: gst,
                      meterRent: meterRent,
                      total: billEst,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return "${d.day} ${months[d.month - 1]} ${d.year}";
}

String _monthNameTop(int m) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return names[m - 1];
}

// ─────────────────────────────────────────────────────────────
// HERO CARD — 2-column layout:
// LEFT  = Amount Due (orange/yellow) + Due Date
// RIGHT = After Due Date Amount (red) + Date
// Below = Pay Now button
// ─────────────────────────────────────────────────────────────
class _HeroPayableCard extends StatelessWidget {
  final double billEst;
  final double lateSurcharge;
  final bool paid;
  final DateTime dueDate;
  final VoidCallback onPayNow;

  const _HeroPayableCard({
    required this.billEst,
    required this.lateSurcharge,
    required this.paid,
    required this.dueDate,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final bool overdue = !paid && DateTime.now().isAfter(dueDate);
    final Color statusColor = paid
        ? const Color(0xFF69F0AE)
        : overdue
            ? const Color(0xFFFF5252)
            : const Color(0xFFBB86FC);
    final String statusLabel = paid ? "PAID" : overdue ? "OVERDUE" : "UNPAID";

    const Color amountDueColor = Color(0xFFFFD740); // orange/yellow
    const Color afterDueColor = Color(0xFFFF5252); // red

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2137), Color(0xFF0A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF00C4D4).withOpacity(0.4),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "GridEye Power",
                    style: GoogleFonts.orbitron(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (paid)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("AMOUNT PAID",
                    style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 10.5,
                        letterSpacing: 0.6)),
                const SizedBox(height: 8),
                Text(
                  "Rs. ${billEst.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF69F0AE), size: 16),
                    SizedBox(width: 6),
                    Text(
                      "Payment received — thank you",
                      style: TextStyle(
                        color: Color(0xFF69F0AE),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else ...[
            // ── 2-column row: Amount Due | After Due Date ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT — Amount Due
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("AMOUNT DUE",
                            style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 10.5,
                                letterSpacing: 0.6)),
                        const SizedBox(height: 8),
                        Text(
                          "Rs. ${billEst.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: amountDueColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                color: amountDueColor, size: 13),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                "Due: ${_fmtDate(dueDate)}",
                                style: const TextStyle(
                                  color: amountDueColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white.withOpacity(0.1),
                  ),

                  // RIGHT — After Due Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("AFTER DUE DATE",
                            style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 10.5,
                                letterSpacing: 0.6)),
                        const SizedBox(height: 8),
                        Text(
                          "Rs. ${(billEst + lateSurcharge).toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: afterDueColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_busy_rounded,
                                color: afterDueColor, size: 13),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                "From: ${_fmtDate(dueDate.add(const Duration(days: 1)))}",
                                style: const TextStyle(
                                  color: afterDueColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onPayNow,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  "PAY NOW",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BILL SUMMARY CARD
// ─────────────────────────────────────────────────────────────
class _BillSummaryCard extends StatelessWidget {
  final String meterID;
  final String area;
  final String city;
  final DateTime issueDate;

  const _BillSummaryCard({
    required this.meterID,
    required this.area,
    required this.city,
    required this.issueDate,
  });

  @override
  Widget build(BuildContext context) {
    final address = [area, city].where((s) => s.isNotEmpty).join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded,
                  color: Color(0xFF00E5FF), size: 15),
              const SizedBox(width: 8),
              Text("BILL SUMMARY",
                  style: GoogleFonts.orbitron(
                      color: const Color(0xFF00E5FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 14),
          _row("Consumer ID", meterID,
              icon: Icons.badge_rounded, iconColor: const Color(0xFF00E5FF)),
          _row("Address", address.isEmpty ? "Not Available" : address,
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFFF5252)),
          _row("Billing Month",
              "${_monthNameTop(issueDate.month)} ${issueDate.year}",
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFFBB86FC)),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? Colors.white38),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(k,
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// METER READING STRIP
// ─────────────────────────────────────────────────────────────
class _MeterReadingStrip extends StatelessWidget {
  final double previousUnits;
  final double presentUnits;
  final double consumedUnits;

  const _MeterReadingStrip({
    required this.previousUnits,
    required this.presentUnits,
    required this.consumedUnits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded,
                  color: Color(0xFF00E5FF), size: 15),
              const SizedBox(width: 8),
              Text("METER READING",
                  style: GoogleFonts.orbitron(
                      color: const Color(0xFF00E5FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _block("PREVIOUS",
                      previousUnits.toStringAsFixed(0), Colors.white54)),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white24, size: 15),
              Expanded(
                  child: _block("PRESENT",
                      presentUnits.toStringAsFixed(0), Colors.white)),
              Container(
                  width: 1, height: 30, color: Colors.white.withOpacity(0.08)),
              Expanded(
                child: _block("CONSUMED",
                    "${consumedUnits.toStringAsFixed(1)} kWh",
                    const Color(0xFF69F0AE)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _block(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.orbitron(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHARGES BREAKDOWN — collapsible
// ─────────────────────────────────────────────────────────────
class _ChargesBreakdownExpandable extends StatefulWidget {
  final double costOfElectricity;
  final double fuelAdjustment;
  final double electricityDuty;
  final double gst;
  final double meterRent;
  final double total;

  const _ChargesBreakdownExpandable({
    required this.costOfElectricity,
    required this.fuelAdjustment,
    required this.electricityDuty,
    required this.gst,
    required this.meterRent,
    required this.total,
  });

  @override
  State<_ChargesBreakdownExpandable> createState() =>
      _ChargesBreakdownExpandableState();
}

class _ChargesBreakdownExpandableState
    extends State<_ChargesBreakdownExpandable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFFFFD740), size: 15),
                    const SizedBox(width: 8),
                    Text("CHARGES BREAKDOWN",
                        style: GoogleFonts.orbitron(
                            color: const Color(0xFF00E5FF),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1)),
                  ],
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38,
                  size: 22,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            _row("Cost of Electricity",
                "Rs. ${widget.costOfElectricity.toStringAsFixed(0)}"),
            _row("Fuel Price Adjustment",
                "Rs. ${widget.fuelAdjustment.toStringAsFixed(0)}"),
            _row("Electricity Duty",
                "Rs. ${widget.electricityDuty.toStringAsFixed(0)}"),
            _row("General Sales Tax", "Rs. ${widget.gst.toStringAsFixed(0)}"),
            _row("Meter Rent", "Rs. ${widget.meterRent.toStringAsFixed(0)}"),
            const Divider(color: Colors.white12, height: 20),
            _row("Total Amount", "Rs. ${widget.total.toStringAsFixed(0)}",
                bold: true, valueColor: const Color(0xFF00E5FF)),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(k,
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: valueColor ?? Colors.white,
                fontSize: bold ? 13.5 : 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}