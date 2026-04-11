import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Colour palette ────────────────────────────────────────────────
const kPrimary = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg = Color(0xFFF4F6FB);
const kCardBg = Colors.white;
const kTextDark = Color(0xFF1F2937);
const kTextMid = Color(0xFF6B7280);
const kBorder = Color(0xFFE5E7EB);
const kGreen = Color(0xFF34A853);
const kRed = Color(0xFFEA4335);

class PatientPrescriptionPdfScreen extends StatefulWidget {
  final PatientPrescription prescription;

  const PatientPrescriptionPdfScreen({
    super.key,
    required this.prescription,
  });

  @override
  State<PatientPrescriptionPdfScreen> createState() =>
      _PatientPrescriptionPdfScreenState();
}

class _PatientPrescriptionPdfScreenState
    extends State<PatientPrescriptionPdfScreen> {
  bool _generating = false;
  bool _generated = false;
  double _progress = 0;
  String? _savedPath;
  Uint8List? _pdfBytes;

  PatientPrescription get _rx => widget.prescription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _generatePdf());
  }

  // ── Date helpers ─────────────────────────────────────────────────
  String _fmtDate(DateTime d) {
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  String _fmtDateTime(DateTime d) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${months[d.month]} ${d.year}  ·  $h:$min $ampm';
  }

  // ── PDF builder ──────────────────────────────────────────────────
  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final rx = _rx;

    // ── Fonts via printing package (no asset files needed) ────────
    final ttf = await PdfGoogleFonts.robotoRegular();
    final ttfBold = await PdfGoogleFonts.robotoBold();
    final ttfItalic = await PdfGoogleFonts.robotoItalic();

    // ── PDF colours ───────────────────────────────────────────────
    final pdfPrimary = PdfColor.fromHex('#1A73E8');
    final pdfPrimaryDark = PdfColor.fromHex('#1558C0');
    final pdfGreen = PdfColor.fromHex('#34A853');
    final pdfTextDark = PdfColor.fromHex('#1F2937');
    final pdfTextMid = PdfColor.fromHex('#6B7280');
    final pdfBorder = PdfColor.fromHex('#E5E7EB');
    final pdfBg = PdfColor.fromHex('#F4F6FB');
    final pdfPrimaryBg = PdfColor.fromHex('#E8F0FE');

    // ── Shared style helper ───────────────────────────────────────
    pw.TextStyle style({
      bool bold = false,
      bool italic = false,
      double size = 10,
      PdfColor? color,
    }) =>
        pw.TextStyle(
          font: bold
              ? ttfBold
              : italic
                  ? ttfItalic
                  : ttf,
          fontSize: size,
          color: color ?? pdfTextDark,
        );

    // ── Reusable widgets ──────────────────────────────────────────
    pw.Widget sectionLabel(String t) => pw.Row(
          children: [
            pw.Container(
              width: 3,
              height: 12,
              decoration: pw.BoxDecoration(
                color: pdfPrimary,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              t,
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 9,
                color: pdfPrimary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        );

    pw.Widget infoBox(
      String text, {
      PdfColor? bg,
      PdfColor? borderColor,
    }) =>
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: bg ?? pdfPrimaryBg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
              color: borderColor ?? pdfPrimary,
              width: 0.5,
            ),
          ),
          child: pw.Text(text, style: style(size: 10)),
        );

    pw.Widget smallChip(String t) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 7, vertical: 3),
          decoration: pw.BoxDecoration(
            color: pdfBg,
            borderRadius: pw.BorderRadius.circular(5),
            border: pw.Border.all(color: pdfBorder, width: 0.5),
          ),
          child: pw.Text(t,
              style: style(size: 9, color: pdfTextMid)),
        );

    // ── Page ──────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 28, vertical: 24),

        // ════════════════════════════════════════════════════════
        //  HEADER  (repeats on every page)
        // ════════════════════════════════════════════════════════
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Clinic + Doctor gradient block ────────────────
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [pdfPrimaryDark, pdfPrimary],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  // Clinic row
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(
                        14, 14, 14, 10),
                    child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              rx.clinicName,
                              style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 15,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              '${rx.clinicAddress}  ·  Ph: ${rx.clinicContact}',
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 9,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                        // Rx badge
                        pw.Container(
                          padding:
                              const pw.EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius:
                                pw.BorderRadius.circular(8),
                          ),
                          child: pw.Text(
                            'Rx #${rx.prescriptionId}',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 14,
                              color: pdfPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider line
                  pw.Divider(
                    color: PdfColors.white,
                    thickness: 0.5,
                    indent: 14,
                    endIndent: 14,
                  ),
                  // Doctor row
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(
                        14, 8, 14, 14),
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          rx.doctorName,
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 13,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${rx.qualification}  ·  ${rx.specialization}',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                        if (rx.regNo?.isNotEmpty == true) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Reg. No. ${rx.regNo}',
                            style: pw.TextStyle(
                              font: ttfItalic,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ── Patient info bar ──────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: pdfBg,
                borderRadius: pw.BorderRadius.circular(10),
                border:
                    pw.Border.all(color: pdfBorder, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(rx.patientName,
                          style: style(bold: true, size: 13)),
                      pw.SizedBox(height: 5),
                      pw.Row(children: [
                        if (rx.patientAge != null &&
                            rx.patientAge! > 0) ...[
                          smallChip('${rx.patientAge} yrs'),
                          pw.SizedBox(width: 6),
                        ],
                        if (rx.patientGender?.isNotEmpty ==
                            true) ...[
                          smallChip(rx.patientGender!),
                          pw.SizedBox(width: 6),
                        ],
                        if (rx.tokenNumber != null)
                          smallChip(
                              'Token #${rx.tokenNumber}'),
                      ]),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date',
                          style: style(
                              size: 9, color: pdfTextMid)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _fmtDate(rx.prescriptionDate),
                        style: style(bold: true, size: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
          ],
        ),

        // ════════════════════════════════════════════════════════
        //  BODY
        // ════════════════════════════════════════════════════════
        build: (context) => [
          // ── Symptoms ────────────────────────────────────────
          if (rx.symptoms?.isNotEmpty == true) ...[
            sectionLabel('SYMPTOMS'),
            pw.SizedBox(height: 6),
            infoBox(
              rx.symptoms!,
              bg: PdfColor.fromHex('#FFFBEB'),
              borderColor: PdfColor.fromHex('#FDE68A'),
            ),
            pw.SizedBox(height: 14),
          ],

          // ── Diagnosis ────────────────────────────────────────
          if (rx.diagnosis?.isNotEmpty == true) ...[
            sectionLabel('DIAGNOSIS'),
            pw.SizedBox(height: 6),
            infoBox(rx.diagnosis!),
            pw.SizedBox(height: 14),
          ],

          // ── Medicines table ──────────────────────────────────
          sectionLabel('MEDICINES'),
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(
                  color: pdfBorder, width: 0.8),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.2),
                  1: const pw.FlexColumnWidth(2.2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.6),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                      color: pdfBorder, width: 0.5),
                ),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: pdfBg),
                    children: [
                      'MEDICINE',
                      'FREQ / DOSE',
                      'TIMING',
                      'DURATION',
                    ]
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets
                                  .symmetric(
                                      horizontal: 8,
                                      vertical: 7),
                              child: pw.Text(
                                h,
                                style: pw.TextStyle(
                                  font: ttfBold,
                                  fontSize: 8,
                                  color: pdfTextMid,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  // Medicine rows
                  ...rx.medicines.map((m) => pw.TableRow(
                        children: [
                          // Name + type tag
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw
                                  .CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  m.medicineName
                                              ?.isNotEmpty ==
                                          true
                                      ? m.medicineName!
                                      : 'Med #${m.medicineId ?? '-'}',
                                  style: style(
                                      bold: true, size: 10),
                                ),
                                if (m.extraInfo
                                        ?.isNotEmpty ==
                                    true) ...[
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    m.extraInfo!,
                                    style: style(
                                        size: 9,
                                        color: pdfPrimary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Dose
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.all(8),
                            child: pw.Center(
                              child: pw.Text(
                                m.doseDisplay,
                                style: style(
                                    bold: true, size: 10),
                                textAlign:
                                    pw.TextAlign.center,
                              ),
                            ),
                          ),
                          // Timing
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.all(8),
                            child: pw.Center(
                              child: pw.Text(
                                m.timing ?? '-',
                                style: style(size: 10),
                                textAlign:
                                    pw.TextAlign.center,
                              ),
                            ),
                          ),
                          // Duration
                          pw.Padding(
                            padding:
                                const pw.EdgeInsets.all(8),
                            child: pw.Center(
                              child: pw.Text(
                                m.duration ?? '-',
                                style: style(
                                    bold: true, size: 10),
                                textAlign:
                                    pw.TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Clinical notes + Advice ──────────────────────────
          if (rx.clinicalNotes?.isNotEmpty == true ||
              rx.advice?.isNotEmpty == true) ...[
            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                if (rx.clinicalNotes?.isNotEmpty == true)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        sectionLabel('CLINICAL INSTRUCTIONS'),
                        pw.SizedBox(height: 6),
                        infoBox(
                          rx.clinicalNotes!,
                          bg: PdfColor.fromHex('#EFF6FF'),
                          borderColor:
                              PdfColor.fromHex('#BFDBFE'),
                        ),
                      ],
                    ),
                  ),
                if (rx.clinicalNotes?.isNotEmpty == true &&
                    rx.advice?.isNotEmpty == true)
                  pw.SizedBox(width: 10),
                if (rx.advice?.isNotEmpty == true)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        sectionLabel("DOCTOR'S ADVICE"),
                        pw.SizedBox(height: 6),
                        infoBox(
                          rx.advice!,
                          bg: PdfColor.fromHex('#F0FFF4'),
                          borderColor:
                              PdfColor.fromHex('#A7F3D0'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
          ],

          // ── Follow-up ────────────────────────────────────────
          if (rx.followUpDate != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0FFF4'),
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(
                  color: PdfColor.fromHex('#A7F3D0'),
                  width: 0.8,
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'NEXT FOLLOW-UP:  ',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 9,
                      color: pdfGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.Text(
                    _fmtDateTime(rx.followUpDate!),
                    style: style(bold: true, size: 11),
                  ),
                  if (rx.followUpRoom?.isNotEmpty == true ||
                      rx.followUpInstruction?.isNotEmpty ==
                          true) ...[
                    pw.SizedBox(width: 8),
                    pw.Text(
                      [
                        if (rx.followUpRoom?.isNotEmpty ==
                            true)
                          rx.followUpRoom!,
                        if (rx.followUpInstruction
                                ?.isNotEmpty ==
                            true)
                          rx.followUpInstruction!,
                      ].join('  ·  '),
                      style: style(
                          size: 9, color: pdfTextMid),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // ── Footer / Signature ───────────────────────────────
          pw.Divider(color: pdfBorder, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'This prescription is valid for 30 days.',
                    style:
                        style(size: 9, color: pdfTextMid),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Dispensed by licensed pharmacist only.',
                    style:
                        style(size: 9, color: pdfTextMid),
                  ),
                ],
              ),
              pw.SizedBox(
                width: 150,
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.center,
                  children: [
                    pw.Divider(
                        color: pdfTextDark,
                        thickness: 0.8),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      rx.doctorName,
                      style: style(bold: true, size: 11),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      '${rx.qualification}  ·  ${rx.specialization}',
                      style: style(
                          size: 9, color: pdfTextMid),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

Future<void> _generatePdf() async {
  setState(() {
    _generating = true;
    _progress = 0;
  });

  try {
    for (var i = 1; i <= 4; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _progress = i / 5);
    }

    final bytes = await _buildPdf();

    setState(() {
      _pdfBytes = bytes;
      _progress = 1.0;
      _generating = false;
      _generated = true;
    });
  } catch (e) {
    setState(() {
      _generating = false;
      _progress = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

Future<void> _downloadPdf() async {
  if (_pdfBytes == null) return;
  // Uses printing package's built-in save — no path_provider needed
  await Printing.layoutPdf(
    onLayout: (_) async => _pdfBytes!,
    name: 'Rx_${_rx.prescriptionId}_${_rx.patientName}',
  );
}

Future<void> _sharePdf() async {
  if (_pdfBytes == null) return;
  await Printing.sharePdf(
    bytes: _pdfBytes!,
    filename:
        'Rx_${_rx.prescriptionId}_${_rx.patientName.replaceAll(' ', '_')}.pdf',
  );
}

Future<void> _printPdf() async {
  if (_pdfBytes == null) return;
  await Printing.layoutPdf(
    onLayout: (_) async => _pdfBytes!,
    name: 'Rx_${_rx.prescriptionId}_${_rx.patientName}',
  );
}

 

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _generating
                ? _buildGenerating()
                : _generated
                    ? _buildPreview()
                    : _buildError(),
          ),
          if (_generated) _buildBottomBar(),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────
  Widget _buildHeader() => Container(
        color: kCardBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(4, 6, 14, 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: kTextDark,
                      size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prescription PDF',
                        style: TextStyle(
                          color: kTextDark,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Rx #${_rx.prescriptionId}  ·  ${_rx.patientName}',
                        style: const TextStyle(
                            color: kTextMid, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_generated) ...[
                  IconButton(
                    icon: const Icon(Icons.print_rounded,
                        color: kPrimary),
                    tooltip: 'Print',
                    onPressed: _printPdf,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded,
                        color: kPrimary),
                    tooltip: 'Share',
                    onPressed: _sharePdf,
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  // ── Generating state ──────────────────────────────────────────────
  Widget _buildGenerating() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: kPrimaryBg,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: kPrimary,
                    size: 40),
              ),
              const SizedBox(height: 28),
              const Text(
                'Generating Prescription PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This will only take a moment',
                style: TextStyle(
                    fontSize: 13, color: kTextMid),
              ),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: kBorder,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              ..._steps.asMap().entries.map((e) {
                final done =
                    _progress >= (e.key + 1) / _steps.length;
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 300),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color:
                              done ? kPrimary : kBorder,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : Icons
                                  .radio_button_unchecked_rounded,
                          color: done
                              ? Colors.white
                              : kTextMid,
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          color: done
                              ? kTextDark
                              : kTextMid,
                          fontWeight: done
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );

  static const _steps = [
    'Fetching prescription details',
    'Formatting medicines & diagnosis',
    'Composing clinic & doctor info',
    'Finalising PDF document',
  ];

  // ── PDF preview (scrollable, printable) ──────────────────────────
  Widget _buildPreview() => PdfPreview(
        build: (_) async => _pdfBytes!,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName:
            'Rx_${_rx.prescriptionId}_${_rx.patientName.replaceAll(' ', '_')}.pdf',
        actions: const [],
        loadingWidget: const Center(
          child:
              CircularProgressIndicator(color: kPrimary),
        ),
        actionBarTheme: const PdfActionBarTheme(
          backgroundColor: kCardBg,
          iconColor: kPrimary,
          textStyle: TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );

  // ── Error state ───────────────────────────────────────────────────
  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: kRed, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Failed to generate PDF',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again',
              style:
                  TextStyle(fontSize: 13, color: kTextMid),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generatePdf,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );

  // ── Bottom action bar ─────────────────────────────────────────────
  Widget _buildBottomBar() => Container(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: const BoxDecoration(
          color: kCardBg,
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                offset: Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
                child: _barBtn(
              icon: Icons.print_rounded,
              label: 'Print',
              onTap: _printPdf,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _barBtn(
              icon: Icons.download_rounded,
              label: 'Download',
              onTap: _downloadPdf,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _barBtn(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: _sharePdf,
            )),
          ],
        ),
      );

  Widget _barBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1558C0), kPrimary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
}