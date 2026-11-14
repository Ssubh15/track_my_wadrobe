import SwiftUI

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "Insights will appear here",
                message: "As your wardrobe grows, you’ll find a snapshot of your collection here.",
                systemImage: "chart.bar"
            )
            .padding(.horizontal, Theme.Spacing.medium)
            .background(Theme.Colors.canvas)
            .navigationTitle("Insights")
        }
    }
}

#Preview {
    InsightsView().environment(DIContainer())
}
