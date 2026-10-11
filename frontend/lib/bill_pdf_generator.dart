import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BillPdfData {
  final String meterID;
  final String address;
  final String billingMonth;
  final DateTime issueDate;
  final DateTime dueDate;
  final double previousUnits;
  final double presentUnits;
  final double consumedUnits;
  final double costOfElectricity;
  final double fuelAdjustment;
  final double electricityDuty;
  final double gst;
  final double meterRent;
  final double totalAmount;
  final double lateSurcharge;
  final bool paid;

  BillPdfData({
    required this.meterID,
    required this.address,
    required this.billingMonth,
    required this.issueDate,
    required this.dueDate,
    required this.previousUnits,
    required this.presentUnits,
    required this.consumedUnits,
    required this.costOfElectricity,
    required this.fuelAdjustment,
    required this.electricityDuty,
    required this.gst,
    required this.meterRent,
    required this.totalAmount,
    required this.lateSurcharge,
    required this.paid,
  });
}

String _fmtDatePdf(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return "${d.day} ${months[d.month - 1]} ${d.year}";
}

Future<Uint8List> generateBillPdf(BillPdfData data, {Uint8List? logoBytes}) async {
  final doc = pw.Document();

  // Headings now use the app's dark navy blue (matches Color(0xFF0D1B2A))
  // instead of cyan, for consistency with the in-app card/appbar color.
  final navyBlue = PdfColor.fromHex('#0D1B2A');
  final dark = PdfColor.fromHex('#0A1628');
  final grey = PdfColor.fromHex('#666666');
  final green = PdfColor.fromHex('#2E7D32');
  final red = PdfColor.fromHex('#C62828');
  final amber = PdfColor.fromHex('#B8860B');

  final bool overdue = !data.paid && DateTime.now().isAfter(data.dueDate);
  final statusText = data.paid ? "PAID" : (overdue ? "OVERDUE" : "UNPAID");
  final statusColor = data.paid ? green : (overdue ? red : amber);

  pw.Widget? logoWidget;
  if (logoBytes != null) {
    logoWidget = pw.Container(
      width: 44,
      height: 44,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
      ),
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
            // Header — logo + company name + status badge
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
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
                        pw.Text("Electricity Consumer Bill",
                            style: pw.TextStyle(fontSize: 10, color: grey)),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: statusColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    statusText,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold),
                  ),
                )
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: navyBlue, thickness: 1.5),
            pw.SizedBox(height: 16),

            // Consumer info + billing period
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _infoBlock("CONSUMER INFORMATION", [
                    ["Consumer ID", data.meterID],
                    ["Address", data.address],
                    ["Tariff Category", "Residential A-1"],
                  ], navyBlue, grey),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: _infoBlock("BILLING PERIOD", [
                    ["Billing Month", data.billingMonth],
                    ["Issue Date", _fmtDatePdf(data.issueDate)],
                    ["Due Date", _fmtDatePdf(data.dueDate)],
                  ], navyBlue, grey),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Meter reading
            pw.Text("METER READING",
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyBlue)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _th("Previous Reading"),
                    _th("Present Reading"),
                    _th("Units Consumed"),
                  ],
                ),
                pw.TableRow(children: [
                  _td(data.previousUnits.toStringAsFixed(0)),
                  _td(data.presentUnits.toStringAsFixed(0)),
                  _td("${data.consumedUnits.toStringAsFixed(1)} kWh"),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),

            // Charges breakdown
            pw.Text("CHARGES BREAKDOWN",
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyBlue)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                _chargeRow("Cost of Electricity", data.costOfElectricity),
                _chargeRow("Fuel Price Adjustment", data.fuelAdjustment),
                _chargeRow("Electricity Duty", data.electricityDuty),
                _chargeRow("General Sales Tax", data.gst),
                _chargeRow("Meter Rent", data.meterRent),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Total Amount",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                          "Rs. ${data.totalAmount.toStringAsFixed(0)}",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Payable amount — now with due/after dates under each amount
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: navyBlue, width: 1.2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Payable Within Due Date",
                          style: pw.TextStyle(fontSize: 9, color: grey)),
                      pw.SizedBox(height: 2),
                      pw.Text("Rs. ${data.totalAmount.toStringAsFixed(0)}",
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: amber)),
                      pw.SizedBox(height: 4),
                      pw.Text("Due by ${_fmtDatePdf(data.dueDate)}",
                          style: pw.TextStyle(fontSize: 8, color: grey)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Payable After Due Date",
                          style: pw.TextStyle(fontSize: 9, color: grey)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                          "Rs. ${(data.totalAmount + data.lateSurcharge).toStringAsFixed(0)}",
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: red)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          "From ${_fmtDatePdf(data.dueDate.add(const Duration(days: 1)))}",
                          style: pw.TextStyle(fontSize: 8, color: grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _infoBlock(String title, List<List<String>> rows, PdfColor titleColor,
    PdfColor labelColor) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleColor)),
        pw.SizedBox(height: 8),
        ...rows.map((r) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(r[0], style: pw.TextStyle(fontSize: 9, color: labelColor)),
                  pw.Flexible(
                    child: pw.Text(r[1],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            )),
      ],
    ),
  );
}

pw.Widget _th(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center),
    );

pw.Widget _td(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
    );

pw.TableRow _chargeRow(String label, double amount) => pw.TableRow(
      children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text("Rs. ${amount.toStringAsFixed(0)}",
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right)),
      ],
    );