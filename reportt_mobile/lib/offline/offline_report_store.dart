import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Çevrimdışı ihbar deposu (Modül 6 — Offline First).
///
/// İnternet olmayan ortamlarda (kırsal bölge, afet durumu) ihbarları
/// lokal dosya sistemine JSON + fotoğraf olarak kaydeder.
/// Cihaz internete bağlandığında [SyncWorker] otomatik senkronize eder.
///
/// Depolama yapısı:
/// ```
/// app_documents/
/// └── offline_reports/
///     ├── report_1714400000000.json
///     ├── report_1714400000000.jpg
///     ├── report_1714400050000.json
///     └── report_1714400050000.jpg
/// ```
class OfflineReportStore {
  static const String _dirName = 'offline_reports';

  /// Çevrimdışı ihbar sayısını döndürür (senkronize edilmeyi bekleyen).
  static Future<int> pendingCount() async {
    final dir = await _getDir();
    if (!await dir.exists()) return 0;
    final files = await dir.list().where((f) => f.path.endsWith('.json')).length;
    return files;
  }

  /// Çevrimdışı ihbar kaydeder.
  ///
  /// [payload] ihbar verileri, [imageFile] kanıt fotoğrafı, [imageHash] SHA-256 hash.
  static Future<void> save({
    required Map<String, dynamic> payload,
    required File imageFile,
    required String imageHash,
  }) async {
    final dir = await _getDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = 'report_$timestamp';

    // Fotoğrafı kopyala
    final ext = p.extension(imageFile.path).isNotEmpty ? p.extension(imageFile.path) : '.jpg';
    final imageDest = File(p.join(dir.path, '$baseName$ext'));
    await imageFile.copy(imageDest.path);

    // Payload'ı JSON olarak kaydet
    final reportData = {
      ...payload,
      'offlineCreatedAt': DateTime.now().toIso8601String(),
      'evidenceHash': imageHash,
      'localImagePath': imageDest.path,
      'synced': false,
    };

    final jsonFile = File(p.join(dir.path, '$baseName.json'));
    await jsonFile.writeAsString(jsonEncode(reportData));

    debugPrint('[OfflineStore] Kaydedildi: $baseName');
  }

  /// Senkronize edilmeyi bekleyen tüm çevrimdışı ihbarları döndürür.
  static Future<List<OfflineReport>> loadPending() async {
    final dir = await _getDir();
    if (!await dir.exists()) return [];

    final reports = <OfflineReport>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          if (data['synced'] != true) {
            reports.add(OfflineReport(
              jsonFile: entity,
              payload: data,
              imageFile: File(data['localImagePath'] as String),
            ));
          }
        } catch (e) {
          debugPrint('[OfflineStore] Parse hatasi: ${entity.path} - $e');
        }
      }
    }

    // Eski tarih önce
    reports.sort((a, b) {
      final aTime = a.payload['offlineCreatedAt'] as String? ?? '';
      final bTime = b.payload['offlineCreatedAt'] as String? ?? '';
      return aTime.compareTo(bTime);
    });

    return reports;
  }

  /// Başarıyla senkronize edilen ihbarı siler.
  static Future<void> markSynced(OfflineReport report) async {
    try {
      if (await report.jsonFile.exists()) {
        await report.jsonFile.delete();
      }
      if (await report.imageFile.exists()) {
        await report.imageFile.delete();
      }
      debugPrint('[OfflineStore] Senkronize edildi ve silindi: ${report.jsonFile.path}');
    } catch (e) {
      debugPrint('[OfflineStore] Silme hatasi: $e');
    }
  }

  /// Tüm çevrimdışı verileri temizler.
  static Future<void> clearAll() async {
    final dir = await _getDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<Directory> _getDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, _dirName));
  }
}

/// Çevrimdışı ihbar veri modeli.
class OfflineReport {
  final File jsonFile;
  final Map<String, dynamic> payload;
  final File imageFile;

  OfflineReport({
    required this.jsonFile,
    required this.payload,
    required this.imageFile,
  });
}
