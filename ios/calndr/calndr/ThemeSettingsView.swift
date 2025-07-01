import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(themeManager.themes) { theme in
                    ThemePreviewView(theme: theme)
                }
            }
            .padding()
        }
        .navigationTitle("Themes")
        .background(themeManager.currentTheme.mainBackgroundColor)
    }
} 