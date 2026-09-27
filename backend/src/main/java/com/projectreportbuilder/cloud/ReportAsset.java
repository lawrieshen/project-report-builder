package com.projectreportbuilder.cloud;

import java.util.Set;
import java.util.UUID;

/** Describe immutable image bytes; the server derives object keys from the owner and report. */
public record ReportAsset(UUID id, String fileName, String altText, String contentType,
                          long byteCount, String sha256) {
    public static final long MAX_BYTES = 20L * 1024 * 1024;
    public ReportAsset {
        if (id == null || fileName == null || fileName.isBlank() || fileName.length() > 255
                || fileName.contains("/") || fileName.contains("\\")
                || altText == null || altText.length() > 2000
                || contentType == null || !Set.of("image/png", "image/jpeg", "image/heic").contains(contentType)
                || byteCount < 1 || byteCount > MAX_BYTES
                || sha256 == null || !sha256.matches("[0-9a-f]{64}")) {
            throw new ReportException(ReportException.Code.INVALID_REPORT, "Invalid image metadata");
        }
    }
}
