import SwiftUI

struct ThemeCreatorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var theme: Theme
    var isNew: Bool

    @State private var themeName: String
    @State private var mainBackgroundColor: Color
    @State private var secondaryBackgroundColor: Color
    @State private var textColor: Color
    @State private var headerTextColor: Color
    @State private var iconColor: Color
    @State private var iconActiveColor: Color
    @State private var accentColor: Color
    @State private var parentOneColor: Color
    @State private var parentTwoColor: Color
    
    init(theme: Binding<Theme>, isNew: Bool) {
        self._theme = theme
        self.isNew = isNew
        _themeName = State(initialValue: theme.wrappedValue.name)
        _mainBackgroundColor = State(initialValue: theme.wrappedValue.mainBackgroundColor.color)
        _secondaryBackgroundColor = State(initialValue: theme.wrappedValue.secondaryBackgroundColor.color)
        _textColor = State(initialValue: theme.wrappedValue.textColor.color)
        _headerTextColor = State(initialValue: theme.wrappedValue.headerTextColor.color)
        _iconColor = State(initialValue: theme.wrappedValue.iconColor.color)
        _iconActiveColor = State(initialValue: theme.wrappedValue.iconActiveColor.color)
        _accentColor = State(initialValue: theme.wrappedValue.accentColor.color)
        _parentOneColor = State(initialValue: theme.wrappedValue.parentOneColor.color)
        _parentTwoColor = State(initialValue: theme.wrappedValue.parentTwoColor.color)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Theme Name")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    TextField("Name", text: $themeName)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)

                Section(header: Text("General Colors")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    ColorPicker("Main Background", selection: $mainBackgroundColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    ColorPicker("Secondary Background", selection: $secondaryBackgroundColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    ColorPicker("Text Color", selection: $textColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    ColorPicker("Header Text Color", selection: $headerTextColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                
                Section(header: Text("UI Elements")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    ColorPicker("Icon Color", selection: $iconColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    ColorPicker("Active Icon Color", selection: $iconActiveColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    ColorPicker("Accent Color", selection: $accentColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)

                Section(header: Text("Parent Colors")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    ColorPicker("Parent 1 Color", selection: $parentOneColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    ColorPicker("Parent 2 Color", selection: $parentTwoColor)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationTitle(isNew ? "Create Theme" : "Edit Theme")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI),
                trailing: Button("Save") {
                    saveTheme()
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
            )
            .animateThemeChanges(themeManager)
        }
        .environmentObject(themeManager)
    }

    private func saveTheme() {
        let updatedTheme = Theme(
            id: isNew ? UUID() : theme.id,
            name: themeName,
            mainBackgroundColor: CodableColor(color: mainBackgroundColor),
            secondaryBackgroundColor: CodableColor(color: secondaryBackgroundColor),
            textColor: CodableColor(color: textColor),
            headerTextColor: CodableColor(color: headerTextColor),
            iconColor: CodableColor(color: iconColor),
            iconActiveColor: CodableColor(color: iconActiveColor),
            accentColor: CodableColor(color: accentColor),
            parentOneColor: CodableColor(color: parentOneColor),
            parentTwoColor: CodableColor(color: parentTwoColor)
        )
        
        if isNew {
            themeManager.addTheme(updatedTheme)
        } else {
            themeManager.updateTheme(updatedTheme)
        }
        themeManager.setTheme(to: updatedTheme)
    }
} 
