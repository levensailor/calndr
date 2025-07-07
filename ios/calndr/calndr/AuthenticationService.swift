
import Foundation
import Combine

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isLoggedIn: Bool = false
    @Published var familyId: String?

    private var cancellables = Set<AnyCancellable>()
    
    private(set) var authManager: AuthenticationManager! {
        didSet {
            // Once the auth manager is configured, subscribe to its state
            authManager.$isAuthenticated
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isAuthenticated in
                    self?.isLoggedIn = isAuthenticated
                    if isAuthenticated {
                        self?.updateFamilyId()
                    } else {
                        self?.familyId = nil
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
        guard let token = KeychainManager.shared.loadToken(for: "currentUser") else {
            self.familyId = nil
            return
        }
        let decodedToken = decode(jwtToken: token)
        
        // Log the entire decoded profile for debugging
        print("👤 User Profile from Token: \(decodedToken)")
        
        self.familyId = decodedToken["family_id"] as? String
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