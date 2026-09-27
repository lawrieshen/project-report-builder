package com.projectreportbuilder.cloud;

import java.time.Instant;
import java.util.UUID;

public record CloudReport(UUID reportID, String ownerID, long revision, int schemaVersion,
                          Instant updatedAt, ReportContent report) { }
