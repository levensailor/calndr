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
                Section(header: Text("Theme Name")) {
                    TextField("Name", text: $themeName)
                }

                Section(header: Text("General Colors")) {
                    ColorPicker("Main Background", selection: $mainBackgroundColor)
                    ColorPicker("Secondary Background", selection: $secondaryBackgroundColor)
                    ColorPicker("Text Color", selection: $textColor)
                    ColorPicker("Header Text Color", selection: $headerTextColor)
                }
                
                Section(header: Text("UI Elements")) {
                    ColorPicker("Icon Color", selection: $iconColor)
                    ColorPicker("Active Icon Color", selection: $iconActiveColor)
                    ColorPicker("Accent Color", selection: $accentColor)
                }

                Section(header: Text("Parent Colors")) {
                    ColorPicker("Parent 1 Color", selection: $parentOneColor)
                    ColorPicker("Parent 2 Color", selection: $parentTwoColor)
                }
            }
            .navigationTitle(isNew ? "Create Theme" : "Edit Theme")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveTheme()
                    presentationMode.wrappedValue.dismiss()
                }
            )
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
