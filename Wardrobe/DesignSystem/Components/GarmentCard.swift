import SwiftUI

struct GarmentCard: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String = "tshirt"
    var image: UIImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Theme.Colors.surface)
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().padding(12)
                } else {
                    Image(systemName: systemImage).font(.system(size: 38)).foregroundStyle(Theme.Colors.accent)
                }
            }
            .aspectRatio(0.82, contentMode: .fit)
            .accessibilityHidden(true)
            Text(title).font(.headline).lineLimit(1)
            if let subtitle { Text(subtitle).font(Theme.TypeStyles.caption).foregroundStyle(Theme.Colors.muted).lineLimit(1) }
        }
        .accessibilityElement(children: .combine)
    }
}
