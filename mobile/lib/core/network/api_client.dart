import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static Dio? _i;
  static String? _token;

  // Registered in app.dart — called whenever both tokens are expired/invalid
  static void Function()? onSessionExpired;

  // Used by the GoRouter redirect to gate protected routes
  static bool get hasToken => _token != null;

  static void setToken(String? token) {
    _token = token;
    if (_i != null) {
      if (token != null) {
        _i!.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _i!.options.headers.remove('Authorization');
      }
    }
  }

  static Dio get instance { _i ??= _build(); return _i!; }

  static Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    if (_token != null) {
      dio.options.headers['Authorization'] = 'Bearer $_token';
    }
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opt, h) {
        if (_token != null) opt.headers['Authorization'] = 'Bearer $_token';
        h.next(opt);
      },
      onError: (err, h) async {
        if (err.response?.statusCode == 401) {
          if (_token != null) {
            // Try to refresh the access token
            final ok = await _refresh(dio);
            if (ok) {
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_token';
              return h.resolve(await dio.fetch(opts));
            }
          } else {
            // No token in memory — session already gone
            _expire();
          }
          // Refresh failed or no token: _expire() was already called,
          // navigation to /login is in flight — reject silently
          return h.reject(DioException(
            requestOptions: err.requestOptions,
            type: DioExceptionType.cancel,
          ));
        }
        h.next(err);
      },
    ));
    return dio;
  }

  static Future<bool> _refresh(Dio dio) async {
    try {
      final rt = await SecureStorageService.getRefreshToken();
      if (rt == null) { _expire(); return false; }
      final r = await dio.post(ApiConstants.refreshToken,
          data: {'refresh_token': rt});
      final d = r.data['data'];
      final newToken = d['accessToken'] as String;
      setToken(newToken);
      await SecureStorageService.saveTokens(
          accessToken: newToken, refreshToken: d['refreshToken']);
      return true;
    } catch (_) {
      _expire();
      return false;
    }
  }

  static bool _expiring = false;
  static void _expire() {
    if (_expiring) return;
    _expiring = true;
    setToken(null);
    SecureStorageService.clearAll().then((_) {
      _expiring = false;
      onSessionExpired?.call();
    });
  }
}
