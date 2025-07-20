import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var username: String?
    @Published var userID: String?
    
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
                let decodedToken = self.decode(jwtToken: token)
                print("🔐 AuthenticationManager: Decoded token: \(decodedToken)")
                
                self.isAuthenticated = true
                self.username = decodedToken["name"] as? String
                self.userID = decodedToken["sub"] as? String
                
                print("🔐 AuthenticationManager: Set isAuthenticated = true, username = \(self.username ?? "nil"), userID = \(self.userID ?? "nil")")
            } else {
                print("🔐 AuthenticationManager: No token found in keychain")
                self.isAuthenticated = false
                self.username = nil
                self.userID = nil
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
                case .success(let token):
                    print("🔐 AuthenticationManager: Login API success, saving token...")
                    let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                    if saved {
                        print("🔐 AuthenticationManager: Token saved successfully")
                        let decodedToken = self?.decode(jwtToken: token) ?? [:]
                        print("🔐 AuthenticationManager: Decoded login token: \(decodedToken)")
                        
                        self?.isAuthenticated = true
                        self?.isLoading = false
                        self?.username = decodedToken["name"] as? String
                        self?.userID = decodedToken["sub"] as? String
                        
                        print("🔐 AuthenticationManager: Login complete - isAuthenticated = true, username = \(self?.username ?? "nil"), userID = \(self?.userID ?? "nil")")
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
    
    func signUp(firstName: String, lastName: String, email: String, password: String, phoneNumber: String?, coparentEmail: String?, coparentPhone: String?, completion: @escaping (Bool) -> Void) {
        APIService.shared.signUp(firstName: firstName, lastName: lastName, email: email, password: password, phoneNumber: phoneNumber, coparentEmail: coparentEmail, coparentPhone: coparentPhone) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                    if saved {
                        self?.isAuthenticated = true
                        self?.isLoading = false
                        let decodedToken = self?.decode(jwtToken: token) ?? [:]
                        self?.username = decodedToken["name"] as? String
                        self?.userID = decodedToken["sub"] as? String
                        completion(true)
                    } else {
                        print("Error: Could not save token to keychain.")
                        self?.isAuthenticated = false
                        self?.isLoading = false
                        completion(false)
                    }
                case .failure(let error):
                    print("Sign up failed: \(error.localizedDescription)")
                    self?.isAuthenticated = false
                    self?.isLoading = false
                    completion(false)
                }
            }
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
            self.username = nil
            self.userID = nil
            print("🔐❌ AuthenticationManager: Logout complete - isAuthenticated = false")
        }
    }

    func loginWithApple(authorizationCode: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.loginWithApple(code: authorizationCode) { result in
            switch result {
            case .success(let token):
                let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                DispatchQueue.main.async {
                    self.isAuthenticated = saved
                    completion(saved)
                }
            case .failure(let err):
                print("Apple login failure", err)
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    func loginWithGoogle(idToken: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.loginWithGoogle(idToken: idToken) { result in
            switch result {
            case .success(let token):
                let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                DispatchQueue.main.async {
                    self.isAuthenticated = saved
                    completion(saved)
                }
            case .failure(let err):
                print("Google login failure", err)
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    func loginWithFacebook(accessToken: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.loginWithFacebook(accessToken: accessToken) { result in
            switch result {
            case .success(let token):
                let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                DispatchQueue.main.async {
                    self.isAuthenticated = saved
                    completion(saved)
                }
            case .failure(let err):
                print("Facebook login failure", err)
                DispatchQueue.main.async {
                    completion(false)
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