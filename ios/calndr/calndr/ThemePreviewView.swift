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
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.currentTheme == theme ? Color.blue : Color.clear, lineWidth: 3)
        )
        .onTapGesture {
            withAnimation {
                themeManager.setTheme(to: theme)
            }
        }
    }
} 
