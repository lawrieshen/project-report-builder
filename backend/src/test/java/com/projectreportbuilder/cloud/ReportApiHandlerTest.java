package com.projectreportbuilder.cloud;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;
import java.nio.file.*;
import java.time.*;
import static org.junit.jupiter.api.Assertions.*;

class ReportApiHandlerTest {
    private final Clock clock = Clock.fixed(Instant.parse("2026-09-27T00:00:00Z"), ZoneOffset.UTC);
    private final ReportApiHandler handler = new ReportApiHandler(
            new ReportService(new InMemoryReportRepository(), clock), "issuer", "client", "approved", clock);
    private final String id = "10000000-0000-0000-0000-000000000001";

    private ObjectNode event(String route) {
        var event = ReportJson.mapper().createObjectNode();
        event.put("version", "2.0").put("routeKey", route);
        event.putObject("pathParameters").put("reportID", id);
        event.putObject("requestContext").putObject("authorizer").putObject("jwt").putObject("claims")
                .put("iss", "issuer").put("client_id", "client").put("sub", "approved")
                .put("token_use", "access").put("scope", "reports/read reports/write")
                .put("exp", clock.instant().getEpochSecond() + 3600);
        return event;
    }
    private String body() throws Exception { return Files.readString(Path.of("contracts/create-report.json")); }
    private int status(ObjectNode event) throws Exception { return (int) handler.handle(event).get("statusCode"); }

    @Test void saveGetListAndConflict() throws Exception {
        var save = event("PUT /reports/{reportID}").put("body", body());
        assertEquals(200, status(save));
        assertEquals(409, status(save));
        var get = handler.handle(event("GET /reports/{reportID}"));
        assertEquals(200, get.get("statusCode"));
        assertTrue(get.get("body").toString().contains("Titan"));
        assertEquals(200, status(event("GET /reports")));
    }

    @Test void rejectsUntrustedClaimsBeforeReadingReports() throws Exception {
        for (String field : new String[]{"iss", "client_id", "sub", "token_use", "scope", "exp"}) {
            var request = event("GET /reports");
            ((ObjectNode) request.at("/requestContext/authorizer/jwt/claims")).put(field, "invalid");
            assertEquals(401, status(request), field);
        }
        var noAuthorizer = event("GET /reports");
        noAuthorizer.remove("requestContext");
        assertEquals(401, status(noAuthorizer));
    }

    @Test void writeRequiresWriteScope() throws Exception {
        var request = event("PUT /reports/{reportID}").put("body", body());
        ((ObjectNode) request.at("/requestContext/authorizer/jwt/claims")).put("scope", "reports/read");
        assertEquals(401, status(request));
    }

    @Test void rejectsUnknownFieldsMissingNumbersAndCoercion() throws Exception {
        for (String body : new String[]{
                body().replace("\"schemaVersion\": 1", "\"schemaVersion\": 1, \"ownerID\": \"attacker\""),
                body().replace("\"schemaVersion\": 1,", ""),
                body().replace("\"expectedRevision\": 0", "\"expectedRevision\": 0.5"),
                body().replace("\"expectedRevision\": 0", "\"expectedRevision\": \"0\""),
                body().replace("\"currentValue\": 120", "\"currentValue\": null"),
                body().replace("\"currentValue\": 120", "\"currentValue\": 120, \"currentValue\": 12"),
                body().replace("10000000-0000-0000-0000-000000000001", "1-0-0-0-1"),
                body().replace("2026-10-01", "2026-02-30"),
                body().replace("\"codeName\": \"Titan\"", "\"codeName\": 123"),
                body() + "{}",
                body().replace("\"metrics\":", "\"assets\": [], \"metrics\":")
        }) assertEquals(400, status(event("PUT /reports/{reportID}").put("body", body)));
    }

    @Test void rejectsInvalidCursorAndLargeBody() throws Exception {
        var request = event("GET /reports");
        request.putObject("queryStringParameters").put("after", "invalid");
        assertEquals(400, status(request));
        assertEquals(400, status(event("PUT /reports/{reportID}").put("body", "x".repeat(300001))));
    }

    @Test void missingReportIs404() throws Exception {
        assertEquals(404, status(event("GET /reports/{reportID}")));
    }
}
