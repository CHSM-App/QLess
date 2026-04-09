import 'package:qless/domain/repository/favorite_repo.dart';

class FavoriteUsecase {
  final FavoriteRepository favoriteRepository;

  FavoriteUsecase(this.favoriteRepository);

  Future<Map<String, dynamic>> getFavoriteDoctor(
    int patientId,
    int doctorId,
  ) {
    return favoriteRepository.getFavoriteDoctor(patientId, doctorId);
  }

  Future<Map<String, dynamic>> addFavoriteDoctor(
    int patientId,
    int doctorId,
  ) {
    return favoriteRepository.addFavoriteDoctor(patientId, doctorId);
  }

  Future<Map<String, dynamic>> deleteFavoriteDoctor(
    int patientId,
    int doctorId,
  ) {
    return favoriteRepository.deleteFavoriteDoctor(patientId, doctorId);
  }
}
