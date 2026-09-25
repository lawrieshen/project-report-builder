import Foundation

extension ProjectReport {
    /// Copy report values with fresh identities; storage copies the referenced files separately.
    nonisolated func duplicated(codeName: String) -> ProjectReport {
        let copiedCard = card.map { original in
            SnippetCard(id: UUID(), health: original.health, summary: original.summary,
                accountability: Accountability(
                    leadEPM: original.accountability.leadEPM.map { Person(id: UUID(), name: $0.name, role: $0.role) },
                    projectDRI: original.accountability.projectDRI.map { Person(id: UUID(), name: $0.name, role: $0.role) }),
                assets: original.assets.map { asset in
                    let id = UUID()
                    let suffix = (asset.localReference as NSString).pathExtension
                    return ImageAsset(id: id, fileName: asset.fileName,
                        localReference: id.uuidString + "." + suffix, altText: asset.altText)
                },
                metrics: original.metrics.map { EngineeringMetric(id: UUID(), name: $0.name,
                    currentValue: $0.currentValue, target: $0.target, unit: $0.unit, severity: $0.severity) })
        }
        return ProjectReport(id: UUID(), codeName: codeName, lineOfBusiness: lineOfBusiness,
                             status: status, card: copiedCard, createdAt: .now, updatedAt: .now)
    }
}
