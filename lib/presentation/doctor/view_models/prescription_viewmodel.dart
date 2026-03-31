import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/usecase/doctor_login_usecase.dart';
import 'package:qless/domain/usecase/prescription_usecase.dart';

class PrescriptionState {
  final bool isLoading;
  final String? error;


  const PrescriptionState({
    this.isLoading = false,
    this.error,
 
  });

  PrescriptionState copyWith({
    bool? isLoading,
    String? error,


  }) {
    return PrescriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
   
    );
  }
}

class PrescriptionViewmodel extends StateNotifier<PrescriptionState> {
  final PrescriptionUsecase usecase;
  PrescriptionViewmodel(this.usecase) : super(const PrescriptionState()) ;

  Future<void> insertPrescription(PrescriptionModel prescription) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.insertPrescription(prescription);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}