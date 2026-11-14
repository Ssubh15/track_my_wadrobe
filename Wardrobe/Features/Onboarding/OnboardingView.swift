import SwiftUI

/// Three swipeable cards shown once on first launch.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let systemImage: String
        let title: String
        let message: String
    }

    private let pages: [Page] = [
        Page(systemImage: "tshirt",
             title: "Build your wardrobe from a photo",
             message: "Snap one garment, or an outfit photo, and Wardrobe cuts out each piece for you."),
        Page(systemImage: "lock.iphone",
             title: "Everything stays on your phone",
             message: "Photos are processed on this device. Nothing is uploaded."),
        Page(systemImage: "checkmark.circle",
             title: "You check every item",
             message: "Review and edit each piece before it is saved to your wardrobe.")
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, Theme.Spacing.large)

            Button {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(isLastPage ? "Get started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.bottom, Theme.Spacing.large)
        .background(Theme.Colors.canvas.ignoresSafeArea())
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()
            RoundedRectangle(cornerRadius: 32)
                .fill(Theme.Colors.surface)
                .frame(width: 240, height: 240)
                .overlay {
                    Image(systemName: page.systemImage)
                        .font(.system(size: 96, weight: .light))
                        .foregroundStyle(Theme.Colors.accent)
                        .accessibilityHidden(true)
                }
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.muted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.Colors.accent : Color(uiColor: .systemGray3))
                    .frame(width: index == page ? 24 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
