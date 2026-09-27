import SwiftUI

/// Show deterministic requirements and human review without implying a cloud save.
struct GoalProgressView: View {
    let evaluation: GoalEvaluation
    @Binding var reviewed: Set<GoalCriterion.ID>
    let reviewLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(evaluation.isConfirmed ? "Goal confirmed — not a save receipt" : "Goal checklist")
                .font(.headline)
            ForEach(evaluation.criteria) { criterion in
                criterionRow(criterion)
            }
        }
    }

    @ViewBuilder private func criterionRow(_ criterion: GoalCriterion) -> some View {
        if criterion.status == .needsReview || criterion.evidence == .userConfirmation {
            Toggle(criterion.explanation, isOn: Binding(
                get: { reviewed.contains(criterion.id) },
                set: { isReviewed in
                    if isReviewed { reviewed.insert(criterion.id) }
                    else { reviewed.remove(criterion.id) }
                }
            ))
            .disabled(reviewLocked)
            .accessibilityValue(reviewed.contains(criterion.id) ? "Reviewed" : "Needs review")
        } else {
            Label(criterion.explanation,
                  systemImage: criterion.status == .satisfied ? "checkmark.circle" : "exclamationmark.circle")
                .accessibilityValue(criterion.status == .satisfied ? "Satisfied" : "Missing")
        }
    }
}
