package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.ObjectStorageProperties;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

@Service
public class FileStorageService {

    private final S3Client s3Client;
    private final ObjectStorageProperties objectStorageProperties;

    public FileStorageService(S3Client s3Client, ObjectStorageProperties objectStorageProperties) {
        this.s3Client = s3Client;
        this.objectStorageProperties = objectStorageProperties;
        try {
            ensureBucketExists();
        } catch (Exception e) {
            // MinIO/S3 kapalı olsa bile uygulama başlasın — dosya yükleme sırasında hata verilir
            System.err.println("[FileStorageService] UYARI: Nesne depolama bağlantısı kurulamadı: " + e.getMessage());
        }
    }

    public StoredFile store(
            Path sourceFile,
            String originalFileName,
            String contentType,
            long fileSize,
            Long reportId
    ) {
        String objectKey = buildObjectKey(reportId, originalFileName);

        try {
            s3Client.putObject(
                    PutObjectRequest.builder()
                            .bucket(objectStorageProperties.bucket())
                            .key(objectKey)
                            .contentType(contentType)
                            .build(),
                    RequestBody.fromFile(sourceFile)
            );
        } catch (S3Exception exception) {
            throw new ApiException(ErrorCode.FILE_STORE_FAILED, "Bulut depolama yuklemesi basarisiz oldu.");
        }

        return new StoredFile(
                "S3",
                objectKey,
                contentType,
                fileSize
        );
    }

    public Path downloadToTempFile(String objectKey) {
        try {
            Path tempFile = Files.createTempFile("complaint-media-dl-", ".bin");
            Files.deleteIfExists(tempFile); // SDK will create it during download
            s3Client.getObject(
                    GetObjectRequest.builder()
                            .bucket(objectStorageProperties.bucket())
                            .key(objectKey)
                            .build(),
                    tempFile
            );
            return tempFile;
        } catch (Exception exception) {
            exception.printStackTrace();
            throw new ApiException(ErrorCode.FILE_STORE_FAILED, "Bulut depolamadan dosya indirilemedi: " + exception.getMessage());
        }
    }

    // ── V2: Kriptografik Kanıt Bütünlüğü (Modül 2) ────────────────

    /**
     * Verilen dosyanın SHA-256 hash'ini hesaplar.
     * Adli kanıt bütünlüğü kontrolü için kullanılır.
     *
     * @param file hash'lenecek dosya
     * @return 64 karakter hex-encoded SHA-256 hash
     */
    public String computeSha256(Path file) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream is = Files.newInputStream(file)) {
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = is.read(buffer)) != -1) {
                    digest.update(buffer, 0, bytesRead);
                }
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (NoSuchAlgorithmException | IOException exception) {
            throw new ApiException(ErrorCode.FILE_STORE_FAILED, "Dosya hash hesaplanamadi: " + exception.getMessage());
        }
    }

    /**
     * İstemci tarafından gönderilen hash ile sunucu tarafında hesaplanan hash'i karşılaştırır.
     * Eşleşmezse {@link ErrorCode#EVIDENCE_HASH_MISMATCH} hatası fırlatır.
     *
     * @param file doğrulanacak dosya
     * @param clientHash istemcinin gönderdiği SHA-256 hash
     * @return doğrulama başarılıysa sunucu tarafında hesaplanan hash
     */
    public String verifyIntegrity(Path file, String clientHash) {
        String serverHash = computeSha256(file);
        if (!serverHash.equalsIgnoreCase(clientHash)) {
            throw new ApiException(ErrorCode.EVIDENCE_HASH_MISMATCH,
                    "Istemci hash: " + clientHash + " | Sunucu hash: " + serverHash);
        }
        return serverHash;
    }

    // ────────────────────────────────────────────────────────────────

    private void ensureBucketExists() {
        try {
            s3Client.headBucket(HeadBucketRequest.builder().bucket(objectStorageProperties.bucket()).build());
        } catch (NoSuchBucketException exception) {
            createBucketIfAllowed();
        } catch (S3Exception exception) {
            if (exception.statusCode() == 404) {
                createBucketIfAllowed();
                return;
            }
            throw new ApiException(ErrorCode.STORAGE_INIT_FAILED, "Bulut depolama kovasi dogrulanamadi.");
        }
    }

    private void createBucketIfAllowed() {
        if (!objectStorageProperties.autoCreateBucket()) {
            throw new ApiException(ErrorCode.STORAGE_INIT_FAILED, "Bulut depolama kovasi bulunamadi.");
        }
        try {
            s3Client.createBucket(CreateBucketRequest.builder().bucket(objectStorageProperties.bucket()).build());
        } catch (S3Exception exception) {
            throw new ApiException(ErrorCode.STORAGE_INIT_FAILED, "Bulut depolama kovasi olusturulamadi.");
        }
    }

    private String buildObjectKey(Long reportId, String originalFileName) {
        String safeName = originalFileName == null || originalFileName.isBlank()
                ? "unknown"
                : Path.of(originalFileName).getFileName().toString().replace(" ", "_");
        return "reports/" + reportId + "/" + UUID.randomUUID() + "-" + safeName;
    }

    public record StoredFile(
            String storageProvider,
            String storagePath,
            String contentType,
            long fileSize
    ) {
    }
}
