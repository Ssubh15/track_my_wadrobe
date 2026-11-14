import SwiftUI

/// Explains what stays on the device. Export and delete are shown as in the design
/// but are not wired up yet, so they are disabled and marked "Coming soon".
struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("What stays on your phone")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    point("iphone", "Every photo is processed on this device. Nothing is uploaded.")
                    point("person.crop.circle.badge.xmark", "Faces and bodies are never saved in your garment images.")
                    point("checkmark", "You review every item before it is saved.")
                }
                .padding(.vertical, 6)
            }

            Section {
                LabeledContent("Export my data", value: "Coming soon")
                    .foregroundStyle(Theme.Colors.muted)
            } header: {
                Text("Your data")
            } footer: {
                Text("Item details and images, saved as a zip you can share or keep.")
            }

            Section {
                Text("Delete all data")
                    .foregroundStyle(Theme.Colors.muted)
            } footer: {
                Text("Permanently removes every item and image from this phone. Not available yet.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .navigationTitle("Privacy and your data")
        .navigationBarTitleDisplayMode(.large)
    }

    private func point(_ systemImage: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text).font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
