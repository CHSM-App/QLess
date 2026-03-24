 import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:qless/data/api/api_service.dart';

class NetworkState {
  final bool isConnected;
  final bool isInitialized;
  final bool isRetrying;     // 👈 NEW
  final String? errorMessage;
  final DateTime? lastChecked;
  final ConnectivityResult? connectionType;

  const NetworkState({
    required this.isConnected,
    this.isInitialized = false,
    this.isRetrying = false,   // 👈 default false
    this.errorMessage,
    this.lastChecked,
    this.connectionType,
  });

  NetworkState copyWith({
    bool? isConnected,
    bool? isInitialized,
    bool? isRetrying,   // 👈 NEW
    String? errorMessage,
    DateTime? lastChecked,
    ConnectivityResult? connectionType,
  }) {
    return NetworkState(
      isConnected: isConnected ?? this.isConnected,
      isInitialized: isInitialized ?? this.isInitialized,
      isRetrying: isRetrying ?? this.isRetrying,  // 👈 NEW
      errorMessage: errorMessage,
      lastChecked: lastChecked ?? this.lastChecked,
      connectionType: connectionType ?? this.connectionType,
    );
  }




  @override
  String toString() {
    return 'NetworkState(connected: $isConnected, initialized: $isInitialized, type: $connectionType, error: $errorMessage)';
  }
}

class ApiState {
  final bool isApiAvailable;
  final String? errorMessage;
  final DateTime? lastChecked;
  final bool isChecking;

  const ApiState({
    required this.isApiAvailable,
    this.errorMessage,
    this.lastChecked,
    this.isChecking = false,
  });
 
  ApiState copyWith({
    bool? isApiAvailable,
    String? errorMessage,
    DateTime? lastChecked,
    bool? isChecking,
  }) {
    return ApiState(
      isApiAvailable: isApiAvailable ?? this.isApiAvailable,
      errorMessage: errorMessage,
      lastChecked: lastChecked ?? this.lastChecked,
      isChecking: isChecking ?? this.isChecking,
    );
  }

  @override
  String toString() {
    return 'ApiState(available: $isApiAvailable, checking: $isChecking, error: $errorMessage)';
  }
}

class EnhancedNetworkStateNotifier extends StateNotifier<NetworkState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicCheck;

  EnhancedNetworkStateNotifier()
      : super(const NetworkState(isConnected: true, isInitialized: false)) {
 
    _init();
  }

  Future<void> _init() async {
    try {
      // Immediate connectivity check
      await _performConnectivityCheck();
    
      _subscription = _connectivity.onConnectivityChanged.listen((results) async {
        await _performConnectivityCheck();
      });
      
      _periodicCheck = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          _performConnectivityCheck();
        }
      });
      
    } catch (e) {
   
      state = state.copyWith(
        isConnected: false,
        isInitialized: true,
        errorMessage: "Network initialization failed: $e",
        lastChecked: DateTime.now(),
      );
    } 
  }

Future<void> _performConnectivityCheck() async {
  try {
    final results = await _connectivity.checkConnectivity();
   
    final isConnected = !results.contains(ConnectivityResult.none);
    final connectionType = results.isNotEmpty ? results.first : ConnectivityResult.none;
   
    state = state.copyWith(
      isConnected: isConnected,
      isInitialized: true,
      errorMessage: isConnected ? null : "No network connection",
      lastChecked: DateTime.now(),
      connectionType: connectionType,
    );
    

    
  } catch (e) {
  
    state = state.copyWith(
      isConnected: false,
      isInitialized: true,
      errorMessage: "Network check failed: $e",
      lastChecked: DateTime.now(),
    );
  }
}

// Also add this test method to trigger network loss manually
void forceNetworkLoss() {

  state = state.copyWith(
    isConnected: false,
    isInitialized: true,
    errorMessage: "Forced network loss (test)",
    lastChecked: DateTime.now(),
  );
  
}

void forceNetworkRestore() {

 
  state = state.copyWith(
    isConnected: true,
    isInitialized: true,
    errorMessage: null,
    lastChecked: DateTime.now(),
  );

}

  // Manual trigger for testing
  void simulateNetworkLoss() {
  
    state = state.copyWith(
      isConnected: false,
      isInitialized: true,
      errorMessage: "Simulated network loss",
      lastChecked: DateTime.now(),
    );
  }
  
  void simulateNetworkRestore() {
   
    state = state.copyWith(
      isConnected: true,
      isInitialized: true,
      errorMessage: null,
      lastChecked: DateTime.now(),
    );
  }

  Future<void> checkConnection() async {
   
    await _performConnectivityCheck();
  }

Future<void> retryConnection(BuildContext context) async {
 

  // Show loading in UI
  state = state.copyWith(
    isRetrying: true,
    errorMessage: null,
  );

  // optional slight delay for animation
  await Future.delayed(const Duration(milliseconds: 400));

  // Perform connection check
  await _performConnectivityCheck();

 

  // Hide loading
  state = state.copyWith(
    isRetrying: false,
    isInitialized: true,
  );
}


  @override
  void dispose() {
   
    _subscription?.cancel();
    _periodicCheck?.cancel();
    super.dispose();
  }
}

class ApiStateNotifier extends StateNotifier<ApiState> {
  final ApiService _apiService;
  Timer? _healthCheckTimer;
  
  ApiStateNotifier(this._apiService) : super(const ApiState(isApiAvailable: true)) {
   
    _startInitialCheck();
  }

  void _startInitialCheck() async {
    await Future.delayed(const Duration(milliseconds: 300));
   // await checkApiHealth();
    
    // Periodic health checks every 2 minutes
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!state.isChecking && mounted) {
        //checkApiHealth();
      }
    });
  }
  
  // Future<void> checkApiHealth() async {
  
    
  //   if (state.isChecking) {
      
  //     return;
  //   }
    
  //   state = state.copyWith(isChecking: true);
    
  //   try {
  //     final response = await _apiService.checkHealth()
  //         .timeout(const Duration(seconds: 10));

  //     if (response.statusCode == 200) {
       
  //       state = state.copyWith(
  //         isApiAvailable: true,
  //         errorMessage: null,
  //         lastChecked: DateTime.now(),
  //         isChecking: false,
  //       );
  //     } else {
       
  //       state = state.copyWith(
  //         isApiAvailable: false,
  //         errorMessage: "Server returned ${response.statusCode}",
  //         lastChecked: DateTime.now(),
  //         isChecking: false,
  //       );
  //     }
  //   } catch (e) {
      
  //     String errorMessage;
  //     if (e is DioException) {
  //       switch (e.type) {
  //         case DioExceptionType.connectionTimeout:
  //         case DioExceptionType.sendTimeout:
  //         case DioExceptionType.receiveTimeout:
  //           errorMessage = "Server timeout";
  //           break;
  //         case DioExceptionType.connectionError:
  //           errorMessage = "Cannot reach server";
  //           break;
  //         case DioExceptionType.badResponse:
  //           errorMessage = "Server error (${e.response?.statusCode})";
  //           break;
  //         default:
  //           errorMessage = "Server unavailable";
  //       }
  //     } else {
  //       errorMessage = "API health check failed";
  //     }
      
  //     state = state.copyWith(
  //       isApiAvailable: false,
  //       errorMessage: errorMessage,
  //       lastChecked: DateTime.now(),
  //       isChecking: false,
  //     );
  //   }
  // }

  @override
  void dispose() {
   
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}


