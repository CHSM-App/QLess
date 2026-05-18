import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctore_settings_viewmodel.dart';

// Local palette (kept independent of the availability page).
const _kPrimary = Color(0xFF26C6B0);
const _kPrimaryLight = Color(0xFFD9F5F1);
const _kTextPrimary = Color(0xFF2D3748);
const _kTextSecondary = Color(0xFF718096);
const _kTextMuted = Color(0xFFA0AEC0);
const _kBorder = Color(0xFFEDF2F7);
const _kError = Color(0xFFE53E3E);

/// Opens the doctor leave / sutti manager as a modal bottom sheet.
Future<void> showDoctorLeaveSheet(BuildContext context, int doctorId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _DoctorLeaveSheet(doctorId: doctorId),
  );
}

class _DoctorLeaveSheet extends ConsumerStatefulWidget {
  final int doctorId;
  const _DoctorLeaveSheet({required this.doctorId});

  @override
  ConsumerState<_DoctorLeaveSheet> createState() => _DoctorLeaveSheetState();
}

class _DoctorLeaveSheetState extends ConsumerState<_DoctorLeaveSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(doctorSettingsViewModelProvider.notifier)
          .getDoctorLeaves(widget.doctorId);
    });
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _pretty(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _kError : _kPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  Future<void> _addLeaveFlow() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, 12, 31),
      helpText: 'Select leave dates',
      saveText: 'Next',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: _kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (range == null || !mounted) return;

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reason (optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_fmt(range.start)}  →  ${_fmt(range.end)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'e.g. Personal leave, Conference',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Apply Leave'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return; // dialog dismissed

    await _submitLeave(
      from: _fmt(range.start),
      to: _fmt(range.end),
      reason: reason.isEmpty ? null : reason,
      force: false,
    );
  }

  Future<void> _submitLeave({
    required String from,
    required String to,
    String? reason,
    required bool force,
  }) async {
    final notifier = ref.read(doctorSettingsViewModelProvider.notifier);
    final (result, affected) = await notifier.addDoctorLeave(
      doctorId: widget.doctorId,
      fromDate: from,
      toDate: to,
      reason: reason,
      force: force,
    );
    if (!mounted) return;

    switch (result) {
      case AddLeaveResult.success:
        HapticFeedback.lightImpact();
        _snack('Leave applied. Affected patients notified.');
        break;
      case AddLeaveResult.needConfirm:
        final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    color: _kError, size: 22),
                SizedBox(width: 8),
                Text('Existing bookings',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              '$affected appointment${affected == 1 ? '' : 's'} '
              '${affected == 1 ? 'is' : 'are'} booked in this date range. '
              'Applying leave will cancel ${affected == 1 ? 'it' : 'them'} '
              'and notify the patient${affected == 1 ? '' : 's'}.',
              style: const TextStyle(fontSize: 13, color: _kTextPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep bookings',
                    style: TextStyle(color: _kTextSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kError,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel & apply leave'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await _submitLeave(
              from: from, to: to, reason: reason, force: true);
        }
        break;
      case AddLeaveResult.error:
        final msg = ref.read(doctorSettingsViewModelProvider).errorMessage;
        _snack(msg.isEmpty ? 'Failed to apply leave' : msg, isError: true);
        break;
    }
  }

  Future<void> _cancelLeave(int leaveId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove this leave?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'The dates re-open for booking. Already-cancelled appointments '
          'are NOT restored — those patients were already asked to rebook.',
          style: TextStyle(fontSize: 13, color: _kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Keep', style: TextStyle(color: _kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kError, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final done = await ref
        .read(doctorSettingsViewModelProvider.notifier)
        .cancelDoctorLeave(doctorId: widget.doctorId, leaveId: leaveId);
    if (!mounted) return;
    _snack(done ? 'Leave removed' : 'Failed to remove leave',
        isError: !done);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorSettingsViewModelProvider);
    final leaves = state.leaves;
    final busy = state.isLeaveBusy;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.beach_access_rounded,
                        color: _kPrimary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Leave',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary)),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPrimary),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Block dates when you are unavailable. Patients '
                    "can't book these dates, and existing bookings are "
                    'cancelled with a notification.',
                    style:
                        TextStyle(fontSize: 11.5, color: _kTextMuted),
                  ),
                ),
              ),
              const Divider(height: 16, color: _kBorder),
              Flexible(
                child: leaves.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(
                          children: const [
                            Icon(Icons.event_available_rounded,
                                size: 38, color: _kTextMuted),
                            SizedBox(height: 8),
                            Text('No upcoming leaves',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _kTextSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        itemCount: leaves.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final l = leaves[i];
                          final single = l.fromDate == l.toDate;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _kPrimaryLight.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: _kBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        single
                                            ? _pretty(l.fromDate)
                                            : '${_pretty(l.fromDate)}  →  ${_pretty(l.toDate)}',
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight:
                                                FontWeight.w700,
                                            color: _kTextPrimary),
                                      ),
                                      if ((l.reason ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(l.reason!.trim(),
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    _kTextSecondary)),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove leave',
                                  onPressed: busy
                                      ? null
                                      : () => _cancelLeave(l.leaveId),
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: _kError,
                                      size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : _addLeaveFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      disabledBackgroundColor: _kPrimaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Leave',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
