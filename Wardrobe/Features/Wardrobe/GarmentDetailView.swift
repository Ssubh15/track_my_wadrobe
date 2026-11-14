import SwiftUI

struct GarmentDetailView: View {
    let item: GarmentItem
    @Bindable var viewModel: WardrobeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                    GarmentCard(title: item.subtype ?? item.category.displayName, subtitle: item.brand, systemImage: item.category.systemImage)
                    HStack { Label(item.category.displayName, systemImage: item.category.systemImage); Spacer(); Button { viewModel.toggleFavorite(item) } label: { Image(systemName: item.isFavorite ? "heart.fill" : "heart") }.accessibilityLabel(item.isFavorite ? "Remove favorite" : "Add favorite") }.foregroundStyle(Theme.Colors.accent)
                    detailRow("Color", item.primaryColorHex); detailRow("Season", item.season); detailRow("Material", item.material); detailRow("Size", item.size); detailRow("Notes", item.notes)
                    VStack(spacing: 12) { Button("Duplicate") { viewModel.duplicate(item); dismiss() }.buttonStyle(.bordered); Button(item.isArchived ? "Unarchive" : "Archive") { viewModel.toggleArchive(item); dismiss() }.buttonStyle(.bordered); Button("Delete", role: .destructive) { viewModel.delete(item); dismiss() }.buttonStyle(.bordered) }
                }.padding()
            }.background(Theme.Colors.canvas).navigationTitle("Item details").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { isEditing = true } } }
        }.sheet(isPresented: $isEditing) { EditGarmentView(item: item, viewModel: viewModel) }
    }
    @ViewBuilder private func detailRow(_ title: String, _ value: String?) -> some View { if let value, !value.isEmpty { LabeledContent(title, value: value) } }
}

struct EditGarmentView: View {
    let item: GarmentItem
    @Bindable var viewModel: WardrobeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var brand: String
    @State private var season: String
    @State private var notes: String

    init(item: GarmentItem, viewModel: WardrobeViewModel) { self.item = item; self.viewModel = viewModel; _name = State(initialValue: item.subtype ?? ""); _brand = State(initialValue: item.brand ?? ""); _season = State(initialValue: item.season ?? ""); _notes = State(initialValue: item.notes ?? "") }
    var body: some View { NavigationStack { Form { Section("Details") { TextField("Name", text: $name); TextField("Brand", text: $brand); TextField("Season", text: $season); TextField("Notes", text: $notes, axis: .vertical) } }.navigationTitle("Edit item").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { item.subtype = name.isEmpty ? nil : name; item.brand = brand.isEmpty ? nil : brand; item.season = season.isEmpty ? nil : season; item.notes = notes.isEmpty ? nil : notes; viewModel.saveChanges(item); dismiss() } }; ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } } }
}

#Preview { GarmentDetailView(item: GarmentItem(category: .jacket, subtype: "Overshirt", cutoutImagePath: "placeholder"), viewModel: WardrobeViewModel(repository: InMemoryWardrobeRepository())) }

#Preview("Filter sheet") { WardrobeFilterSheet(viewModel: WardrobeViewModel(repository: InMemoryWardrobeRepository())) }
#Preview("Favorites") { NavigationStack { FavoritesView(repository: InMemoryWardrobeRepository()) } }
#Preview("Archive") { NavigationStack { ArchiveView(repository: InMemoryWardrobeRepository()) } }
