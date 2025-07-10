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

struct PreferenceCard: View {
    let item: PreferenceItem
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(item.isToggle && item.toggleBinding?.wrappedValue == true ? item.activeColor : themeManager.currentTheme.iconColor)
                    .frame(width: 30, height: 30)
                
                Spacer()
                
                if item.isToggle, let binding = item.toggleBinding {
                    Toggle("", isOn: binding)
                        .scaleEffect(0.9)
                } else if let action = item.action {
                    Button(action: action) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Only handle tap gestures for non-toggle items
            // Toggle items should be controlled only by the Toggle control itself
            if !item.isToggle, let action = item.action {
                action()
            }
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var allowPastCustodyEditing = UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")
    @State private var newEmail = ""
    @State private var emailValues: [Int: String] = [:]
    @FocusState private var isEmailFieldFocused: Bool

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Form {
            // Display & Features Section
            Section(header: Text("Display & Features")) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(displayPreferences) { item in
                        PreferenceCard(item: item)
                    }
                }
                .padding(.vertical, 8)
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
                .frame(height: 300)
            }
            
            // Custody Settings Section
            Section(header: Text("Custody Settings")) {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(custodyPreferences) { item in
                        PreferenceCard(item: item)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Notification Emails Section
            Section(header: Text("Notification Emails"), footer: Text("These emails will receive notifications when custody changes. Tap an email to edit. Swipe to delete.")) {
                if viewModel.isOffline {
                    Text("You are currently offline. Email management is disabled.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.notificationEmails) { email in
                        HStack {
                            TextField("Email", text: Binding(
                                get: { self.emailValues[email.id, default: email.email] },
                                set: { self.emailValues[email.id] = $0 }
                            ))
                            .foregroundColor(isEmailValid(emailValues[email.id, default: email.email]) ? .primary : .red)
                            .onSubmit {
                                updateEmail(email)
                            }
                            .disabled(viewModel.isOffline)
                            
                            if isEmailValid(emailValues[email.id, default: email.email]) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onDelete(perform: viewModel.deleteNotificationEmail)
                    
                    // Add new email field
                    HStack {
                        TextField("Add new email...", text: $newEmail)
                            .keyboardType(.emailAddress)
                            .foregroundColor(isEmailValid(newEmail) || newEmail.isEmpty ? .primary : .red)
                            .onSubmit(addEmail)
                            .focused($isEmailFieldFocused)

                        if isEmailValid(newEmail) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }

                        Button("Add", action: addEmail)
                            .disabled(!isEmailValid(newEmail))
                    }
                }
            }
            .disabled(viewModel.isOffline)
        }
        .navigationTitle("Preferences")
        .background(themeManager.currentTheme.mainBackgroundColor)
        .onAppear(perform: setupView)
        .onChange(of: allowPastCustodyEditing) { oldValue, newValue in
            UserDefaults.standard.set(newValue, forKey: "allowPastCustodyEditing")
        }
    }
    
    // MARK: - Preference Items
    
    private var displayPreferences: [PreferenceItem] {
        [
            PreferenceItem(
                title: "Weather Effects",
                icon: "cloud.sun.fill",
                description: "Show weather information and visual effects on calendar",
                isToggle: true,
                toggleBinding: $viewModel.showWeather,
                activeColor: .blue
            ),
            PreferenceItem(
                title: "School Events",
                icon: "graduationcap.fill",
                description: "Display school events and academic calendar",
                isToggle: true,
                toggleBinding: $viewModel.showSchoolEvents,
                activeColor: .green
            )
        ]
    }
    
    private var custodyPreferences: [PreferenceItem] {
        [
            PreferenceItem(
                title: "Edit Past Custody",
                icon: "calendar.badge.clock",
                description: "Allow editing custody for past dates. No notifications will be sent for past edits.",
                isToggle: true,
                toggleBinding: $allowPastCustodyEditing,
                activeColor: .orange
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func isEmailValid(_ email: String) -> Bool {
        return email.isValidEmail()
    }
    
    private func setupView() {
        if viewModel.notificationEmails.isEmpty {
            viewModel.fetchNotificationEmails()
        }
    }
    
    private func updateEmail(_ email: NotificationEmail) {
        if let updatedValue = emailValues[email.id], updatedValue != email.email {
            viewModel.updateNotificationEmail(for: email, with: updatedValue)
        }
    }
    
    private func addEmail() {
        guard isEmailValid(newEmail) else { return }
        viewModel.addNotificationEmail(newEmail) { success in
            if success {
                newEmail = ""
                isEmailFieldFocused = false
            }
        }
    }
} 