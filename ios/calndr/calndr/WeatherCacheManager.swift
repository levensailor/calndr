import Foundation

struct CachedWeatherInfo: Codable {
    let weatherInfo: WeatherInfo
    let timestamp: Date
}

class WeatherCacheManager {
    static let shared = WeatherCacheManager()
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "weatherDataCache"

    private init() {}

    func save(weatherData: [String: WeatherInfo]) {
        var currentCache = load()
        let now = Date()

        for (dateString, info) in weatherData {
            currentCache[dateString] = CachedWeatherInfo(weatherInfo: info, timestamp: now)
        }

        do {
            let data = try JSONEncoder().encode(currentCache)
            userDefaults.set(data, forKey: cacheKey)
            print("Weather cache saved with \(currentCache.count) items.")
        } catch {
            print("Error saving weather cache: \(error)")
        }
    }

    func load() -> [String: CachedWeatherInfo] {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            return [:]
        }

        do {
            let cachedData = try JSONDecoder().decode([String: CachedWeatherInfo].self, from: data)
            return cachedData
        } catch {
            print("Error loading weather cache: \(error)")
            return [:]
        }
    }
    
    func getValidCache() -> [String: WeatherInfo] {
        let allCachedData = load()
        let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 3600)
        
        let validCache = allCachedData.filter { $0.value.timestamp > fortyEightHoursAgo }
        
        print("Loaded \(validCache.count) valid items from weather cache.")
        return validCache.mapValues { $0.weatherInfo }
    }

    func pruneCache() {
        var currentCache = load()
        let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 3600)
        
        let prunedCache = currentCache.filter { $0.value.timestamp > fortyEightHoursAgo }
        
        do {
            let data = try JSONEncoder().encode(prunedCache)
            userDefaults.set(data, forKey: cacheKey)
            print("Pruned weather cache. Removed \(currentCache.count - prunedCache.count) expired items.")
        } catch {
            print("Error pruning weather cache: \(error)")
        }
    }
} 