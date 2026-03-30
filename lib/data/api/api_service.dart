import 'package:dio/dio.dart';
import 'package:qless/core/constant.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/models/master_data.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/patients.dart';
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

  @POST("login/logout")
  Future<dynamic> logOut(@Body() TokenResponse tokenResponse);

  //------------------------------------------//DOCTOR API//---------------------------------------
  // GET API
  @GET("login/checkPhoneDoctor")
  Future<List<DoctorLogin>> checkPhoneDoctor(@Query("mobile") String mobile);

  @GET("doctor/users/getMedicineTypes")
  Future<List<Medicine>> fetchMedicineTypes();

  @GET("doctor/users/getAllMedicines/{doctor_id}")
  Future<List<Medicine>> fetchAllMedicines(@Path("doctor_id") int doctorId);

  // Doctor's Post API 
  @POST("login/addDoctorDetails")
  Future<dynamic> addDoctorDetails(@Body() DoctorLogin doctorLogin);

  @POST("doctor/insert/insertMedicine")
  Future<dynamic> addMedicine(@Body() Medicine medicine);


  //-------------------------------------------//PATIENT API//----------------------------------------------
  // GET API
  @GET("login/checkPhonePatient")
  Future<List<Patients>> checkPhonePatient(@Query("mobileNo") String mobileNo);

  // POST API
  @POST("login/insertPatient")
  Future<dynamic> addPatient(@Body() Patients patient);


  @POST("patient/insert/insertFamilyMember")
  Future<dynamic> addFamilyMember(@Body() FamilyMember member);

  //-----------------------------------------//PATIENT AND DOCTOR COMMON API//------------------------------
  
  @GET("users/fetchGenderList")
  Future<List<GenderModel>> fetchGenderList();

  
  @GET("users/fetchRelationList")
  Future<List<RelationModel>> fetchRelationList();

  
  @GET("users/fetchBloodGroupList")
  Future<List<BloodGroupModel>> fetchBloodGroupList();
}
