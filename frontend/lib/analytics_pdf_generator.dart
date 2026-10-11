import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AnalyticsPdfData {
  final int efficiency;
  final int lastMonthEff;
  final int normalCount;
  final int theftCount;
  final int faultCount;
  final int gridLoss;
  final double revenue;
  final int activeCases;
  final DateTime generatedAt;

  AnalyticsPdfData({
    required this.efficiency,
    required this.lastMonthEff,
    required this.normalCount,
    required this.theftCount,
    required this.faultCount,
    required this.gridLoss,
    required this.revenue,
    required this.activeCases,
    required this.generatedAt,
  });
}

String _fmtDateTimeAnalytics(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return "${d.day} ${months[d.month - 1]} ${d.year}, "
      "$h:${d.minute.toString().padLeft(2, '0')} $ampm";
}

Future<Uint8List> generateAnalyticsPdf(AnalyticsPdfData data,
    {Uint8List? logoBytes}) async {
  final doc = pw.Document();

  // Same palette as bill_pdf_generator.dart for visual consistency
  final navyBlue = PdfColor.fromHex('#0D1B2A');
  final dark = PdfColor.fromHex('#0A1628');
  final grey = PdfColor.fromHex('#666666');
  final cyan = PdfColor.fromHex('#00A9BD');
  final green = PdfColor.fromHex('#2E7D32');
  final red = PdfColor.fromHex('#C62828');

  final int totalMeters = data.normalCount + data.theftCount + data.faultCount;
  final int delta = data.efficiency - data.lastMonthEff;
  final bool improved = delta >= 0;

  pw.Widget? logoWidget;
  if (logoBytes != null) {
    logoWidget = pw.Container(
      width: 44,
      height: 44,
      decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(8)),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.cover),
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header — logo + company name ──
            pw.Row(
              children: [
                if (logoWidget != null) ...[
                  logoWidget,
                  pw.SizedBox(width: 12),
                ],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("GRIDEYE POWER DISTRIBUTION",
                        style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                            color: dark)),
                    pw.Text("System Analytics Report",
                        style: pw.TextStyle(fontSize: 10, color: grey)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: navyBlue, thickness: 1.5),
            pw.SizedBox(height: 4),
            pw.Text("Generated: ${_fmtDateTimeAnalytics(data.generatedAt)}",
                style: pw.TextStyle(fontSize: 9, color: grey)),
            pw.SizedBox(height: 20),

            // ── Overall Recovery Rate ──
            pw.Text("OVERALL RECOVERY RATE",
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyBlue)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: navyBlue, width: 1.2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("This Month",
                          style: pw.TextStyle(fontSize: 9, color: grey)),
                      pw.SizedBox(height: 2),
                      pw.Text("${data.efficiency}%",
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: cyan)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Last Month",
                          style: pw.TextStyle(fontSize: 9, color: grey)),
                      pw.SizedBox(height: 2),
                      pw.Text("${data.lastMonthEff}%",
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: grey)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          "${improved ? '\u25B2' : '\u25BC'} ${delta.abs()}% "
                          "${improved ? 'improvement' : 'decline'}",
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: improved ? green : red)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Meter Breakdown ──
            pw.Text("METER BREAKDOWN",
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyBlue)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _thA("Normal"),
                    _thA("Theft"),
                    _thA("Fault"),
                    _thA("Total Meters"),
                  ],
                ),
                pw.TableRow(children: [
                  _tdA(data.normalCount.toString()),
                  _tdA(data.theftCount.toString()),
                  _tdA(data.faultCount.toString()),
                  _tdA(totalMeters.toString()),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── System Metrics ──
            pw.Text("SYSTEM METRICS",
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyBlue)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                _metricRowA("Total Grid Loss", "${data.gridLoss.abs()} units"),
                _metricRowA(
                    "Revenue Recovered", "Rs. ${data.revenue.toStringAsFixed(0)}"),
                _metricRowA(
                    "Active Investigations", "${data.activeCases} cases"),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              "This report reflects live system data at the time of generation "
              "and is intended for internal administrative review.",
              style: pw.TextStyle(fontSize: 8, color: grey),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _thA(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center),
    );

pw.Widget _tdA(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
    );

pw.TableRow _metricRowA(String label, String value) => pw.TableRow(
      children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(value,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right)),
      ],
    );