import 'package:dio/dio.dart';
import 'package:qless/core/constant.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/models/master_data.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/models/review_model.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/domain/models/token_response.dart';
import 'package:retrofit/retrofit.dart';
part 'api_service.g.dart';

@RestApi(baseUrl: baseUrl) // <-- replace with your base URL
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;
  @GET("/")
  Future<HttpResponse<dynamic>> checkHealth();

  //----------------------------------------//LOGIN API //---------------------------------
  @POST("login/CreateLogin")
  Future<TokenResponse> createLogin(@Body() TokenResponse tokenResponse);

  @POST("login/refreshAccessToken")
  Future<TokenResponse> refreshAccessToken(@Body() TokenResponse tokenResponse);

  @POST("login/saveFirebaseToken")
  Future<dynamic> saveFcmToken(@Body() TokenResponse token);

  @POST("login/logout")
  Future<dynamic> logOut(@Body() TokenResponse tokenResponse);
  //---------------------------------------------------------------------------------------------------------------------------------------//
  //------------------------------------------//DOCTOR API//---------------------------------------
  // GET API
  @GET("login/checkPhoneDoctor")
  Future<List<DoctorDetails>> checkPhoneDoctor(@Query("mobile") String mobile);

  @GET("doctor/users/getMedicineTypes")
  Future<List<Medicine>> fetchMedicineTypes();

  @GET("doctor/users/getAllMedicines/{doctor_id}")
  Future<List<Medicine>> fetchAllMedicines(@Path("doctor_id") int doctorId);

  @GET("doctor/users/getDoctorSchedule/{doctor_id}")
  Future<DoctorScheduleModel> getDoctorSchedule(
    @Path("doctor_id") int doctorId,
  );

  @GET("doctor/users/appointmentWisePrescription/{appointment_id}")
  Future<List<PrescriptionModel>> appointmentWisePrescription(
    @Path("appointment_id") int appointmentId,
  );

  @GET("doctor/users/patientAppointmentList/{doctor_id}")
  Future<List<AppointmentList>> fetchPatientAppointments(
    @Path("doctor_id") int doctorId,
  );


  //  POST API
  @POST("login/addDoctorDetails")
  Future<dynamic> addDoctorDetails(@Body() DoctorDetails doctorLogin);

  @POST("doctor/insert/insertMedicine")
  Future<dynamic> addMedicine(@Body() Medicine medicine);

  @POST("doctor/insert/insertPrescription")
  Future<dynamic> insertPrescription(@Body() PrescriptionModel prescription);

  @POST("doctor/insert/saveDoctorSchedule")
  Future<dynamic> saveDoctorSchedule(
    @Body() DoctorScheduleModel doctorSchedule,
  );

  @POST("doctor/insert/appointment/queueNext")
  Future<AppointmentResponseModel> queueNext(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("doctor/insert/appointment/queueStart")
  Future<AppointmentResponseModel> queueStart(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("doctor/insert/appointment/queuePause")
  Future<AppointmentResponseModel> queuePause(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("doctor/insert/appointment/queueStop")
  Future<AppointmentResponseModel> queueStop(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("doctor/insert/appointment/queueSkip")
  Future<AppointmentResponseModel> queueSkip(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("doctor/insert/appointment/queueRecall")
  Future<AppointmentResponseModel> queueRecall(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("doctor/insert/appointment/startSession")
Future<AppointmentResponseModel> startSession(
  @Body() AppointmentRequestModel appointmentRequest,
);

@POST("doctor/insert/appointment/endSession")
Future<AppointmentResponseModel> endSession(
  @Body() AppointmentRequestModel appointmentRequest,
);

  @POST("doctor/insert/addQueueStartTime/")
  Future<dynamic> updateLeadTime(
     @Body() DoctorDetails doctor
  );


  // DELETE API
  @DELETE("doctor/index/deleteMedicine/{medicine_id}")
  Future<Medicine> deleteMedicine(@Path("medicine_id") int medicineId);

  //------------------------------------------------------------------------------------------------------------------------//
  //-------------------------------------------//PATIENT API//----------------------------------------------
  // GET API
  @GET("login/checkPhonePatient")
  Future<List<Patients>> checkPhonePatient(@Query("mobileNo") String mobileNo);

  @GET("patient/users/fetchFamilyMembers/{family_id}")
  Future<List<FamilyMember>> fetchFamilyMembers(
    @Path("family_id") int familyId,
  );

  @GET("patient/users/getDoctors")
  Future<List<DoctorDetails>> fetchDoctors();

  @GET("patient/users/getDoctorAvailability/{doctor_id}")
  Future<List<DoctorAvailabilityModel>> getDoctorAvailability(
    @Path("doctor_id") int doctorId,
  );

  @GET("patient/users/getPatientAppointments/{family_id}")
  Future<List<AppointmentList>> getPatientAppointments(
    @Path("family_id") int familyId,
  );

  @GET("patient/users/favoriteDoctor/{patient_id}/{doctor_id}")
  Future<dynamic> getFavoriteDoctor(
    @Path("patient_id") int patientId,
    @Path("doctor_id") int doctorId,
  );

  @GET("patient/users/patientPrescriptionDetails/{prescription_id}")
  Future<List<PrescriptionModel>> patientPrescriptionDetails(
    @Path("prescription_id") int prescriptionId,
  );

  @GET("patient/users/patientPrescriptionList/{patient_id}")
  Future<List<PrescriptionModel>> patientPrescriptionList(
    @Path("patient_id") int patientId,
  );

  @GET("patient/insert/appointment/getAvailability")
  Future<AppointmentResponseModel> getAppointmentAvailability(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @GET("patient/users/appointment/getBookedSlots/{doctor_id}")
  Future<List<MonthSlotData>> getBookedSlots(@Path("doctor_id") int doctorId);

  @GET("patient/users/review/appointment/{appointment_id}")
  Future<List<ReviewModel>> getAppointmentReviews(
    @Path("appointment_id") int appointmentId,
  );

  @GET("patient/users/review/doctor/{doctor_id}")
  Future<List<ReviewModel>> getDoctorReviews(@Path("doctor_id") int doctorId);

  // POST API
  @POST("login/addPatientDetails")
  Future<dynamic> addPatient(@Body() Patients patient);

  @POST("patient/insert/insertFamilyMember")
  Future<dynamic> addFamilyMember(@Body() FamilyMember member);

  @POST("patient/insert/appointment/book")
  Future<AppointmentResponseModel> bookAppointment(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("patient/insert/rescheduleAppointment")
  Future<AppointmentResponseModel> rescheduleAppointment(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("patient/insert/cancelAppointment/{appointment_id}")
  Future<AppointmentResponseModel> cancelAppointment(
    @Path("appointment_id") int appointmentId,
  );

  @POST("patient/insert/appointment/queueStatus")
  Future<AppointmentResponseModel> updateQueueStatus(
    @Body() AppointmentRequestModel appointmentRequest,
  );

  @POST("patient/insert/favoriteDoctor/add")
  Future<dynamic> addFavoriteDoctor(@Body() Map<String, dynamic> body);

  // REVIEW API (appointment-based)
  @POST("patient/insert/review/add")
  Future<dynamic> addAppointmentReview(
    @Body() ReviewRequestModel reviewRequest,
  );

  //DELETE API
  @DELETE("patient/index/deleteFamilyMember/{member_id}")
  Future<FamilyMember> deleteFamilyMember(@Path("member_id") int memberId);

  @DELETE("patient/index/favoriteDoctor/{patient_id}/{doctor_id}")
  Future<dynamic> deleteFavoriteDoctor(
    @Path("patient_id") int patientId,
    @Path("doctor_id") int doctorId,
  );

  //------------------------------------------------------------------------------------------------------------------------------------//
  //-----------------------------------------//PATIENT AND DOCTOR COMMON API//------------------------------

  @GET("users/fetchGenderList")
  Future<List<GenderModel>> fetchGenderList();

  @GET("users/fetchRelationList")
  Future<List<RelationModel>> fetchRelationList();

  @GET("users/fetchBloodGroupList")
  Future<List<BloodGroupModel>> fetchBloodGroupList();
}
