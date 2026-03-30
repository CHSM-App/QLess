import 'package:flutter/material.dart';

// ─── Queue Status ───────────────────────────────────────────────────────────
enum QueueStatus { running, paused, closed }

extension QueueStatusExt on QueueStatus {
  String get label => name[0].toUpperCase() + name.substring(1);

  Color get color {
    switch (this) {
      case QueueStatus.running: return const Color(0xFF16A06A);
      case QueueStatus.paused:  return const Color(0xFFF5A623);
      case QueueStatus.closed:  return const Color(0xFFE24B4A);
    }
  }
}

// ─── Patient ─────────────────────────────────────────────────────────────────
class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final int token;
  final DateTime arrivedAt;
  PatientStatus status;
  Prescription? prescription;
  List<Visit> visitHistory;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.token,
    required this.arrivedAt,
    this.status = PatientStatus.waiting,
    this.prescription,
    this.visitHistory = const [],
  });

  String get waitingDuration {
    final diff = DateTime.now().difference(arrivedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}

enum PatientStatus { waiting, inConsultation, completed, skipped }

// ─── Queue Stats ─────────────────────────────────────────────────────────────
class QueueStats {
  final int total;
  final int waiting;
  final int completed;
  final int skipped;
  final int currentToken;

  const QueueStats({
    required this.total,
    required this.waiting,
    required this.completed,
    required this.skipped,
    required this.currentToken,
  });
}

// ─── Medicine ─────────────────────────────────────────────────────────────────
class Medicine {
  String name;
  bool morning;
  bool afternoon;
  bool night;
  int durationDays;
  String instructions; // e.g. "After food"

  Medicine({
    required this.name,
    this.morning = false,
    this.afternoon = false,
    this.night = false,
    this.durationDays = 3,
    this.instructions = 'After food',
  });

  Medicine copyWith({
    String? name,
    bool? morning,
    bool? afternoon,
    bool? night,
    int? durationDays,
    String? instructions,
  }) {
    return Medicine(
      name: name ?? this.name,
      morning: morning ?? this.morning,
      afternoon: afternoon ?? this.afternoon,
      night: night ?? this.night,
      durationDays: durationDays ?? this.durationDays,
      instructions: instructions ?? this.instructions,
    );
  }
}

// ─── Prescription ─────────────────────────────────────────────────────────────
class Prescription {
  String symptoms;
  String diagnosis;
  String observations;
  List<Medicine> medicines;
  String notes;
  DateTime? followUpDate;
  final DateTime createdAt;

  Prescription({
    this.symptoms = '',
    this.diagnosis = '',
    this.observations = '',
    List<Medicine>? medicines,
    this.notes = '',
    this.followUpDate,
    DateTime? createdAt,
  })  : medicines = medicines ?? [],
        createdAt = createdAt ?? DateTime.now();
}

// ─── Visit (History) ─────────────────────────────────────────────────────────
class Visit {
  final DateTime date;
  final String diagnosis;
  final String symptoms;
  final List<String> medicineNames;

  const Visit({
    required this.date,
    required this.diagnosis,
    required this.symptoms,
    required this.medicineNames,
  });
}

// ─── Sample Data ─────────────────────────────────────────────────────────────
class SampleData {
  static List<Patient> get patients => [
        Patient(
          id: '1',
          name: 'Priya Mehta',
          age: 28,
          gender: 'F',
          token: 15,
          arrivedAt: DateTime.now().subtract(const Duration(minutes: 12)),
          status: PatientStatus.inConsultation,
          visitHistory: [
            Visit(
              date: DateTime.now().subtract(const Duration(days: 87)),
              diagnosis: 'Seasonal Allergies',
              symptoms: 'Sneezing, runny nose, itchy eyes',
              medicineNames: ['Loratadine 10mg', 'Nasal spray'],
            ),
            Visit(
              date: DateTime.now().subtract(const Duration(days: 197)),
              diagnosis: 'Gastritis',
              symptoms: 'Stomach pain, acidity, nausea',
              medicineNames: ['Pantoprazole', 'Domperidone', 'Antacid'],
            ),
          ],
        ),
        Patient(
          id: '2',
          name: 'Rohan Patil',
          age: 45,
          gender: 'M',
          token: 16,
          arrivedAt: DateTime.now().subtract(const Duration(minutes: 8)),
          status: PatientStatus.waiting,
        ),
        Patient(
          id: '3',
          name: 'Sunita Desai',
          age: 61,
          gender: 'F',
          token: 17,
          arrivedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          status: PatientStatus.waiting,
        ),
        Patient(
          id: '4',
          name: 'Amit Joshi',
          age: 34,
          gender: 'M',
          token: 18,
          arrivedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          status: PatientStatus.waiting,
        ),
        Patient(
          id: '5',
          name: 'Kavita Rao',
          age: 52,
          gender: 'F',
          token: 10,
          arrivedAt: DateTime.now().subtract(const Duration(hours: 2)),
          status: PatientStatus.completed,
          prescription: Prescription(
            symptoms: 'Joint pain, swelling in knees',
            diagnosis: 'Osteoarthritis',
            medicines: [
              Medicine(name: 'Diclofenac 50mg', morning: true, afternoon: false, night: true, durationDays: 5),
              Medicine(name: 'Calcium + D3', morning: true, afternoon: false, night: false, durationDays: 30),
            ],
          ),
        ),
      ];

  static QueueStats get stats => const QueueStats(
        total: 24,
        waiting: 8,
        completed: 14,
        skipped: 2,
        currentToken: 15,
      );
}