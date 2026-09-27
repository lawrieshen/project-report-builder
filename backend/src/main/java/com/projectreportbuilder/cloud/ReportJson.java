package com.projectreportbuilder.cloud;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.cfg.CoercionAction;
import com.fasterxml.jackson.databind.cfg.CoercionInputShape;
import com.fasterxml.jackson.databind.type.LogicalType;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.io.IOException;
import java.util.UUID;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

/** Decode the published contract without scalar coercion or missing record fields. */
final class ReportJson {
    static ObjectMapper mapper() {
        var identifiers = new SimpleModule();
        identifiers.addDeserializer(UUID.class, new JsonDeserializer<>() {
            @Override public UUID deserialize(JsonParser parser, DeserializationContext context) throws IOException {
                if (!parser.hasToken(JsonToken.VALUE_STRING)) {
                    return (UUID) context.handleUnexpectedToken(UUID.class, parser);
                }
                try { return canonicalID(parser.getText()); }
                catch (IllegalArgumentException error) {
                    throw context.weirdStringException(parser.getText(), UUID.class, "Canonical UUID required");
                }
            }
        });
        identifiers.addDeserializer(LocalDate.class, new JsonDeserializer<>() {
            @Override public LocalDate deserialize(JsonParser parser, DeserializationContext context) throws IOException {
                if (!parser.hasToken(JsonToken.VALUE_STRING)) {
                    return (LocalDate) context.handleUnexpectedToken(LocalDate.class, parser);
                }
                String value = parser.getText();
                try {
                    if (!value.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")) throw new DateTimeParseException("Invalid date", value, 0);
                    return LocalDate.parse(value);
                } catch (DateTimeParseException error) {
                    throw context.weirdStringException(value, LocalDate.class, "Valid YYYY-MM-DD date required");
                }
            }
        });
        var mapper = JsonMapper.builder().addModule(new JavaTimeModule()).addModule(identifiers)
                .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS)
                .disable(DeserializationFeature.ACCEPT_FLOAT_AS_INT)
                .enable(DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES)
                .enable(DeserializationFeature.FAIL_ON_MISSING_CREATOR_PROPERTIES)
                .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
                .enable(JsonParser.Feature.STRICT_DUPLICATE_DETECTION)
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS).build();
        mapper.coercionConfigFor(LogicalType.Textual)
                .setCoercion(CoercionInputShape.Integer, CoercionAction.Fail)
                .setCoercion(CoercionInputShape.Float, CoercionAction.Fail)
                .setCoercion(CoercionInputShape.Boolean, CoercionAction.Fail);
        return mapper;
    }

    static UUID canonicalID(String text) {
        var id = UUID.fromString(text);
        if (!id.toString().equals(text)) throw new IllegalArgumentException("Canonical UUID required");
        return id;
    }
}
