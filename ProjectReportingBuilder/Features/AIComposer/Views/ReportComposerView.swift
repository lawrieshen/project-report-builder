import SwiftUI

/// Review an in-memory AI candidate before returning changes to the normal editor.
struct ReportComposerView: View {
    @ObservedObject var model: ReportComposerViewModel
    let loadImage: (ImageAsset) async throws -> Data
    let onApply: (Bool) -> Void
    let onUndo: () -> Void
    let onRebase: () -> Void
    let onClose: () -> Void
    @State private var input = ""
    @State private var audience: ReportCompositionGoal.Audience = .leadership
    @State private var purpose: ReportCompositionGoal.Purpose = .statusUpdate
    @State private var language: ReportCompositionGoal.Language = .english
    @State private var sections: Set<ReportCompositionGoal.Section> = [.summary]
    @State private var goalAccepted = false
    @State private var reviewed: Set<GoalCriterion.ID> = []
    @State private var confirmClose = false
    @State private var confirmIncomplete = false

    private var generating: Bool {
        if case .generating = model.graph.state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        goalForm
                        goalProgress
                        conversation
                        inputArea
                        changes
                        candidateEditor
                    }.padding(20)
                }.frame(minWidth: 340, idealWidth: 420)
                LivePreviewView(model: ReportPreviewModel(draft: model.candidate), loadImage: loadImage,
                                onDismiss: requestClose, maximumHeight: 700)
                    .frame(minWidth: 380)
            }
            Divider()
            actions
        }
        .frame(minWidth: 850, minHeight: 650)
        .onAppear {
            let goal = model.graph.version.goal
            audience = goal.audience
            purpose = goal.purpose
            language = goal.language
            sections = Set(goal.requiredSections)
        }
        .onChange(of: model.graph.version) { _, _ in reviewed = [] }
        .onDisappear { model.close() }
        .confirmationDialog("Discard this composition session?", isPresented: $confirmClose) {
            Button("Discard and close", role: .destructive) { model.close(); onClose() }
            Button("Keep working", role: .cancel) { }
        } message: {
            Text("Unapplied changes and chat will be discarded. Cancelling does not guarantee an AI request stops processing or charging.")
        }
        .confirmationDialog("Apply with an unfinished goal?", isPresented: $confirmIncomplete) {
            Button("Apply as ordinary edits") { onApply(true) }
            Button("Continue reviewing", role: .cancel) { }
        } message: {
            Text("These changes enter the editor and its normal autosave flow. The composition goal remains unconfirmed.")
        }
    }

    @ViewBuilder private var header: some View {
        HStack {
            Label("AI Report Composer", systemImage: "sparkles").font(.title2)
            Spacer()
            Button("Close", action: requestClose)
        }.padding()
        Text("Your notes, conversation and report text are sent to Gemini. Images are not sent. Changes stay here until you apply them.")
            .font(.callout).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom)
    }

    @ViewBuilder private var goalForm: some View {
        GroupBox("Report goal") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Audience", selection: $audience) {
                    ForEach(ReportCompositionGoal.Audience.allCases, id: \.self) { Text(label($0.rawValue)).tag($0) }
                }
                Picker("Purpose", selection: $purpose) {
                    ForEach(ReportCompositionGoal.Purpose.allCases, id: \.self) { Text(label($0.rawValue)).tag($0) }
                }
                Picker("Language", selection: $language) {
                    ForEach(ReportCompositionGoal.Language.allCases, id: \.self) { Text(label($0.rawValue)).tag($0) }
                }
                ForEach(ReportCompositionGoal.Section.allCases, id: \.self) { section in
                    Toggle(label(section.rawValue), isOn: Binding(get: { sections.contains(section) }, set: {
                        if $0 { sections.insert(section) } else { sections.remove(section) }
                    }))
                }
                Button(goalAccepted ? "Goal confirmed" : "Confirm goal") {
                    let old = model.graph.version.goal
                    model.changeGoal(ReportCompositionGoal(id: old.id, revision: old.revision + 1,
                        audience: audience, purpose: purpose, language: language,
                        requiredSections: ReportCompositionGoal.Section.allCases.filter { sections.contains($0) }))
                    goalAccepted = true
                }.disabled(goalAccepted || model.graph.state == .stale)
            }.padding(8)
        }
        .onChange(of: audience) { _, _ in goalAccepted = false }
        .onChange(of: purpose) { _, _ in goalAccepted = false }
        .onChange(of: language) { _, _ in goalAccepted = false }
        .onChange(of: sections) { _, _ in goalAccepted = false }
    }

    @ViewBuilder private var goalProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.evaluation.isConfirmed ? "Goal confirmed — not a save receipt" : "Goal checklist").font(.headline)
            ForEach(model.evaluation.criteria) { criterion in
                if criterion.status == .needsReview || criterion.evidence == .userConfirmation {
                    Toggle(criterion.explanation, isOn: Binding(get: { reviewed.contains(criterion.id) }, set: {
                        if $0 { reviewed.insert(criterion.id) } else { reviewed.remove(criterion.id) }
                    })).disabled(model.graph.state == .confirmed)
                } else {
                    Label(criterion.explanation, systemImage: criterion.status == .satisfied ? "checkmark.circle" : "circle")
                }
            }
            if model.graph.state == .confirmed {
                Button("Review again") { model.reviewAgain() }
            } else {
                Button("Confirm reviewed candidate") { model.confirm(reviewedCriteria: reviewed) }
                    .disabled(!goalAccepted || !model.evaluation.readyForReview || model.graph.state != .reviewing)
            }
        }
    }

    @ViewBuilder private var conversation: some View {
        ForEach(Array(model.messages.enumerated()), id: \.offset) { _, message in
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "AI").font(.caption.bold())
                Text(message.text).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        if let proposal = model.proposal {
            ForEach(Array(proposal.clarifyingQuestions.enumerated()), id: \.offset) { _, question in
                Label(question, systemImage: "questionmark.circle")
            }
            ForEach(Array(proposal.warnings.enumerated()), id: \.offset) { _, warning in
                Label(warning, systemImage: "exclamationmark.triangle")
            }
        }
        if let error = model.errorMessage { Text(error).foregroundStyle(.secondary) }
    }

    @ViewBuilder private var inputArea: some View {
        TextEditor(text: $input).font(.system(size: 13)).frame(minHeight: 90)
            .padding(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
            .accessibilityLabel("Message to AI report composer")
        HStack {
            if generating {
                ProgressView().controlSize(.small)
                Button("Cancel request") { model.cancel() }
            } else {
                Button("Send") {
                    let text = input
                    let previousCount = model.messages.count
                    Task {
                        await model.send(text)
                        if model.messages.count > previousCount && input == text { input = "" }
                    }
                }.keyboardShortcut(.return, modifiers: .command)
                    .disabled(!goalAccepted || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.graph.state == .stale)
            }
            if let remaining = model.remainingDailyRequests { Text("\(remaining) attempts left at last request").font(.caption) }
        }
    }

    @ViewBuilder private var changes: some View {
        if let edits = model.edits {
            Text("Select changes").font(.headline)
            ForEach(CompositionTextChange.Field.allCases.filter { edits.fields.contains($0) }, id: \.self) { field in
                Text("Before: " + fieldValue(field, in: edits.base)).font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("After: " + fieldValue(field, in: edits.proposed)).font(.callout).textSelection(.enabled)
                Toggle(label(field.rawValue), isOn: Binding(get: { model.selectedFields.contains(field) }, set: {
                    var fields = model.selectedFields
                    if $0 { fields.insert(field) } else { fields.remove(field) }
                    model.select(fields: fields, metrics: model.selectedMetrics)
                }))
            }
            ForEach(Array(edits.metricIDs).sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                Text("Before: " + metricValue(edits.base.metrics.first { $0.id == id }))
                    .font(.caption).foregroundStyle(.secondary)
                Text("After: " + metricValue(edits.proposed.metrics.first { $0.id == id })).font(.callout)
                Toggle(edits.proposed.metrics.first { $0.id == id }?.name ?? "Remove metric", isOn: Binding(
                    get: { model.selectedMetrics.contains(id) }, set: {
                        var metrics = model.selectedMetrics
                        if $0 { metrics.insert(id) } else { metrics.remove(id) }
                        model.select(fields: model.selectedFields, metrics: metrics)
                    }))
            }
        }
    }

    @ViewBuilder private var candidateEditor: some View {
        DisclosureGroup("Adjust candidate text") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Edits stay in this candidate until Apply. Editing replaces the current AI change selection and requires a new review.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Code name", text: candidateText(\.codeName))
                TextField("Product line", text: candidateText(\.lineOfBusiness))
                TextField("Milestone phase", text: candidateText(\.milestonePhase))
                TextField("Lead EPM", text: candidateText(\.leadEPMName))
                TextField("Project DRI", text: candidateText(\.projectDRIName))
                Text("Executive summary").font(.caption)
                TextEditor(text: candidateText(\.summaryMessage))
                    .font(.system(size: 13)).frame(minHeight: 110).padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                    .accessibilityLabel("Candidate executive summary")
            }.textFieldStyle(.roundedBorder).padding(.top, 8)
        }.disabled(generating || model.graph.state == .stale || model.graph.state == .closed)
    }

    private func candidateText(_ keyPath: WritableKeyPath<ReportEditorDraft, String>) -> Binding<String> {
        Binding(get: { model.candidate[keyPath: keyPath] }, set: { value in
            var draft = model.candidate
            draft[keyPath: keyPath] = value
            model.editCandidate(draft)
        })
    }

    private func metricValue(_ metric: EngineeringMetricDraft?) -> String {
        guard let metric else { return "Not present" }
        var description = "\(metric.name): \(metric.currentValueText) \(metric.unit)"
        if metric.hasTarget { description += " — target \(metric.comparison.rawValue) \(metric.targetValueText)" }
        if let severity = metric.severity { description += " (\(severity.rawValue))" }
        return description
    }

    @ViewBuilder private var actions: some View {
        HStack {
            Button("Undo AI changes", action: onUndo).disabled(!model.canUndo || generating)
            if model.graph.state == .stale {
                Text("The editor changed. This candidate is out of date.")
                Button("Use latest draft", action: onRebase)
            }
            Spacer()
            Text("Apply uses normal autosave.").font(.caption).foregroundStyle(.secondary)
            Button(model.graph.state == .confirmed ? "Apply changes" : "Apply unfinished edits") {
                if model.graph.state == .confirmed { onApply(false) } else { confirmIncomplete = true }
            }.buttonStyle(.borderedProminent)
                .disabled(!goalAccepted || !model.hasUnappliedChanges || ![.reviewing, .confirmed].contains(model.graph.state))
        }.padding()
    }

    private func requestClose() {
        if model.hasUnappliedChanges || !model.messages.isEmpty || generating { confirmClose = true }
        else { model.close(); onClose() }
    }

    private func fieldValue(_ field: CompositionTextChange.Field, in draft: ReportEditorDraft) -> String {
        switch field {
        case .codeName: return draft.codeName
        case .lineOfBusiness: return draft.lineOfBusiness
        case .ragStatus: return draft.ragStatus?.rawValue ?? "Not set"
        case .milestonePhase: return draft.milestonePhase
        case .milestoneDeadline: return CompositionDraft(draft: draft).milestoneDeadline ?? "Not set"
        case .summaryType: return draft.summaryType.rawValue
        case .summaryMessage: return draft.summaryMessage
        case .leadEPMName: return draft.leadEPMName
        case .projectDRIName: return draft.projectDRIName
        }
    }

    private func label(_ value: String) -> String {
        value.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}

#if DEBUG
@MainActor
private struct ComposerPreview: View {
    @StateObject private var model: ReportComposerViewModel

    init() {
        let report = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Mac", status: .active,
                                   createdAt: .now, updatedAt: .now)
        _model = StateObject(wrappedValue: ReportComposerViewModel(draft: ReportEditorDraft(project: report),
            reportID: report.id, accountSessionID: UUID(), service: ComposerPreviewService()))
    }

    var body: some View {
        ReportComposerView(model: model, loadImage: { _ in throw CompositionEditError.invalidProposal },
            onApply: { _ in }, onUndo: {}, onRebase: { model.rebase(on: model.base) }, onClose: {})
            .frame(width: 1100, height: 800)
    }
}

private struct ComposerPreviewService: ReportComposing {
    func compose(_ request: CompositionRequest) async throws -> CompositionResponse {
        CompositionResponse(requestID: request.requestID, baseDraftVersion: request.baseDraftVersion,
            candidateVersion: request.candidateVersion, goalID: request.goal.id, goalRevision: request.goal.revision,
            proposal: CompositionProposal(assistantMessage: "Here is a sample candidate for review.",
                clarifyingQuestions: [], proposedChanges: [.init(field: .summaryMessage, operation: .set,
                    value: "The team is preparing the next milestone. Confirm dates and owners before sharing.")],
                metricChanges: [], warnings: ["Preview data only; no AI request was sent."], semanticFindings: []),
            remainingDailyRequests: 19)
    }
}

#Preview("AI Composer — offline") { ComposerPreview() }
#endif
