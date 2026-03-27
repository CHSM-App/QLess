import 'package:dio/dio.dart';
import 'package:qless/core/constant.dart';
import 'package:qless/domain/models/doctor_login.dart';
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

  @GET("login/checkPhoneDoctor")
  Future<List<DoctorLogin>> checkPhoneDoctor(@Query("mobile") String mobile);

  @POST("login/addDoctorDetails")
  Future<dynamic> addDoctorDetails(@Body() DoctorLogin doctorLogin);

  //-------------------------------------------//PATIENT API//----------------------------------------------

  @GET("login/checkPhonePatient")
  Future<List<Patients>> checkPhonePatient(@Query("mobileNo") String mobileNo);

  @POST("login/insertPatient")
  Future<dynamic> addPatient(@Body() Patients patient);
}
