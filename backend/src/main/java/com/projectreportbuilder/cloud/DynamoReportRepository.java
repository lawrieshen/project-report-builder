package com.projectreportbuilder.cloud;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;

/** Store owner-scoped snapshots with conditional writes for revision conflicts. */
public final class DynamoReportRepository implements ReportRepository {
    private final DynamoDbClient client;
    private final String table;
    private final ObjectMapper json = ReportJson.mapper();

    public DynamoReportRepository(DynamoDbClient client, String table) {
        this.client = Objects.requireNonNull(client);
        this.table = Objects.requireNonNull(table);
    }

    @Override public Optional<CloudReport> find(String owner, UUID id) {
        var result = client.getItem(GetItemRequest.builder().tableName(table).key(key(owner, id))
                .consistentRead(true).build());
        return result.hasItem() ? Optional.of(decode(result.item())) : Optional.empty();
    }

    @Override public List<CloudReport> list(String owner, UUID after, int limit) {
        var results = new ArrayList<CloudReport>();
        Map<String, AttributeValue> start = after == null ? Map.of() : key(owner, after);
        do {
            var request = QueryRequest.builder().tableName(table)
                    .keyConditionExpression("ownerID = :owner")
                    .expressionAttributeValues(Map.of(":owner", text(owner)))
                    .limit(limit - results.size())
                    .consistentRead(true).scanIndexForward(true);
            if (!start.isEmpty()) request.exclusiveStartKey(start);
            var page = client.query(request.build());
            for (var item : page.items()) results.add(decode(item));
            start = page.lastEvaluatedKey();
            // DynamoDB may stop at 1 MB before reaching the requested item count.
        } while (!start.isEmpty() && results.size() < limit);
        return List.copyOf(results);
    }

    @Override public CloudReport save(String owner, UUID id, long expectedRevision,
                                       ReportContent content, Instant now) {
        var report = new CloudReport(id, owner, expectedRevision + 1, content.assets().isEmpty() ? 1 : 2, now, content);
        String payload;
        try { payload = json.writeValueAsString(report); }
        catch (JsonProcessingException error) { throw new IllegalStateException("Cannot encode report", error); }
        // Leave room for keys and metadata below DynamoDB's 400 KB item limit.
        if (payload.getBytes(StandardCharsets.UTF_8).length > 350_000) {
            throw new ReportException(ReportException.Code.INVALID_REPORT, "Report is too large");
        }
        var item = new HashMap<>(key(owner, id));
        item.put("revision", AttributeValue.builder().n(Long.toString(report.revision())).build());
        item.put("payload", text(payload));
        var request = PutItemRequest.builder().tableName(table).item(item);
        if (expectedRevision == 0) {
            request.conditionExpression("attribute_not_exists(reportID)");
        } else {
            request.conditionExpression("revision = :expected")
                    .expressionAttributeValues(Map.of(":expected",
                            AttributeValue.builder().n(Long.toString(expectedRevision)).build()));
        }
        try { client.putItem(request.build()); }
        catch (ConditionalCheckFailedException error) {
            throw new ReportException(ReportException.Code.REVISION_CONFLICT, "Report revision changed; reload before saving");
        }
        return report;
    }

    private CloudReport decode(Map<String, AttributeValue> item) {
        try { return json.treeToValue(ReportJson.withLegacyAssets(json.readTree(item.get("payload").s())), CloudReport.class); }
        catch (JsonProcessingException error) { throw new IllegalStateException("Cannot decode stored report", error); }
    }

    private static Map<String, AttributeValue> key(String owner, UUID id) {
        return Map.of("ownerID", text(owner), "reportID", text(id.toString()));
    }
    private static AttributeValue text(String value) { return AttributeValue.builder().s(value).build(); }
}
