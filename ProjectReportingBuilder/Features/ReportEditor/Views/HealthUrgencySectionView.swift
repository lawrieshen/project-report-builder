import SwiftUI

struct HealthUrgencySectionView: View {
    @Binding var draft: ReportEditorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text("Health & Urgency").font(.title3.bold())
            Picker("Health", selection: $draft.ragStatus) {
                Text("Not assessed").tag(nil as RAGStatus?)
                ForEach(RAGStatus.allCases, id: \.self) { status in
                    Label(status.displayName, systemImage: "circle.fill")
                        .foregroundStyle(status.color)
                        .tag(Optional(status))
                }
            }
            TextField("Milestone Phase", text: $draft.milestonePhase)
                .accessibilityIdentifier("reportMilestonePhase")
            Toggle("Set milestone deadline", isOn: Binding(
                get: { draft.milestoneDeadline != nil },
                set: { draft.milestoneDeadline = $0 ? Date() : nil }
            ))
            if let deadline = Binding($draft.milestoneDeadline) {
                DatePicker("Deadline", selection: deadline, displayedComponents: .date)
                Text(deadlineDescription(deadline.wrappedValue))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message = draft.milestoneError {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func deadlineDescription(_ deadline: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now),
                                           to: calendar.startOfDay(for: deadline)).day ?? 0
        if days < 0 { return "\(-days) days overdue" }
        if days == 0 { return "Due today" }
        return "\(days) days remaining"
    }
}
