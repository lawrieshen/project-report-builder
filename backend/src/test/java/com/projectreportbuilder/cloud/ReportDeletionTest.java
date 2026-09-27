package com.projectreportbuilder.cloud;

import org.junit.jupiter.api.Test;
import java.time.Clock;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class ReportDeletionTest {
    @Test void deletionIsOwnerScopedRevisionSafeAndRepeatable() {
        var service = new ReportService(new InMemoryReportRepository(), Clock.systemUTC());
        var owner = new ReportService.Principal("owner");
        var other = new ReportService.Principal("other");
        var id = UUID.randomUUID();
        var content = new ReportContent("Test", "Mac", "draft", null, null, null, "update", "", "", "", List.of());
        service.save(owner, id, new ReportService.SaveRequest(1, 0, content));
        assertThrows(ReportException.class, () -> service.delete(other, id, new ReportService.DeleteRequest(1)));
        assertThrows(ReportException.class, () -> service.delete(owner, id, new ReportService.DeleteRequest(2)));
        service.delete(owner, id, new ReportService.DeleteRequest(1));
        service.delete(owner, id, new ReportService.DeleteRequest(1));
        assertTrue(service.list(owner, null, 20).items().isEmpty());
        assertThrows(ReportException.class, () -> service.get(owner, id));
        for (long revision : new long[]{0, 1, 2}) {
            assertThrows(ReportException.class, () -> service.save(owner, id, new ReportService.SaveRequest(1, revision, content)));
        }
    }
}
