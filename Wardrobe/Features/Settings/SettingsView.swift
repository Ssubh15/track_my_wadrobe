import SwiftUI

struct SettingsView: View {
    let repository: any WardrobeRepository
    @State private var didSeed = false
    @AppStorage("keepOriginalOutfitPhotos") private var keepOriginalOutfitPhotos = false
    @AppStorage("saveDiagnosticImages") private var saveDiagnosticImages = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Privacy", systemImage: "hand.raised")
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                } header: {
                    SectionHeader(title: "Preferences")
                }
                Section("Outfit photos") {
                    Toggle("Keep originals", isOn: $keepOriginalOutfitPhotos)
                    Text("When off, Wardrobe does not retain the full outfit photo after extraction. Saved items contain garment cut-outs only.")
                        .font(Theme.TypeStyles.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Section("Diagnostics") {
                    LabeledContent("Outfit segmenter in use", value: OutfitDiagnostics.currentSegmenterName)
                    LabeledContent("Load status", value: UserDefaults.standard.string(forKey: OutfitDiagnostics.modelErrorKey).map { "Failed: \($0)" } ?? "Loaded")
                    LabeledContent("Background removal model", value: UserDefaults.standard.string(forKey: OutfitDiagnostics.u2NetStatusKey) ?? "U2NetP not checked")
                    Toggle("Save diagnostic images", isOn: $saveDiagnosticImages)
                    Text("When enabled, extraction images are saved in Documents/Diagnostics so you can inspect them in Files.")
                        .font(Theme.TypeStyles.caption).foregroundStyle(Theme.Colors.muted)
                }
                Section {
                    Text("Wardrobe keeps photo processing on your device.")
                        .font(Theme.TypeStyles.body)
                        .foregroundStyle(Theme.Colors.muted)
                } header: {
                    SectionHeader(title: "About")
                }
                #if DEBUG
                Section("Developer") {
                    Button("Seed sample wardrobe") { seedSamples() }
                    if didSeed { Text("Sample items added.").font(Theme.TypeStyles.caption).foregroundStyle(Theme.Colors.muted) }
                    NavigationLink("OOTD segmentation debug") {
                        OOTDSegmentationDebugView()
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
        }
    }

    private func seedSamples() {
        let viewModel = WardrobeViewModel(repository: repository)
        viewModel.seedSampleItems()
        didSeed = true
    }
}

#Preview {
    SettingsView(repository: InMemoryWardrobeRepository()).environment(DIContainer())
}
