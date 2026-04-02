import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/usecase/prescription_usecase.dart';

class PrescriptionState {
  final bool isLoading;
  final String? error;
  final List<Medicine>? typeWiseMedicines;

  const PrescriptionState({
    this.isLoading = false,
    this.error,
    this.typeWiseMedicines,
  

  });

  PrescriptionState copyWith({
    bool? isLoading,
    String? error,
    List<Medicine>? typeWiseMedicines,

  }) {
    return PrescriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      typeWiseMedicines: typeWiseMedicines ?? this.typeWiseMedicines,
   
    );
  }
}

class PrescriptionViewmodel extends StateNotifier<PrescriptionState> {
  final PrescriptionUsecase usecase;
  PrescriptionViewmodel(this.usecase) : super(const PrescriptionState()) ;

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return e.message ?? 'Request failed';
    }
    return e.toString();
  }

  Future<void> insertPrescription(PrescriptionModel prescription) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.insertPrescription(prescription);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<void> deleteMedicine(int medicineId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.deleteMedicine(medicineId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

}
