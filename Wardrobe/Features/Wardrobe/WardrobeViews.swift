import SwiftUI

struct WardrobeHomeView: View {
    let repository: any WardrobeRepository
    @State private var viewModel: WardrobeViewModel
    @State private var isFilterPresented = false

    init(repository: any WardrobeRepository, imageStore: (any ImageStore)? = nil) { self.repository = repository; _viewModel = State(initialValue: WardrobeViewModel(repository: repository, imageStore: imageStore)) }

    var body: some View {
        WardrobeCollectionView(viewModel: viewModel, isFilterPresented: $isFilterPresented)
            .navigationTitle("Wardrobe")
            .onAppear { viewModel.reload() }
            .sheet(isPresented: $isFilterPresented) { WardrobeFilterSheet(viewModel: viewModel) }
    }
}

struct FavoritesView: View {
    let repository: any WardrobeRepository
    @State private var viewModel: WardrobeViewModel
    init(repository: any WardrobeRepository) { self.repository = repository; let model = WardrobeViewModel(repository: repository); model.section = .favorites; _viewModel = State(initialValue: model) }
    var body: some View { WardrobeCollectionView(viewModel: viewModel).navigationTitle("Favorites") }
}

struct ArchiveView: View {
    let repository: any WardrobeRepository
    @State private var viewModel: WardrobeViewModel
    init(repository: any WardrobeRepository) { self.repository = repository; let model = WardrobeViewModel(repository: repository); model.section = .archived; _viewModel = State(initialValue: model) }
    var body: some View { WardrobeCollectionView(viewModel: viewModel).navigationTitle("Archive") }
}

struct WardrobeCollectionView: View {
    @Bindable var viewModel: WardrobeViewModel
    @Binding var isFilterPresented: Bool
    @State private var selectedItem: GarmentItem?
    init(viewModel: WardrobeViewModel, isFilterPresented: Binding<Bool> = .constant(false)) { _viewModel = Bindable(wrappedValue: viewModel); _isFilterPresented = isFilterPresented }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.section == .all { categoryTabs }
            HStack {
                Label("Search wardrobe", systemImage: "magnifyingglass")
                    .foregroundStyle(Theme.Colors.muted)
                TextField("", text: $viewModel.searchText).textFieldStyle(.plain).accessibilityLabel("Search wardrobe")
                Button { isFilterPresented = true } label: { Image(systemName: viewModel.filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }.accessibilityLabel("Filter and sort")
            }.padding(12).background(Theme.Colors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).padding()
            if viewModel.filteredItems.isEmpty {
                EmptyStateView(title: viewModel.section == .archived ? "Archive is empty" : "Your wardrobe starts here", message: viewModel.searchText.isEmpty ? "Add a garment or outfit photo to begin building your collection." : "No items match your search.", actionTitle: viewModel.searchText.isEmpty ? "Add an item" : nil) {}
                Spacer()
            } else {
                ScrollView { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.large) { ForEach(viewModel.filteredItems, id: \.id) { item in card(item) } }.padding() }
            }
        }
        .background(Theme.Colors.canvas)
        .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { if viewModel.isSelectMode { Button("Done") { viewModel.clearSelection() } } else { Menu { NavigationLink("Favorites", destination: FavoritesView(repository: viewModel.repository)); NavigationLink("Archive", destination: ArchiveView(repository: viewModel.repository)); Button("Select items") { viewModel.isSelectMode = true } } label: { Image(systemName: "ellipsis.circle") } } } }
        .safeAreaInset(edge: .bottom) { if viewModel.isSelectMode && !viewModel.selectedIDs.isEmpty { HStack { Button("Archive") { viewModel.archiveSelected() }; Spacer(); Button("Delete", role: .destructive) { viewModel.deleteSelected() } }.padding().background(.regularMaterial) } }
        .alert("Wardrobe", isPresented: .constant(viewModel.errorMessage != nil), actions: { Button("OK") { viewModel.errorMessage = nil } }, message: { Text(viewModel.errorMessage ?? "") })
        .sheet(item: $selectedItem) { item in GarmentDetailView(item: item, viewModel: viewModel) }
    }

    private var categoryTabs: some View { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(viewModel.categories, id: \.self) { category in Button(category == .allCategory ? "All" : category.displayName) { viewModel.selectedCategory = category == .allCategory ? nil : category }.buttonStyle(.borderedProminent).tint(viewModel.selectedCategory == category || (category == .allCategory && viewModel.selectedCategory == nil) ? Theme.Colors.accent : Theme.Colors.surface).foregroundStyle(Theme.Colors.accent) } }.padding(.horizontal) }.padding(.top, 8) }
    private func card(_ item: GarmentItem) -> some View { Button { if viewModel.isSelectMode { viewModel.toggleSelection(item) } else { selectedItem = item } } label: { GarmentCard(title: item.subtype ?? item.category.displayName, subtitle: item.brand, systemImage: item.category.systemImage, image: viewModel.itemImages[item.id]).overlay(alignment: .topTrailing) { if viewModel.isSelectMode { Image(systemName: viewModel.selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle").font(.title2).padding(8).foregroundStyle(Theme.Colors.accent) } } }.buttonStyle(.plain).contextMenu { Button(item.isFavorite ? "Remove favorite" : "Favorite") { viewModel.toggleFavorite(item) }; Button(item.isArchived ? "Unarchive" : "Archive") { viewModel.toggleArchive(item) }; Button("Duplicate") { viewModel.duplicate(item) }; Button("Delete", role: .destructive) { viewModel.delete(item) } } }
}

struct WardrobeFilterSheet: View {
    @Bindable var viewModel: WardrobeViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { Form { Section("Sort") { Picker("Order", selection: $viewModel.sort) { ForEach(WardrobeSort.allCases) { Text($0.rawValue).tag($0) } } }
        Section("Filter") { Picker("Category", selection: $viewModel.filters.category) { Text("Any").tag(nil as GarmentCategory?); ForEach(GarmentCategory.builtIn, id: \.self) { Text($0.displayName).tag(Optional($0)) } }; Picker("Color", selection: $viewModel.filters.color) { Text("Any").tag(nil as String?); ForEach(viewModel.availableColors, id: \.self) { Text($0).tag(Optional($0)) } }; Picker("Brand", selection: $viewModel.filters.brand) { Text("Any").tag(nil as String?); ForEach(viewModel.availableBrands, id: \.self) { Text($0).tag(Optional($0)) } }; Picker("Season", selection: $viewModel.filters.season) { Text("Any").tag(nil as String?); ForEach(viewModel.availableSeasons, id: \.self) { Text($0).tag(Optional($0)) } }; Toggle("Favorites only", isOn: $viewModel.filters.favoritesOnly); Toggle("Recently added", isOn: $viewModel.filters.recentlyAdded) } }.navigationTitle("Filter & Sort").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .cancellationAction) { Button("Reset") { viewModel.filters = WardrobeFilters(category: nil, color: nil, brand: nil, season: nil); viewModel.sort = .recentlyAdded } } } } }
}

extension GarmentCategory { var systemImage: String { switch self { case .shoes: return "shoe.2"; case .dress: return "figure.dress.line.vertical.figure"; case .pants, .jeans, .trousers, .shorts: return "figure.walk"; case .jacket: return "jacket"; case .accessory: return "bag"; default: return "tshirt" } } }

#Preview { NavigationStack { WardrobeHomeView(repository: InMemoryWardrobeRepository()) } }
