import 'dart:io';
import 'package:flutter/foundation.dart';

/// Kriptografik kanıt bütünlüğü servisi (Modül 2 — Dijital Mühür).
///
/// Fotoğraf çekildiği anda SHA-256 hash hesaplar. Bu hash backend'e
/// gönderilir ve sunucu tarafında MinIO'ya kaydetmeden önce tekrar
/// hesaplanarak bütünlük teyit edilir.
///
/// Kullanım:
/// ```dart
/// final hash = await EvidenceHashService.computeSha256(file);
/// ```
class EvidenceHashService {
  EvidenceHashService._();

  /// Dosyanın SHA-256 hash'ini hesaplar.
  ///
  /// Büyük dosyalarda ana thread'i bloke etmemek için [compute] ile
  /// izole bir thread'de çalıştırılır.
  static Future<String> computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    return compute(_calculateHash, bytes);
  }

  /// İzole thread'de çalışan hash hesaplama fonksiyonu.
  static String _calculateHash(Uint8List bytes) {
    // dart:convert içindeki SHA-256 implementasyonu
    final digest = _sha256(bytes);
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Pure-Dart SHA-256 implementasyonu (harici paket bağımlılığı yok).
  static List<int> _sha256(Uint8List data) {
    // SHA-256 sabit başlangıç hash değerleri (ilk 8 asal sayının kareköklerinin kesirli kısımları)
    final h = <int>[
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];

    // SHA-256 yuvarlak sabitleri (ilk 64 asal sayının küp köklerinin kesirli kısımları)
    final k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
      0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
      0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
      0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
      0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    int rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;
    int ch(int x, int y, int z) => (x & y) ^ (~x & z);
    int maj(int x, int y, int z) => (x & y) ^ (x & z) ^ (y & z);
    int sigma0(int x) => rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
    int sigma1(int x) => rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
    int gamma0(int x) => rotr(x, 7) ^ rotr(x, 18) ^ (x >>> 3);
    int gamma1(int x) => rotr(x, 17) ^ rotr(x, 19) ^ (x >>> 10);

    // Padding
    final bitLength = data.length * 8;
    final padded = <int>[...data, 0x80];
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    // 64-bit big-endian length
    for (int i = 56; i >= 0; i -= 8) {
      padded.add((bitLength >> i) & 0xFF);
    }

    // Process 512-bit blocks
    for (int offset = 0; offset < padded.length; offset += 64) {
      final w = List<int>.filled(64, 0);
      for (int i = 0; i < 16; i++) {
        w[i] = (padded[offset + i * 4] << 24) |
               (padded[offset + i * 4 + 1] << 16) |
               (padded[offset + i * 4 + 2] << 8) |
               (padded[offset + i * 4 + 3]);
      }
      for (int i = 16; i < 64; i++) {
        w[i] = (gamma1(w[i - 2]) + w[i - 7] + gamma0(w[i - 15]) + w[i - 16]) & 0xFFFFFFFF;
      }

      var a = h[0], b = h[1], c = h[2], d = h[3];
      var e = h[4], f = h[5], g = h[6], hh = h[7];

      for (int i = 0; i < 64; i++) {
        final t1 = (hh + sigma1(e) + ch(e, f, g) + k[i] + w[i]) & 0xFFFFFFFF;
        final t2 = (sigma0(a) + maj(a, b, c)) & 0xFFFFFFFF;
        hh = g; g = f; f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c; c = b; b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hh) & 0xFFFFFFFF;
    }

    final result = <int>[];
    for (final v in h) {
      result.add((v >> 24) & 0xFF);
      result.add((v >> 16) & 0xFF);
      result.add((v >> 8) & 0xFF);
      result.add(v & 0xFF);
    }
    return result;
  }
}
