import SwiftUI

struct NavigationBarThemer: ViewModifier {
    @ObservedObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .onAppear(perform: applyTheme)
            .onChange(of: themeManager.currentTheme) {
                applyTheme()
            }
    }
    
    private func applyTheme() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(themeManager.currentTheme.mainBackgroundColor.color)
        
        let titleColor = UIColor(themeManager.currentTheme.textColor.color)
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

extension View {
    func themeNavigationBar(themeManager: ThemeManager) -> some View {
        self.modifier(NavigationBarThemer(themeManager: themeManager))
    }
} 
