import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportRepository(dio);
});

// A simple DTO class for Report
class ReportResponse {
  final int id;
  final String title;
  final String description;
  final String status;
  final String category;
  final String addressText;

  ReportResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.category,
    required this.addressText,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      category: json['category'] ?? '',
      addressText: json['addressText'] ?? '',
    );
  }
}

class ReportRepository {
  final Dio _dio;

  ReportRepository(this._dio);

  Future<List<ReportResponse>> getMyReports() async {
    try {
      final response = await _dio.get('/reports/my');
      final List<dynamic> data = response.data;
      return data.map((e) => ReportResponse.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'İhbarlar alınamadı');
    }
  }

  Future<ReportResponse> getReportDetail(String id) async {
    try {
      final response = await _dio.get('/reports/$id');
      return ReportResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Detay alınamadı');
    }
  }

  Future<void> createReport(Map<String, dynamic> payload, String filePath) async {
    try {
      // 1. Get capture session token
      final sessionResp = await _dio.post('/reports/capture-sessions');
      final String sessionToken = sessionResp.data['sessionToken'];

      // 2. Prepare the payload map
      final Map<String, dynamic> reportData = {
        'title': payload['title'],
        'description': payload['description'],
        'category': payload['category'],
        'latitude': payload['latitude'],
        'longitude': payload['longitude'],
        'addressText': payload['addressText'],
        'incidentAt': DateTime.now().toIso8601String().split('.').first, // Format: yyyy-MM-ddTHH:mm:ss
        'captureSessionToken': sessionToken,
      };

      // 3. Create Multipart Form Data
      final formData = FormData();

      // Send payload as a JSON part
      formData.files.add(MapEntry(
        'payload',
        MultipartFile.fromString(
          jsonEncode(reportData),
          contentType: DioMediaType('application', 'json'),
        ),
      ));

      // Send file as 'files' part (Spring expects List<MultipartFile> files)
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(
          filePath, 
          filename: filePath.split('/').last,
        ),
      ));

      await _dio.post(
        '/reports',
        data: formData,
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map 
          ? (e.response?.data['userMessage'] ?? e.response?.data['message']) 
          : null;
      throw Exception(errorMsg ?? 'İhbar oluşturulamadı. Lütfen bilgileri kontrol edin.');
    }
  }
}

// State provider to fetch reports automatically
final myReportsProvider = FutureProvider<List<ReportResponse>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getMyReports();
});

final reportDetailProvider = FutureProvider.family<ReportResponse, String>((ref, id) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportDetail(id);
});
