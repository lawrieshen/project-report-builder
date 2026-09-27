package com.projectreportbuilder.cloud;

import org.junit.jupiter.api.Test;
import software.amazon.awssdk.auth.credentials.*;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import java.lang.reflect.Proxy;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class ReportAssetTest {
    private final UUID id = UUID.randomUUID();
    private ReportAsset asset(long bytes) {
        return new ReportAsset(id, "image.png", "Diagram", "image/png", bytes, "a".repeat(64));
    }
    @Test void rejectsUnsafeMetadata() {
        assertThrows(ReportException.class, () -> asset(0));
        assertThrows(ReportException.class, () -> asset(21L * 1024 * 1024));
        assertThrows(ReportException.class, () -> new ReportAsset(id, "../image.png", "", "image/png", 1, "a".repeat(64)));
        assertThrows(ReportException.class, () -> new ReportAsset(id, "image.svg", "", "image/svg+xml", 1, "a".repeat(64)));
        assertThrows(ReportException.class, () -> new ReportAsset(id, "image.png", "", "image/png", 1, "invalid"));
    }
    @Test void signedUploadBindsOwnerSizeTypeAndChecksum() {
        try (var signer = S3Presigner.builder().region(Region.AP_SOUTHEAST_2)
                .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create("test", "test"))).build()) {
            var storage = new S3ReportAssetStorage(null, signer, "test-images");
            var upload = storage.upload("owner", id, asset(12));
            assertTrue(upload.url().contains("reports/owner/" + id + "/"));
            assertTrue(upload.url().contains("X-Amz-Expires=300"));
            assertEquals("12", upload.headers().get("content-length"));
            assertEquals("image/png", upload.headers().get("content-type"));
            assertEquals(Base64.getEncoder().encodeToString(HexFormat.of().parseHex("a".repeat(64))),
                    upload.headers().get("x-amz-checksum-sha256"));
            assertEquals(Set.of("content-length", "content-type", "x-amz-checksum-sha256"), upload.headers().keySet());
            assertNotEquals(S3ReportAssetStorage.key("owner", id, asset(12)),
                    S3ReportAssetStorage.key("other", id, asset(12)));
        }
    }
    @Test void verificationRejectsMissingOrMismatchedObject() {
        String checksum = Base64.getEncoder().encodeToString(HexFormat.of().parseHex("a".repeat(64)));
        var valid = HeadObjectResponse.builder().contentLength(12L).contentType("image/png").checksumSHA256(checksum).build();
        new S3ReportAssetStorage(client(valid), null, "bucket").verify("owner", id, asset(12));
        assertThrows(ReportException.class, () -> new S3ReportAssetStorage(client(valid), null, "bucket").verify("owner", id, asset(13)));
        var missing = S3Exception.builder().statusCode(404).build();
        assertThrows(ReportException.class, () -> new S3ReportAssetStorage(client(missing), null, "bucket").verify("owner", id, asset(12)));
    }
    @Test void reportRejectsDuplicateAndOversizedImageSets() {
        var same = asset(1);
        assertThrows(ReportException.class, () -> content(List.of(same, same)));
        var large = new ArrayList<ReportAsset>();
        for (int i = 0; i < 3; i++) {
            large.add(new ReportAsset(UUID.randomUUID(), "image.png", "", "image/png", 20L * 1024 * 1024, "a".repeat(64)));
        }
        assertThrows(ReportException.class, () -> content(large));
        assertDoesNotThrow(() -> content(large.subList(0, 2)));
    }
    private ReportContent content(List<ReportAsset> assets) {
        return new ReportContent("Test", "Mac", "draft", null, null, null,
                "update", "", "", "", List.of(), assets);
    }
    private S3Client client(Object result) {
        return (S3Client) Proxy.newProxyInstance(getClass().getClassLoader(), new Class[]{S3Client.class}, (proxy, method, args) -> {
            if (result instanceof RuntimeException error) throw error;
            return result;
        });
    }
}
