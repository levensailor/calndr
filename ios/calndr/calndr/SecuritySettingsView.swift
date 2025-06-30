import SwiftUI

struct SecuritySettingsView: View {
    @StateObject private var passwordViewModel = PasswordViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showSuccessMessage = false

    var body: some View {
        Form {
            Section(header: Text("Update Web UI Password")) {
                SecureField("Current Password", text: $passwordViewModel.currentPassword)
                SecureField("New Password", text: $passwordViewModel.newPassword)
                SecureField("Confirm New Password", text: $passwordViewModel.confirmPassword)
            }

            Button(action: {
                passwordViewModel.updatePassword()
            }) {
                Text("Update Password")
                    .frame(maxWidth: .infinity)
            }
            .disabled(passwordViewModel.currentPassword.isEmpty || passwordViewModel.newPassword.isEmpty)

            if !passwordViewModel.passwordUpdateMessage.isEmpty {
                Text(passwordViewModel.passwordUpdateMessage)
                    .foregroundColor(passwordViewModel.isPasswordUpdateSuccessful ? .green : .red)
                    .onAppear {
                        // If the message is a success message, make it disappear after a few seconds
                        if passwordViewModel.isPasswordUpdateSuccessful {
                            showSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showSuccessMessage = false
                                // Also clear the message from the viewmodel
                                passwordViewModel.passwordUpdateMessage = ""
                                passwordViewModel.isPasswordUpdateSuccessful = false
                            }
                        }
                    }
                    // Only show the view if the logic says so
                    .if(showSuccessMessage || !passwordViewModel.isPasswordUpdateSuccessful) { view in
                        view
                    }
            }

            Section {
                Button(action: {
                    authManager.logout()
                }) {
                    Text("Logout")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Security")
        .onDisappear {
            // Clear fields and messages when the view disappears
            passwordViewModel.currentPassword = ""
            passwordViewModel.newPassword = ""
            passwordViewModel.confirmPassword = ""
            passwordViewModel.passwordUpdateMessage = ""
            passwordViewModel.isPasswordUpdateSuccessful = false
        }
    }
}

// Custom ViewModifier to conditionally apply a view
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 