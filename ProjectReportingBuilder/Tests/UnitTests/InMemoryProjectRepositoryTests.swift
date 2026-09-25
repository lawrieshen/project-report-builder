import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct InMemoryProjectRepositoryTests {
    @Test func saveInsertsAndUpdatesByIdentity() async throws {
        let repository = InMemoryProjectRepository()
        var project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        try await repository.save(project)
        project.codeName = "Titan Updated"
        try await repository.save(project)
        let projects = try await repository.fetchProjects()
        #expect(projects == [project])
    }

    @Test func lookupFindsOnlyTheRequestedProject() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let repository = InMemoryProjectRepository(projects: [project])
        #expect(try await repository.fetchProject(id: project.id) == project)
        #expect(try await repository.fetchProject(id: UUID()) == nil)
        try await repository.delete(project)
        #expect(try await repository.fetchProject(id: project.id) == nil)
    }

    @Test func deletingOneProjectPreservesTheOthers() async throws {
        let first = ProjectReport(id: UUID(), codeName: "One", lineOfBusiness: "Camera",
                                  status: .draft, createdAt: .now, updatedAt: .now)
        let second = ProjectReport(id: UUID(), codeName: "Two", lineOfBusiness: "Services",
                               status: .active, createdAt: .now, updatedAt: .now)
        let repository = InMemoryProjectRepository(projects: [first, second])
        try await repository.delete(first)
        try await repository.delete(first)
        #expect(try await repository.fetchProjects() == [second])
    }
}
