import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'bill_pdf_generator.dart';
import 'dart:typed_data';

class BillReportScreen extends StatelessWidget {
  final BillPdfData data;
  final Uint8List? logoBytes;
  const BillReportScreen({super.key, required this.data, this.logoBytes});

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
        title: Text(
          "BILL REPORT",
          style: GoogleFonts.orbitron(
              color: const Color(0xFF00E5FF), fontSize: 15),
        ),
      ),
      body: PdfPreview(
        build: (format) => generateBillPdf(data, logoBytes: logoBytes),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: "GridEye_Bill_${data.meterID}.pdf",
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      ),
    );
  }
}