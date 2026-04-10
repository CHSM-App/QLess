import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/repository/appointment_repo.dart';

class AppointmentUsecase {
  final AppointmentRepository appointmentRepository;

  AppointmentUsecase(this.appointmentRepository);

  Future<AppointmentResponseModel> getAppointmentAvailability(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.getAppointmentAvailability(appointmentRequest);
  }

  Future<AppointmentResponseModel> bookAppointment(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.bookAppointment(appointmentRequest);
  }

  Future<AppointmentResponseModel> cancelAppointment(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.cancelAppointment(appointmentRequest);
  }

  Future<AppointmentResponseModel> updateQueueStatus(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.updateQueueStatus(appointmentRequest);
  }

  Future<List<MonthSlotData>> getBookedSlots(int doctorId) {
    return appointmentRepository.getBookedSlots(doctorId);
  }

  Future<List<AppointmentList>> fetchPatientAppointments(int doctorId) {
    return appointmentRepository.fetchPatientAppointments(doctorId);
  }

  Future<List<AppointmentList>> getPatientAppointments(int familyId) {
    return appointmentRepository.getPatientAppointments(familyId);
  }

  Future<AppointmentResponseModel> queueNext(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.queueNext(appointmentRequest);
  }

  Future<AppointmentResponseModel> queueStart(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.queueStart(appointmentRequest);
  }

  Future<AppointmentResponseModel> queuePause(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.queuePause(appointmentRequest);
  }

  Future<AppointmentResponseModel> queueStop(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.queueStop(appointmentRequest);
  }

  Future<AppointmentResponseModel> queueSkip(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.queueSkip(appointmentRequest);
  }

  Future<AppointmentResponseModel> queueRecall(
    AppointmentRequestModel appointmentRequest,
  ) {
    return appointmentRepository.queueRecall(appointmentRequest);
  }
}
