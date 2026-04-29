// Reportt — Temel smoke test
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Uygulama smoke testi — basit assertion', () {
    // Temel smoke test — uygulamanın test altyapısının çalıştığını doğrular
    expect(1 + 1, equals(2));
  });
}
