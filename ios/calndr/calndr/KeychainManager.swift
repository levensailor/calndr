import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.calndr.app" // Unique identifier for your app's keychain entries

    private init() {}

    func save(token: String, for account: String) -> Bool {
        print("🔑🔑🔑 KeychainManager: Saving token for account '\(account)' 🔑🔑🔑")
        print("🔑 Token length: \(token.count) characters")
        print("🔑 Token preview: \(String(token.prefix(20)))...")
        print("🔑 Token suffix: ...\(String(token.suffix(10)))")
        
        guard let data = token.data(using: .utf8) else { 
            print("🔑❌ Failed to convert token to data")
            return false 
        }
        
        print("🔑 Data size: \(data.count) bytes")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary) // Delete any old token first
        print("🔑 Deleted old token (if any)")

        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess
        
        print("🔑 Save status: \(status) (\(success ? "SUCCESS" : "FAILED"))")
        
        return success
    }

    func loadToken(for account: String) -> String? {
        print("🔑🔑🔑 KeychainManager: Loading token for account '\(account)' 🔑🔑🔑")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        print("🔑 Load status: \(status)")

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            print("🔑 Retrieved data size: \(data.count) bytes")
            
            if let token = String(data: data, encoding: .utf8) {
                print("🔑 Retrieved token length: \(token.count) characters")
                print("🔑 Retrieved token preview: \(String(token.prefix(20)))...")
                print("🔑 Retrieved token suffix: ...\(String(token.suffix(10)))")
                return token
            } else {
                print("🔑❌ Failed to convert data to string")
                return nil
            }
        } else {
            print("🔑❌ Failed to load token, status: \(status)")
        }
        
        return nil
    }

    func deleteToken(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
} 