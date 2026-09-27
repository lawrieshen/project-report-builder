package com.projectreportbuilder.cloud;

import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

class ReportServiceTest {
    private final Instant now = Instant.parse("2026-09-27T00:00:00Z");
    private final ReportService service = new ReportService(new InMemoryReportRepository(), Clock.fixed(now, ZoneOffset.UTC));
    private final ReportService.Principal alice = new ReportService.Principal("alice");
    private final ReportService.Principal bob = new ReportService.Principal("bob");

    private ReportContent content(String name) {
        return new ReportContent(name, "iPhone", "active", "amber", "DVT", LocalDate.of(2026, 10, 1),
                "update", "Ready for review", "Jane", "Alex", List.of());
    }
    private CloudReport save(UUID id, long revision, String name) {
        return service.save(alice, id, new ReportService.SaveRequest(1, revision, content(name)));
    }
    private void fails(ReportException.Code code, Runnable action) {
        assertEquals(code, assertThrows(ReportException.class, action::run).code());
    }

    @Test void createReadAndUpdatePreserveIdentity() {
        UUID id = UUID.randomUUID();
        var first = save(id, 0, "Titan");
        assertEquals(first, service.get(alice, id));
        assertEquals(now, first.updatedAt());
        assertEquals(1, first.revision());
        var second = save(id, 1, "Titan Updated");
        assertEquals(id, second.reportID());
        assertEquals("alice", second.ownerID());
        assertEquals(2, second.revision());
        assertEquals("Titan", first.report().codeName());
    }

    @Test void anotherOwnerCannotReadOrOverwrite() {
        UUID id = UUID.randomUUID();
        var first = save(id, 0, "Private");
        fails(ReportException.Code.NOT_FOUND, () -> service.get(bob, id));
        assertTrue(service.list(bob, null, 10).items().isEmpty());
        fails(ReportException.Code.REVISION_CONFLICT, () -> service.save(bob, id,
                new ReportService.SaveRequest(1, 1, content("Overwrite"))));
        service.save(bob, id, new ReportService.SaveRequest(1, 0, content("Independent copy")));
        assertEquals(first, service.get(alice, id));
    }

    @Test void staleAndRepeatedCreatesCannotOverwrite() {
        UUID id = UUID.randomUUID();
        save(id, 0, "Original");
        fails(ReportException.Code.REVISION_CONFLICT, () -> save(id, 0, "Retry"));
        save(id, 1, "New");
        fails(ReportException.Code.REVISION_CONFLICT, () -> save(id, 1, "Stale"));
        assertEquals("New", service.get(alice, id).report().codeName());
    }

    @Test void concurrentUpdatesAllowOnlyOneWinner() throws Exception {
        UUID id = UUID.randomUUID();
        save(id, 0, "Original");
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            Callable<Boolean> update = () -> {
                start.await();
                try { save(id, 1, "Update"); return true; }
                catch (ReportException error) {
                    assertEquals(ReportException.Code.REVISION_CONFLICT, error.code());
                    return false;
                }
            };
            var first = executor.submit(update);
            var second = executor.submit(update);
            start.countDown();
            assertNotEquals(first.get(5, TimeUnit.SECONDS), second.get(5, TimeUnit.SECONDS));
        }
        assertEquals(2, service.get(alice, id).revision());
    }

    @Test void paginationIsStableAndOwnerScoped() {
        UUID first = UUID.fromString("00000000-0000-0000-0000-000000000001");
        UUID second = UUID.fromString("00000000-0000-0000-0000-000000000002");
        save(second, 0, "Second"); save(first, 0, "First");
        var page = service.list(alice, null, 1);
        assertEquals(first, page.items().getFirst().reportID());
        assertEquals(first, page.nextCursor());
        var next = service.list(alice, page.nextCursor(), 1);
        assertEquals(second, next.items().getFirst().reportID());
        assertNull(next.nextCursor());
    }

    @Test void rejectsMissingIdentityInvalidRequestsAndMissingReports() {
        fails(ReportException.Code.UNAUTHENTICATED, () -> service.list(null, null, 10));
        fails(ReportException.Code.UNAUTHENTICATED, () -> service.get(new ReportService.Principal(" "), UUID.randomUUID()));
        fails(ReportException.Code.UNAUTHENTICATED, () -> service.save(null, UUID.randomUUID(), null));
        fails(ReportException.Code.NOT_FOUND, () -> service.get(alice, UUID.randomUUID()));
        fails(ReportException.Code.INVALID_REPORT, () -> service.list(alice, null, 101));
        fails(ReportException.Code.INVALID_REPORT, () -> service.save(alice, UUID.randomUUID(), new ReportService.SaveRequest(3, 0, content("A"))));
        fails(ReportException.Code.INVALID_REPORT, () -> save(UUID.randomUUID(), -1, "A"));
        fails(ReportException.Code.INVALID_REPORT, () -> save(UUID.randomUUID(), 0, " "));
    }

    @Test void rejectsInvalidFieldsAndNonFiniteMetrics() {
        fails(ReportException.Code.INVALID_REPORT, () -> new ReportContent("A", "Camera", "active", null,
                null, null, "update", "", "", "", List.of()));
        fails(ReportException.Code.INVALID_REPORT, () -> new ReportContent("A", "Mac", "active", null,
                "DVT", null, "update", "", "", "", List.of()));
        fails(ReportException.Code.INVALID_REPORT, () -> new ReportContent.Metric(UUID.randomUUID(), "Latency", Double.NaN, null, null, "ms", null));
    }

    @Test void metricOrderIsImmutableAndDuplicateNamesAreRejected() {
        var a = new ReportContent.Metric(UUID.randomUUID(), "Latency", 80, 100.0, "lt", "ms", "P1");
        var b = new ReportContent.Metric(UUID.randomUUID(), "Builds", 10, null, null, null, null);
        var metrics = new ArrayList<>(List.of(a, b));
        var report = new ReportContent("A", "Mac", "draft", null, null, null, "update", "", "", "", metrics);
        metrics.clear();
        assertEquals(List.of(a, b), report.metrics());
        var duplicate = new ReportContent.Metric(UUID.randomUUID(), " LATENCY ", 10, null, null, null, null);
        fails(ReportException.Code.INVALID_REPORT, () -> new ReportContent("A", "Mac", "draft", null, null, null,
                "update", "", "", "", List.of(a, duplicate)));
    }
}
