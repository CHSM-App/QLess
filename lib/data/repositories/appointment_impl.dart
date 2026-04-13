import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/repository/appointment_repo.dart';

class AppointmentImpl implements AppointmentRepository {
  final ApiService apiService;

  AppointmentImpl(this.apiService);

  @override
  Future<AppointmentResponseModel> getAppointmentAvailability(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.getAppointmentAvailability(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> bookAppointment(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.bookAppointment(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> rescheduleAppointment(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.rescheduleAppointment(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> cancelAppointment(int appointmentId) {
    return apiService.cancelAppointment(appointmentId);
  }

  @override
  Future<AppointmentResponseModel> updateQueueStatus(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.updateQueueStatus(appointmentRequest);
  }

  @override
  Future<List<MonthSlotData>> getBookedSlots(int doctorId) {
    return apiService.getBookedSlots(doctorId);
  }

  @override
  Future<List<AppointmentList>> fetchPatientAppointments(int doctorId) {
    return apiService.fetchPatientAppointments(doctorId);
  }

  @override
  Future<List<AppointmentList>> getPatientAppointments(int familyId) {
    return apiService.getPatientAppointments(familyId);
  }

  @override
  Future<AppointmentResponseModel> queueNext(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.queueNext(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> queueStart(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.queueStart(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> queuePause(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.queuePause(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> queueStop(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.queueStop(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> queueSkip(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.queueSkip(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> queueRecall(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.queueRecall(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> startSession(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.startSession(appointmentRequest);
  }

  @override
  Future<AppointmentResponseModel> endSession(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.endSession(appointmentRequest);
  }

}
