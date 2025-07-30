import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showThemeCreator = false
    @State private var isEditing = false
    @State private var themeToEdit: Theme = Theme.defaultTheme
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(themeManager.themes) { theme in
                            ThemePreviewView(
                                theme: theme,
                                onEdit: { theme in
                                    self.themeToEdit = theme
                                    self.isEditing = true
                                    self.showThemeCreator = true
                                },
                                onDelete: { theme in
                                    themeManager.deleteTheme(theme)
                                }
                            )
                            .onTapGesture {
                                themeManager.setTheme(to: theme)
                            }
                        }
                    }
                    .padding()
                }
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
            .navigationBarItems(trailing:
                                    Button(action: {
                isEditing = false
                themeToEdit = Theme.defaultTheme
                showThemeCreator = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
            }
            )
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
            .animateThemeChanges(themeManager)
            .sheet(isPresented: $showThemeCreator) {
                ThemeCreatorView(
                    theme: $themeToEdit,
                    isNew: !isEditing
                )
                .environmentObject(themeManager)
            }
        }
    }
}
