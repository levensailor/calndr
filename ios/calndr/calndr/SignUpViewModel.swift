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
    @Published var familyId: String?
    
    // Track whether a code was entered or generated
    @Published var enteredValidCode = false
    @Published var generatedCode: String? = nil
    
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
        
        // Print debug info
        print("📱 Creating enrollment code...")
        
        // Use the debug version of the API call
        APIService.shared.debugCreateEnrollmentCode { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    // Debug the full response
                    print("📱 Enrollment code response: success=\(response.success), message=\(response.message ?? "nil"), code=\(response.enrollmentCode ?? "nil"), familyId=\(response.familyId ?? "nil")")
                    
                    // The backend returns success=true with the message "Enrollment code created successfully"
                    // and includes the enrollmentCode and familyId
                    if let code = response.enrollmentCode {
                        print("📱 Successfully created enrollment code: \(code)")
                        self?.enrollmentCode = code
                        
                        // Store familyId directly as String
                        self?.familyId = response.familyId
                        
                        self?.generatedCode = code
                        completion(true, code)
                    } else {
                        print("📱 Failed to create enrollment code: \(response.message ?? "Unknown error")")
                        self?.errorMessage = response.message ?? "Failed to create enrollment code"
                        completion(false, nil)
                    }
                case .failure(let error):
                    print("📱 Error creating enrollment code: \(error.localizedDescription)")
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
                        self?.enteredValidCode = true
                        completion(true)
                    } else {
                        self?.errorMessage = response.message ?? "Invalid enrollment code"
                        self?.enteredValidCode = false
                        completion(false)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.enteredValidCode = false
                    completion(false)
                }
            }
        }
    }
    
    func completeSignUp(authManager: AuthenticationManager, completion: @escaping (Bool, Bool) -> Void) {
        isLoading = true
        
        authManager.signUp(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { [weak self] result, requiresEmailVerification in
            DispatchQueue.main.async {
                self?.isLoading = false
                if !result && !requiresEmailVerification {
                    self?.errorMessage = "Registration failed. Please check your information and try again."
                }
                completion(result, requiresEmailVerification)
            }
        }
    }
    
    func completeSignUpWithFamily(authManager: AuthenticationManager, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        // Check if the user is already authenticated but just needs to complete enrollment
        if authManager.isAuthenticated {
            print("📱 User is already authenticated, just continuing with enrollment")
            // Don't mark as fully enrolled yet, just associate with family
            authManager.completeEnrollment(familyId: familyId, enrollmentCode: enrollmentCode) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if !result {
                        self?.errorMessage = "Failed to continue enrollment. Please try again."
                    }
                    completion(result)
                }
            }
        } else {
            // Full signup for new users
            print("📱 New user signup with family")
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
    
    func emailEnrollmentCode(to coparentName: String, code: String) {
        // This would typically call an API endpoint to send an email with the enrollment code
        // For now, we'll just print to the console
        print("📧 Would send enrollment code \(code) to co-parent \(coparentName)")
        
        // In a real implementation, you would call an API endpoint like this:
        // APIService.shared.sendEnrollmentCodeEmail(to: coparentEmail, name: coparentName, code: code) { result in
        //     // Handle success/failure
        // }
    }
} 