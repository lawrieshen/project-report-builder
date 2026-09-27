package com.projectreportbuilder.cloud;

import com.amazonaws.services.lambda.runtime.*;
import com.fasterxml.jackson.databind.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.*;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

/** Accept only HTTP API events from the JWT-authorized gateway integration. */
public final class ReportApiHandler implements RequestStreamHandler {
    private static final int MAX_BODY_BYTES = 300_000;
    private final ObjectMapper json = ReportJson.mapper();
    private final ReportService service;
    private final String issuer, clientID, approvedSubject;
    private final Clock clock;
    private ReportAssetStorage assets;

    public ReportApiHandler() {
        this(new ReportService(new DynamoReportRepository(DynamoDbClient.create(), required("REPORTS_TABLE")),
                        Clock.systemUTC()), required("COGNITO_ISSUER"), required("COGNITO_CLIENT_ID"),
                required("APPROVED_SUBJECT"), Clock.systemUTC());
        assets = new S3ReportAssetStorage(software.amazon.awssdk.services.s3.S3Client.create(),
                software.amazon.awssdk.services.s3.presigner.S3Presigner.create(), required("ASSETS_BUCKET"));
    }

    ReportApiHandler(ReportService service, String issuer, String clientID, String approvedSubject, Clock clock) {
        this.service = service;
        this.issuer = issuer;
        this.clientID = clientID;
        this.approvedSubject = approvedSubject;
        this.clock = clock;
    }

    ReportApiHandler(ReportService service, String issuer, String clientID, String approvedSubject,
                     Clock clock, ReportAssetStorage assets) {
        this(service, issuer, clientID, approvedSubject, clock);
        this.assets = assets;
    }

    @Override public void handleRequest(InputStream input, OutputStream output, Context context) throws IOException {
        try {
            JsonNode event = json.readTree(input);
            var response = handle(event);
            json.writeValue(output, response);
        } catch (Exception error) {
            // Do not log tokens, report content, or exception messages containing request data.
            if (context != null) {
                String code = error.getClass().getSimpleName();
                if (error instanceof software.amazon.awssdk.awscore.exception.AwsServiceException serviceError
                        && serviceError.awsErrorDetails() != null) {
                    code += ":" + serviceError.awsErrorDetails().errorCode();
                }
                context.getLogger().log("Report API request failed: " + code + "\n");
            }
            json.writeValue(output, response(500, Map.of("code", "INTERNAL_ERROR", "message", "Unable to process request")));
        }
    }

    Map<String, Object> handle(JsonNode event) throws IOException {
        try {
            String route = event.path("routeKey").asText();
            String scope = (route.startsWith("PUT ") || route.startsWith("POST ") || route.startsWith("DELETE ")) ? "reports/write" : "reports/read";
            var principal = authenticate(event, scope);
            var query = event.path("queryStringParameters");
            Object result;
            switch (route) {
                case "POST /reports/{reportID}/assets/upload" -> {
                    var asset = json.readValue(requestBytes(event), ReportAsset.class);
                    result = assets.upload(principal.userID(), reportID(event), asset);
                }
                case "GET /reports/{reportID}/assets/{assetID}" -> {
                    var report = service.get(principal, reportID(event));
                    var assetID = ReportJson.canonicalID(event.path("pathParameters").path("assetID").asText());
                    var asset = report.report().assets().stream().filter(a -> a.id().equals(assetID)).findFirst()
                            .orElseThrow(() -> new ReportException(ReportException.Code.NOT_FOUND, "Image not found"));
                    result = assets.download(principal.userID(), report.reportID(), asset);
                }
                case "DELETE /reports/{reportID}" -> {
                    service.delete(principal, reportID(event), json.readValue(requestBytes(event), ReportService.DeleteRequest.class));
                    result = Map.of("deleted", true);
                }
                case "GET /reports" -> {
                    var after = query.has("after") ? ReportJson.canonicalID(query.get("after").asText()) : null;
                    int limit = query.has("limit") ? Integer.parseInt(query.get("limit").asText()) : 20;
                    result = service.list(principal, after, limit);
                }
                case "GET /reports/{reportID}" -> result = service.get(principal, reportID(event));
                case "PUT /reports/{reportID}" -> {
                    var tree = json.readTree(requestBytes(event));
                    if (tree.path("schemaVersion").asInt() == 1 && tree.path("report").has("assets")) {
                        throw new IllegalArgumentException("Images require schema version 2");
                    }
                    var request = json.treeToValue(ReportJson.withLegacyAssets(tree), ReportService.SaveRequest.class);
                    if (request.report() != null) {
                        for (var asset : request.report().assets()) assets.verify(principal.userID(), reportID(event), asset);
                    }
                    result = service.save(principal, reportID(event), request);
                }
                default -> { return response(404, Map.of("code", "NOT_FOUND", "message", "Route not found")); }
            }
            return response(200, result);
        } catch (ReportException error) {
            int status = switch (error.code()) {
                case UNAUTHENTICATED -> 401;
                case NOT_FOUND -> 404;
                case INVALID_REPORT -> 400;
                case REVISION_CONFLICT -> 409;
            };
            return response(status, Map.of("code", error.code().name(), "message", error.getMessage()));
        } catch (com.fasterxml.jackson.core.JsonProcessingException | IllegalArgumentException error) {
            return response(400, Map.of("code", "INVALID_REPORT", "message", "Invalid report request"));
        }
    }

    private ReportService.Principal authenticate(JsonNode event, String scope) {
        // Signature, issuer, audience, and time checks happen at API Gateway first.
        // Never decode an Authorization header or accept identity from the report body.
        var claims = event.path("requestContext").path("authorizer").path("jwt").path("claims");
        var scopes = Arrays.asList(claims.path("scope").asText().split(" "));
        long expires;
        try { expires = Long.parseLong(claims.path("exp").asText()); }
        catch (NumberFormatException error) { expires = 0; }
        if (!event.path("version").asText().equals("2.0")
                || !issuer.equals(claims.path("iss").asText())
                || !clientID.equals(claims.path("client_id").asText())
                || !approvedSubject.equals(claims.path("sub").asText())
                || !claims.path("token_use").asText().equals("access")
                || expires <= clock.instant().getEpochSecond() || !scopes.contains(scope)) {
            throw new ReportException(ReportException.Code.UNAUTHENTICATED, "Approved access token required");
        }
        return new ReportService.Principal(approvedSubject);
    }

    private byte[] requestBytes(JsonNode event) {
        String body = event.path("body").asText();
        if (body.length() > MAX_BODY_BYTES * 2) throw new IllegalArgumentException();
        byte[] bytes = event.path("isBase64Encoded").asBoolean()
                ? Base64.getDecoder().decode(body) : body.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAX_BODY_BYTES) throw new IllegalArgumentException();
        return bytes;
    }

    private UUID reportID(JsonNode event) {
        return ReportJson.canonicalID(event.path("pathParameters").path("reportID").asText());
    }

    private Map<String, Object> response(int status, Object body) throws IOException {
        return Map.of("statusCode", status, "headers", Map.of("content-type", "application/json", "cache-control", "no-store"),
                "isBase64Encoded", false, "body", json.writeValueAsString(body));
    }

    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) throw new IllegalStateException("Missing configuration: " + name);
        return value;
    }
}
