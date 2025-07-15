import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTheme: Theme? = nil
    @State private var showThemeCreator = false
    @State private var isEditing = false
    @State private var themeToEdit: Theme = Theme.defaultTheme

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    Button(action: {
                        isEditing = false
                        themeToEdit = Theme.defaultTheme
                        showThemeCreator = true
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.iconColorSwiftUI)
                        }
                        .frame(height: 100)
                    }

                    ForEach(themeManager.themes) { theme in
                        ThemePreviewView(theme: theme, selectedTheme: $selectedTheme)
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Edit Theme") {
                    if let theme = selectedTheme {
                        isEditing = true
                        themeToEdit = theme
                        showThemeCreator = true
                    }
                }
                .disabled(selectedTheme == nil)
                
                Button("Set Theme") {
                    if let theme = selectedTheme {
                        themeManager.setTheme(to: theme)
                    }
                }
                .disabled(selectedTheme == nil)
            }
            .padding()

        }
        .navigationTitle("Themes")
        .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
        .sheet(isPresented: $showThemeCreator) {
            ThemeCreatorView(
                theme: $themeToEdit,
                isNew: !isEditing
            )
            .environmentObject(themeManager)
        }
    }
} 