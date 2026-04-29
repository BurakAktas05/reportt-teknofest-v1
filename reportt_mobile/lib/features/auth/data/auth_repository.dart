import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio, secureStorage);
});

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository(this._dio, this._storage);

  Future<String?> login(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'phoneNumber': username,
        'password': password,
      });
      
      final token = response.data['accessToken'];
      final refreshToken = response.data['refreshToken'];
      final role = response.data['role'];

      if (token != null) {
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_role', value: role ?? 'CITIZEN');
        if (refreshToken != null) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }
      } else {
        throw Exception('Sunucudan token alınamadı. Lütfen tekrar deneyin.');
      }
      return role ?? 'CITIZEN';
    } on DioException catch (e) {
      throw _handleError(e, 'Giriş başarısız. Lütfen bilgilerinizi kontrol edin.');
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  Future<void> register(String fullName, String phone, String email, String password) async {
    try {
      await _dio.post('/auth/register/citizen', data: {
        'fullName': fullName,
        'phoneNumber': phone,
        'email': email,
        'password': password,
      });
    } on DioException catch (e) {
      throw _handleError(e, 'Kayıt başarısız. Bilgilerinizi kontrol edip tekrar deneyin.');
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  Future<void> registerOfficer({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String stationCode,
  }) async {
    try {
      await _dio.post('/auth/register/officer', data: {
        'fullName': fullName,
        'phoneNumber': phone,
        'email': email,
        'password': password,
        'stationCode': stationCode,
        'role': 'OFFICER',
      });
    } on DioException catch (e) {
      throw _handleError(e, 'Memur kaydı başarısız. Kayıt kodunu kontrol edin.');
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  Exception _handleError(DioException e, String defaultMessage) {
    if (e.response != null && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        final msg = data['userMessage'] ?? data['message'] ?? defaultMessage;
        
        // Eğer detaylı hata varsa (örn: Validation hataları)
        if (data['details'] != null && data['details'] is List && data['details'].isNotEmpty) {
           final firstDetail = data['details'][0];
           if (firstDetail is Map && firstDetail['message'] != null) {
             return Exception('$msg (${firstDetail['message']})');
           }
        }
        return Exception(msg);
      } else if (data is String) {
        return Exception(defaultMessage);
      }
    }
    return Exception('Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_role');
  }
  
  Future<String?> getSavedRole() async {
    return await _storage.read(key: 'user_role');
  }
}
