import SwiftUI

struct ThemeableViewModifier: ViewModifier {
    @ObservedObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .onAppear(perform: applyTheme)
            .onChange(of: themeManager.currentTheme) { _, _ in
                applyTheme()
            }
    }

    private func applyTheme() {
        let theme = themeManager.currentTheme
        let appearance = UINavigationBarAppearance()

        // Configure background and shadow
        appearance.backgroundColor = UIColor(theme.mainBackgroundColorSwiftUI)
        appearance.shadowColor = .clear // Optional: for a flatter look

        // Configure title text attributes
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(theme.smartHeaderTextColor)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(theme.smartHeaderTextColor)
        ]

        // Configure button appearance
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(theme.accentColorSwiftUI)
        ]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance

        // Apply the appearance to all navigation bar states
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    func themeable(_ themeManager: ThemeManager) -> some View {
        self.modifier(ThemeableViewModifier(themeManager: themeManager))
    }
}
