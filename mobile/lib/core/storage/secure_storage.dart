import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Tokens ────────────────────────────────────────────────────────────────
  static Future<void> saveTokens({required String accessToken, required String refreshToken}) =>
    Future.wait([
      _s.write(key: 'access_token',  value: accessToken),
      _s.write(key: 'refresh_token', value: refreshToken),
    ]);

  static Future<String?> getAccessToken()  => _s.read(key: 'access_token');
  static Future<String?> getRefreshToken() => _s.read(key: 'refresh_token');

  // ── User info ─────────────────────────────────────────────────────────────
  static Future<void> saveUserInfo({
    required String userId,
    required String userType,
    required String schoolId,
  }) =>
    Future.wait([
      _s.write(key: 'user_id',    value: userId),
      _s.write(key: 'user_type',  value: userType),
      _s.write(key: 'school_id',  value: schoolId),
    ]);

  static Future<String?> getUserType() => _s.read(key: 'user_type');
  static Future<String?> getSchoolId() => _s.read(key: 'school_id');

  // ── PIN state ─────────────────────────────────────────────────────────────
  static Future<void> setPinSet(bool value) =>
    _s.write(key: 'pin_set', value: value.toString());

  static Future<bool> getPinSet() async =>
    (await _s.read(key: 'pin_set')) == 'true';

  // ── Last login credentials (for returning to PIN login screen) ────────────
  static Future<void> saveLastLogin({
    required String mobile,
    required String schoolSubdomain,
    String? admissionNo,
  }) =>
    Future.wait([
      _s.write(key: 'last_mobile',       value: mobile),
      _s.write(key: 'last_school',        value: schoolSubdomain),
      _s.write(key: 'last_admission_no',  value: admissionNo ?? ''),
    ]);

  static Future<({String? mobile, String? school, String? admissionNo})>
      getLastLogin() async {
    final results = await Future.wait([
      _s.read(key: 'last_mobile'),
      _s.read(key: 'last_school'),
      _s.read(key: 'last_admission_no'),
    ]);
    return (
      mobile:      results[0],
      school:      results[1],
      admissionNo: results[2]?.isEmpty == true ? null : results[2],
    );
  }

  // ── Clear ─────────────────────────────────────────────────────────────────
  // Clears tokens + user info but keeps PIN state and last-login
  // so returning users still get PIN login screen after signing out
  static Future<void> clearSession() =>
    Future.wait([
      _s.delete(key: 'access_token'),
      _s.delete(key: 'refresh_token'),
      _s.delete(key: 'user_id'),
      _s.delete(key: 'user_type'),
      _s.delete(key: 'school_id'),
    ]);

  // Full wipe (e.g. "use different account" or forgot PIN)
  static Future<void> clearAll() => _s.deleteAll();
}
