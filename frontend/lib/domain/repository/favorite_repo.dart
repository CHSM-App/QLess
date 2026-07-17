abstract class FavoriteRepository {
  Future<List<dynamic>> getFavoriteDoctors(int patientId);

  Future<Map<String, dynamic>> getFavoriteDoctor(
    int patientId,
    int doctorId,
    String clinicId,
  );

  Future<Map<String, dynamic>> addFavoriteDoctor(
    int patientId,
    int doctorId, {
    String? clinicId,
  });

  Future<Map<String, dynamic>> deleteFavoriteDoctor(
    int patientId,
    int doctorId,
    String clinicId,
  );
}
