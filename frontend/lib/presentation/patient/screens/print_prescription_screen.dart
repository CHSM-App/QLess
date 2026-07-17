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
const kPageBg = Color(0xFFF8F9FB);

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

  final ttf = await PdfGoogleFonts.robotoRegular();
  final ttfBold = await PdfGoogleFonts.robotoBold();
  final ttfItalic = await PdfGoogleFonts.robotoItalic();

  pw.TextStyle s({bool bold = false, bool italic = false, double size = 10}) =>
      pw.TextStyle(
        font: bold ? ttfBold : italic ? ttfItalic : ttf,
        fontSize: size,
        color: PdfColors.black,
      );

  pw.Widget labeledRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(label, style: s(bold: true, size: 9)),
            ),
            pw.Text(': ', style: s(size: 9)),
            pw.Expanded(child: pw.Text(value, style: s(size: 9))),
          ],
        ),
      );

  // Dose / Freq rendered as a Morning–Afternoon–Night mini table.
  List<String> splitSlots(String? raw) {
    final parts = (raw ?? '').split('-').map((p) => p.trim()).toList();
    while (parts.length < 3) {
      parts.add('-');
    }
    return parts.take(3).map((p) => p.isEmpty ? '-' : p).toList();
  }

  pw.Widget doseCell(String? raw) {
    final dose = splitSlots(raw);
    pw.Widget head(String t) => pw.Expanded(
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  font: ttfBold, fontSize: 7, color: PdfColors.grey600)),
        );
    pw.Widget val(String t) => pw.Expanded(
          child: pw.Text(t,
              textAlign: pw.TextAlign.center, style: s(bold: true, size: 8)),
        );
    return pw.Column(children: [
      pw.Row(children: [head('M'), head('A'), head('N')]),
      pw.SizedBox(height: 2),
      pw.Divider(height: 0.5, thickness: 0.4, color: PdfColors.grey400),
      pw.SizedBox(height: 2),
      pw.Row(children: [val(dose[0]), val(dose[1]), val(dose[2])]),
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),

      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Clinic & Doctor
          pw.Text(rx.clinicName, style: s(bold: true, size: 14)),
          pw.SizedBox(height: 2),
          pw.Text(
            '${rx.clinicAddress}  |  Ph: ${rx.clinicContact}',
            style: s(size: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(rx.doctorName, style: s(bold: true, size: 11)),
          pw.Text(
            '${rx.qualification}  |  ${rx.specialization}'
            '${rx.regNo?.isNotEmpty == true ? '  |  Reg. No. ${rx.regNo}' : ''}',
            style: s(size: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.8, color: PdfColors.black),
          pw.SizedBox(height: 6),

          // Patient info — all left-aligned
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Patient: ${rx.patientName}', style: s(bold: true, size: 11)),
              pw.SizedBox(height: 2),
              pw.Text(
                [
                  if (rx.patientAge != null && rx.patientAge! > 0) '${rx.patientAge} yrs',
                  if (rx.patientGender?.isNotEmpty == true) rx.patientGender!,
                  if (rx.tokenNumber != null) 'Token #${rx.tokenNumber}',
                ].join('  |  '),
                style: s(size: 9),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Rx #${rx.prescriptionId}', style: s(bold: true, size: 11)),
              pw.SizedBox(height: 2),
              pw.Text(_fmtDate(rx.prescriptionDate), style: s(size: 9)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 10),
        ],
      ),

      build: (_) => [
        // Symptoms
        if (rx.symptoms?.isNotEmpty == true) ...[
          labeledRow('Symptoms', rx.symptoms!),
          pw.SizedBox(height: 6),
        ],

        // Diagnosis
        if (rx.diagnosis?.isNotEmpty == true) ...[
          labeledRow('Diagnosis', rx.diagnosis!),
          pw.SizedBox(height: 10),
        ],

        // Medicines table
        pw.Text('Medicines', style: s(bold: true, size: 10)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: ['Medicine', 'Dose / Freq', 'Timing', 'Duration']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: pw.Text(h, style: s(bold: true, size: 9)),
                      ))
                  .toList(),
            ),
            // Rows
            ...rx.medicines.map((m) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            m.medicineName?.isNotEmpty == true
                                ? m.medicineName!
                                : 'Med #${m.medicineId ?? '-'}',
                            style: s(bold: true, size: 9),
                          ),
                          if (m.extraInfo?.isNotEmpty == true)
                            pw.Text(m.extraInfo!, style: s(size: 8, italic: true)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 5),
                      child: doseCell(m.doseDisplay),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 5),
                      child: pw.Text(m.timing ?? '-', style: s(size: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 5),
                      child: pw.Text(m.duration ?? '-', style: s(size: 9)),
                    ),
                  ],
                )),
          ],
        ),
        pw.SizedBox(height: 10),

        // Clinical Notes
        if (rx.clinicalNotes?.isNotEmpty == true) ...[
          labeledRow('Instructions', rx.clinicalNotes!),
          pw.SizedBox(height: 6),
        ],

        // Advice
        if (rx.advice?.isNotEmpty == true) ...[
          labeledRow("Doctor's Advice", rx.advice!),
          pw.SizedBox(height: 6),
        ],

        // Follow-up
        if (rx.followUpDate != null) ...[
          pw.SizedBox(height: 4),
          labeledRow(
            'Follow-up',
            [
              _fmtDateTime(rx.followUpDate!),
              if (rx.followUpRoom?.isNotEmpty == true) rx.followUpRoom!,
              if (rx.followUpInstruction?.isNotEmpty == true)
                rx.followUpInstruction!,
            ].join('  |  '),
          ),
          pw.SizedBox(height: 10),
        ],

        // Footer
        pw.SizedBox(height: 20),
        pw.Divider(thickness: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Valid for 30 days from date of issue.', style: s(size: 8)),
                pw.Text('Dispensed by licensed pharmacist only.', style: s(size: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 24), // signature space
                pw.Container(width: 140, height: 0.5, color: PdfColors.black),
                pw.SizedBox(height: 3),
                pw.Text(rx.doctorName, style: s(bold: true, size: 10)),
                pw.Text('${rx.qualification}  |  ${rx.specialization}',
                    style: s(size: 8)),
              ],
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
      backgroundColor: kPageBg,
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
                          fontSize: 16,
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
                  fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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