/// Offer hardware build stages reflected in Apple's public engineering roles.
nonisolated enum MilestonePhase: String, CaseIterable {
    case prototype = "Prototype"
    case evt = "EVT"
    case dvt = "DVT"
    case pvt = "PVT"
    case massProduction = "Mass Production"

    static var options: [String] { allCases.map(\.rawValue) }
}
