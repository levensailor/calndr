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

        // Configure appearance based on theme
        appearance.configureWithOpaqueBackground()
        
        // Set the background color based on the theme's main background color
        appearance.backgroundColor = UIColor(theme.mainBackgroundColorSwiftUI)
        
        // Remove shadow
        appearance.shadowColor = .clear
        
        // Configure title text attributes with smart contrast
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(theme.smartHeaderTextColor)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(theme.smartHeaderTextColor)
        ]

        // Configure button appearance with proper contrast
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(theme.smartTextColor)
        ]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        
        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Also update tab bar appearance for consistency
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(theme.mainBackgroundColorSwiftUI)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}

extension View {
    func themeable(_ themeManager: ThemeManager) -> some View {
        self.modifier(ThemeableViewModifier(themeManager: themeManager))
    }
}
