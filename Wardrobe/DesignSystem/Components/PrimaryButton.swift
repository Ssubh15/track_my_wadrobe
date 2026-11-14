import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title).fontWeight(.semibold)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.medium)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.Colors.accent)
    }
}
