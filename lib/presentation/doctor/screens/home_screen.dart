import 'package:flutter/material.dart';


// ─── Data Models ────────────────────────────────────────────────────────────

enum QueueStatus { running, paused, waiting, completed }

class Patient {
  final int token;
  final String name;
  final String gender;
  final int age;
  final String reason;
  final QueueStatus status;
  final String initials;
  final Color avatarColor;
  final Color avatarTextColor;

  const Patient({
    required this.token,
    required this.name,
    required this.gender,
    required this.age,
    required this.reason,
    required this.status,
    required this.initials,
    required this.avatarColor,
    required this.avatarTextColor,
  });
}

// ─── Sample Data ─────────────────────────────────────────────────────────────

final List<Patient> waitingPatients = [
  Patient(
    token: 9,
    name: 'Rahul Singh',
    gender: 'M',
    age: 28,
    reason: 'Fever & Cold',
    status: QueueStatus.waiting,
    initials: 'RS',
    avatarColor: const Color(0xFFE3F2FD),
    avatarTextColor: const Color(0xFF1565C0),
  ),
  Patient(
    token: 10,
    name: 'Anita Mehra',
    gender: 'F',
    age: 52,
    reason: 'Diabetes Review',
    status: QueueStatus.waiting,
    initials: 'AM',
    avatarColor: const Color(0xFFF3E5F5),
    avatarTextColor: const Color(0xFF7B1FA2),
  ),
  Patient(
    token: 11,
    name: 'Vijay Kumar',
    gender: 'M',
    age: 67,
    reason: 'BP Checkup',
    status: QueueStatus.paused,
    initials: 'VK',
    avatarColor: const Color(0xFFE8F5E9),
    avatarTextColor: const Color(0xFF2E7D32),
  ),
  Patient(
    token: 12,
    name: 'Sunita Patil',
    gender: 'F',
    age: 41,
    reason: 'Skin Allergy',
    status: QueueStatus.waiting,
    initials: 'SP',
    avatarColor: const Color(0xFFFFF3E0),
    avatarTextColor: const Color(0xFFE65100),
  ),
  Patient(
    token: 13,
    name: 'Nikhil Joshi',
    gender: 'M',
    age: 19,
    reason: 'Eye Infection',
    status: QueueStatus.waiting,
    initials: 'NJ',
    avatarColor: const Color(0xFFFCE4EC),
    avatarTextColor: const Color(0xFF880E4F),
  ),
  Patient(
    token: 14,
    name: 'Kavitha Rao',
    gender: 'F',
    age: 58,
    reason: 'Follow-up Visit',
    status: QueueStatus.waiting,
    initials: 'KR',
    avatarColor: const Color(0xFFE0F7FA),
    avatarTextColor: const Color(0xFF006064),
  ),
];

const Patient currentPatient = Patient(
  token: 8,
  name: 'Priya Sharma',
  gender: 'F',
  age: 34,
  reason: 'General Checkup',
  status: QueueStatus.running,
  initials: 'PS',
  avatarColor: Color(0xFFE3F2FD),
  avatarTextColor: Color(0xFF1565C0),
);

// ─── Home Page ───────────────────────────────────────────────────────────────

class QueueHomePage extends StatefulWidget {
  const QueueHomePage({super.key});

  @override
  State<QueueHomePage> createState() => _QueueHomePageState();
}

class _QueueHomePageState extends State<QueueHomePage> {
  QueueStatus _currentStatus = QueueStatus.running;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color.fromARGB(255, 208, 234, 253)],
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: Container(
                    color: const Color(0xFFF0F4F8),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildQueueCard(),
                          const SizedBox(height: 14),
                          _buildQuickActions(),
                          const SizedBox(height: 6),
                          _buildWaitingHeader(),
                          _buildPatientList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Queue Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Monday, 30 March',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
          // Container(
          //   width: 42,
          //   height: 42,
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.25),
          //     shape: BoxShape.circle,
          //     border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          //   ),
          //   alignment: Alignment.center,
          //   child: const Text(
          //     'DM',
          //     style: TextStyle(
          //       color: Colors.white,
          //       fontWeight: FontWeight.w700,
          //       fontSize: 14,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // ─── Queue Card ────────────────────────────────────────────────────────────

  Widget _buildQueueCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE QUEUE STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 12),
            _buildTokenRow(),
            const SizedBox(height: 14),
            _buildPatientInfoRow(),
            const SizedBox(height: 14),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenRow() {
    return Row(
      children: [
        _tokenBox(
          label: 'Current',
          value: '08',
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          labelColor: Colors.white70,
          valueColor: Colors.white,
        ),
        const SizedBox(width: 10),
        _tokenBox(
          label: 'Up Next',
          value: '09',
          color: const Color(0xFFF0F4F8),
          labelColor: const Color(0xFF90A4AE),
          valueColor: const Color(0xFF37474F),
        ),
        const SizedBox(width: 10),
        _tokenBox(
          label: 'Total',
          value: '14',
          color: const Color(0xFFE8F5E9),
          labelColor: const Color(0xFF81C784),
          valueColor: const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  Widget _tokenBox({
    required String label,
    required String value,
    Gradient? gradient,
    Color? color,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFF0F4F8), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Priya Sharma',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'F · 34 yrs · General Checkup',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          _statusBadge(_currentStatus),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _actionBtn(
          label: '▶  Start',
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          textColor: Colors.white,
          onTap: () {
            setState(() => _currentStatus = QueueStatus.running);
            _showSnack('Queue started');
          },
        ),
        const SizedBox(width: 8),
        _actionBtn(
          label: '⏸  Pause',
          color: const Color(0xFFFFF8E1),
          textColor: const Color(0xFFF57F17),
          border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
          onTap: () {
            setState(() => _currentStatus = QueueStatus.paused);
            _showSnack('Queue paused');
          },
        ),
        const SizedBox(width: 8),
        _actionBtn(
          label: '✕  Close',
          color: const Color(0xFFFFEBEE),
          textColor: const Color(0xFFC62828),
          border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
          onTap: () => _showSnack('Queue closed'),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    Color? color,
    required Color textColor,
    Border? border,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: gradient,
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _quickBtn(
                  label: '✓  Mark Complete',
                  color: const Color(0xFFE8F5E9),
                  textColor: const Color(0xFF2E7D32),
                  onTap: () => _showSnack('Patient marked complete'),
                ),
                const SizedBox(width: 10),
                _quickBtn(
                  label: '⏭  Skip Patient',
                  color: const Color(0xFFFBE9E7),
                  textColor: const Color(0xFFBF360C),
                  onTap: () => _showSnack('Patient skipped'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Waiting List ──────────────────────────────────────────────────────────

  Widget _buildWaitingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Waiting Patients',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
            ),
          ),
          Text(
            '${waitingPatients.length} remaining',
            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE)),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: waitingPatients
            .map((p) => _patientCard(p))
            .toList(),
      ),
    );
  }

  Widget _patientCard(Patient patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _avatarCircle(patient.initials, patient.avatarColor, patient.avatarTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.gender} · ${patient.age} yrs · ${patient.reason}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE)),
                ),
                const SizedBox(height: 6),
                _statusBadge(patient.status),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                patient.token.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E88E5),
                  height: 1,
                ),
              ),
              const Text(
                'Token',
                style: TextStyle(fontSize: 10, color: Color(0xFFB0BEC5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String initials, Color bg, Color fg) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _statusBadge(QueueStatus status) {
    late String label;
    late Color bg;
    late Color fg;
    late Color dot;

    switch (status) {
      case QueueStatus.running:
        label = 'Running';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        dot = const Color(0xFF43A047);
        break;
      case QueueStatus.paused:
        label = 'Paused';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        dot = const Color(0xFFFFB300);
        break;
      case QueueStatus.waiting:
        label = 'Waiting';
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        dot = const Color(0xFFE53935);
        break;
      case QueueStatus.completed:
        label = 'Completed';
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        dot = const Color(0xFF1E88E5);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}