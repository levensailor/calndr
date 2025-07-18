
import Foundation
import Combine

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isLoggedIn: Bool = false
    @Published var familyId: String?

    private var cancellables = Set<AnyCancellable>()
    
    private(set) var authManager: AuthenticationManager! {
        didSet {
            print("🔄 AuthenticationService: AuthManager configured, setting up subscription...")
            // Once the auth manager is configured, subscribe to its state
            authManager.$isAuthenticated
                .removeDuplicates() // Prevent duplicate notifications
                .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce rapid changes
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isAuthenticated in
                    guard let self = self else { return }
                    
                    print("🔄 AuthenticationService: isAuthenticated changed to: \(isAuthenticated)")
                    
                    // Only process if the state actually changed
                    if self.isLoggedIn != isAuthenticated {
                        self.isLoggedIn = isAuthenticated
                        
                        if isAuthenticated {
                            print("🔄 AuthenticationService: User authenticated, updating familyId...")
                            self.updateFamilyId()
                        } else {
                            print("🔄 AuthenticationService: User not authenticated, clearing familyId")
                            self.familyId = nil
                        }
                        
                        print("🔄 AuthenticationService: Final state - isLoggedIn: \(self.isLoggedIn), familyId: \(self.familyId ?? "nil")")
                    } else {
                        print("🔄 AuthenticationService: State unchanged, skipping update")
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private init() {
        // This is now private and does not create the authManager
    }

    static func configure(with authManager: AuthenticationManager) {
        shared.authManager = authManager
    }
    
    private func updateFamilyId() {
        print("🔄 AuthenticationService: updateFamilyId() called")
        guard let token = KeychainManager.shared.loadToken(for: "currentUser") else {
            print("🔄❌ AuthenticationService: No token found when updating familyId")
            self.familyId = nil
            return
        }
        
        print("🔄 AuthenticationService: Token found, decoding...")
        let decodedToken = decode(jwtToken: token)
        
        // Log the entire decoded profile for debugging
        print("👤 AuthenticationService: User Profile from Token: \(decodedToken)")
        
        let extractedFamilyId = decodedToken["family_id"] as? String
        self.familyId = extractedFamilyId
        print("🔄 AuthenticationService: Extracted familyId: \(extractedFamilyId ?? "nil")")
        print("🔄 AuthenticationService: Set self.familyId = \(self.familyId ?? "nil")")
    }
    
    private func decode(jwtToken jwt: String) -> [String: Any] {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return [:] }
        
        var base64String = segments[1]
        
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