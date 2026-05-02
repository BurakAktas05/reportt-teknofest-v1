# Reportt — Akıllı Şehir İhbar Sistemi

**Teknofest 2026 Yazılım Yarışması Projesi**

> Vatandaşların şehirdeki kural ihlallerini kamerayla tespit edip anlık olarak
> yetkili birimlere bildirmesini sağlayan AI destekli mobil ihbar platformu.

## 🏗️ Mimari

| Katman | Teknoloji |
|--------|-----------|
| **Backend** | Spring Boot 3.3, Java 21, PostgreSQL + PostGIS |
| **Mobil** | Flutter 3.x, Riverpod, Go Router |
| **Nesne Depolama** | Cloudflare R2 (S3 uyumlu) / MinIO (local) |
| **Mesaj Kuyruğu** | RabbitMQ |
| **Cache** | Redis |
| **Push Bildirim** | Firebase Cloud Messaging (FCM) |
| **AI** | On-device TFLite + Server-side Python media_guard |
| **Deploy** | Railway (Docker) |

## 🚀 Hızlı Başlangıç

### Gereksinimler
- Java 21+, Maven 3.9+
- Flutter SDK 3.10+
- Docker & Docker Compose
- Python 3.10+ (media analysis için)

### Local Geliştirme
```bash
# 1) Altyapı servislerini başlat
docker-compose up -d postgis minio rabbitmq redis

# 2) Backend'i çalıştır
./mvnw spring-boot:run

# 3) Flutter'ı çalıştır
cd reportt_mobile
flutter pub get
flutter run
```

### Production Deploy (Railway)
```bash
# Railway CLI ile deploy
railway up

# Gerekli env variables → KEYS_AND_CREDENTIALS.txt dosyasına bakın
```

### Flutter Build (Production APK)
```bash
cd reportt_mobile
flutter build apk --release \
  --dart-define=REPORTT_API_BASE_URL=https://your-app.up.railway.app/api
```

## 📂 Proje Yapısı
```
├── src/main/java/com/reportt/complaintapp/
│   ├── api/          # REST Controller'lar
│   ├── config/       # Spring konfigürasyon
│   ├── domain/       # JPA Entity'ler
│   ├── dto/          # Request/Response DTO'lar
│   ├── exception/    # Hata yönetimi
│   ├── repository/   # JPA Repository'ler
│   ├── security/     # JWT, Rate Limit, CORS
│   └── service/      # İş mantığı
├── reportt_mobile/   # Flutter mobil uygulama
├── tools/            # Python AI analiz scriptleri
├── Dockerfile        # Railway/Docker deploy
└── docker-compose.yml
```

## 🔒 Güvenlik
- JWT tabanlı kimlik doğrulama + refresh token
- SHA-256 kanıt bütünlüğü doğrulaması
- Zero-Trust cihaz doğrulama
- Rate limiting (Bucket4j)
- BCrypt şifreleme

## 📱 Özellikler
- 📸 Canlı kamera ile kanıt fotoğraf/video çekimi
- 🤖 On-device AI sınıflandırma (TFLite)
- 📍 GPS tabanlı otomatik karakol ataması (PostGIS)
- 🔔 FCM push bildirimler
- 📴 Çevrimdışı mod + otomatik senkronizasyon
- 🗣️ Sesli ihbar (Speech-to-Text)
- 📊 İstatistik ve heatmap görünümü
- ⭐ Güven puanı sistemi

## 📄 Lisans
Bu proje Teknofest 2026 yarışması kapsamında geliştirilmiştir.
