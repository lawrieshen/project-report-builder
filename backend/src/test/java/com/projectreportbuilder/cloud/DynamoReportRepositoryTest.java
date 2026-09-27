package com.projectreportbuilder.cloud;

import org.junit.jupiter.api.Test;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;
import java.time.Instant;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class DynamoReportRepositoryTest {
    private final FakeDynamo client = new FakeDynamo();
    private final DynamoReportRepository repository = new DynamoReportRepository(client, "reports");
    private final UUID id = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private final ReportContent content = new ReportContent("Titan", "iPhone", "draft", null, null, null,
            "update", "", "", "", List.of());

    @Test void createAndUpdateUseAtomicConditionsAndOwnerKey() {
        var created = repository.save("owner", id, 0, content, Instant.now());
        assertEquals("attribute_not_exists(reportID)", client.write.conditionExpression());
        assertEquals("owner", client.write.item().get("ownerID").s());
        assertEquals(created, repository.find("owner", id).orElseThrow());
        assertTrue(client.read.consistentRead());
        repository.save("owner", id, 1, content, Instant.now());
        assertEquals("revision = :expected AND attribute_not_exists(deleted)", client.write.conditionExpression());
        assertEquals("1", client.write.expressionAttributeValues().get(":expected").n());
    }

    @Test void emptyFirstPageOmitsStartingKey() {
        client.pages.add(QueryResponse.builder().build());
        assertTrue(repository.list("owner", null, 10).isEmpty());
        assertFalse(client.queries.getFirst().hasExclusiveStartKey());
    }

    @Test void conditionalFailureBecomesConflict() {
        client.conflict = true;
        var error = assertThrows(ReportException.class, () -> repository.save("owner", id, 1, content, Instant.now()));
        assertEquals(ReportException.Code.REVISION_CONFLICT, error.code());
    }

    @Test void followsDynamoByteLimitedPagesUntilRequestedCount() {
        repository.save("owner", id, 0, content, Instant.now());
        client.pages.add(QueryResponse.builder().items(client.write.item())
                .lastEvaluatedKey(Map.of("reportID", AttributeValue.builder().s(id.toString()).build())).build());
        client.pages.add(QueryResponse.builder().items(client.write.item()).build());
        assertEquals(2, repository.list("owner", null, 2).size());
        assertEquals(2, client.queries.size());
        assertEquals(1, client.queries.get(1).limit());
        assertEquals("owner", client.queries.getFirst().expressionAttributeValues().get(":owner").s());
        assertFalse(client.queries.get(1).exclusiveStartKey().isEmpty());
    }

    @Test void tombstonesAreHiddenAndDoNotStopPagination() {
        repository.delete("owner", id, 1, Instant.now());
        var tombstone = client.write.item();
        assertTrue(tombstone.containsKey("deleted"));
        assertTrue(repository.find("owner", id).isEmpty());
        assertTrue(client.write.conditionExpression().contains("revision = :next"));
        client.pages.add(QueryResponse.builder().items(tombstone)
                .lastEvaluatedKey(Map.of("reportID", AttributeValue.builder().s(id.toString()).build())).build());
        repository.save("owner", UUID.randomUUID(), 0, content, Instant.now());
        client.pages.add(QueryResponse.builder().items(client.write.item()).build());
        assertEquals(1, repository.list("owner", null, 1).size());
        assertEquals(2, client.queries.size());
    }

    private static final class FakeDynamo implements DynamoDbClient {
        PutItemRequest write;
        GetItemRequest read;
        boolean conflict;
        Queue<QueryResponse> pages = new ArrayDeque<>();
        List<QueryRequest> queries = new ArrayList<>();
        @Override public String serviceName() { return "dynamodb"; }
        @Override public void close() { }
        @Override public PutItemResponse putItem(PutItemRequest request) {
            write = request;
            if (conflict) throw ConditionalCheckFailedException.builder().message("conflict").build();
            return PutItemResponse.builder().build();
        }
        @Override public GetItemResponse getItem(GetItemRequest request) {
            read = request;
            return GetItemResponse.builder().item(write.item()).build();
        }
        @Override public QueryResponse query(QueryRequest request) {
            queries.add(request);
            return pages.remove();
        }
    }
}
