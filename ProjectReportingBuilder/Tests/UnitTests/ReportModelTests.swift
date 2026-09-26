import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ReportModelTests {
    @Test func newReportStartsWithoutACard() {
        let report = ProjectReport(
            id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
            status: .draft, createdAt: .now, updatedAt: .now
        )

        #expect(report.card == nil)
    }

    @Test func reportCodingPreservesIdentityStatusAndDates() throws {
        let report = ProjectReport(
            id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
            status: .active,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ProjectReport.self, from: data)

        #expect(decoded == report)
    }

    @Test func legacyTemplateFieldIsIgnoredAndNotReencoded() throws {
        let report = ProjectReport(
            id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
            status: .active, createdAt: .distantPast, updatedAt: .distantPast
        )
        var legacy = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(report)) as? [String: Any])
        // Historical template choices must not prevent loading the structured report.
        for value in ["executive", "technical", "product", "status", "unknown-layout"] {
            legacy["template"] = value
            let data = try JSONSerialization.data(withJSONObject: legacy)
            let decoded = try JSONDecoder().decode(ProjectReport.self, from: data)
            #expect(decoded == report)
            let encoded = try #require(JSONSerialization.jsonObject(
                with: JSONEncoder().encode(decoded)) as? [String: Any])
            #expect(encoded["template"] == nil)
        }
    }

    @Test func personCodingPreservesIdentityAndRole() throws {
        let person = Person(id: UUID(), name: "Jane Smith", role: "Lead EPM")
        let data = try JSONEncoder().encode(person)
        let decoded = try JSONDecoder().decode(Person.self, from: data)

        #expect(decoded == person)
    }
}
