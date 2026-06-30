import 'package:qless/domain/repository/favorite_repo.dart';

class FavoriteUsecase {
  final FavoriteRepository favoriteRepository;

  FavoriteUsecase(this.favoriteRepository);

  Future<List<dynamic>> getFavoriteDoctors(int patientId) =>
      favoriteRepository.getFavoriteDoctors(patientId);

  Future<Map<String, dynamic>> getFavoriteDoctor(
    int patientId,
    int doctorId,
    String clinicId,
  ) {
    return favoriteRepository.getFavoriteDoctor(patientId, doctorId, clinicId);
  }

  Future<Map<String, dynamic>> addFavoriteDoctor(
    int patientId,
    int doctorId, {
    String? clinicId,
  }) {
    return favoriteRepository.addFavoriteDoctor(patientId, doctorId, clinicId: clinicId);
  }

  Future<Map<String, dynamic>> deleteFavoriteDoctor(
    int patientId,
    int doctorId,
    String clinicId,
  ) {
    return favoriteRepository.deleteFavoriteDoctor(patientId, doctorId, clinicId);
  }
}
