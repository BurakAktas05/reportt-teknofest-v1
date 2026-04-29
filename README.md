# Violation Backend

Java ve Spring Boot ile yazilmis, Flutter mobil istemci tarafindan tuketilmek uzere hazirlanan kamu sikayet backend'i.

Bu backend; vatandas ihbarlarini en yakin karakola yonlendirir, delilleri bulut depolamada saklar, medya icin ilk seviye otomatik analiz yapar ve amir tarafina guvenli bir is akisi sunar.

## Neler Hazir

- JWT tabanli kimlik dogrulama ve rol ayrimi: `CITIZEN`, `OFFICER`, `ADMIN`
- PostGIS ile en yakin karakol esleme
- Tek kullanimlik ve kisa omurlu `capture session` akisi
- Foto ve video deliliyle sikayet olusturma
- Bulut tabanli obje depolama: S3 uyumlu API, varsayilan yerel gelistirme icin MinIO
- Medya guvenlik analizi:
  - dis mekan olasiligi
  - selfie / yuze yakin cekim riski
  - uygun kategorilerde plaka OCR denemesi
- Sikayet geri bildirim sistemi
- Vatandas puanlama mekanizmasi
- Endpoint bazli rate limiting
- Tek formatta profesyonel JSON hata cevaplari
- Flyway migration yapisi

## Mimari Notlar

Bu proje, yuksek ciddiyetli bir kamu uygulamasi gibi dusunulerek tasarlandi:

- domain, service, repository ve config katmanlari ayrildi
- global exception handling ile frontend dostu tutarli hata modeli kuruldu
- request bazli `X-Request-Id` uretildi
- hassas alanlar icin yetki kontrolleri service seviyesinde toplandi
- medya dosyalari uygulama diskinde tutulmuyor, obje depolamaya gidiyor
- supheli medya dosyalari otomatik olarak `manual review` akisina itilabiliyor

## Teknolojiler

- Java 21
- Spring Boot 3
- Spring Security
- Spring Data JPA
- PostgreSQL + PostGIS
- Flyway
- Bucket4j
- AWS SDK S3
- Lombok
- Python yardimci analiz scriptleri

## Varsayilan Veritabani Ayarlari

- Veritabani: `violation_db`
- Kullanici: `postgres`
- Sifre: `2457`
- JDBC: `jdbc:postgresql://localhost:5432/violation_db`

Tum uygulama tablolari `complaint_app` schema'sinda tutulur.

## Yerel Ortam

Yerel gelistirme icin `docker-compose.yml` iki servis sunar:

- `postgis` -> PostgreSQL + PostGIS
- `minio` -> S3 uyumlu obje depolama

Calistirmak icin:

```bash
docker compose up -d
```

MinIO konsolu:

- API: `http://localhost:9000`
- Console: `http://localhost:9001`
- Kullanici: `minioadmin`
- Sifre: `minioadmin`

Uygulama, bucket yoksa otomatik olusturabilir.

## Uygulamayi Baslatma

```bash
mvn spring-boot:run
```

## Konfigurasyon

`application.yml` dosyasi ortam degiskenlerini destekler. Onemli alanlar:

- `COMPLAINT_DB_URL`
- `COMPLAINT_DB_USERNAME`
- `COMPLAINT_DB_PASSWORD`
- `COMPLAINT_JWT_SECRET`
- `COMPLAINT_OBJECT_STORAGE_ENDPOINT`
- `COMPLAINT_OBJECT_STORAGE_REGION`
- `COMPLAINT_OBJECT_STORAGE_BUCKET`
- `COMPLAINT_OBJECT_STORAGE_ACCESS_KEY`
- `COMPLAINT_OBJECT_STORAGE_SECRET_KEY`
- `COMPLAINT_MEDIA_ANALYSIS_ENABLED`
- `COMPLAINT_MEDIA_ANALYSIS_PYTHON`
- `COMPLAINT_MEDIA_ANALYSIS_SCRIPT_PATH`

Varsayilan gelistirme degerleri dosyada tanimlidir.

## Temel API Akisi

1. `POST /api/auth/register/citizen`
2. `POST /api/auth/login`
3. `POST /api/reports/capture-sessions`
4. `POST /api/reports` `multipart/form-data`
5. `GET /api/reports/my`
6. `GET /api/reports/assigned`
7. `PATCH /api/reports/{id}/status`
8. `POST /api/reports/{id}/feedback`

## Ornek Sikayet Yukleme

`POST /api/reports` istegi `multipart/form-data` olarak gonderilir:

- `payload`: JSON
- `files`: bir veya daha fazla medya dosyasi

Ornek `payload`:

```json
{
  "title": "Park ihlali",
  "description": "Yaya yolunu kapatan arac fotograflandi.",
  "category": "PARKING_VIOLATION",
  "incidentAt": "2026-04-26T11:30:00",
  "latitude": 41.0082,
  "longitude": 28.9784,
  "addressText": "Fatih, Istanbul",
  "captureSessionToken": "tek-kullanimlik-oturum-token"
}
```

## Hata Sozlesmesi

Frontend icin butun hata cevaplari ayni sekilde doner:

```json
{
  "requestId": "7ef2c934-4b3c-49cc-a5b6-c3db8c6d3144",
  "status": 400,
  "error": "Bad Request",
  "code": "VALIDATION_ERROR",
  "category": "VALIDATION",
  "message": "Gonderilen veri dogrulanamadi.",
  "retryable": false,
  "path": "/api/reports",
  "timestamp": "2026-04-26T12:30:00+03:00",
  "fieldErrors": [
    {
      "field": "title",
      "message": "bos olamaz"
    }
  ]
}
```

Bu yapi sayesinde Flutter tarafi:

- `code` ile is kurali bazli davranabilir
- `category` ile UI akisini ayirabilir
- `requestId` ile destek ve audit kaydi tutabilir
- `retryable` ile tekrar deneme UX'i kurabilir

## Medya Analizi

Python scripti: [media_guard.py](C:/Users/AKTASSAK/Desktop/Reportt/tools/media_guard.py)

Amac:

- galeriden uygunsuz selfie gonderimini azaltmak
- dis mekan olasiligini daha karakola dusmeden anlamak
- plaka var ise OCR ile okumayi denemek

Script kesin hukuki karar vermez; yalnizca risk skoru uretir. Supheli kayitlar `reviewRequired=true` olarak isaretlenir.

Python bagimliliklari:

```bash
pip install -r tools/requirements.txt
```

Ek plaka OCR betigi: [plate_reader.py](C:/Users/AKTASSAK/Desktop/Reportt/tools/plate_reader.py)

## Canli Cekim Siniri

Sadece backend ile galeriden secimi yuzde yuz engellemek mumkun degil. Bu proje savunmaci bir model kurar:

- mobil uygulama once `capture session` alir
- session tek kullanimliktir
- suresi dolarsa medya reddedilir
- medya icin selfie / dis mekan analizi yapilir

Flutter tarafinda ayrica su kontroller tavsiye edilir:

- galeriden secim UI olarak kapatilmali
- capture timestamp ve EXIF uyumu kontrol edilmeli
- rooted / emulated cihaz riski degerlendirilmeli
- gerekirse cihaz butunluk kontrolleri eklenmeli

## Roller

- `CITIZEN`: sikayet acar, kendi kayitlarini gorur
- `OFFICER`: kendi karakoluna dusen kayitlari gorur, durum gunceller, geri bildirim ekler
- `ADMIN`: officer hesaplarini acar, tum kayitlara erisebilir

## Onerilen Sonraki Adimlar

- SMS OTP veya e-Devlet tabanli kimlik dogrulama
- audit log tablolari ve degistirilemez islem kaydi
- medya dosyalari icin KMS destekli sifreleme
- delil erisimleri icin signed URL veya proxy download katmani
- OpenAPI / Swagger dokumani
- officer paneli icin queue, filtre ve harita tabanli ekranlar

## Onemli Dosyalar

- [ComplaintApplication.java](C:/Users/AKTASSAK/Desktop/Reportt/src/main/java/com/reportt/complaintapp/ComplaintApplication.java)
- [SecurityConfig.java](C:/Users/AKTASSAK/Desktop/Reportt/src/main/java/com/reportt/complaintapp/config/SecurityConfig.java)
- [ComplaintService.java](C:/Users/AKTASSAK/Desktop/Reportt/src/main/java/com/reportt/complaintapp/service/ComplaintService.java)
- [GlobalExceptionHandler.java](C:/Users/AKTASSAK/Desktop/Reportt/src/main/java/com/reportt/complaintapp/exception/GlobalExceptionHandler.java)
- [V1__init_schema.sql](C:/Users/AKTASSAK/Desktop/Reportt/src/main/resources/db/migration/V1__init_schema.sql)
- [V2__cloud_storage_and_media_analysis.sql](C:/Users/AKTASSAK/Desktop/Reportt/src/main/resources/db/migration/V2__cloud_storage_and_media_analysis.sql)
