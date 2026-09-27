package com.projectreportbuilder.cloud;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ReportRepository {
    void delete(String ownerID, UUID reportID, long expectedRevision, Instant now);

    Optional<CloudReport> find(String ownerID, UUID reportID);
    List<CloudReport> list(String ownerID, UUID after, int limit);

    /** Atomically compare revision and write. Expected revision zero means create only. */
    CloudReport save(String ownerID, UUID reportID, long expectedRevision,
                     ReportContent content, Instant now);
}
