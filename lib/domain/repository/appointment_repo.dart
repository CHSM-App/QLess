import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';

abstract class AppointmentRepository {
  Future<AppointmentResponseModel> getAppointmentAvailability(
    AppointmentRequestModel appointmentRequest,
  );

  Future<AppointmentResponseModel> bookAppointment(
    AppointmentRequestModel appointmentRequest,
  );

  Future<AppointmentResponseModel> cancelAppointment(
    AppointmentRequestModel appointmentRequest,
  );

  Future<AppointmentResponseModel> updateQueueStatus(
    AppointmentRequestModel appointmentRequest,
  );

  Future<List<MonthSlotData>> getBookedSlots(int doctorId);

  Future<List<AppointmentList>> fetchPatientAppointments(int doctorId);

  Future<List<AppointmentList>> getPatientAppointments(int patientId);
  
}
