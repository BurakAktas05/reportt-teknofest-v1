import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../offline/offline_report_store.dart';
import '../features/reports/data/report_repository.dart';

/// Çevrimdışı ihbar otomatik senkronizasyon servisi (Modül 6 — Auto-Sync).
///
/// [connectivity_plus] paketi ile ağ durumunu izler.
/// Cihaz internete bağlandığı anda kuyruktaki ihbarları sırayla backend'e gönderir.
///
/// Kullanım:
/// ```dart
/// // main.dart
/// SyncWorker.instance.startListening(reportRepository);
/// ```
///
/// Mimari:
/// ```
/// [Offline Store] ──connectivity_plus──▶ [SyncWorker] ──Dio──▶ [Backend]
///     (JSON+JPG)       "online oldu"        (auto-sync)
/// ```
class SyncWorker {
  static final SyncWorker instance = SyncWorker._();
  SyncWorker._();

  StreamSubscription? _subscription;
  bool _isSyncing = false;

  /// Bağlantı durumunu dinlemeye başlar.
  /// Online olduğunda otomatik senkronizasyon tetiklenir.
  void startListening(ReportRepository repository) {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      // results bir List<ConnectivityResult>
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        syncPendingReports(repository);
      }
    });

    debugPrint('[SyncWorker] Bağlantı dinleyicisi başlatıldı.');
  }

  /// Dinlemeyi durdurur.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Kuyruktaki tüm çevrimdışı ihbarları sırayla senkronize eder.
  ///
  /// Hata durumunda ihbar kuyrukta kalır ve bir sonraki bağlantıda tekrar denenir.
  Future<void> syncPendingReports(ReportRepository repository) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = await OfflineReportStore.loadPending();
      if (pending.isEmpty) {
        debugPrint('[SyncWorker] Senkronize edilecek ihbar yok.');
        return;
      }

      debugPrint('[SyncWorker] ${pending.length} ihbar senkronize ediliyor...');

      for (final report in pending) {
        try {
          // Offline payload'tan ihbar verilerini çıkar
          final payload = Map<String, dynamic>.from(report.payload);
          payload.remove('synced');
          payload.remove('localImagePath');

          final hash = payload.remove('evidenceHash') as String?;

          await repository.createReport(
            payload,
            report.imageFile.path,
            evidenceHash: hash,
          );

          // Başarıyla gönderildi — lokal kopyayı sil
          await OfflineReportStore.markSynced(report);
          debugPrint('[SyncWorker] ✓ Senkronize: ${report.jsonFile.path}');
        } catch (e) {
          debugPrint('[SyncWorker] ✗ Hata (kuyrukta kalacak): $e');
          // Bu ihbar kuyrukta kalır, bir sonraki bağlantıda tekrar denenir
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// İnternetin şu anda mevcut olup olmadığını kontrol eder.
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
