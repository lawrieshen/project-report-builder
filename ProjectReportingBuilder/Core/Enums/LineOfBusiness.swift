/// Offer product categories from Apple's public financial reporting.
nonisolated enum LineOfBusiness: String, CaseIterable {
    case iPhone = "iPhone"
    case mac = "Mac"
    case iPad = "iPad"
    case wearablesHomeAccessories = "Wearables, Home and Accessories"
    case services = "Services"

    static var options: [String] { allCases.map(\.rawValue) }
}
