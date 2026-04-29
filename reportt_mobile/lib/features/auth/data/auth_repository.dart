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
      
      final token = response.data['token']; // Backendin döndüğü token fieldı
      final role = response.data['role'];   // Backendin döndüğü rol fieldı

      if (token != null) {
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_role', value: role ?? 'CITIZEN');
      }
      return role ?? 'CITIZEN';
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        // Backend'deki GlobalExceptionHandler'ın döndüğü standart hata formatı (code, message vs)
        throw Exception(e.response?.data['message'] ?? 'Giriş başarısız');
      }
      throw Exception('Sunucuya bağlanılamadı');
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
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Kayıt başarısız');
      }
      throw Exception('Sunucuya bağlanılamadı');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
  }
  
  Future<String?> getSavedRole() async {
    return await _storage.read(key: 'user_role');
  }
}
