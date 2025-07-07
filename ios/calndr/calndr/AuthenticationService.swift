
import Foundation
import Combine

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isLoggedIn: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var authManager: AuthenticationManager! {
        didSet {
            // Once the auth manager is configured, subscribe to its state
            authManager.$isAuthenticated
                .assign(to: \.isLoggedIn, on: self)
                .store(in: &cancellables)
        }
    }
    
    var familyId: String? {
        guard let token = KeychainManager.shared.loadToken(for: "currentUser") else { return nil }
        let decodedToken = decode(jwtToken: token)
        return decodedToken["family_id"] as? String
    }
    
    private init() {
        // This is now private and does not create the authManager
    }

    static func configure(with authManager: AuthenticationManager) {
        shared.authManager = authManager
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