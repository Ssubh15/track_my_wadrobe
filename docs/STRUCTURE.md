# Project Structure

```text
Wardrobe/
├── AGENTS.md
├── README.md
├── project.yml
├── .github/workflows/ios.yml
├── docs/
│   ├── PRD.md
│   ├── STRUCTURE.md
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   └── BUILD.md
├── Wardrobe/
│   ├── App/
│   ├── Core/
│   │   ├── Models/
│   │   ├── Persistence/
│   │   ├── Services/{Imaging,Classification,Outfit,BrandLookup}/
│   │   └── Utilities/
│   ├── Features/
│   │   ├── Onboarding/
│   │   ├── AddItem/{Entry,Capture,ProductMode,OutfitMode,Shared}/
│   │   ├── Wardrobe/
│   │   ├── Insights/
│   │   └── Settings/
│   ├── DesignSystem/Components/
│   └── Resources/{Assets.xcassets,Models}/
├── WardrobeTests/
├── WardrobeUITests/
└── backend/
```

This is a directory-only scaffold. App sources, XcodeGen configuration, CI, and backend implementation are intentionally deferred.
