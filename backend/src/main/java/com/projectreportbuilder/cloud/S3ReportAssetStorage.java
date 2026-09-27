package com.projectreportbuilder.cloud;

import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import java.time.Duration;
import java.util.*;

public final class S3ReportAssetStorage implements ReportAssetStorage {
    private final S3Client client;
    private final S3Presigner signer;
    private final String bucket;
    public S3ReportAssetStorage(S3Client client, S3Presigner signer, String bucket) {
        this.client = client;
        this.signer = signer;
        this.bucket = bucket;
    }
    static String key(String owner, UUID report, ReportAsset asset) {
        // Content-addressed keys prevent a later upload from changing referenced bytes.
        return "reports/" + owner + "/" + report + "/" + asset.sha256();
    }
    private static String checksum(ReportAsset asset) {
        return Base64.getEncoder().encodeToString(HexFormat.of().parseHex(asset.sha256()));
    }
    @Override public Transfer upload(String owner, UUID report, ReportAsset asset) {
        var request = PutObjectRequest.builder().bucket(bucket).key(key(owner, report, asset))
                .contentType(asset.contentType()).contentLength(asset.byteCount())
                .checksumSHA256(checksum(asset)).build();
        var signed = signer.presignPutObject(b -> b.signatureDuration(Duration.ofMinutes(5)).putObjectRequest(request));
        var headers = new HashMap<String, String>();
        signed.signedHeaders().forEach((name, values) -> {
            if (!name.equalsIgnoreCase("host")) headers.put(name, String.join(",", values));
        });
        return new Transfer(signed.url().toString(), Map.copyOf(headers));
    }
    @Override public Transfer download(String owner, UUID report, ReportAsset asset) {
        var request = GetObjectRequest.builder().bucket(bucket).key(key(owner, report, asset)).build();
        var signed = signer.presignGetObject(b -> b.signatureDuration(Duration.ofMinutes(5)).getObjectRequest(request));
        return new Transfer(signed.url().toString(), Map.of());
    }
    @Override public void verify(String owner, UUID report, ReportAsset asset) {
        try {
            var head = client.headObject(HeadObjectRequest.builder().bucket(bucket).key(key(owner, report, asset))
                    .checksumMode(ChecksumMode.ENABLED).build());
            if (head.contentLength() != asset.byteCount() || !asset.contentType().equals(head.contentType())
                    || !checksum(asset).equals(head.checksumSHA256())) {
                throw new ReportException(ReportException.Code.INVALID_REPORT, "Image upload is incomplete or does not match metadata");
            }
        } catch (S3Exception error) {
            if (error.statusCode() == 404 || error.statusCode() == 403) {
                throw new ReportException(ReportException.Code.INVALID_REPORT, "Upload every image before saving the report");
            }
            throw error;
        }
    }
}
