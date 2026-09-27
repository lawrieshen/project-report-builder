package com.projectreportbuilder.cloud;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.module.SimpleModule;
import java.io.IOException;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.UUID;

/** Keep strict report parsing while accepting Swift UUID casing and omitted optional properties. */
public final class AiJson {
    private AiJson() { }

    public static ObjectMapper mapper() {
        var identifiers = new SimpleModule();
        identifiers.addDeserializer(UUID.class, new JsonDeserializer<>() {
            @Override public UUID deserialize(JsonParser parser, DeserializationContext context) throws IOException {
                if (!parser.hasToken(JsonToken.VALUE_STRING)) return (UUID) context.handleUnexpectedToken(UUID.class, parser);
                try {
                    var id = UUID.fromString(parser.getText());
                    if (!id.toString().equalsIgnoreCase(parser.getText())) throw new IllegalArgumentException();
                    return id;
                } catch (IllegalArgumentException error) {
                    throw context.weirdStringException("[redacted]", UUID.class, "UUID required");
                }
            }
        });
        return ReportJson.mapper().registerModule(identifiers)
                .disable(DeserializationFeature.FAIL_ON_MISSING_CREATOR_PROPERTIES)
                .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
    }

    /** Hash decoded records, so object-key ordering, UUID case, and optional nulls do not change intent. */
    public static String requestHash(AiContracts.Request request) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(mapper().writeValueAsBytes(request)));
        } catch (Exception error) {
            throw new AiException(AiException.Code.AI_UNAVAILABLE);
        }
    }
}
