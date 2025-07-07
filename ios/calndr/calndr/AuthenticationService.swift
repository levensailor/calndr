
import Foundation
import Combine

class AuthenticationService {
    static let shared = AuthenticationService()
    
    private(set) var authManager: AuthenticationManager!
    
    var isLoggedIn: Bool {
        guard authManager != nil else { return false }
        return authManager.isAuthenticated
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