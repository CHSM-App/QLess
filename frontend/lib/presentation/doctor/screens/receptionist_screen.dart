import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/receptionist_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const _kPrimary       = Color(0xFF26C6B0);
const _kPrimaryLight  = Color(0xFFD9F5F1);
const _kTextPrimary   = Color(0xFF2D3748);
const _kTextSecondary = Color(0xFF718096);
const _kTextMuted     = Color(0xFFA0AEC0);
const _kBorder        = Color(0xFFEDF2F7);
const _kError         = Color(0xFFFC8181);
const _kRedLight      = Color(0xFFFEE2E2);
const _kSuccess       = Color(0xFF68D391);
const _kGreenLight    = Color(0xFFDCFCE7);
const _kHairline      = Color(0xFFE8EEF1);
const _kCardBg        = Color(0xFFF7F8FA);
const LinearGradient _kGradient = LinearGradient(
  colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

BoxDecoration _cardDec() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kHairline),
    );

// ── Helpers ───────────────────────────────────────────────────────────────────
const _genderMap = {'Male': 1, 'Female': 2, 'Other': 3};
const _genderRev = {1: 'Male', 2: 'Female', 3: 'Other'};

String? _parseClinicId(String? value) {
  final cleaned = value?.trim();
  if (cleaned == null || cleaned.isEmpty ||
      cleaned.toLowerCase() == 'null' || cleaned == '0') {
    return null;
  }
  return cleaned;
}

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ════════════════════════════════════════════════════════════════════
//  LIST PAGE
// ════════════════════════════════════════════════════════════════════
class ReceptionistPage extends ConsumerStatefulWidget {
  const ReceptionistPage({super.key});

  @override
  ConsumerState<ReceptionistPage> createState() => _ReceptionistPageState();
}

class _ReceptionistPageState extends ConsumerState<ReceptionistPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadList);
  }

  String? get _clinicId {
    final doctorState = ref.read(doctorLoginViewModelProvider);
    final doctorClinicId = doctorState.clinic_id;
    final receptionistClinicId =
        ref.read(receptionistLoginViewModelProvider).clinicId;
    final phoneCheckClinicId = doctorState.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first.clinicId : null,
      orElse: () => null,
    );
    return _parseClinicId(
      doctorClinicId ?? receptionistClinicId ?? phoneCheckClinicId,
    );
  }

  Future<void> _loadList() async {
    final clinicId = _clinicId;
    if (clinicId == null) {
      return;
    }
    await ref
        .read(receptionistLoginViewModelProvider.notifier)
        .fetchReceptionistList(clinicId);
  }

  void _goAdd() async {
    final result = await Navigator.push<ReceptionistApiModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReceptionistPage(clinicId: _clinicId),
      ),
    );
    if (result != null) _loadList();
  }

  void _goEdit(List<ReceptionistApiModel> list, int i) async {
    final result = await Navigator.push<ReceptionistApiModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReceptionistPage(
          existing: list[i],
          clinicId: _clinicId,
        ),
      ),
    );
    if (result != null) _loadList();
  }

  void _confirmDelete(List<ReceptionistApiModel> list, int i) {
    final r = list[i];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: _kRedLight, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, color: _kError, size: 22),
            ),
            const SizedBox(height: 12),
            const Text('Remove Receptionist?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTextPrimary)),
            const SizedBox(height: 6),
            Text('Remove ${r.name ?? ''} from your clinic?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _kTextSecondary, height: 1.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kBorder),
                    foregroundColor: _kTextSecondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (r.recepId == null) return;
                    await ref
                        .read(receptionistLoginViewModelProvider.notifier)
                        .deleteReceptionist(r.recepId!);
                    final error = ref.read(receptionistLoginViewModelProvider).error;
                    if (error != null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receptionist removed.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kError, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Remove',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receptionistList =
        ref.watch(receptionistLoginViewModelProvider).receptionistList;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7)))),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Receptionists',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextPrimary)),
                    Text('Manage clinic staff access',
                        style: TextStyle(fontSize: 11, color: _kTextSecondary)),
                  ]),
                ),
                GestureDetector(
                  onTap: _goAdd,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(gradient: _kGradient, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: receptionistList.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
            ),
            error: (_, __) => _buildError(),
            data: (list) => list.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    color: _kPrimary,
                    onRefresh: _loadList,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildCard(list, i),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.people_outline_rounded, size: 30, color: _kPrimary),
          ),
          const SizedBox(height: 14),
          const Text('No Receptionists Added',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextPrimary)),
          const SizedBox(height: 6),
          const Text('Tap "Add" to add your clinic receptionist.',
              style: TextStyle(fontSize: 12, color: _kTextSecondary)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _goAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(gradient: _kGradient, borderRadius: BorderRadius.circular(12)),
              child: const Text('Add Receptionist',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      );

  Widget _buildError() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: _kRedLight, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.error_outline_rounded, size: 30, color: _kError),
          ),
          const SizedBox(height: 14),
          const Text('Could Not Load Receptionists',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextPrimary)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadList,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(gradient: _kGradient, borderRadius: BorderRadius.circular(12)),
              child: const Text('Try Again',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      );

  Widget _buildCard(List<ReceptionistApiModel> list, int i) {
    final r = list[i];
    final gender = _genderRev[r.genderId] ?? 'Other';
    final genderIcon = r.genderId == 1 ? Icons.male_rounded : Icons.female_rounded;
    final isActive = r.activeStatus == 1;

    return Container(
      decoration: _cardDec(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _kGradient),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: Text(_initials(r.name),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),

        // Name + contact + gender
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name ?? '—',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 11, color: _kTextMuted),
              const SizedBox(width: 4),
              Text(r.mobileNo ?? '—', style: const TextStyle(fontSize: 11.5, color: _kTextSecondary)),
              const SizedBox(width: 10),
              Icon(genderIcon, size: 12, color: _kTextMuted),
              const SizedBox(width: 3),
              Text(gender, style: const TextStyle(fontSize: 11.5, color: _kTextSecondary)),
            ]),
          ]),
        ),

        // Active / Inactive badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? _kGreenLight : _kRedLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: isActive ? _kSuccess : _kError)),
        ),
        const SizedBox(width: 8),

        // Edit icon
        GestureDetector(
          onTap: () => _goEdit(list, i),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_outlined, size: 14, color: _kPrimary),
          ),
        ),
        const SizedBox(width: 6),

        // Delete icon
        GestureDetector(
          onTap: () => _confirmDelete(list, i),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _kRedLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline_rounded, size: 14, color: _kError),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ADD / EDIT PAGE
// ════════════════════════════════════════════════════════════════════
class AddReceptionistPage extends ConsumerStatefulWidget {
  final ReceptionistApiModel? existing;
  final String? clinicId;

  const AddReceptionistPage({super.key, this.existing, this.clinicId});

  @override
  ConsumerState<AddReceptionistPage> createState() => _AddReceptionistPageState();
}

class _AddReceptionistPageState extends ConsumerState<AddReceptionistPage> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _mobileCtrl  = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _gender = 'Female';
  File?  _photo;
  bool   _saving = false;

  final _picker = ImagePicker();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text    = e.name    ?? '';
      _mobileCtrl.text  = e.mobileNo ?? '';
      _emailCtrl.text   = e.email   ?? '';
      _addressCtrl.text = e.address ?? '';
      _gender           = _genderRev[e.genderId] ?? 'Female';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }


  // ── Photo picker ─────────────────────────────────────────────────────────
  void _pickPhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Staff Photo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextPrimary)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose how to set the profile picture',
                  style: TextStyle(fontSize: 12, color: _kTextMuted)),
            ),
            const SizedBox(height: 14),
            _srcTile(ctx, Icons.camera_alt_outlined, _kPrimaryLight, _kPrimary,
                'Take a Photo', 'Use your camera', () async {
              Navigator.pop(ctx);
              final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (x != null && mounted) setState(() => _photo = File(x.path));
            }),
            const SizedBox(height: 8),
            _srcTile(ctx, Icons.photo_library_outlined, const Color(0xFFEDE9FE), const Color(0xFF9F7AEA),
                'Choose from Gallery', 'Pick from your photos', () async {
              Navigator.pop(ctx);
              final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (x != null && mounted) setState(() => _photo = File(x.path));
            }),
            if (_photo != null) ...[
              const SizedBox(height: 8),
              _srcTile(ctx, Icons.delete_outline_rounded, _kRedLight, _kError,
                  'Remove Photo', 'Use initials instead', () {
                Navigator.pop(ctx);
                setState(() => _photo = null);
              }),
            ],
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Widget _srcTile(BuildContext ctx, IconData icon, Color bg, Color fg,
      String label, String subtitle, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _kCardBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder)),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: fg, size: 18)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: _kTextMuted)),
            ]),
          ]),
        ),
      );

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<String?> _resolveClinicId() async {
    final doctorState = ref.read(doctorLoginViewModelProvider);
    final doctorClinicId = doctorState.clinic_id;
    final receptionistClinicId =
        ref.read(receptionistLoginViewModelProvider).clinicId;
    final phoneCheckClinicId = doctorState.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first.clinicId : null,
      orElse: () => null,
    );
    final storedClinicId = await TokenStorage.getValue('clinic_id');

    final clinicId = _parseClinicId(widget.clinicId?.toString()) ??
        _parseClinicId(doctorClinicId) ??
        _parseClinicId(receptionistClinicId) ??
        _parseClinicId(phoneCheckClinicId) ??
        _parseClinicId(storedClinicId);
    debugPrint(
      '[ReceptionistDebug] resolveClinicId initial '
      'widget=${widget.clinicId} '
      'doctorState=$doctorClinicId '
      'receptionistState=$receptionistClinicId '
      'phoneCheck=$phoneCheckClinicId '
      'storage=$storedClinicId '
      'resolved=$clinicId',
    );
    if (clinicId != null) return clinicId;

    final mobile = (doctorState.mobile ?? await TokenStorage.getValue('mobile'))
        ?.trim();
    debugPrint(
      '[ReceptionistDebug] clinicId missing, refresh doctor by mobile '
      'hasMobile=${mobile != null && mobile.isNotEmpty}',
    );
    if (mobile == null || mobile.isEmpty) return null;

    try {
      await ref
          .read(doctorLoginViewModelProvider.notifier)
          .checkPhoneDoctor(mobile);
    } catch (e) {
      debugPrint('[ReceptionistDebug] checkPhoneDoctor failed: $e');
      return null;
    }
    final refreshedState = ref.read(doctorLoginViewModelProvider);
    final refreshedClinicId = refreshedState.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first.clinicId : null,
      orElse: () => null,
    );

    final refreshedStorageClinicId = await TokenStorage.getValue('clinic_id');
    final refreshedResolved = _parseClinicId(refreshedState.clinic_id) ??
        _parseClinicId(refreshedClinicId) ??
        _parseClinicId(refreshedStorageClinicId);
    debugPrint(
      '[ReceptionistDebug] resolveClinicId after refresh '
      'doctorState=${refreshedState.clinic_id} '
      'phoneCheck=$refreshedClinicId '
      'storage=$refreshedStorageClinicId '
      'resolved=$refreshedResolved',
    );
    return refreshedResolved;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final clinicId = await _resolveClinicId();
    debugPrint('[ReceptionistDebug] save receptionist clinicId=$clinicId');
    if (!mounted) return;
    if (clinicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinic not found. Please try again.')),
      );
      return;
    }

    setState(() => _saving = true);

    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId;

    final model = ReceptionistApiModel(
      recepId:  widget.existing?.recepId,
      name:     _nameCtrl.text.trim(),
      mobileNo: _mobileCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      address:  _addressCtrl.text.trim(),
      genderId: _genderMap[_gender] ?? 2,
      clinicId: clinicId,
      activeStatus: widget.existing?.activeStatus ?? 1,
      doctorId: doctorId,
    );

    try {
      await ref
          .read(receptionistLoginViewModelProvider.notifier)
          .addReceptionist(model, image: _photo);
      final error = ref.read(receptionistLoginViewModelProvider).error;
      if (!mounted) return;
      if (error == null) {
        Navigator.pop(context, model);
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final initials = _nameCtrl.text.trim().isNotEmpty
        ? _initials(_nameCtrl.text.trim())
        : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7)))),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_isEdit ? 'Edit Receptionist' : 'Add Receptionist',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextPrimary)),
                    Text(_isEdit ? 'Update staff details' : 'Fill staff details below',
                        style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        // Form
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 100),
              children: [
                // Photo
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      Container(
                        width: 90, height: 90,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _kGradient),
                        clipBehavior: Clip.antiAlias,
                        child: _photo != null
                            ? Image.file(_photo!, fit: BoxFit.cover)
                            : Center(child: Text(initials,
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
                      ),
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                            gradient: _kGradient, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(child: Text('Tap to add photo',
                    style: TextStyle(fontSize: 11, color: _kTextMuted))),
                const SizedBox(height: 24),

                // Personal Info
                _sectionLabel('Personal Info'),
                const SizedBox(height: 10),
                Container(
                  decoration: _cardDec(),
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    _field(ctrl: _nameCtrl, label: 'Full Name', hint: 'e.g. Priya Patil',
                        icon: Icons.person_outline_rounded, inputType: TextInputType.name,
                        textCap: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    _field(ctrl: _mobileCtrl, label: 'Mobile Number', hint: '10-digit number',
                        icon: Icons.phone_outlined, inputType: TextInputType.phone,
                        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        readOnly: _isEdit,
                        validator: (v) => (v == null || v.trim().length != 10) ? 'Valid 10-digit number required' : null),
                    const SizedBox(height: 12),
                    _field(ctrl: _emailCtrl, label: 'Email Address (optional)', hint: 'staff@clinic.com',
                        icon: Icons.email_outlined, inputType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim()) ? null : 'Invalid email';
                        }),
                  ]),
                ),

                const SizedBox(height: 16),

                // Other Details
                _sectionLabel('Other Details'),
                const SizedBox(height: 10),
                Container(
                  decoration: _cardDec(),
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    _field(ctrl: _addressCtrl, label: 'Address', hint: 'Street, City, District',
                        icon: Icons.location_on_outlined, inputType: TextInputType.streetAddress,
                        textCap: TextCapitalization.sentences, maxLines: 2),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: const Icon(Icons.wc_rounded, size: 17, color: _kTextMuted),
                        labelStyle: const TextStyle(fontSize: 12, color: _kTextSecondary),
                        filled: true, fillColor: _kCardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
                      ),
                      style: const TextStyle(fontSize: 13, color: _kTextPrimary, fontWeight: FontWeight.w600),
                      dropdownColor: Colors.white,
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) { if (v != null) setState(() => _gender = v); },
                    ),
                  ]),
                ),

                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_saving ? 'Saving…' : (_isEdit ? 'Update Receptionist' : 'Save Receptionist'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary, foregroundColor: Colors.white,
                      disabledBackgroundColor: _kPrimaryLight, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(children: [
          Container(width: 3, height: 12,
              decoration: BoxDecoration(gradient: _kGradient, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: _kTextPrimary, letterSpacing: 0.3)),
        ]),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    TextCapitalization textCap = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 1,
    bool readOnly = false,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        textCapitalization: textCap,
        inputFormatters: formatters,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 13, color: _kTextPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon, size: 17, color: _kTextMuted),
          labelStyle: const TextStyle(fontSize: 12, color: _kTextSecondary),
          hintStyle: const TextStyle(fontSize: 12, color: _kTextMuted),
          filled: true, fillColor: _kCardBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kError)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kError, width: 1.5)),
        ),
      );
}
