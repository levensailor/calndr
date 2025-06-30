import SwiftUI

struct AlertsSettingsView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var newEmail = ""
    @State private var emailValues: [Int: String] = [:]
    @FocusState private var isEmailFieldFocused: Bool
    
    var body: some View {
        Form {
            if viewModel.isOffline {
                Section {
                    Text("You are currently offline. Email management is disabled.")
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Email Addresses"), footer: Text("Tap an email to edit. Swipe to delete.")) {
                List {
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
                }
            }
            
            Section {
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
            .disabled(viewModel.isOffline)
        }
        .navigationTitle("Alerts")
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