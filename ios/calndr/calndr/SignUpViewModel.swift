import Foundation
import Combine

class SignUpViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var phoneNumber = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func validateAndSendPin(completion: @escaping (Bool, String) -> Void) {
        // Clear previous error
        errorMessage = nil
        
        // Validate inputs
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "First name is required"
            return
        }
        
        guard !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Last name is required"
            return
        }
        
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email is required"
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        guard !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Phone number is required"
            return
        }
        
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate phone number format
        guard isValidPhoneNumber(cleanPhone) else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        
        isLoading = true
        
        // Send verification PIN
        APIService.shared.sendPhoneVerificationPin(phoneNumber: cleanPhone) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        completion(true, cleanPhone)
                    } else {
                        self?.errorMessage = response.message
                        completion(false, "")
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false, "")
                }
            }
        }
    }
    
    func completeSignUp(authManager: AuthenticationManager, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        authManager.signUp(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                if !result {
                    self?.errorMessage = "Registration failed. Please check your information and try again."
                }
                completion(result)
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPhoneNumber(_ phone: String) -> Bool {
        // Remove all non-digit characters for validation
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Should be 10 digits (US format) or 11 digits with country code
        return digits.count == 10 || (digits.count == 11 && digits.hasPrefix("1"))
    }
} 