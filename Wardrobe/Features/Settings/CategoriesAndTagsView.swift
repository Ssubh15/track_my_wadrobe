import SwiftUI

struct CategoriesAndTagsView: View {
    let repository: any WardrobeRepository

    @State private var store = CategoryTagStore()
    @State private var counts: [String: Int] = [:]
    @State private var isEditing = false
    @State private var prompt: Prompt?
    @State private var promptText = ""
    @State private var errorMessage: String?

    private enum Prompt: Equatable {
        case addCategory
        case renameCategory(String)
        case addTag
        case renameTag(String)

        var title: String {
            switch self {
            case .addCategory: return "New category"
            case .renameCategory: return "Rename category"
            case .addTag: return "New tag"
            case .renameTag: return "Rename tag"
            }
        }
    }

    var body: some View {
        List {
            builtInSection
            customCategoriesSection
            tagsSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .navigationTitle("Categories and tags")
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
            }
        }
        .onAppear(perform: reloadCounts)
        .alert(prompt?.title ?? "", isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })) {
            TextField("Name", text: $promptText)
            Button("Save", action: commitPrompt)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn’t save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var builtInSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(GarmentCategory.builtIn, id: \.self) { category in
                    chip(category.displayName, foreground: Theme.Colors.muted, background: Color(uiColor: .systemGray5))
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Built-in categories")
        }
    }

    private var customCategoriesSection: some View {
        Section {
            ForEach(store.categories, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    let count = counts[name, default: 0]
                    Text("\(count) \(count == 1 ? "item" : "items")")
                        .foregroundStyle(Theme.Colors.muted)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing { startPrompt(.renameCategory(name), text: name) }
                }
            }
            .onDelete { offsets in
                for name in offsets.map({ store.categories[$0] }) { removeCategory(name) }
            }
            .onMove { source, destination in
                store.moveCategories(from: source, to: destination)
            }

            Button {
                startPrompt(.addCategory, text: "")
            } label: {
                Label("Add category", systemImage: "plus")
            }
            .foregroundStyle(Theme.Colors.accent)
        } header: {
            Text("My categories")
        }
    }

    private var tagsSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(store.tags, id: \.self) { tag in
                    HStack(spacing: 6) {
                        Button {
                            if isEditing { startPrompt(.renameTag(tag), text: tag) }
                        } label: {
                            Text(tag)
                        }
                        .buttonStyle(.plain)
                        if isEditing {
                            Button {
                                store.removeTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove tag \(tag)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.accent.opacity(0.12), in: Capsule())
                }
                Button {
                    startPrompt(.addTag, text: "")
                } label: {
                    Label("New tag", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Theme.Colors.accent, style: StrokeStyle(lineWidth: 1, dash: [4])))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Tags")
        } footer: {
            Text("Built-in categories can’t be renamed or removed. Deleting a category moves its items to Other.")
        }
    }

    private func chip(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
    }

    // MARK: Actions

    private func startPrompt(_ newPrompt: Prompt, text: String) {
        promptText = text
        prompt = newPrompt
    }

    private func commitPrompt() {
        guard let current = prompt else { return }
        let text = promptText
        prompt = nil
        do {
            switch current {
            case .addCategory:
                try store.addCategory(text)
            case let .renameCategory(old):
                let new = try store.renameCategory(from: old, to: text)
                if new != old { try recategorise(from: .custom(old), to: .custom(new)) }
            case .addTag:
                try store.addTag(text)
            case let .renameTag(old):
                try store.renameTag(from: old, to: text)
            }
            reloadCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeCategory(_ name: String) {
        do {
            try recategorise(from: .custom(name), to: .other)
            store.removeCategory(name)
            reloadCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Uses the existing repository API to move items from one category to another.
    private func recategorise(from old: GarmentCategory, to new: GarmentCategory) throws {
        for item in try repository.fetchItems(includeArchived: true) where item.category == old {
            item.category = new
            try repository.save(item)
        }
    }

    private func reloadCounts() {
        var result: [String: Int] = [:]
        for item in (try? repository.fetchItems(includeArchived: true)) ?? [] {
            if case let .custom(name) = item.category { result[name, default: 0] += 1 }
        }
        counts = result
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack { CategoriesAndTagsView(repository: InMemoryWardrobeRepository()) }
}
