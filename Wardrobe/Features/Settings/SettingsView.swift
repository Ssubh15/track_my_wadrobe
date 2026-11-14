import SwiftUI

struct SettingsView: View {
    let repository: any WardrobeRepository
    @State private var didSeed = false
    @AppStorage("keepOriginalOutfitPhotos") private var keepOriginalOutfitPhotos = false
    @AppStorage("saveDiagnosticImages") private var saveDiagnosticImages = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Keep original photos", isOn: $keepOriginalOutfitPhotos)
                } header: {
                    Text("Outfit photos")
                } footer: {
                    Text("When off, Wardrobe does not retain the full outfit photo after extraction. Saved items contain garment cut-outs only.")
                }

                Section("Wardrobe") {
                    NavigationLink("Categories and tags") {
                        CategoriesAndTagsView(repository: repository)
                    }
                }

                Section("Privacy") {
                    NavigationLink("Privacy and your data") {
                        PrivacyView()
                    }
                }

                Section {
                    LabeledContent("Outfit segmenter in use", value: OutfitDiagnostics.currentSegmenterName)
                    LabeledContent("Load status", value: UserDefaults.standard.string(forKey: OutfitDiagnostics.modelErrorKey).map { "Failed: \($0)" } ?? "Loaded")
                    LabeledContent("Background removal model", value: UserDefaults.standard.string(forKey: OutfitDiagnostics.u2NetStatusKey) ?? "U2NetP not checked")
                    Toggle("Save diagnostic images", isOn: $saveDiagnosticImages)
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("When enabled, extraction images are saved in Documents/Diagnostics so you can inspect them in Files.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Wardrobe keeps photo processing on your device.")
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
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.canvas)
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
