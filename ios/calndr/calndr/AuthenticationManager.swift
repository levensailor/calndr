import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var userProfile: UserProfile?
    @Published var hasCompletedOnboarding: Bool = true // Default to true for existing users
    @Published var authToken: String?
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        checkAuthentication()
    }
    
    func checkAuthentication() {
        print("🔐 AuthenticationManager: Starting authentication check...")
        // Show splash screen for at least 2 seconds for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let token = KeychainManager.shared.loadToken(for: "currentUser") {
                print("🔐 AuthenticationManager: Found token in keychain")
                // Don't set isAuthenticated yet, wait for profile fetch
                
                // Fetch user profile to ensure data is up-to-date
                APIService.shared.getUserProfile { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let profile):
                            self.userProfile = profile
                            print("🔐 AuthenticationManager: Successfully fetched user profile.")
                            
                            // Only set isAuthenticated to true if the user is enrolled
                            if profile.enrolled == true {
                                self.isAuthenticated = true
                                print("🔐 AuthenticationManager: User is enrolled, setting isAuthenticated = true")
                            } else {
                                self.isAuthenticated = false
                                print("🔐 AuthenticationManager: User is not enrolled, setting isAuthenticated = false")
                            }
                        case .failure(let error):
                            print("🔐❌ AuthenticationManager: Failed to fetch user profile: \(error.localizedDescription)")
                            // Handle failure, maybe logout user
                            self.logout()
                        }
                    }
                }
                
                // Check if user has completed onboarding
                // If the key doesn't exist, assume true for existing users
                if UserDefaults.standard.object(forKey: "hasCompletedOnboarding") != nil {
                    self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                } else {
                    self.hasCompletedOnboarding = true // Default to true for existing users
                }
                
            } else {
                print("🔐 AuthenticationManager: No token found in keychain")
                self.isAuthenticated = false
                self.userProfile = nil
                self.hasCompletedOnboarding = true // Reset for new users
                print("🔐 AuthenticationManager: Set isAuthenticated = false")
            }
            self.isLoading = false
            print("🔐 AuthenticationManager: Set isLoading = false, final state: isAuthenticated = \(self.isAuthenticated)")
        }
    }
    
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        print("🔐 AuthenticationManager: Starting login for email: \(email)")
        APIService.shared.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (profile, token)):
                    print("🔐 AuthenticationManager: Login API success, saving token...")
                    
                    let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                    if saved {
                        print("🔐 AuthenticationManager: Token saved successfully")
                        self?.isLoading = false
                        self?.userProfile = profile
                        
                        // Only set isAuthenticated to true if the user is enrolled
                        if profile.enrolled == true {
                            self?.isAuthenticated = true
                            print("🔐 AuthenticationManager: User is enrolled, setting isAuthenticated = true")
                        } else {
                            print("🔐 AuthenticationManager: User is not enrolled, keeping isAuthenticated = false")
                        }
                        
                        print("🔐 AuthenticationManager: Login complete - userProfile = \(profile)")
                        completion(true)
                    } else {
                        print("🔐❌ AuthenticationManager: Error - Could not save token to keychain")
                        self?.isAuthenticated = false
                        self?.isLoading = false
                        completion(false)
                    }
                case .failure(let error):
                    print("🔐❌ AuthenticationManager: Login failed: \(error.localizedDescription)")
                    self?.isAuthenticated = false
                    self?.isLoading = false
                    completion(false)
                }
            }
        }
    }
    
    func signUp(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        phoneNumber: String?,
        completion: @escaping (Bool, Bool) -> Void
    ) {
        APIService.shared.signUp(
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            phoneNumber: phoneNumber,
            coparentEmail: nil,
            coparentPhone: nil
        ) { [weak self] result in
            switch result {
            case .success(let response):
                // response is a tuple (token: String, shouldSkipOnboarding: Bool)
                // Check if token is empty (indicates email verification required)
                if response.token.isEmpty {
                    // Email verification required - don't save token yet
                    completion(false, true) // success=false, requiresEmailVerification=true
                } else {
                    // Normal signup flow - save token
                    self?.authToken = response.token
                    let saved = KeychainManager.shared.save(token: response.token, for: "currentUser")
                    if !saved {
                        print("⚠️ AuthenticationManager: Failed to save token to keychain during signup")
                    }
                    
                    // Set onboarding state based on backend response
                    self?.hasCompletedOnboarding = response.shouldSkipOnboarding
                    UserDefaults.standard.set(response.shouldSkipOnboarding, forKey: "hasCompletedOnboarding")
                    
                    // If they should skip onboarding, mark as authenticated immediately
                    if response.shouldSkipOnboarding {
                        self?.isAuthenticated = true
                    }
                    
                    completion(true, false) // success=true, requiresEmailVerification=false
                }
            case .failure(let error):
                print("Sign up failure:", error)
                completion(false, false) // success=false, requiresEmailVerification=false
            }
        }
    }
    
    func signUpWithFamily(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        phoneNumber: String?,
        enrollmentCode: String,
        familyId: Int?,
        completion: @escaping (Bool) -> Void
    ) {
        APIService.shared.signUpWithFamily(
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            phoneNumber: phoneNumber,
            enrollmentCode: enrollmentCode,
            familyId: familyId
        ) { [weak self] result in
            switch result {
            case .success(let response):
                // Save the token
                self?.authToken = response.token
                let saved = KeychainManager.shared.save(token: response.token, for: "currentUser")
                if !saved {
                    print("⚠️ AuthenticationManager: Failed to save token to keychain during family signup")
                }
                
                // Set onboarding state based on backend response
                self?.hasCompletedOnboarding = response.shouldSkipOnboarding
                UserDefaults.standard.set(response.shouldSkipOnboarding, forKey: "hasCompletedOnboarding")
                
                // If they should skip onboarding, mark as authenticated immediately
                if response.shouldSkipOnboarding {
                    self?.isAuthenticated = true
                }
                
                completion(true)
            case .failure(let error):
                print("Family sign up failure:", error)
                completion(false)
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Now set isAuthenticated to true to transition to the main app
        if authToken != nil {
            isAuthenticated = true
        }
    }
    
    func logout() {
        print("🔐❌ AuthenticationManager: LOGOUT CALLED")
        print("🔐❌ AuthenticationManager: Call stack:")
        Thread.callStackSymbols.forEach { print("🔐❌   \($0)") }
        
        KeychainManager.shared.deleteToken(for: "currentUser")
        DispatchQueue.main.async {
            print("🔐❌ AuthenticationManager: Clearing authentication state...")
            self.isAuthenticated = false
            self.isLoading = false
            self.userProfile = nil
            self.hasCompletedOnboarding = true // Reset for next user
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            print("🔐❌ AuthenticationManager: Logout complete - isAuthenticated = false")
        }
    }

    func loginWithApple(authorizationCode: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.loginWithApple(code: authorizationCode) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                    if saved {
                        // After saving the token, fetch the user profile
                        self?.fetchProfileAfterSocialLogin(completion: completion)
                    } else {
                        completion(false)
                    }
                case .failure(let err):
                    print("Apple login failure", err)
                    completion(false)
                }
            }
        }
    }

    func loginWithGoogle(idToken: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.loginWithGoogle(idToken: idToken) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                    if saved {
                        // After saving the token, fetch the user profile
                        self?.fetchProfileAfterSocialLogin(completion: completion)
                    } else {
                        completion(false)
                    }
                case .failure(let err):
                    print("Google login failure", err)
                    completion(false)
                }
            }
        }
    }
    
    private func fetchProfileAfterSocialLogin(completion: @escaping (Bool) -> Void) {
        APIService.shared.getUserProfile { [weak self] profileResult in
            DispatchQueue.main.async {
                switch profileResult {
                case .success(let profile):
                    self?.userProfile = profile
                    
                    // Only set isAuthenticated to true if the user is enrolled
                    if profile.enrolled == true {
                        self?.isAuthenticated = true
                        print("🔐 AuthenticationManager: User is enrolled, setting isAuthenticated = true")
                    } else {
                        print("🔐 AuthenticationManager: User is not enrolled, keeping isAuthenticated = false")
                    }
                    
                    completion(true)
                case .failure(let profileErr):
                    print("Failed to fetch profile after social login:", profileErr)
                    // If profile fetch fails, we can't determine enrollment status
                    // Default to not authenticated so user goes through onboarding
                    completion(true)
                }
            }
        }
    }

    private func decode(jwtToken jwt: String) -> [String: Any] {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return [:] }
        
        var base64String = segments[1]
        
        // Add padding if needed
        while base64String.count % 4 != 0 {
            base64String += "="
        }
        
        guard let data = Data(base64Encoded: base64String) else { return [:] }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return json
            }
        } catch {
            print("Error decoding JWT: \(error)")
        }
        
        return [:]
    }
} 