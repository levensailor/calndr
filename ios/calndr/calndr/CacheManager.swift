import Foundation

// MARK: - Cache Configuration
struct CacheConfig {
    static let userProfileCacheExpiry: TimeInterval = 24 * 3600 // 24 hours
    static let custodyRecordsCacheExpiry: TimeInterval = 2 * 3600 // 2 hours
    static let eventRecordsCacheExpiry: TimeInterval = 2 * 3600 // 2 hours
    static let maxCacheSize = 50 // Maximum number of cached items per type
}

// MARK: - Cached Data Structures
struct CachedUserProfile: Codable {
    let profile: UserProfile
    let timestamp: Date
    let familyMembers: [FamilyMember]
}

struct CachedCustodyRecords: Codable {
    let records: [CustodyResponse]
    let year: Int
    let month: Int
    let timestamp: Date
}

struct CachedEventRecords: Codable {
    let events: [Event]
    let year: Int
    let month: Int
    let timestamp: Date
}

// MARK: - Main Cache Manager
class CacheManager {
    static let shared = CacheManager()
    private let userDefaults = UserDefaults.standard
    
    // Cache keys
    private let userProfileKey = "cachedUserProfile"
    private let custodyRecordsKey = "cachedCustodyRecords"
    private let eventRecordsKey = "cachedEventRecords"
    
    private init() {
        // Prune expired cache on initialization
        pruneExpiredCache()
    }
    
    // MARK: - User Profile Caching
    
    func cacheUserProfile(_ profile: UserProfile, familyMembers: [FamilyMember]) {
        let cachedProfile = CachedUserProfile(
            profile: profile,
            timestamp: Date(),
            familyMembers: familyMembers
        )
        
        do {
            let data = try JSONEncoder().encode(cachedProfile)
            userDefaults.set(data, forKey: userProfileKey)
            print("✅ User profile cached successfully")
        } catch {
            print("❌ Error caching user profile: \(error)")
        }
    }
    
    func getCachedUserProfile() -> (profile: UserProfile, familyMembers: [FamilyMember])? {
        guard let data = userDefaults.data(forKey: userProfileKey) else {
            return nil
        }
        
        do {
            let cachedProfile = try JSONDecoder().decode(CachedUserProfile.self, from: data)
            
            // Check if cache is still valid
            let cacheAge = Date().timeIntervalSince(cachedProfile.timestamp)
            if cacheAge > CacheConfig.userProfileCacheExpiry {
                print("⚠️ User profile cache expired (age: \(cacheAge)s)")
                return nil
            }
            
            print("✅ Retrieved cached user profile (age: \(cacheAge)s)")
            return (cachedProfile.profile, cachedProfile.familyMembers)
        } catch {
            print("❌ Error loading cached user profile: \(error)")
            return nil
        }
    }
    
    // MARK: - Custody Records Caching
    
    func cacheCustodyRecords(_ records: [CustodyResponse], year: Int, month: Int) {
        let cachedRecords = CachedCustodyRecords(
            records: records,
            year: year,
            month: month,
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(cachedRecords)
            let key = "\(custodyRecordsKey)_\(year)_\(month)"
            userDefaults.set(data, forKey: key)
            print("✅ Cached \(records.count) custody records for \(year)-\(month)")
        } catch {
            print("❌ Error caching custody records: \(error)")
        }
    }
    
    func getCachedCustodyRecords(year: Int, month: Int) -> [CustodyResponse]? {
        let key = "\(custodyRecordsKey)_\(year)_\(month)"
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let cachedRecords = try JSONDecoder().decode(CachedCustodyRecords.self, from: data)
            
            // Check if cache is still valid
            let cacheAge = Date().timeIntervalSince(cachedRecords.timestamp)
            if cacheAge > CacheConfig.custodyRecordsCacheExpiry {
                print("⚠️ Custody records cache expired for \(year)-\(month) (age: \(cacheAge)s)")
                return nil
            }
            
            print("✅ Retrieved cached custody records for \(year)-\(month) (age: \(cacheAge)s)")
            return cachedRecords.records
        } catch {
            print("❌ Error loading cached custody records: \(error)")
            return nil
        }
    }
    
    // MARK: - Event Records Caching
    
    func cacheEventRecords(_ events: [Event], year: Int, month: Int) {
        let cachedEvents = CachedEventRecords(
            events: events,
            year: year,
            month: month,
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(cachedEvents)
            let key = "\(eventRecordsKey)_\(year)_\(month)"
            userDefaults.set(data, forKey: key)
            print("✅ Cached \(events.count) event records for \(year)-\(month)")
        } catch {
            print("❌ Error caching event records: \(error)")
        }
    }
    
    func getCachedEventRecords(year: Int, month: Int) -> [Event]? {
        let key = "\(eventRecordsKey)_\(year)_\(month)"
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let cachedEvents = try JSONDecoder().decode(CachedEventRecords.self, from: data)
            
            // Check if cache is still valid
            let cacheAge = Date().timeIntervalSince(cachedEvents.timestamp)
            if cacheAge > CacheConfig.eventRecordsCacheExpiry {
                print("⚠️ Event records cache expired for \(year)-\(month) (age: \(cacheAge)s)")
                return nil
            }
            
            print("✅ Retrieved cached event records for \(year)-\(month) (age: \(cacheAge)s)")
            return cachedEvents.events
        } catch {
            print("❌ Error loading cached event records: \(error)")
            return nil
        }
    }
    
    // MARK: - Bulk Operations
    
    func cacheCurrentMonthData(custodyRecords: [CustodyResponse], events: [Event]) {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        // Cache custody records for current month
        cacheCustodyRecords(custodyRecords, year: year, month: month)
        
        // Cache event records for current month
        cacheEventRecords(events, year: year, month: month)
        
        print("✅ Cached current month data: \(custodyRecords.count) custody records, \(events.count) events")
    }
    
    func getCurrentMonthCachedData() -> (custodyRecords: [CustodyResponse], events: [Event]) {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        let cachedCustodyRecords = getCachedCustodyRecords(year: year, month: month) ?? []
        let cachedEvents = getCachedEventRecords(year: year, month: month) ?? []
        
        return (cachedCustodyRecords, cachedEvents)
    }
    
    // MARK: - Cache Management
    
    func clearAllCache() {
        // Clear user profile cache
        userDefaults.removeObject(forKey: userProfileKey)
        
        // Clear all custody records cache
        let custodyKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(custodyRecordsKey) }
        custodyKeys.forEach { userDefaults.removeObject(forKey: $0) }
        
        // Clear all event records cache
        let eventKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(eventRecordsKey) }
        eventKeys.forEach { userDefaults.removeObject(forKey: $0) }
        
        print("🗑️ All cache cleared")
    }
    
    func clearExpiredCache() {
        pruneExpiredCache()
    }
    
    private func pruneExpiredCache() {
        let now = Date()
        var prunedCount = 0
        
        // Prune custody records cache
        let custodyKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(custodyRecordsKey) }
        for key in custodyKeys {
            if let data = userDefaults.data(forKey: key),
               let cachedRecords = try? JSONDecoder().decode(CachedCustodyRecords.self, from: data) {
                let cacheAge = now.timeIntervalSince(cachedRecords.timestamp)
                if cacheAge > CacheConfig.custodyRecordsCacheExpiry {
                    userDefaults.removeObject(forKey: key)
                    prunedCount += 1
                }
            }
        }
        
        // Prune event records cache
        let eventKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(eventRecordsKey) }
        for key in eventKeys {
            if let data = userDefaults.data(forKey: key),
               let cachedEvents = try? JSONDecoder().decode(CachedEventRecords.self, from: data) {
                let cacheAge = now.timeIntervalSince(cachedEvents.timestamp)
                if cacheAge > CacheConfig.eventRecordsCacheExpiry {
                    userDefaults.removeObject(forKey: key)
                    prunedCount += 1
                }
            }
        }
        
        // Prune user profile cache
        if let data = userDefaults.data(forKey: userProfileKey),
           let cachedProfile = try? JSONDecoder().decode(CachedUserProfile.self, from: data) {
            let cacheAge = now.timeIntervalSince(cachedProfile.timestamp)
            if cacheAge > CacheConfig.userProfileCacheExpiry {
                userDefaults.removeObject(forKey: userProfileKey)
                prunedCount += 1
            }
        }
        
        if prunedCount > 0 {
            print("🧹 Pruned \(prunedCount) expired cache entries")
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() -> [String: Any] {
        let custodyKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(custodyRecordsKey) }
        let eventKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(eventRecordsKey) }
        let hasUserProfile = userDefaults.data(forKey: userProfileKey) != nil
        
        return [
            "userProfileCached": hasUserProfile,
            "custodyRecordsCached": custodyKeys.count,
            "eventRecordsCached": eventKeys.count,
            "totalCacheEntries": custodyKeys.count + eventKeys.count + (hasUserProfile ? 1 : 0)
        ]
    }
} 