import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ProjectBrowserViewModelTests {
    private func project(_ name: String, _ business: String,
                         _ status: ReportStatus, _ timestamp: Double) -> ProjectReport {
        ProjectReport(id: UUID(), codeName: name, lineOfBusiness: business,
                      status: status, createdAt: Date(timeIntervalSince1970: 0),
                      updatedAt: Date(timeIntervalSince1970: timestamp))
    }

    @Test func searchFiltersSortWithoutChangingSource() async {
        let titan = project("Titan", "iOS / Camera", .onTrack, 1)
        let atlas = project("Atlas", "iOS / Camera", .blocked, 3)
        let nova = project("Nova", "Services", .draft, 2)
        let source = [titan, atlas, nova]
        let model = ProjectBrowserViewModel(repository: InMemoryProjectRepository(projects: source))
        await model.loadProjects()
        #expect(model.projects == source)
        #expect(model.visibleProjects == [atlas, nova, titan])
        #expect(!model.isLoading)

        model.searchText = "tItAn"
        #expect(model.visibleProjects == [titan])
        model.searchText = "CAMERA"
        #expect(model.visibleProjects == [atlas, titan])
        model.filter.statuses = [.onTrack]
        #expect(model.visibleProjects == [titan])
        model.filter.linesOfBusiness = ["Services"]
        #expect(model.visibleProjects.isEmpty)
        model.clearFilters()
        #expect(model.visibleProjects == [atlas, titan])
        model.searchText = ""
        model.filter.linesOfBusiness = ["Services"]
        #expect(model.visibleProjects == [nova])
        model.clearFilters()
        model.filter.statuses = [.draft, .blocked]
        #expect(model.visibleProjects == [atlas, nova])
        #expect(model.projects == source)
        #expect(model.linesOfBusiness == ["Services", "iOS / Camera"])
    }

    @Test func createAndDeleteUpdateRepositoryAndSelection() async throws {
        let repository = InMemoryProjectRepository()
        let model = ProjectBrowserViewModel(repository: repository)
        model.searchText = "no match"
        model.filter.statuses = [.blocked]
        let created = await model.createProject(codeName: " Titan ",
                                                lineOfBusiness: " Camera ", status: .draft)
        #expect(created)
        let saved = try #require(model.projects.first)
        #expect(saved.codeName == "Titan")
        #expect(saved.lineOfBusiness == "Camera")
        #expect(saved.status == .draft)
        #expect(model.visibleProjects == [saved])
        #expect(try await repository.fetchProjects() == [saved])
        model.selectProject(saved)
        #expect(model.selectedProject == saved)
        await model.deleteProject(saved)
        #expect(model.projects.isEmpty)
        #expect(model.selectedProject == nil)
        #expect(try await repository.fetchProjects().isEmpty)
    }

    @Test func invalidCreationDoesNotSave() async throws {
        let repository = InMemoryProjectRepository()
        let model = ProjectBrowserViewModel(repository: repository)
        let created = await model.createProject(codeName: "  ", lineOfBusiness: "Camera", status: .draft)
        #expect(!created)
        #expect(model.actionErrorMessage != nil)
        #expect(try await repository.fetchProjects().isEmpty)
    }

    @Test func repositoryFailuresPreserveDataAndAllowRetry() async {
        let existing = project("Titan", "Camera", .draft, 1)
        let repository = FailingProjectRepository(projects: [existing])
        let model = ProjectBrowserViewModel(repository: repository)
        await model.loadProjects()
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)

        repository.shouldFail = false
        await model.loadProjects()
        #expect(model.errorMessage == nil)
        #expect(model.projects == [existing])

        repository.shouldFail = true
        await model.deleteProject(existing)
        #expect(model.projects == [existing])
        #expect(model.actionErrorMessage != nil)
        let created = await model.createProject(codeName: "New", lineOfBusiness: "Services", status: .draft)
        #expect(!created)
        #expect(model.projects == [existing])
        #expect(!model.isSaving)
    }
}

@MainActor
private final class FailingProjectRepository: ProjectRepository {
    var shouldFail = true
    var projects: [ProjectReport]

    init(projects: [ProjectReport]) { self.projects = projects }

    enum Failure: Error { case unavailable }

    func fetchProjects() async throws -> [ProjectReport] {
        if shouldFail { throw Failure.unavailable }
        return projects
    }

    func save(_ project: ProjectReport) async throws {
        if shouldFail { throw Failure.unavailable }
        projects.append(project)
    }

    func delete(_ project: ProjectReport) async throws {
        if shouldFail { throw Failure.unavailable }
        projects.removeAll { $0.id == project.id }
    }
}
