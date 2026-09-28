package com.projectreportbuilder.cloud;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/** Transport model independent of Swift Codable. Image metadata is ordered; bytes live in private object storage. */
public record ReportContent(String codeName, String lineOfBusiness, String status,
                            String ragStatus, String milestonePhase, LocalDate milestoneDeadline,
                            String summaryType, String summaryMessage,
                            String leadEPMName, String projectDRIName, List<Metric> metrics, List<ReportAsset> assets, String projectSize) {
    public ReportContent {
        require(codeName != null && !codeName.isBlank() && codeName.length() <= 200, "Invalid code name");
        require(Set.of("iPhone", "Mac", "iPad", "Wearables, Home and Accessories", "Services")
                .contains(lineOfBusiness == null ? "" : lineOfBusiness), "Invalid product line");
        require(projectSize == null || choice(projectSize, "small", "medium", "large"), "Invalid project size");
        require(choice(status, "draft", "active", "archived"), "Invalid project status");
        require(ragStatus == null || choice(ragStatus, "green", "amber", "red"), "Invalid health");
        require((milestonePhase == null) == (milestoneDeadline == null), "Phase and deadline must be paired");
        require(milestonePhase == null || choice(milestonePhase, "Prototype", "EVT", "DVT", "PVT", "Mass Production"), "Invalid phase");
        require(choice(summaryType, "update", "blocker", "ask"), "Invalid summary type");
        require(summaryMessage != null && summaryMessage.length() <= 20000, "Invalid summary");
        require(leadEPMName != null && leadEPMName.length() <= 200, "Invalid lead name");
        require(projectDRIName != null && projectDRIName.length() <= 200, "Invalid DRI name");
        require(metrics != null && metrics.size() <= 100, "Invalid metrics");
        var ids = new HashSet<UUID>();
        var names = new HashSet<String>();
        for (Metric metric : metrics) {
            require(metric != null, "Null metric");
            require(ids.add(metric.id()), "Duplicate metric ID");
            require(names.add(metric.name().strip().toLowerCase(Locale.ROOT)), "Duplicate metric name");
        }
        metrics = List.copyOf(metrics);
        require(assets != null && assets.size() <= 10, "At most 10 images are allowed");
        var imageIDs = new HashSet<UUID>();
        for (var asset : assets) {
            require(asset != null && imageIDs.add(asset.id()), "Invalid or duplicate image ID");
        }
        require(assets.stream().mapToLong(ReportAsset::byteCount).sum() <= 50L * 1024 * 1024, "Images exceed 50 MiB");
        assets = List.copyOf(assets);
    }

    public ReportContent(String codeName, String lineOfBusiness, String status, String ragStatus,
                         String milestonePhase, LocalDate milestoneDeadline, String summaryType,
                         String summaryMessage, String leadEPMName, String projectDRIName, List<Metric> metrics) {
        this(codeName, lineOfBusiness, status, ragStatus, milestonePhase, milestoneDeadline,
                summaryType, summaryMessage, leadEPMName, projectDRIName, metrics, List.of(), null);
    }

    /** Preserve source compatibility for callers without project size. */
    public ReportContent(String codeName, String lineOfBusiness, String status, String ragStatus,
                         String milestonePhase, LocalDate milestoneDeadline, String summaryType,
                         String summaryMessage, String leadEPMName, String projectDRIName,
                         List<Metric> metrics, List<ReportAsset> assets) {
        this(codeName, lineOfBusiness, status, ragStatus, milestonePhase, milestoneDeadline,
                summaryType, summaryMessage, leadEPMName, projectDRIName, metrics, assets, null);
    }

    public ReportContent withProjectSize(String size) {
        return new ReportContent(codeName, lineOfBusiness, status, ragStatus, milestonePhase,
                milestoneDeadline, summaryType, summaryMessage, leadEPMName, projectDRIName,
                metrics, assets, size);
    }

    public record Metric(UUID id, String name, double currentValue, Double targetValue,
                         String comparison, String unit, String severity) {
        public Metric {
            require(id != null, "Metric ID required");
            require(name != null && !name.isBlank() && name.length() <= 200, "Invalid metric name");
            require(Double.isFinite(currentValue), "Invalid metric value");
            require((targetValue == null) == (comparison == null), "Target and comparison must be paired");
            require(targetValue == null || Double.isFinite(targetValue), "Invalid target value");
            require(comparison == null || choice(comparison, "lt", "lte", "gt", "gte", "eq"), "Invalid comparison");
            require(unit == null || unit.length() <= 50, "Invalid unit");
            require(severity == null || choice(severity, "P0", "P1", "P2", "P3", "Info"), "Invalid severity");
        }
    }

    private static boolean choice(String value, String... options) {
        return value != null && Set.of(options).contains(value);
    }

    private static void require(boolean valid, String message) {
        if (!valid) throw new ReportException(ReportException.Code.INVALID_REPORT, message);
    }
}
