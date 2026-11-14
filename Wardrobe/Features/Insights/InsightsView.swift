import SwiftUI

struct InsightsView: View {
    @State private var viewModel: InsightsViewModel

    init(repository: any WardrobeRepository) {
        _viewModel = State(initialValue: InsightsViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.totalItems == 0 {
                    EmptyStateView(
                        title: "Insights will appear here",
                        message: "As your wardrobe grows, you’ll find a snapshot of your collection here.",
                        systemImage: "chart.bar"
                    )
                    .padding(.horizontal, Theme.Spacing.medium)
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.medium) {
                            summaryCard
                            chartCard(title: "By category", rows: viewModel.categoryRows)
                            chartCard(title: "By colour", rows: viewModel.colorRows)
                            chartCard(title: "By brand", rows: viewModel.brandRows)
                        }
                        .padding(Theme.Spacing.medium)
                    }
                }
            }
            .background(Theme.Colors.canvas)
            .navigationTitle("Insights")
            .onAppear { viewModel.reload() }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your wardrobe")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.muted)
            Text(viewModel.summary)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.medium)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func chartCard(title: String, rows: [InsightRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(rows) { row in
                    barRow(row, maxCount: rows.first?.count ?? 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.medium)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func barRow(_ row: InsightRow, maxCount: Int) -> some View {
        HStack(spacing: 10) {
            Text(row.name)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            Capsule()
                .fill(Color(uiColor: .systemGray5))
                .frame(height: 14)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Theme.Colors.accent)
                            .frame(width: proxy.size.width * CGFloat(row.count) / CGFloat(max(maxCount, 1)))
                    }
                }
            Text("\(row.count)")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.muted)
                .frame(minWidth: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.count) \(row.count == 1 ? "item" : "items")")
    }
}

#Preview {
    InsightsView(repository: InMemoryWardrobeRepository())
}
