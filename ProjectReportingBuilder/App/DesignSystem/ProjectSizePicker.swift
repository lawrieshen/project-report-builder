import SwiftUI

/// Select a scope without assigning a default to existing projects.
struct ProjectSizePicker: View {
    @Binding var selection: ProjectSize?

    var body: some View {
        Picker("Project Size", selection: $selection) {
            Text("Not set").tag(nil as ProjectSize?)
            ForEach(ProjectSize.allCases, id: \.self) { size in
                Text(size.displayName).tag(Optional(size))
            }
        }
    }
}
