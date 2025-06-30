import Foundation
import Combine

class PasswordViewModel: ObservableObject {
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var passwordUpdateMessage = ""
    @Published var isPasswordUpdateSuccessful = false

    func updatePassword() {
        // Reset state
        passwordUpdateMessage = ""
        isPasswordUpdateSuccessful = false

        // 1. Validate new passwords match
        guard !newPassword.isEmpty, newPassword == confirmPassword else {
            passwordUpdateMessage = "New passwords do not match."
            isPasswordUpdateSuccessful = false
            return
        }
        
        // 2. Validate new password is not empty
        guard !newPassword.isEmpty else {
            passwordUpdateMessage = "New password cannot be empty."
            return
        }

        let passwordUpdate = PasswordUpdate(current_password: currentPassword, new_password: newPassword)
        
        APIService.shared.updatePassword(passwordUpdate: passwordUpdate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.passwordUpdateMessage = "Password updated successfully!"
                    self?.isPasswordUpdateSuccessful = true
                    // Clear fields after successful update
                    self?.currentPassword = ""
                    self?.newPassword = ""
                    self?.confirmPassword = ""
                case .failure(let error):
                    self?.passwordUpdateMessage = "Error: \(error.localizedDescription)"
                    self?.isPasswordUpdateSuccessful = false
                }
            }
        }
    }
} 