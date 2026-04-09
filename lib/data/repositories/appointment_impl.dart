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
  Future<AppointmentResponseModel> cancelAppointment(
    AppointmentRequestModel appointmentRequest,
  ) {
    return apiService.cancelAppointment(appointmentRequest);
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
}
