// AI medical report summaries — shared by the doctor and patient apps.
//   ReportCaptureScreen  photos (camera/gallery, ≤ 6) or one PDF → Summarize
//   ReportDetailScreen   summary + original pages; doctor: assign / save / discard
//   ReportsListScreen    unassigned inbox · a patient's reports · a prescription's reports
// Claude is called once, on the Summarize tap; everything else reads the saved summary.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/data/api/reports_api.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _primary   = Color(0xFF26C6B0);
const _primaryLt = Color(0xFFD9F5F1);
const _text      = Color(0xFF2D3748);
const _textSub   = Color(0xFF718096);
const _border    = Color(0xFFEDF2F7);
const _bg        = Color(0xFFF7F8FA);
const _green     = Color(0xFF276749);
const _greenLt   = Color(0xFFDCFCE7);
const _amber     = Color(0xFF975A16);
const _amberLt   = Color(0xFFFEF3C7);
const _red       = Color(0xFFC53030);
const _redLt     = Color(0xFFFEE2E2);

const _maxPhotos = 6;
// Claude downscales anything bigger, so larger photos would only cost upload time.
const _maxSide = 1568.0;
const _consentKey = 'ai_report_consent_v1';

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

AppBar _appBar(String title) => AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _text,
      elevation: 0,
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );

/// One-time consent: reports are sent to Anthropic (Claude) for the summary.
Future<bool> _ensureConsent(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_consentKey) == true) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('AI report summary'),
      content: const Text(
          'The report pages you upload are sent to our AI provider, Anthropic (Claude), to create the '
          'summary. The summary and pages are then stored securely in QLess.\n\n'
          'AI summaries can be wrong — always check against the original report.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I agree')),
      ],
    ),
  );
  if (ok == true) await prefs.setBool(_consentKey, true);
  return ok == true;
}

// ════════════════════════════════════════════════════════════════════
//  Capture
// ════════════════════════════════════════════════════════════════════
class ReportCaptureScreen extends ConsumerStatefulWidget {
  final bool isPatient;
  final int? patientId, userType, prescriptionId;
  final String? patientName;
  const ReportCaptureScreen({
    super.key,
    required this.isPatient,
    this.patientId,
    this.userType,
    this.prescriptionId,
    this.patientName,
  });

  @override
  ConsumerState<ReportCaptureScreen> createState() => _ReportCaptureScreenState();
}

class _ReportCaptureScreenState extends ConsumerState<ReportCaptureScreen> {
  final _picker = ImagePicker();
  final List<File> _photos = [];
  File? _pdf;
  bool _busy = false;

  bool get _hasInput => _photos.isNotEmpty || _pdf != null;

  Future<void> _camera() async {
    final x = await _picker.pickImage(
        source: ImageSource.camera, maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: 70);
    if (x != null) setState(() { _pdf = null; _photos.add(File(x.path)); });
  }

  Future<void> _gallery() async {
    final xs = await _picker.pickMultiImage(maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: 70);
    if (xs.isEmpty) return;
    final room = _maxPhotos - _photos.length;
    setState(() {
      _pdf = null;
      _photos.addAll(xs.take(room).map((x) => File(x.path)));
    });
    if (xs.length > room && mounted) _snack(context, 'Up to $_maxPhotos pages per report.');
  }

  Future<void> _pickPdf() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = r?.files.single.path;
    if (path != null) setState(() { _photos.clear(); _pdf = File(path); });
  }

  Future<void> _summarize() async {
    if (!await _ensureConsent(context)) return;
    setState(() => _busy = true);
    try {
      final report = await ref.read(reportsApiProvider).summarize(
            _pdf != null ? [_pdf!] : _photos,
            patientId: widget.patientId,
            userType: widget.userType,
            prescriptionId: widget.prescriptionId,
          );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ReportDetailScreen(report: report, isPatient: widget.isPatient, justCreated: true)));
    } catch (e) {
      if (mounted) _snack(context, reportErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = _photos.length >= _maxPhotos;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar('AI Report Summary'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.patientName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('For ${widget.patientName}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: _text)),
          ),
        const Text('Take a photo of each page (up to 6), pick from gallery, or upload one PDF (up to 10 pages).',
            style: TextStyle(color: _textSub, fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _PickButton(Icons.photo_camera_outlined, 'Camera', full || _busy ? null : _camera)),
          const SizedBox(width: 8),
          Expanded(child: _PickButton(Icons.photo_library_outlined, 'Gallery', full || _busy ? null : _gallery)),
          const SizedBox(width: 8),
          Expanded(child: _PickButton(Icons.picture_as_pdf_outlined, 'PDF', _busy ? null : _pickPdf)),
        ]),
        const SizedBox(height: 16),
        if (_pdf != null)
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.picture_as_pdf, color: _red),
            title: Text(_pdf!.path.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _pdf = null)),
          ),
        if (_photos.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_photos[i], width: 96, height: 128, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: InkWell(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 3)])),
                ),
              ]),
          ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _primary, minimumSize: const Size.fromHeight(48)),
            onPressed: _hasInput && !_busy ? _summarize : null,
            icon: _busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_busy ? 'Reading report…' : 'Summarize'),
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PickButton(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Column(children: [Icon(icon), const SizedBox(height: 4), Text(label)]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  Detail
// ════════════════════════════════════════════════════════════════════
class ReportDetailScreen extends ConsumerStatefulWidget {
  final MedicalReport report;
  final bool isPatient;
  final bool justCreated;
  const ReportDetailScreen({super.key, required this.report, required this.isPatient, this.justCreated = false});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  late MedicalReport _report = widget.report;
  bool _busy = false;

  Future<void> _openPage(int n) async {
    try {
      final bytes = await ref.read(reportsApiProvider).file(_report.id, n);
      if (!mounted) return;
      if (_report.files[n] == 'pdf') {
        final f = File('${(await getTemporaryDirectory()).path}/report_${_report.id}.pdf');
        await f.writeAsBytes(bytes);
        await OpenFile.open(f.path);
      } else {
        showDialog(
          context: context,
          builder: (_) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(children: [
              InteractiveViewer(child: Center(child: Image.memory(Uint8List.fromList(bytes)))),
              const SafeArea(child: CloseButton(color: Colors.white)),
            ]),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack(context, reportErrorText(e));
    }
  }

  Future<void> _assign() async {
    final updated = await showModalBottomSheet<MedicalReport>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AssignReportSheet(report: _report),
    );
    if (updated != null && mounted) {
      setState(() => _report = updated);
      _snack(context, 'Report attached to ${updated.patientName ?? 'patient'}.');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('The summary and pages will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(reportsApiProvider).delete(_report.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _busy = false); _snack(context, reportErrorText(e)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    // Each side manages only what it uploaded; a patient's report shared via a
    // prescription is read-only for the clinic.
    final staff = !widget.isPatient && !r.uploadedByPatient;
    final canDelete = staff || (widget.isPatient && r.uploadedByPatient);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        title: Text(r.reportType.isEmpty ? 'Report summary' : r.reportType,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (canDelete)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ReportSummaryView(report: r),
        const SizedBox(height: 16),
        const Text('Original pages', style: TextStyle(fontWeight: FontWeight.w700, color: _text)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < r.files.length; i++)
            ActionChip(
              avatar: Icon(r.files[i] == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 18),
              label: Text(r.files[i] == 'pdf' ? 'Open PDF' : 'Page ${i + 1}'),
              onPressed: () => _openPage(i),
            ),
        ]),
      ]),
      bottomNavigationBar: staff
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  if (widget.justCreated && !r.isAssigned) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () {
                          _snack(context, 'Saved to Unassigned reports.');
                          Navigator.pop(context, true);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _primary, minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _assign,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(r.isAssigned ? 'Reassign' : 'Assign to patient'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

/// The summary card — also usable inline elsewhere.
class ReportSummaryView extends StatelessWidget {
  final MedicalReport report;
  const ReportSummaryView({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final meta = [
      if (r.patientName != null) 'Attached to: ${r.patientName}',
      if (r.doctorName != null) 'Doctor: ${r.doctorName}',
    ];
    final details = r.details;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (details.isNotEmpty) ...[
          const Text('Details on report',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSub)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              for (final (label, value) in details)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 100,
                        child: Text(label, style: const TextStyle(fontSize: 12, color: _textSub))),
                    Expanded(child: SelectableText(value,
                        style: const TextStyle(fontSize: 13, color: _text, fontWeight: FontWeight.w600))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        for (final m in meta) Text(m, style: const TextStyle(fontSize: 12, color: _textSub)),
        if (meta.isNotEmpty) const SizedBox(height: 10),
        if (r.overview.isNotEmpty)
          Text(r.overview, style: const TextStyle(fontSize: 14, color: _text, height: 1.4)),
        if (r.findings.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final f in r.findings)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.test, style: const TextStyle(fontWeight: FontWeight.w600, color: _text, fontSize: 13)),
                    if (f.referenceRange.isNotEmpty)
                      Text('Range ${f.referenceRange}', style: const TextStyle(fontSize: 11, color: _textSub)),
                  ]),
                ),
                Text('${f.value} ${f.unit}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: _text, fontSize: 13)),
                const SizedBox(width: 8),
                _FlagChip(f.flag),
              ]),
            ),
        ],
        if (r.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final n in r.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $n', style: const TextStyle(fontSize: 13, color: _text)),
            ),
        ],
        const SizedBox(height: 12),
        const Text('AI-generated summary. Always verify against the original report.',
            style: TextStyle(fontSize: 11, color: _textSub, fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String flag;
  const _FlagChip(this.flag);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (flag) {
      'normal' => (_greenLt, _green),
      'high' || 'low' => (_amberLt, _amber),
      _ => (_redLt, _red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(flag.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Assign (doctor / receptionist): patient → optional prescription
// ════════════════════════════════════════════════════════════════════
class AssignReportSheet extends ConsumerStatefulWidget {
  final MedicalReport report;
  const AssignReportSheet({super.key, required this.report});

  @override
  ConsumerState<AssignReportSheet> createState() => _AssignReportSheetState();
}

typedef _Patient = ({int id, int userType, String name, String mobile});
typedef _Rx = ({int id, String label});

const _titles = {'mr', 'mrs', 'ms', 'miss', 'dr', 'master', 'baby', 'smt', 'shri', 'kum', 'mst'};
String _last10(String s) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}
Set<String> _nameTokens(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L} ]', unicode: true), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.length > 1 && !_titles.contains(t))
    .toSet();

/// How well a patient matches the details printed on a report:
/// 2 = same phone (last 10 digits), 1 = same name (≥ 2 shared words, or all
/// words of a one-word name; titles like Mr/Mrs ignored), 0 = no match.
int reportMatchScore(String reportName, String reportPhone, String name, String mobile) {
  final rp = _last10(reportPhone);
  if (rp.length == 10 && rp == _last10(mobile)) return 2;
  final a = _nameTokens(reportName), b = _nameTokens(name);
  if (a.isEmpty || b.isEmpty) return 0;
  final shared = a.intersection(b).length;
  return shared > 0 && shared >= (a.length < b.length ? a.length : b.length).clamp(1, 2) ? 1 : 0;
}

class _AssignReportSheetState extends ConsumerState<AssignReportSheet> {
  late final Future<List<_Patient>> _patients = _loadPatients();
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchFor(String v) {
    _search.text = v;
    setState(() => _q = v.trim().toLowerCase());
  }

  Widget _patientTile(_Patient p, {String? why}) => ListTile(
        leading: const CircleAvatar(backgroundColor: _primaryLt, child: Icon(Icons.person, color: _primary)),
        title: Text(p.name),
        subtitle: Text([if (p.mobile.isNotEmpty) p.mobile, if (p.userType == 2) 'Family member'].join(' · ')),
        trailing: why == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _greenLt, borderRadius: BorderRadius.circular(10)),
                child: Text(why, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _green)),
              ),
        onTap: () => setState(() { _picked = p; _rxs = _loadRxs(p); }),
      );
  _Patient? _picked;
  Future<List<_Rx>>? _rxs;
  bool _busy = false;

  // Only patients who have seen this doctor can be attached (the server checks the same).
  Future<List<_Patient>> _loadPatients() async {
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    final rows = await ref.read(apiServiceProvider).fetchPatientAppointments(doctorId);
    final seen = <String>{};
    return [
      for (final a in rows)
        if (a.patientId != null && seen.add('${a.patientId}-${a.userType ?? 1}'))
          (id: a.patientId!, userType: a.userType ?? 1, name: a.patientName ?? 'Patient', mobile: a.mobile ?? ''),
    ];
  }

  Future<List<_Rx>> _loadRxs(_Patient p) async {
    final rows = await ref.read(apiServiceProvider).patientPrescriptionList(p.id);
    final seen = <int>{};
    final fmt = DateFormat('d MMM yyyy');
    return [
      for (final r in rows)
        if (r.prescriptionId != null && (r.userType ?? 1) == p.userType && seen.add(r.prescriptionId!))
          (
            id: r.prescriptionId!,
            label: [
              if (DateTime.tryParse(r.prescriptionDate ?? '') != null)
                fmt.format(DateTime.parse(r.prescriptionDate!).toLocal()),
              if ((r.diagnosis ?? '').isNotEmpty) r.diagnosis!,
            ].join(' · '),
          ),
    ];
  }

  Future<void> _save(int? prescriptionId) async {
    final p = _picked!;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(reportsApiProvider)
          .assign(widget.report.id, patientId: p.id, userType: p.userType, prescriptionId: prescriptionId);
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) { setState(() => _busy = false); _snack(context, reportErrorText(e)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 8),
          child: _picked == null ? _patientStep() : _rxStep(),
        ),
      ),
    );
  }

  Widget _patientStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Assign to patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Search by name or mobile',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchFor('')),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
        // One tap to search by what the report says.
        if (widget.report.phoneOnReport.isNotEmpty || widget.report.nameOnReport.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, children: [
              if (widget.report.phoneOnReport.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.phone_outlined, size: 16),
                  label: Text(widget.report.phoneOnReport),
                  onPressed: () => _searchFor(_last10(widget.report.phoneOnReport)),
                ),
              if (widget.report.nameOnReport.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.badge_outlined, size: 16),
                  label: Text(widget.report.nameOnReport),
                  onPressed: () => _searchFor(widget.report.nameOnReport),
                ),
            ]),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: FutureBuilder<List<_Patient>>(
            future: _patients,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(reportErrorText(snap.error!)));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final r = widget.report;
              final scored = [
                for (final p in snap.data!) (p: p, score: reportMatchScore(r.nameOnReport, r.phoneOnReport, p.name, p.mobile)),
              ];
              // Searching: a name/mobile query matches words in any order (a report name like
              // "PARAB ARJUN" still finds "Arjun Parab").
              final qWords = _q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
              bool hit(_Patient p) => _q.isEmpty ||
                  qWords.every((w) => p.name.toLowerCase().contains(w) || p.mobile.contains(w));
              final suggested = _q.isEmpty
                  ? (scored.where((s) => s.score > 0).toList()..sort((a, b) => b.score - a.score))
                  : const <({_Patient p, int score})>[];
              final others = scored.where((s) => hit(s.p) && !suggested.contains(s)).toList()
                ..sort((a, b) => b.score - a.score);
              if (suggested.isEmpty && others.isEmpty) return const Center(child: Text('No matching patients.'));
              return ListView(children: [
                if (suggested.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text('Suggested from report',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _green)),
                  ),
                  for (final s in suggested) _patientTile(s.p, why: s.score == 2 ? 'PHONE MATCH' : 'NAME MATCH'),
                  const Divider(),
                ],
                if (_q.isEmpty && others.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text('All patients',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSub)),
                  ),
                for (final s in others)
                  _patientTile(s.p, why: s.score == 2 ? 'PHONE MATCH' : s.score == 1 ? 'NAME MATCH' : null),
              ]);
            },
          ),
        ),
      ]);

  Widget _rxStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: _busy ? null : () => setState(() => _picked = null)),
          Expanded(child: Text(_picked!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        const Text('Attach to a prescription (optional)', style: TextStyle(color: _textSub)),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.folder_shared_outlined, color: _primary),
          title: const Text('No specific prescription'),
          subtitle: const Text("Save to the patient's reports"),
          onTap: _busy ? null : () => _save(null),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<_Rx>>(
            future: _rxs,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(reportErrorText(snap.error!)));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.isEmpty) return const Center(child: Text('No prescriptions yet.'));
              return ListView(children: [
                for (final rx in snap.data!)
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(rx.label.isEmpty ? 'Prescription #${rx.id}' : rx.label),
                    onTap: _busy ? null : () => _save(rx.id),
                  ),
              ]);
            },
          ),
        ),
      ]);
}

// ════════════════════════════════════════════════════════════════════
//  Lists
// ════════════════════════════════════════════════════════════════════
enum ReportsListMode { unassigned, patient, prescription }

class ReportsListScreen extends ConsumerStatefulWidget {
  final ReportsListMode mode;
  final bool isPatient;
  final int? patientId, userType, prescriptionId;
  final String? title, patientName;
  const ReportsListScreen({
    super.key,
    required this.mode,
    required this.isPatient,
    this.patientId,
    this.userType,
    this.prescriptionId,
    this.title,
    this.patientName,
  });

  @override
  ConsumerState<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends ConsumerState<ReportsListScreen> {
  late Future<List<MedicalReport>> _future = _load();

  Future<List<MedicalReport>> _load() {
    final api = ref.read(reportsApiProvider);
    return switch (widget.mode) {
      ReportsListMode.unassigned => api.unassigned(),
      ReportsListMode.patient => api.forPatient(widget.patientId!, widget.userType ?? 1),
      ReportsListMode.prescription => api.forPrescription(widget.prescriptionId!),
    };
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final unassigned = widget.mode == ReportsListMode.unassigned;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(widget.title ?? (unassigned ? 'Unassigned reports' : 'Reports')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan report'),
        onPressed: () => _push(ReportCaptureScreen(
          isPatient: widget.isPatient,
          patientId: widget.patientId,
          userType: widget.userType,
          prescriptionId: widget.prescriptionId,
          patientName: widget.patientName,
        )),
      ),
      body: RefreshIndicator(
        onRefresh: () async { _reload(); await _future; },
        child: FutureBuilder<List<MedicalReport>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(children: [
                Padding(padding: const EdgeInsets.all(32), child: Text(reportErrorText(snap.error!), textAlign: TextAlign.center)),
              ]);
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            if (list.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(unassigned ? 'No unassigned reports.' : 'No reports yet. Tap "Scan report" to add one.',
                      textAlign: TextAlign.center, style: const TextStyle(color: _textSub)),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => ReportTile(
                report: list[i],
                onTap: () => _push(ReportDetailScreen(report: list[i], isPatient: widget.isPatient)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReportTile extends StatelessWidget {
  final MedicalReport report;
  final VoidCallback onTap;
  const ReportTile({super.key, required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final sub = [
      if (r.createdAt != null) DateFormat('d MMM yyyy').format(r.createdAt!),
      if (!r.isAssigned && r.nameOnReport.isNotEmpty) r.nameOnReport,
      if (r.isAssigned && r.patientName != null) r.patientName!,
      if (r.doctorName != null) 'Dr. ${r.doctorName}',
    ].join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _border)),
        onTap: onTap,
        leading: const CircleAvatar(backgroundColor: _primaryLt,
            child: Icon(Icons.description_outlined, color: _primary)),
        title: Text(r.reportType.isEmpty ? 'Medical report' : r.reportType,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _text)),
        subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: r.abnormalCount > 0 ? _FlagChip('${r.abnormalCount} flagged') : null,
      ),
    );
  }
}

/// "Reports · 2 attached" row for a prescription screen → its reports list (with Scan).
class PrescriptionReportsTile extends ConsumerStatefulWidget {
  final int prescriptionId, patientId;
  final int? userType;
  final String? patientName;
  final bool isPatient;
  const PrescriptionReportsTile({
    super.key,
    required this.prescriptionId,
    required this.patientId,
    required this.isPatient,
    this.userType,
    this.patientName,
  });

  @override
  ConsumerState<PrescriptionReportsTile> createState() => _PrescriptionReportsTileState();
}

class _PrescriptionReportsTileState extends ConsumerState<PrescriptionReportsTile> {
  late Future<List<MedicalReport>> _future = _load();

  Future<List<MedicalReport>> _load() => ref.read(reportsApiProvider).forPrescription(widget.prescriptionId);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MedicalReport>>(
        future: _future,
        builder: (context, snap) {
          final n = snap.data?.length;
          return Material(
            color: _primaryLt,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.document_scanner_outlined, color: _primary),
              title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w700, color: _text)),
              subtitle: Text(n == null
                  ? (snap.hasError ? 'Tap to view or add' : 'Loading…')
                  : n == 0 ? 'Add a lab report — AI summary' : '$n attached · tap to view or add'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsListScreen(
                  mode: ReportsListMode.prescription,
                  isPatient: widget.isPatient,
                  prescriptionId: widget.prescriptionId,
                  patientId: widget.patientId,
                  userType: widget.userType,
                  patientName: widget.patientName,
                  title: 'Prescription reports',
                )));
                if (mounted) setState(() => _future = _load());
              },
            ),
          );
        },
      );
}
