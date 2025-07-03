import SwiftUI

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
            Section(header: Text("Custody Settings"), footer: Text("When enabled, you can edit custody for past dates. No notifications will be sent for past edits.")) {
                Toggle("Allow editing past days", isOn: $allowPastCustodyEditing)
                    .onChange(of: allowPastCustodyEditing) { value in
                        UserDefaults.standard.set(value, forKey: "allowPastCustodyEditing")
                    }
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
    }
    
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