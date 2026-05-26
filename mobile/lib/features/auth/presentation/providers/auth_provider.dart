import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  const AuthState({this.isLoading = false, this.error, this.isAuthenticated = false});
  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated}) =>
    AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void reset() => state = const AuthState();

  Future<bool> requestOtp({
    required String schoolSubdomain,
    required String mobile,
    String? admissionNo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.instance.post(ApiConstants.requestOtp, data: {
        'school_subdomain': schoolSubdomain,
        'mobile': mobile,
        if (admissionNo != null && admissionNo.isNotEmpty) 'admission_no': admissionNo,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']
          ?? '${e.type}: ${e.message}';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Returns (success, pinSet) — pinSet=false means user must set a PIN now
  Future<(bool, bool)> verifyOtp({
    required String schoolSubdomain,
    required String mobile,
    required String otp,
    String? admissionNo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final r = await ApiClient.instance.post(ApiConstants.verifyOtp, data: {
        'school_subdomain': schoolSubdomain,
        'mobile': mobile,
        'otp': otp,
      });
      final d = r.data['data'];
      final pinSet = d['pin_set'] as bool? ?? false;

      ApiClient.setToken(d['accessToken'] as String);
      await Future.wait([
        SecureStorageService.saveTokens(
          accessToken: d['accessToken'],
          refreshToken: d['refreshToken'],
        ),
        SecureStorageService.saveUserInfo(
          userId: d['userId'],
          userType: d['userType'],
          schoolId: d['schoolId'],
        ),
        SecureStorageService.setPinSet(pinSet),
        SecureStorageService.saveLastLogin(
          mobile: mobile,
          schoolSubdomain: schoolSubdomain,
          admissionNo: admissionNo,
        ),
      ]);

      state = state.copyWith(isLoading: false, isAuthenticated: true);
      return (true, pinSet);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.response?.data?['error'] ?? 'Verification failed');
      return (false, false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Network error');
      return (false, false);
    }
  }

  Future<bool> setPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.instance.post(ApiConstants.setPin, data: {'pin': pin});
      await SecureStorageService.setPinSet(true);
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.response?.data?['error'] ?? 'Failed to set PIN');
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Network error');
      return false;
    }
  }

  Future<bool> loginWithPin({
    required String schoolSubdomain,
    required String mobile,
    required String pin,
    String? admissionNo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final r = await ApiClient.instance.post(ApiConstants.loginPin, data: {
        'school_subdomain': schoolSubdomain,
        'mobile': mobile,
        'pin': pin,
        if (admissionNo != null && admissionNo.isNotEmpty) 'admission_no': admissionNo,
      });
      final d = r.data['data'];

      ApiClient.setToken(d['accessToken'] as String);
      await Future.wait([
        SecureStorageService.saveTokens(
          accessToken: d['accessToken'],
          refreshToken: d['refreshToken'],
        ),
        SecureStorageService.saveUserInfo(
          userId: d['userId'],
          userType: d['userType'],
          schoolId: d['schoolId'],
        ),
      ]);

      state = state.copyWith(isLoading: false, isAuthenticated: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.response?.data?['error'] ?? 'Incorrect PIN');
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Network error');
      return false;
    }
  }

  Future<void> logout() async {
    try { await ApiClient.instance.post(ApiConstants.logout); } catch (_) {}
    ApiClient.setToken(null);
    await SecureStorageService.clearSession();
    state = const AuthState();
  }

  // Full sign-out — clears PIN too, forces OTP next time
  Future<void> signOutCompletely() async {
    try { await ApiClient.instance.post(ApiConstants.logout); } catch (_) {}
    ApiClient.setToken(null);
    await SecureStorageService.clearAll();
    state = const AuthState();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);

// Provider to check if returning user has PIN set
final pinSetProvider = FutureProvider<bool>((_) => SecureStorageService.getPinSet());
