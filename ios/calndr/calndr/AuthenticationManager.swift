import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var username: String?
    @Published var userID: String?
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        checkAuthentication()
    }
    
    func checkAuthentication() {
        if let token = KeychainManager.shared.loadToken(for: "currentUser") {
            self.isAuthenticated = true
            let decodedToken = decode(jwtToken: token)
            self.username = decodedToken["name"] as? String
            self.userID = decodedToken["sub"] as? String
        } else {
            self.isAuthenticated = false
            self.username = nil
            self.userID = nil
        }
    }
    
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    let saved = KeychainManager.shared.save(token: token, for: "currentUser")
                    if saved {
                        self?.isAuthenticated = true
                        let decodedToken = self?.decode(jwtToken: token) ?? [:]
                        self?.username = decodedToken["name"] as? String
                        self?.userID = decodedToken["sub"] as? String
                        completion(true)
                    } else {
                        print("Error: Could not save token to keychain.")
                        self?.isAuthenticated = false
                        completion(false)
                    }
                case .failure(let error):
                    print("Login failed: \(error.localizedDescription)")
                    self?.isAuthenticated = false
                    completion(false)
                }
            }
        }
    }
    
    func logout() {
        KeychainManager.shared.deleteToken(for: "currentUser")
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.username = nil
            self.userID = nil
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