import Foundation
import Combine

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func login(authManager: AuthenticationManager) {
        // Clear the error message at the very beginning
        errorMessage = nil
        isLoading = true
        
        authManager.login(email: email, password: password) { [weak self] result in
            // The result comes back on the main thread from the authManager
            self?.isLoading = false
            if !result {
                self?.errorMessage = "Invalid email or password. Please try again."
            }
        }
    }
} 