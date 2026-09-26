import SwiftUI

/// Offer the supported product categories.
struct LineOfBusinessPicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("Line of Business", selection: Binding(
            get: { LineOfBusiness.options.contains(selection) ? selection : "" },
            set: { selection = $0 }
        )) {
            Text(selection.isEmpty ? "Select a product line" : "Please select a product line again").tag("")
            ForEach(LineOfBusiness.options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}
