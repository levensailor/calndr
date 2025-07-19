import SwiftUI

struct QuickThemeSwitcher: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAllThemes = false
    
    var body: some View {
        Menu {
            // Quick access to current theme and most popular themes
            Section("Current Theme") {
                Button(action: {}) {
                    HStack {
                        Text(themeManager.currentTheme.name)
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
                .disabled(true)
            }
            
            Section("Quick Switch") {
                ForEach(popularThemes) { theme in
                    if theme.id != themeManager.currentTheme.id {
                        Button(action: {
                            themeManager.setTheme(to: theme)
                        }) {
                            HStack {
                                Circle()
                                    .fill(theme.accentColor.color)
                                    .frame(width: 12, height: 12)
                                Text(theme.name)
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    showingAllThemes = true
                }) {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                        Text("All Themes")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(themeManager.currentTheme.accentColor.color)
                    .frame(width: 16, height: 16)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
            }
        }
        .sheet(isPresented: $showingAllThemes) {
            NavigationView {
                ThemeSettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingAllThemes = false
                            }
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        }
                    }
            }
            .environmentObject(themeManager)
        }
    }
    
    // Popular themes for quick access (limit to 5 most popular)
    private var popularThemes: [Theme] {
        let popularThemeNames = ["Default", "Dracula", "One Dark Pro", "GitHub Dark", "Monokai Pro"]
        return themeManager.themes.filter { theme in
            popularThemeNames.contains(theme.name)
        }.sorted { first, second in
            let firstIndex = popularThemeNames.firstIndex(of: first.name) ?? Int.max
            let secondIndex = popularThemeNames.firstIndex(of: second.name) ?? Int.max
            return firstIndex < secondIndex
        }
    }
}

struct HorizontalThemeSwitcher: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAllThemes = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(themeManager.themes.prefix(8)) { theme in
                    ThemeQuickButton(theme: theme)
                }
                
                // "More" button
                Button(action: {
                    showingAllThemes = true
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        }
                        
                        Text("More")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingAllThemes) {
            NavigationView {
                ThemeSettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingAllThemes = false
                            }
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        }
                    }
            }
            .environmentObject(themeManager)
        }
    }
}

struct ThemeQuickButton: View {
    let theme: Theme
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            themeManager.setTheme(to: theme)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(theme.mainBackgroundColor.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(theme.accentColor.color, lineWidth: isCurrentTheme ? 3 : 1)
                        )
                    
                    // Mini color preview
                    HStack(spacing: 2) {
                        Circle()
                            .fill(theme.parentOneColor.color)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(theme.parentTwoColor.color)
                            .frame(width: 8, height: 8)
                    }
                    
                    if isCurrentTheme {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(theme.smartTextColor(for: theme.mainBackgroundColor))
                            .offset(x: 12, y: -12)
                    }
                }
                
                Text(theme.name)
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 50)
            }
        }
        .scaleEffect(isCurrentTheme ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCurrentTheme)
    }
    
    private var isCurrentTheme: Bool {
        theme.id == themeManager.currentTheme.id
    }
}

// Preview for development
struct QuickThemeSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        let themeManager = ThemeManager()
        
        VStack(spacing: 20) {
            QuickThemeSwitcher()
            HorizontalThemeSwitcher()
        }
        .environmentObject(themeManager)
        .padding()
    }
} 