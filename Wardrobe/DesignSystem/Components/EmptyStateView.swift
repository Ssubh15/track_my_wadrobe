import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tshirt"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityHidden(true)
            Text(title).font(Theme.TypeStyles.section).accessibilityAddTraits(.isHeader)
            Text(message).font(Theme.TypeStyles.body).foregroundStyle(Theme.Colors.muted).multilineTextAlignment(.center)
            if let actionTitle, let action { PrimaryButton(title: actionTitle, systemImage: "plus", action: action) }
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity)
    }
}
