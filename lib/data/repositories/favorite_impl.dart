import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/repository/favorite_repo.dart';

class FavoriteImpl implements FavoriteRepository {
  final ApiService apiService;

  FavoriteImpl(this.apiService);

  @override
  Future<Map<String, dynamic>> getFavoriteDoctor(int patientId, int doctorId) {
    return apiService.getFavoriteDoctor(patientId, doctorId).then(_asMap);
  }

  @override
  Future<Map<String, dynamic>> addFavoriteDoctor(int patientId, int doctorId) {
    return apiService
        .addFavoriteDoctor({'patient_id': patientId, 'doctor_id': doctorId})
        .then(_asMap);
  }

  @override
  Future<Map<String, dynamic>> deleteFavoriteDoctor(
    int patientId,
    int doctorId,
  ) {
    return apiService.deleteFavoriteDoctor(patientId, doctorId).then(_asMap);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
