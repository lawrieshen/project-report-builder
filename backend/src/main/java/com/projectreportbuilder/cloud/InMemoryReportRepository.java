package com.projectreportbuilder.cloud;

import java.time.Instant;
import java.util.*;

/** Process-local storage for tests and development; all state is lost on restart. */
public final class InMemoryReportRepository implements ReportRepository {
    private record Key(String ownerID, UUID reportID) { }
    private final Map<Key, CloudReport> reports = new HashMap<>();

    public synchronized Optional<CloudReport> find(String ownerID, UUID reportID) {
        return Optional.ofNullable(reports.get(new Key(ownerID, reportID)));
    }

    public synchronized List<CloudReport> list(String ownerID, UUID after, int limit) {
        return reports.values().stream()
                .filter(report -> report.ownerID().equals(ownerID))
                .filter(report -> after == null || report.reportID().toString().compareTo(after.toString()) > 0)
                .sorted(Comparator.comparing(report -> report.reportID().toString()))
                .limit(limit).toList();
    }

    public synchronized CloudReport save(String ownerID, UUID reportID, long expectedRevision,
                                          ReportContent content, Instant now) {
        var key = new Key(ownerID, reportID);
        CloudReport existing = reports.get(key);
        long actualRevision = existing == null ? 0 : existing.revision();
        if (actualRevision != expectedRevision) {
            throw new ReportException(ReportException.Code.REVISION_CONFLICT, "Report changed; download before retrying");
        }
        var saved = new CloudReport(reportID, ownerID, actualRevision + 1, 1, now, content);
        reports.put(key, saved);
        return saved;
    }
}
