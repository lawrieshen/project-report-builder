import SwiftUI
import Testing
@testable import Project_Report_Builder

struct AppAppearanceTests {
    @Test func explicitAppearanceAndSystemFallback() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }
}
