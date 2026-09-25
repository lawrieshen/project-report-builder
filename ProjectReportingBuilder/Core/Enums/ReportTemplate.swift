//
//  ReportTemplate.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

enum ReportTemplate: String, Codable, CaseIterable, Identifiable {
    case executive
    case technical
    case product
    case status

    var id: Self { self }

    var displayName: String {
        switch self {
        case .executive: "Executive"
        case .technical: "Technical"
        case .product: "Product"
        case .status: "Status"
        }
    }

    var description: String {
        switch self {
        case .executive:
            "High-level executive summary"
        case .technical:
            "Detailed engineering metrics and technical information"
        case .product:
            "Product-focused visual layout"
        case .status:
            "Compact project status update"
        }
    }
}
