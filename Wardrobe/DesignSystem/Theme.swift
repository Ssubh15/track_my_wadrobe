import SwiftUI

enum Theme {
    enum Colors {
        static let accent = Color(red: 0.35, green: 0.36, blue: 0.27)
        static let canvas = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let muted = Color.secondary
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    enum TypeStyles {
        static let title = Font.largeTitle.weight(.semibold)
        static let section = Font.title3.weight(.semibold)
        static let body = Font.body
        static let caption = Font.caption
    }
}
