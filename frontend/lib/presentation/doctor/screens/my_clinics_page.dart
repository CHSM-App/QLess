import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qless/core/network/auth_image_url.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_availability_page.dart';

// ── Colour palette (mirrors doctor_registration.dart) ─────────────
const _kPrimary       = Color(0xFF26C6B0);
const _kPrimaryDark   = Color(0xFF1EA898);
const _kPrimaryDarker = Color(0xFF158578);
const _kPrimaryLight  = Color(0xFFD9F5F1);

const _kBgSoft  = Color(0xFFF7FAFC);
const _kSurface = Color(0xFFFFFFFF);

const _kTextPrimary   = Color(0xFF1A202C);
const _kTextSecondary = Color(0xFF4A5568);
const _kTextMuted     = Color(0xFF94A3B8);

const _kBorder       = Color(0xFFF1F5F9);
const _kBorderStrong = Color(0xFFE2E8F0);

const _kError      = Color(0xFFFC8181);
const _kPurple     = Color(0xFF9F7AEA);
const _kPurpleLight = Color(0xFFEDE9FE);

const LinearGradient _kGrad = LinearGradient(
  colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ════════════════════════════════════════════════════════════════════
//  MY CLINICS PAGE
// ════════════════════════════════════════════════════════════════════
class MyClinicsPage extends ConsumerStatefulWidget {
  const MyClinicsPage({super.key});

  @override
  ConsumerState<MyClinicsPage> createState() => _MyClinicsPageState();
}

class _MyClinicsPageState extends ConsumerState<MyClinicsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final doctorId = ref.read(doctorLoginViewModelProvider).doctorId;
      if (doctorId != null && doctorId > 0) {
        ref.read(doctorLoginViewModelProvider.notifier).getDoctorClinics(doctorId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorLoginViewModelProvider);
    final primaryClinicId = state.clinic_id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: _kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Clinics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kBorder),
        ),
      ),
      body: state.clinicsList == null
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : state.clinicsList!.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
              error: (e, _) => Center(
                child: Text('Error: $e', style: const TextStyle(color: _kError)),
              ),
              data: (clinics) => _buildList(clinics, primaryClinicId),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddClinic(context),
        backgroundColor: _kPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Clinic',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildList(List<DoctorDetails> clinics, String? primaryClinicId) {
    if (clinics.isEmpty) {
      return const Center(
        child: Text('No clinics found', style: TextStyle(color: _kTextMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      itemCount: clinics.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ClinicCard(
        clinic: clinics[i],
        isPrimary: clinics[i].clinicId == primaryClinicId,
        onEdit: () => _openEditClinic(clinics[i]),
        onSchedule: () => _openSchedule(clinics[i].clinicId),
        onDelete: () => _confirmDelete(clinics[i]),
      ),
    );
  }

  void _openAddClinic(BuildContext context) {
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClinicPage(doctorId: doctorId ?? 0),
      ),
    ).then((_) {
      if (doctorId != null && doctorId > 0) {
        ref.read(doctorLoginViewModelProvider.notifier).getDoctorClinics(doctorId);
      }
    });
  }

  void _openEditClinic(DoctorDetails clinic) {
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClinicPage(doctorId: doctorId ?? 0, editClinic: clinic),
      ),
    ).then((_) {
      if (doctorId != null && doctorId > 0) {
        ref.read(doctorLoginViewModelProvider.notifier).getDoctorClinics(doctorId);
      }
    });
  }

  void _openSchedule(String? clinicId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorAvailabilityPage(clinicId: clinicId)),
    );
  }

  void _confirmDelete(DoctorDetails clinic) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Clinic',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextPrimary)),
        content: Text(
          'Delete "${clinic.clinicName ?? 'this clinic'}"? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
              final ok = await ref
                  .read(doctorLoginViewModelProvider.notifier)
                  .deleteClinic(clinic.clinicId ?? '', doctorId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Clinic deleted' : 'Failed to delete clinic'),
                backgroundColor: ok ? _kPrimary : _kError,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CLINIC CARD
// ════════════════════════════════════════════════════════════════════
class _ClinicCard extends StatelessWidget {
  final DoctorDetails clinic;
  final bool isPrimary;
  final VoidCallback onEdit;
  final VoidCallback onSchedule;
  final VoidCallback onDelete;

  const _ClinicCard({
    required this.clinic,
    required this.isPrimary,
    required this.onEdit,
    required this.onSchedule,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isPrimary ? _kPrimary.withValues(alpha: 0.4) : _kBorderStrong),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: _kGrad, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            clinic.clinicName ?? '—',
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: _kTextPrimary),
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kPrimaryLight, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Primary',
                                style: TextStyle(
                                    fontSize: 10, color: _kPrimaryDark, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (clinic.clinicAddress != null && clinic.clinicAddress!.isNotEmpty)
                      Text(clinic.clinicAddress!,
                          style: const TextStyle(fontSize: 12, color: _kTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (clinic.consultationFee != null)
                      Text('₹${clinic.consultationFee!.toStringAsFixed(0)} consultation',
                          style: const TextStyle(fontSize: 11, color: _kTextMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),
          Row(
            children: [
              _ActionChip(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: _kPrimaryDark,
                bg: _kPrimaryLight,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.calendar_month_outlined,
                label: 'Schedule',
                color: const Color(0xFF6C63FF),
                bg: const Color(0xFFEDE9FE),
                onTap: onSchedule,
              ),
              const Spacer(),
              if (!isPrimary)
                _ActionChip(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: _kError,
                  bg: const Color(0xFFFEE2E2),
                  onTap: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  ADD CLINIC PAGE
// ════════════════════════════════════════════════════════════════════
class AddClinicPage extends ConsumerStatefulWidget {
  final int doctorId;
  final DoctorDetails? editClinic;
  const AddClinicPage({super.key, required this.doctorId, this.editClinic});

  @override
  ConsumerState<AddClinicPage> createState() => _AddClinicPageState();
}

class _AddClinicPageState extends ConsumerState<AddClinicPage> {
  late final _nameCtrl    = TextEditingController(text: widget.editClinic?.clinicName ?? '');
  late final _addressCtrl = TextEditingController(text: widget.editClinic?.clinicAddress ?? '');
  late final _feeCtrl     = TextEditingController(
      text: widget.editClinic?.consultationFee != null
          ? widget.editClinic!.consultationFee!.toStringAsFixed(0)
          : '');
  late final _emailCtrl   = TextEditingController(text: widget.editClinic?.clinicEmail ?? '');
  late final _contactCtrl = TextEditingController(text: widget.editClinic?.clinicContact ?? '');
  late final _websiteCtrl = TextEditingController(text: widget.editClinic?.websiteName ?? '');

  final List<File>   _clinicImages        = [];
  final List<String> _networkImages       = [];
  final List<String> _removedNetworkUrls  = [];
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  String? _nameError;
  String? _addressError;

  bool get _isEditMode => widget.editClinic != null;

  @override
  void initState() {
    super.initState();
    if (widget.editClinic != null) {
      _latitude  = widget.editClinic!.latitude;
      _longitude = widget.editClinic!.longitude;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGallery());
    }
  }

  Future<void> _fetchGallery() async {
    final clinicId = widget.editClinic?.clinicId;
    if (clinicId == null || clinicId.isEmpty) return;
    try {
      final urls = await ref
          .read(doctorLoginViewModelProvider.notifier)
          .fetchClinicGallery(clinicId);
      if (mounted) setState(() { _networkImages
        ..clear()
        ..addAll(urls); });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _feeCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  // ── Location ─────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError('Location permission permanently denied. Enable it in settings.');
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      _showError('Failed to get location');
    }
  }

  Future<void> _selectFromMap() async {
    final result = await Navigator.push<gmap.LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLatLng: (_latitude != null && _longitude != null)
              ? gmap.LatLng(_latitude!, _longitude!)
              : const gmap.LatLng(15.9073, 73.6990),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _latitude  = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  void _previewClinicPhoto(int index) {
    final photo = _clinicImages[index];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: [
          InteractiveViewer(
            child: Center(child: Image.file(photo, fit: BoxFit.contain)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        _clinicImages.addAll(picked.map((x) => File(x.path)));
        if (_clinicImages.length > 5) {
          _clinicImages.removeRange(5, _clinicImages.length);
        }
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────
  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: _kTextPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _nameError    = _nameCtrl.text.trim().isEmpty ? 'Clinic name is required' : null;
      _addressError = _addressCtrl.text.trim().isEmpty ? 'Address is required' : null;
    });
    if (_nameError != null || _addressError != null) ok = false;
    return ok;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    final clinic = DoctorDetails(
      doctorId: widget.doctorId,
      clinicId: widget.editClinic?.clinicId,
      clinicName: _nameCtrl.text.trim(),
      clinicAddress: _addressCtrl.text.trim(),
      consultationFee: double.tryParse(_feeCtrl.text.trim()),
      clinicEmail: _emailCtrl.text.trim(),
      clinicContact: _contactCtrl.text.trim(),
      websiteName: _websiteCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    final notifier = ref.read(doctorLoginViewModelProvider.notifier);

    // Delete removed network photos first (edit mode only)
    if (_isEditMode && _removedNetworkUrls.isNotEmpty && widget.editClinic?.clinicId != null) {
      await notifier.deleteClinicGallery(widget.editClinic!.clinicId!, _removedNetworkUrls);
    }

    final ok = _isEditMode
        ? await notifier.updateClinic(clinic, clinicImages: _clinicImages.isEmpty ? null : _clinicImages)
        : await notifier.addClinic(clinic, clinicImages: _clinicImages.isEmpty ? null : _clinicImages);

    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Clinic updated successfully' : 'Clinic added successfully'),
          backgroundColor: _kPrimary,
        ),
      );
      Navigator.pop(context);
    } else {
      final err = ref.read(doctorLoginViewModelProvider).error ?? 'Failed to add clinic';
      _showError(err);
    }
  }

  // ── Field builders (same style as doctor_registration.dart) ───────
  Widget _buildField(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    IconData? icon,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D2E), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _kTextMuted, fontSize: 13.5),
              prefixIcon: icon != null ? Icon(icon, color: _kTextMuted, size: 19) : null,
              filled: true,
              fillColor: _kBgSoft,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _kBorderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: _kError)
                    : const BorderSide(color: _kBorderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: _kError, width: 1.6)
                    : const BorderSide(color: _kPrimary, width: 1.6),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: _kError),
              const SizedBox(width: 5),
              Expanded(
                child: Text(errorText,
                    style: const TextStyle(
                        fontSize: 9.5, color: _kError, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool required = false,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D2E), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _kTextMuted, fontSize: 13.5),
              filled: true,
              fillColor: _kBgSoft,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _kBorderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: _kError)
                    : const BorderSide(color: _kBorderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _kPrimary, width: 1.6),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: _kError),
              const SizedBox(width: 5),
              Expanded(
                child: Text(errorText,
                    style: const TextStyle(
                        fontSize: 9.5, color: _kError, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    final hasLocation = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 50,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: hasLocation ? _kPrimaryLight : _kBgSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: hasLocation ? _kPrimary : _kBorderStrong,
                  width: hasLocation ? 1.6 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                  size: 17,
                  color: hasLocation ? _kPrimaryDark : _kTextMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLocation
                        ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                        : 'No location selected',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasLocation ? _kPrimaryDarker : _kTextMuted,
                      fontWeight: hasLocation ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          _LocationButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Use GPS',
            onTap: _getCurrentLocation,
          ),
          const SizedBox(width: 8),
          _LocationButton(
            icon: Icons.map_outlined,
            tooltip: 'Pick on map',
            onTap: _selectFromMap,
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: _kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Clinic' : 'Add Clinic',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextPrimary),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Clinic Photos ─────────────────────────────────────
            _ClinicPhotoGrid(
              networkImages: _networkImages
                  .map((u) => ref.read(authImageUrlProvider)(u) ?? u)
                  .toList(),
              photos: _clinicImages,
              onAdd: _pickImages,
              onRemoveNetwork: (i) => setState(() {
                final url = _networkImages[i].trim();
                _networkImages.removeAt(i);
                if (url.isNotEmpty) _removedNetworkUrls.add(url);
              }),
              onRemove: (i) => setState(() => _clinicImages.removeAt(i)),
              onPreview: _previewClinicPhoto,
            ),
            const SizedBox(height: 16),

            // ── Clinic Details ────────────────────────────────────
            _SectionCard(
              icon: Icons.local_hospital_outlined,
              iconBg: _kPrimaryLight,
              iconColor: _kPrimaryDark,
              title: 'Clinic Details',
              subtitle: 'Basic information about your clinic',
              children: [
                _buildField(
                  'Clinic Name',
                  _nameCtrl,
                  hint: 'e.g. City Care Clinic',
                  icon: Icons.local_hospital_outlined,
                  required: true,
                  errorText: _nameError,
                ),
                _buildTextArea(
                  'Clinic Address',
                  _addressCtrl,
                  hint: 'Full address with landmark',
                  required: true,
                  errorText: _addressError,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'Contact Number',
                        _contactCtrl,
                        hint: '9876543210',
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        'Clinic Email',
                        _emailCtrl,
                        hint: 'clinic@example.com',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'Website',
                        _websiteCtrl,
                        hint: 'www.yourclinic.com',
                        icon: Icons.public_outlined,
                        keyboard: TextInputType.url,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        'Consultation Fee (₹)',
                        _feeCtrl,
                        hint: '500',
                        icon: Icons.currency_rupee_outlined,
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Clinic Location ───────────────────────────────────
            _SectionCard(
              icon: Icons.location_on_outlined,
              iconBg: _kPrimaryLight,
              iconColor: _kPrimaryDark,
              title: 'Clinic Location',
              subtitle: 'Pin your clinic on the map',
              children: [
                _buildLocationField(),
              ],
            ),
            const SizedBox(height: 28),

            // ── Save Button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kPrimary, _kPrimaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: _saving
                      ? const SizedBox.shrink()
                      : Text(
                          _isEditMode ? 'Update Clinic' : 'Save Clinic',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SECTION CARD
// ════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kTextPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _kTextSecondary,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: _kBorder, height: 22, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CLINIC PHOTO GRID
// ════════════════════════════════════════════════════════════════════
class _ClinicPhotoGrid extends StatelessWidget {
  final List<String> networkImages;
  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveNetwork;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPreview;

  const _ClinicPhotoGrid({
    this.networkImages = const [],
    required this.photos,
    required this.onAdd,
    required this.onRemoveNetwork,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final total  = networkImages.length + photos.length;
    final canAdd = total < 5;
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kTextPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _kPurpleLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.photo_library_outlined, color: _kPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clinic Photos',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextPrimary, letterSpacing: -0.3)),
                    Text('Showcase your space ($total/5)',
                        style: const TextStyle(fontSize: 11.5, color: _kTextSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: _kBorder, height: 22, thickness: 1),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Existing uploaded photos (network)
              ...List.generate(networkImages.length, (i) => _NetworkThumb(
                url: networkImages[i],
                onRemove: () => onRemoveNetwork(i),
              )),
              // Newly picked local photos
              ...List.generate(photos.length, (i) => _PhotoThumb(
                file: photos[i],
                onRemove: () => onRemove(i),
                onTap: () => onPreview(i),
              )),
              if (canAdd)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 86, height: 86,
                    decoration: BoxDecoration(
                      color: _kPrimaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kPrimary.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: _kPrimaryDark, size: 28),
                        SizedBox(height: 4),
                        Text('Add', style: TextStyle(fontSize: 11.5, color: _kPrimaryDarker, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _NetworkThumb({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86, height: 86,
    child: Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url, width: 86, height: 86, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 86, height: 86,
            decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.broken_image_rounded, color: _kTextSecondary, size: 28),
          ),
        ),
      ),
      Positioned(
        top: 4, right: 4,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: _kTextPrimary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
          ),
        ),
      ),
    ]),
  );
}

class _PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PhotoThumb({required this.file, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 86,
        height: 86,
        child: Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file, width: 86, height: 86, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _kTextPrimary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  FIELD LABEL
// ════════════════════════════════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _kTextPrimary,
              letterSpacing: 0.1,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(color: _kError, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ],
      );
}

// ════════════════════════════════════════════════════════════════════
//  LOCATION BUTTON
// ════════════════════════════════════════════════════════════════════
class _LocationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _LocationButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _kPrimaryLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _kPrimary.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, color: _kPrimaryDark, size: 20),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  MAP PICKER SCREEN
// ════════════════════════════════════════════════════════════════════
class _MapPickerScreen extends StatefulWidget {
  final gmap.LatLng initialLatLng;
  const _MapPickerScreen({required this.initialLatLng});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late gmap.LatLng _selected;
  gmap.GoogleMapController? _mapController;

  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();

  static const _apiKey = 'AIzaSyDTRL5VzQ9UAwsCB9uCbSNj5wZasYHjFKA';

  List<Map<String, dynamic>> _predictions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLatLng;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _predictions = []; _showSuggestions = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:in'
        '&language=en'
        '&key=$_apiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions']);
          _showSuggestions = _predictions.isNotEmpty;
        });
      } else {
        setState(() { _predictions = []; _showSuggestions = false; });
      }
    } catch (e) {
      debugPrint('Places search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    _searchCtrl.text = prediction['description'] ?? '';
    try {
      final placeId = prediction['place_id'];
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_apiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        final latLng = gmap.LatLng(loc['lat'], loc['lng']);
        setState(() => _selected = latLng);
        _mapController?.animateCamera(
          gmap.CameraUpdate.newCameraPosition(
            gmap.CameraPosition(target: latLng, zoom: 15),
          ),
        );
      }
    } catch (e) {
      debugPrint('Place detail error: $e');
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() { _predictions = []; _showSuggestions = false; });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _kBgSoft,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: _kTextPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Location',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _kTextPrimary)),
              Text('Pin your clinic on the map',
                  style: TextStyle(fontSize: 11, color: _kTextSecondary)),
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _kBorder),
          ),
        ),
        body: Stack(
          children: [
            gmap.GoogleMap(
              initialCameraPosition:
                  gmap.CameraPosition(target: _selected, zoom: 14),
              onMapCreated: (ctrl) => _mapController = ctrl,
              onTap: (latLng) {
                _focusNode.unfocus();
                setState(() { _selected = latLng; _showSuggestions = false; });
              },
              markers: {
                gmap.Marker(
                  markerId: const gmap.MarkerId('selected'),
                  position: _selected,
                ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
            // Search bar
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x18000000), blurRadius: 14, offset: Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
                      decoration: InputDecoration(
                        hintText: 'Search for a place...',
                        hintStyle: const TextStyle(fontSize: 14, color: _kTextMuted),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _kPrimary)),
                              )
                            : const Icon(Icons.search_rounded, color: _kPrimaryDark, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: _kTextMuted, size: 18),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (_showSuggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 14,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: _predictions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: _kBorder),
                          itemBuilder: (_, i) {
                            final p = _predictions[i];
                            final mainText =
                                p['structured_formatting']?['main_text'] ??
                                p['description'] ?? '';
                            final secondText =
                                p['structured_formatting']?['secondary_text'] ?? '';
                            return InkWell(
                              onTap: () => _selectPrediction(p),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _kPrimaryLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.location_on_rounded,
                                          color: _kPrimaryDark, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(mainText,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _kTextPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          if (secondText.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(secondText,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: _kTextSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.north_west_rounded,
                                        size: 14, color: _kTextMuted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom confirm panel
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                              color: _kPrimaryLight, shape: BoxShape.circle),
                          child: const Icon(Icons.location_on_rounded,
                              color: _kPrimaryDark, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selected coordinates',
                                  style: TextStyle(fontSize: 11, color: _kTextSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                '${_selected.latitude.toStringAsFixed(6)}, '
                                '${_selected.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kPrimary, _kPrimaryDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _selected),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Confirm Location',
                            style:
                                TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
