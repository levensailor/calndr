import SwiftUI

struct PreferenceItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
    let isToggle: Bool
    let toggleBinding: Binding<Bool>?
    let action: (() -> Void)?
    let activeColor: Color
    
    init(title: String, icon: String, description: String, isToggle: Bool = false, toggleBinding: Binding<Bool>? = nil, action: (() -> Void)? = nil, activeColor: Color = .blue) {
        self.title = title
        self.icon = icon
        self.description = description
        self.isToggle = isToggle
        self.toggleBinding = toggleBinding
        self.action = action
        self.activeColor = activeColor
    }
}

struct PreferenceRow: View {
    let item: PreferenceItem
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundColor(item.isToggle && item.toggleBinding?.wrappedValue == true ? item.activeColor : themeManager.currentTheme.iconColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
            }
            
            Spacer()
            
            if item.isToggle, let binding = item.toggleBinding {
                Toggle("", isOn: binding)
                    .labelsHidden()
            } else if let action = item.action {
                Button(action: action) {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct PreferencesView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var allowPastCustodyEditing = UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Form {
            // Features Section
            Section(header: Text("Features")) {
                ForEach(featurePreferences) { item in
                    PreferenceRow(item: item)
                }
            }
            
            // Theme Selection Section
            Section(header: Text("Themes")) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(themeManager.themes) { theme in
                            ThemePreviewView(theme: theme)
                        }
                    }
                    .padding()
                }
                .frame(height: 250)
            }
        }
        .navigationTitle("Preferences")
        .background(themeManager.currentTheme.mainBackgroundColor)
        .onChange(of: allowPastCustodyEditing) { oldValue, newValue in
            UserDefaults.standard.set(newValue, forKey: "allowPastCustodyEditing")
        }
    }
    
    // MARK: - Preference Items
    
    private var featurePreferences: [PreferenceItem] {
        [
            PreferenceItem(
                title: "Weather Effects",
                icon: "cloud.sun.fill",
                description: "Show weather and visual effects",
                isToggle: true,
                toggleBinding: $viewModel.showWeather,
                activeColor: .blue
            ),
            PreferenceItem(
                title: "School Events",
                icon: "graduationcap.fill",
                description: "Display school calendar",
                isToggle: true,
                toggleBinding: $viewModel.showSchoolEvents,
                activeColor: .green
            ),
            PreferenceItem(
                title: "Edit Past Custody",
                icon: "calendar.badge.clock",
                description: "Allow editing of past custody",
                isToggle: true,
                toggleBinding: $allowPastCustodyEditing,
                activeColor: .orange
            )
        ]
    }
} 