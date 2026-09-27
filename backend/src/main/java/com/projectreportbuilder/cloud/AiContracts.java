package com.projectreportbuilder.cloud;

import java.time.LocalDate;
import java.util.*;

/** Define text-only composition input and allowlisted proposals, separate from saved reports. */
public final class AiContracts {
    public static final int MAX_REQUEST_BYTES = 64_000;
    public static final int MAX_PROPOSAL_BYTES = 24_000;
    private static final Set<String> FIELDS = Set.of("codeName", "lineOfBusiness", "ragStatus", "milestonePhase",
            "milestoneDeadline", "summaryType", "summaryMessage", "leadEPMName", "projectDRIName");
    private static final Set<String> SECTIONS = Set.of("summary", "health", "milestone", "accountability", "metrics");
    private static final Set<String> COMPARISONS = Set.of("lessThan", "lessThanOrEqual", "greaterThan", "greaterThanOrEqual", "equal");
    private static final Set<String> SEVERITIES = Set.of("p0", "p1", "p2", "p3", "info");

    private AiContracts() { }

    public record Goal(UUID id, int revision, int criterionPolicyVersion, String audience, String purpose,
                       String language, List<String> requiredSections) {
        public Goal {
            require(id != null && revision > 0 && criterionPolicyVersion == 1);
            choice(audience, Set.of("leadership", "engineering", "stakeholders"));
            choice(purpose, Set.of("statusUpdate", "escalation", "supportRequest"));
            choice(language, Set.of("english", "traditionalChinese", "simplifiedChinese"));
            requiredSections = list(requiredSections, 5);
            require(new HashSet<>(requiredSections).size() == requiredSections.size());
            requiredSections.forEach(section -> choice(section, SECTIONS));
        }
    }

    public record MetricDraft(UUID id, String name, String currentValueText, boolean hasTarget,
                              String targetValueText, String comparison, String unit, String severity) {
        public MetricDraft {
            require(id != null);
            text(name, 200); text(currentValueText, 100); text(targetValueText, 100); text(unit, 50);
            choice(comparison, COMPARISONS);
            if (severity != null) choice(severity, SEVERITIES);
        }
    }

    public record Draft(String codeName, String lineOfBusiness, String ragStatus, String milestonePhase,
                        LocalDate milestoneDeadline, String summaryType, String summaryMessage,
                        String leadEPMName, String projectDRIName, List<MetricDraft> metrics) {
        public Draft {
            // Partially edited fields are allowed as context, but all input is bounded.
            text(codeName, 200); text(lineOfBusiness, 200); text(milestonePhase, 200);
            text(summaryMessage, 20_000); text(leadEPMName, 200); text(projectDRIName, 200);
            if (ragStatus != null) choice(ragStatus, Set.of("green", "amber", "red"));
            choice(summaryType, Set.of("update", "blocker", "ask"));
            metrics = list(metrics, 100);
            require(metrics.stream().map(MetricDraft::id).distinct().count() == metrics.size());
        }
    }

    public record Message(String role, String text) {
        public Message { choice(role, Set.of("user", "assistant")); AiContracts.text(text, 8_000); require(!text.isBlank()); }
    }

    public record Request(UUID requestID, UUID baseDraftVersion, UUID candidateVersion, Goal goal,
                          Draft draft, List<Message> messages) {
        public Request {
            require(requestID != null && baseDraftVersion != null && candidateVersion != null && goal != null && draft != null);
            messages = list(messages, 12);
            require(!messages.isEmpty() && messages.getLast().role().equals("user"));
        }
    }

    public record TextChange(String field, String operation, String value) {
        public TextChange {
            choice(field, FIELDS); choice(operation, Set.of("set", "clear"));
            if (operation.equals("clear")) {
                require(value == null && !field.equals("summaryType"));
            } else {
                text(value, field.equals("summaryMessage") ? 20_000 : 200);
                require(!value.isBlank());
                switch (field) {
                    case "lineOfBusiness" -> choice(value, Set.of("iPhone", "Mac", "iPad", "Wearables, Home and Accessories", "Services"));
                    case "ragStatus" -> choice(value, Set.of("green", "amber", "red"));
                    case "milestonePhase" -> choice(value, Set.of("Prototype", "EVT", "DVT", "PVT", "Mass Production"));
                    case "milestoneDeadline" -> {
                        require(value.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}"));
                        try { LocalDate.parse(value); } catch (RuntimeException error) { require(false); }
                    }
                    case "summaryType" -> choice(value, Set.of("update", "blocker", "ask"));
                    default -> { }
                }
            }
        }
    }

    public record MetricValues(String name, double currentValue, Double targetValue,
                               String comparison, String unit, String severity) {
        public MetricValues {
            text(name, 200); require(!name.isBlank() && Double.isFinite(currentValue));
            require((targetValue == null) == (comparison == null));
            if (targetValue != null) { require(Double.isFinite(targetValue)); choice(comparison, COMPARISONS); }
            if (unit != null) text(unit, 50);
            if (severity != null) choice(severity, SEVERITIES);
        }
    }

    public record MetricChange(String operation, UUID id, MetricValues values) {
        public MetricChange {
            choice(operation, Set.of("add", "update", "remove"));
            require(operation.equals("add") ? id == null : id != null);
            require(operation.equals("remove") ? values == null : values != null);
        }
    }

    public record Finding(String criterionID, String explanation) {
        public Finding {
            choice(criterionID, Set.of("audienceFit", "languageFit", "factualAccuracy", "clearAsk", "clearBlocker"));
            text(explanation, 1_000); require(!explanation.isBlank());
        }
    }

    public record Proposal(String assistantMessage, List<String> clarifyingQuestions,
                           List<TextChange> proposedChanges, List<MetricChange> metricChanges,
                           List<String> warnings, List<Finding> semanticFindings) {
        public Proposal {
            text(assistantMessage, 4_000); require(!assistantMessage.isBlank());
            clarifyingQuestions = list(clarifyingQuestions, 5); clarifyingQuestions.forEach(s -> text(s, 1_000));
            proposedChanges = list(proposedChanges, FIELDS.size());
            require(proposedChanges.stream().map(TextChange::field).distinct().count() == proposedChanges.size());
            metricChanges = list(metricChanges, 100);
            warnings = list(warnings, 10); warnings.forEach(s -> text(s, 1_000));
            semanticFindings = list(semanticFindings, 5);
            require(semanticFindings.stream().map(Finding::criterionID).distinct().count() == semanticFindings.size());
        }

        public void validateAgainst(Request request) {
            var available = new HashSet<>(request.draft().metrics().stream().map(MetricDraft::id).toList());
            var changed = new HashSet<UUID>();
            int count = available.size();
            for (var change : metricChanges) {
                if (change.id() != null) require(available.contains(change.id()) && changed.add(change.id()));
                if (change.operation().equals("add")) count++;
                if (change.operation().equals("remove")) count--;
            }
            require(count <= 100);
            for (var finding : semanticFindings) {
                if (finding.criterionID().equals("clearAsk")) require(request.goal().purpose().equals("supportRequest"));
                if (finding.criterionID().equals("clearBlocker")) require(request.goal().purpose().equals("escalation"));
            }
        }
    }

    public record Response(UUID requestID, UUID baseDraftVersion, UUID candidateVersion, UUID goalID,
                           int goalRevision, Proposal proposal, int remainingDailyRequests) {
        public static Response forRequest(Request request, Proposal proposal, int remaining) {
            return new Response(request.requestID(), request.baseDraftVersion(), request.candidateVersion(),
                    request.goal().id(), request.goal().revision(), proposal, remaining);
        }
    }

    private static void text(String value, int max) { require(value != null && value.length() <= max); }
    private static void choice(String value, Set<String> allowed) { require(value != null && allowed.contains(value)); }
    private static <T> List<T> list(List<T> values, int max) {
        require(values != null && values.size() <= max && values.stream().allMatch(Objects::nonNull));
        return List.copyOf(values);
    }
    private static void require(boolean valid) { if (!valid) throw new AiException(AiException.Code.INVALID_INPUT); }
}
