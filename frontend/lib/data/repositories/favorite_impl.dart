import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/repository/favorite_repo.dart';

class FavoriteImpl implements FavoriteRepository {
  final ApiService apiService;

  FavoriteImpl(this.apiService);

  @override
  Future<List<dynamic>> getFavoriteDoctors(int patientId) async {
    final result = await apiService.getFavoriteDoctors(patientId);
    if (result is List) return result;
    return [];
  }

  @override
  Future<Map<String, dynamic>> getFavoriteDoctor(int patientId, int doctorId, String clinicId) {
    return apiService.getFavoriteDoctor(patientId, doctorId, clinicId).then(_asMap);
  }

  @override
  Future<Map<String, dynamic>> addFavoriteDoctor(int patientId, int doctorId, {String? clinicId}) {
    final body = <String, dynamic>{'patient_id': patientId, 'doctor_id': doctorId};
    if (clinicId != null && clinicId.isNotEmpty) body['clinic_id'] = clinicId;
    return apiService.addFavoriteDoctor(body).then(_asMap);
  }

  @override
  Future<Map<String, dynamic>> deleteFavoriteDoctor(
    int patientId,
    int doctorId,
    String clinicId,
  ) {
    return apiService.deleteFavoriteDoctor(patientId, doctorId, clinicId).then(_asMap);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
