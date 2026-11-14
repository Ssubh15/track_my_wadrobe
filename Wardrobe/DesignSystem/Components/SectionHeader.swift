import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
            Text(title).font(Theme.TypeStyles.section).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(Theme.TypeStyles.caption).foregroundStyle(Theme.Colors.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
