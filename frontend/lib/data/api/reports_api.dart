// AI medical report summaries — backend routes in backend/src/routes/reports.js.
// Plain Dio (no retrofit codegen); dioProvider adds the token + refresh.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:qless/core/network/dio_provider.dart';

class ReportFinding {
  final String test, value, unit, referenceRange, flag;
  ReportFinding.fromJson(Map<String, dynamic> j)
      : test = '${j['test'] ?? ''}',
        value = '${j['value'] ?? ''}',
        unit = '${j['unit'] ?? ''}',
        referenceRange = '${j['reference_range'] ?? ''}',
        flag = '${j['flag'] ?? 'normal'}';
}

class MedicalReport {
  final int id;
  final int? patientId, userType, prescriptionId;
  final String? patientName, doctorName;
  final bool uploadedByPatient;
  final DateTime? createdAt;
  final List<String> files; // 'image' | 'pdf', in page order
  final String reportType, reportDate, overview;
  final List<ReportFinding> findings;
  final List<String> notes;
  final Map<String, dynamic> _summary;

  MedicalReport.fromJson(Map<String, dynamic> j)
      : id = j['report_id'] as int,
        patientId = j['patient_id'] as int?,
        userType = j['user_type'] as int?,
        prescriptionId = j['prescription_id'] as int?,
        patientName = j['patient_name'] as String?,
        doctorName = j['doctor_name'] as String?,
        uploadedByPatient = j['uploaded_by_patient'] == true,
        createdAt = DateTime.tryParse('${j['created_at']}')?.toLocal(),
        files = List<String>.from(j['files'] as List? ?? const []),
        reportType = '${(j['summary'] as Map?)?['report_type'] ?? ''}',
        reportDate = '${(j['summary'] as Map?)?['report_date'] ?? ''}',
        overview = '${(j['summary'] as Map?)?['overview'] ?? ''}',
        _summary = Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
        findings = [
          for (final f in (j['summary'] as Map?)?['key_findings'] as List? ?? const [])
            ReportFinding.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        notes = List<String>.from((j['summary'] as Map?)?['notes'] as List? ?? const []);

  String _s(String key) => '${_summary[key] ?? ''}'.trim();

  /// Patient / report details as printed on the report (empty when not printed).
  String get nameOnReport => _s('patient_name');
  String get phoneOnReport => _s('patient_phone');

  /// Label → value, only what the report actually shows.
  List<(String, String)> get details => [
        for (final (label, key) in const [
          ('Name', 'patient_name'),
          ('Age', 'patient_age'),
          ('Gender', 'patient_gender'),
          ('Phone', 'patient_phone'),
          ('Address', 'patient_address'),
          ('Patient ID', 'patient_id_on_report'),
          ('Referred by', 'referred_by'),
          ('Lab / hospital', 'lab_name'),
          ('Report date', 'report_date'),
        ])
          if (_s(key).isNotEmpty) (label, _s(key)),
      ];

  bool get isAssigned => patientId != null;
  int get abnormalCount => findings.where((f) => f.flag != 'normal').length;
}

class ReportsApi {
  final Dio dio;
  ReportsApi(this.dio);

  static List<MedicalReport> _list(dynamic data) => [
        for (final r in (data as Map)['reports'] as List) MedicalReport.fromJson(Map<String, dynamic>.from(r as Map)),
      ];

  /// [files]: 1–6 photos or one PDF. Claude runs once here; the result is saved.
  Future<MedicalReport> summarize(List<File> files, {int? patientId, int? userType, int? prescriptionId}) async {
    final form = FormData.fromMap({
      if (patientId != null) 'patient_id': patientId,
      if (userType != null) 'user_type': userType,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      'files': [for (final f in files) await MultipartFile.fromFile(f.path, filename: p.basename(f.path))],
    });
    final res = await dio.post('reports/summarize',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 120),
        ));
    return MedicalReport.fromJson(Map<String, dynamic>.from(res.data['report'] as Map));
  }

  Future<List<MedicalReport>> unassigned() async => _list((await dio.get('reports/unassigned')).data);

  Future<List<MedicalReport>> forPatient(int patientId, int userType) async =>
      _list((await dio.get('reports/patient/$patientId', queryParameters: {'user_type': userType})).data);

  Future<List<MedicalReport>> forPrescription(int prescriptionId) async =>
      _list((await dio.get('reports/prescription/$prescriptionId')).data);

  Future<MedicalReport> assign(int reportId, {required int patientId, required int userType, int? prescriptionId}) async {
    final res = await dio.put('reports/$reportId/assign',
        data: {'patient_id': patientId, 'user_type': userType, 'prescription_id': prescriptionId});
    return MedicalReport.fromJson(Map<String, dynamic>.from(res.data['report'] as Map));
  }

  Future<void> delete(int reportId) => dio.delete('reports/$reportId');

  /// Original page [n] (0-based) as bytes — through Dio so an expired token refreshes.
  Future<List<int>> file(int reportId, int n) async {
    final res = await dio.get<List<int>>('reports/$reportId/file/$n',
        options: Options(responseType: ResponseType.bytes));
    return res.data!;
  }
}

final reportsApiProvider = Provider<ReportsApi>((ref) => ReportsApi(ref.watch(dioProvider).value!));

/// User-facing text for a failed reports call. The server hides 5xx bodies,
/// so those are mapped by status.
String reportErrorText(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (status == 503) return 'AI summary is unavailable right now. Please try again later.';
    if (status != null && status >= 500) return 'AI summary failed. Please try again.';
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (e.message != null) return e.message!;
  }
  return 'Something went wrong. Please try again.';
}
