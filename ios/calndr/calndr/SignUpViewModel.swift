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
    @Published var enrollmentCode = ""
    @Published var familyId: Int?
    
    func validateBasicInfo() -> Bool {
        // Clear previous error
        errorMessage = nil
        
        // Validate inputs
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "First name is required"
            return false
        }
        
        guard !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Last name is required"
            return false
        }
        
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email is required"
            return false
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return false
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long"
            return false
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
    
    func validateAllInfo() -> Bool {
        // First validate basic info
        guard validateBasicInfo() else {
            return false
        }
        
        // Then validate phone number
        guard !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Phone number is required"
            return false
        }
        
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate phone number format
        guard isValidPhoneNumber(cleanPhone) else {
            errorMessage = "Please enter a valid phone number"
            return false
        }
        
        return true
    }
    
    func createEnrollmentCode(completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.createEnrollmentCode { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success, let code = response.enrollmentCode {
                        self?.enrollmentCode = code
                        self?.familyId = response.familyId
                        completion(true, code)
                    } else {
                        self?.errorMessage = response.message ?? "Failed to create enrollment code"
                        completion(false, nil)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false, nil)
                }
            }
        }
    }
    
    func validateEnrollmentCode(_ code: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.validateEnrollmentCode(code: code) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        self?.enrollmentCode = code
                        self?.familyId = response.familyId
                        completion(true)
                    } else {
                        self?.errorMessage = response.message ?? "Invalid enrollment code"
                        completion(false)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    func completeSignUpWithFamily(authManager: AuthenticationManager, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        authManager.signUpWithFamily(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            enrollmentCode: enrollmentCode,
            familyId: familyId
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