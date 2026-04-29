package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.ObjectStorageProperties;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import java.nio.file.Path;
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
import java.nio.file.Files;

@Service
public class FileStorageService {

    private final S3Client s3Client;
    private final ObjectStorageProperties objectStorageProperties;

    public FileStorageService(S3Client s3Client, ObjectStorageProperties objectStorageProperties) {
        this.s3Client = s3Client;
        this.objectStorageProperties = objectStorageProperties;
        ensureBucketExists();
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
