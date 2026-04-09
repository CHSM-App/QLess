abstract class FavoriteRepository {
  Future<Map<String, dynamic>> getFavoriteDoctor(
    int patientId,
    int doctorId,
  );

  Future<Map<String, dynamic>> addFavoriteDoctor(
    int patientId,
    int doctorId,
  );

  Future<Map<String, dynamic>> deleteFavoriteDoctor(
    int patientId,
    int doctorId,
  );
}
