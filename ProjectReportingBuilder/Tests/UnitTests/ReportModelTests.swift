import Foundation
import Testing
@testable import Project_Report_Builder

struct ReportModelTests {
    @Test func newReportDefaultsToExecutiveTemplate() {
        let report = ProjectReport(
            id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
            status: .draft, createdAt: .now, updatedAt: .now
        )

        #expect(report.template == .executive)
        #expect(report.card == nil)
    }

    @Test func reportCodingPreservesTemplateAndDates() throws {
        let report = ProjectReport(
            id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
            status: .active, template: .technical,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ProjectReport.self, from: data)

        #expect(decoded == report)
    }

    @Test func personCodingPreservesIdentityAndRole() throws {
        let person = Person(id: UUID(), name: "Jane Smith", role: "Lead EPM")
        let data = try JSONEncoder().encode(person)
        let decoded = try JSONDecoder().decode(Person.self, from: data)

        #expect(decoded == person)
    }
}
