package com.projectreportbuilder.cloud;

import java.time.Clock;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public final class ReportService {
    /** Only a trusted authentication adapter may construct this from verified credentials. */
    public record Principal(String userID) { }
    public record SaveRequest(int schemaVersion, long expectedRevision, ReportContent report) { }
    public record DeleteRequest(long expectedRevision) { }
    public record Page(List<CloudReport> items, UUID nextCursor) { }

    private final ReportRepository repository;
    private final Clock clock;

    public ReportService(ReportRepository repository, Clock clock) {
        this.repository = Objects.requireNonNull(repository);
        this.clock = Objects.requireNonNull(clock);
    }

    public CloudReport get(Principal principal, UUID id) {
        String owner = owner(principal);
        require(id != null, "Report ID required");
        return repository.find(owner, id).orElseThrow(() ->
                new ReportException(ReportException.Code.NOT_FOUND, "Report not found"));
    }

    public Page list(Principal principal, UUID after, int limit) {
        String owner = owner(principal);
        require(limit >= 1 && limit <= 100, "Limit must be between 1 and 100");
        var results = repository.list(owner, after, limit + 1);
        boolean hasMore = results.size() > limit;
        var items = List.copyOf(results.subList(0, Math.min(limit, results.size())));
        return new Page(items, hasMore ? items.getLast().reportID() : null);
    }

    public void delete(Principal principal, UUID id, DeleteRequest request) {
        String owner = owner(principal);
        require(id != null && request != null, "Report ID and revision required");
        require(request.expectedRevision() > 0 && request.expectedRevision() < Long.MAX_VALUE, "Invalid revision");
        repository.delete(owner, id, request.expectedRevision(), clock.instant());
    }

    public CloudReport save(Principal principal, UUID id, SaveRequest request) {
        return save(principal, id, request, true);
    }

    /** Retain size for old clients that omit the field; explicit null clears it. */
    public CloudReport save(Principal principal, UUID id, SaveRequest request, boolean projectSizeProvided) {
        String owner = owner(principal);
        require(id != null && request != null, "Report ID and request required");
        require((request.schemaVersion() == 1 || request.schemaVersion() == 2), "Unsupported schema version");
        require(request.expectedRevision() >= 0 && request.expectedRevision() < Long.MAX_VALUE,
                "Invalid expected revision");
        require(request.report() != null, "Report content required");
        require(request.schemaVersion() == 2 || request.report().assets().isEmpty(), "Images require schema version 2");
        var content = request.report();
        if (!projectSizeProvided && request.expectedRevision() > 0) {
            var current = repository.find(owner, id).orElseThrow(() ->
                    new ReportException(ReportException.Code.REVISION_CONFLICT, "Report changed; reload before saving"));
            if (current.revision() != request.expectedRevision()) {
                throw new ReportException(ReportException.Code.REVISION_CONFLICT, "Report changed; reload before saving");
            }
            content = content.withProjectSize(current.report().projectSize());
        }
        // The conditional write also detects updates or deletion after the compatibility read.
        return repository.save(owner, id, request.expectedRevision(), content, clock.instant());
    }

    private static String owner(Principal principal) {
        if (principal == null || principal.userID() == null || principal.userID().isBlank()) {
            throw new ReportException(ReportException.Code.UNAUTHENTICATED, "Verified identity required");
        }
        return principal.userID();
    }

    private static void require(boolean valid, String message) {
        if (!valid) throw new ReportException(ReportException.Code.INVALID_REPORT, message);
    }
}
