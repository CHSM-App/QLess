
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/usecase/doctor_login_usecase.dart';

class DoctorLoginState {
  final bool isLoading;
  final String? error;
  final String? name;
  final String? mobileNo;
  final String? email;
  final String? roleId;
  final String? token;
  
  const DoctorLoginState({
  
    this.isLoading = false,
    this.error,
    this.name,
    this.mobileNo,
    this.email,
    this.roleId,
    this.token,
  });

  DoctorLoginState copyWith({
  
    bool? isLoading,
    String? error,
 
    String? name,
    String? mobileNo,
    String? email,
    String? roleId,
    String? token,
  }) {
    return DoctorLoginState(
     
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    
      name: name ?? this.name,
      mobileNo: mobileNo ?? this.mobileNo,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      token: token ?? this.token,
    
    );
  }
}

class DoctorLoginViewmodel extends StateNotifier<DoctorLoginState> {
  final DoctorLoginUsecase usecase;
  DoctorLoginViewmodel(this.usecase) : super(const DoctorLoginState()) {
    // Initial fetch or setup can be done here if needed
   // loadFromStorage();
  }

  // Future<void> loadFromStorage() async {

  //   final name = await TokenStorage.getValue('name');
  //   print("name is : $name");
  //   final mobileNo = await TokenStorage.getValue('mobile_no');
  //   final email = await TokenStorage.getValue('email');
  //   final  roleId = await TokenStorage.getValue('role_id');
    
  //   final token = await TokenStorage.getValue('token');
  //   final isCheckedIn = await TokenStorage.getValue('isCheckedIn');
  //   final userIdStr = await TokenStorage.getValue('user_id');
  //   final userId = int.tryParse(userIdStr ?? '0') ?? 0;
    
  //   print("company Id : $companyId");
  //   print("company Name : $companyName");
  //   final regionIdStr = await TokenStorage.getValue('region_id');
  //   final regionId = int.tryParse(regionIdStr ?? '');
  //   final joiningDate = await TokenStorage.getValue('joining_date');
  //   final isSuperadminStr = await TokenStorage.getValue('is_superadmin');
  //   final isSuperadmin = isSuperadminStr?.toString() == 'true';
  //   state = state.copyWith(
  //     companyId: companyId,
  //     userId: userId,
  //     name: name,
  //     mobileNo: mobileNo,
  //     email: email,
  //     roleId: roleId,
  //     companyName: companyName,
  //     token: token,
  //     isCheckedIn: isCheckedIn,
  //     regionId: regionId,
  //     joiningDate: joiningDate,
  //     isSuperadmin: isSuperadmin,

  //     phoneCheckResult: AsyncValue.data([
  //       LoginInfo(
  //         name: name,
  //         mobileNo: mobileNo,
  //         email: email,
  //         roleId: roleId != null ? int.tryParse(roleId) : null,
  //         companyName: companyName,
  //         Token: token,
  //         isCheckedIn: isCheckedIn,
  //         companyId: companyId,
  //       ),
  //     ]),
  //   );
  // }

  Future<void> addDoctorDetails(DoctorLogin doctorLogin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.addDoctorDetails(doctorLogin);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  }

  // Future<void> clearLogin(String refreshToken) async {
  //   await usecase.logOut(refreshToken);
  //   state = const AdminloginState(
  //     isLoading: false,
  //     error: null,
  //     adminDetails: AsyncValue.data([]),
  //     phoneCheckResult: AsyncValue.data([]),
  //     userId: 0,
  //     name: null, 
  //     mobileNo: null,
  //     email: null,
  //     roleId: null,
  //     companyName: null,
  //     token: null,
  //     isCheckedIn: null,
  //     companyId: null,
  //   );

  //   await TokenStorage.clear();
  // }





