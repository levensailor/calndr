import SwiftUI

struct ThemePreviewView: View {
    let theme: Theme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(theme.allColors.indices, id: \.self) { index in
                    theme.allColors[index]
                }
            }
            .frame(height: 60)

            Text(theme.name)
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(themeManager.currentTheme.smartTextColor(for: themeManager.currentTheme.secondaryBackgroundColor))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
            
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.currentTheme == theme ? themeManager.currentTheme.accentColorSwiftUI : themeManager.currentTheme.textColorSwiftUI.opacity(0.2), lineWidth: themeManager.currentTheme == theme ? 3 : 1)
        )
        .animateThemeChanges(themeManager)
    }
} 
