import Foundation
import UIKit

enum APIError: Error, LocalizedError, Equatable {
    case unauthorized
    case invalidResponse
    case requestFailed(statusCode: Int)
    case themeNotFound
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized: Please check your credentials and try again."
        case .invalidResponse:
            return "Invalid response from the server. Please try again later."
        case .requestFailed(let statusCode):
            return "The request failed with a status code: \(statusCode)."
        case .themeNotFound:
            return "The selected theme is no longer available."
        case .invalidURL:
            return "The URL provided was invalid."
        }
    }
}

// MARK: - Auth Token Response
struct AuthTokenResponse: Codable {
    let access_token: String
    let token_type: String
}

struct UserRegistrationRequest: Codable {
    let first_name: String
    let last_name: String
    let email: String
    let password: String
    let phone_number: String?
    let coparent_email: String?
    let coparent_phone: String?
}

struct UserRegistrationResponse: Codable {
    let user_id: String
    let family_id: String
    let access_token: String
    let token_type: String
    let message: String
    let should_skip_onboarding: Bool?
    
    // Computed property to provide default value
    var shouldSkipOnboarding: Bool {
        return should_skip_onboarding ?? false
    }
}

struct CoParentCreateRequest: Codable {
    let first_name: String
    let last_name: String
    let email: String
    let phone_number: String?
}

struct UserResponse: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let phone_number: String?
    let family_id: String
    let status: String?
}

struct PhoneVerificationResponse: Codable {
    let success: Bool
    let message: String
    let expires_in: Int?
    let retry_after: Int?
}

struct EnrollmentCodeResponse: Codable {
    let success: Bool
    let message: String?
    let enrollmentCode: String?
    let familyId: Int?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case enrollmentCode = "enrollment_code"
        case familyId = "family_id"
    }
}

struct EmailVerificationResponse: Codable {
    let success: Bool
    let message: String
    let expires_in: Int?
    let user_id: String?
}

struct ChildCreateRequest: Codable {
    let first_name: String
    let last_name: String
    let dob: String
}

struct ChildResponse: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let dob: String
    let family_id: String
}

struct TokenResponse: Codable {
    let access_token: String
}

class APIService {
    static let shared = APIService()
    private let baseURL = URL(string: "https://staging.calndr.club/api/v1")!

    private init() {}

    // Helper function to create an authenticated request
    private func createAuthenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        print("🔐 APIService: Creating authenticated request for: \(url.path)")
        
        if let token = KeychainManager.shared.loadToken(for: "currentUser") {
            print("🔐 APIService: Token found in keychain (length: \(token.count))")
            print("🔐 Token preview: \(String(token.prefix(20)))...")
            print("🔐 Token suffix: ...\(String(token.suffix(10)))")
            
            // Validate token before using it
            if isTokenValid(token) {
                print("🔐✅ APIService: Token is valid, adding to request")
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔐✅ Authorization header set: Bearer \(String(token.prefix(20)))...")
            } else {
                print("🔐❌ APIService: Token is expired or invalid, not adding to request")
                print("🔐❌ Token segments: \(token.components(separatedBy: ".").count)")
                // Note: The request will proceed without Authorization header,
                // which will result in 401 and trigger logout in the caller
            }
        } else {
            print("🔐❌ APIService: No token found in keychain")
        }
        return request
    }
    
    // Helper function to validate JWT token
    private func isTokenValid(_ token: String) -> Bool {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { 
            print("🔐❌ APIService: Token has invalid format")
            return false
        }
        
        var base64String = segments[1]
        
        // Add padding if needed
        while base64String.count % 4 != 0 {
            base64String += "="
        }
        
        guard let data = Data(base64Encoded: base64String) else { 
            print("🔐❌ APIService: Unable to decode token payload")
            return false
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let exp = json["exp"] as? TimeInterval {
                let currentTime = Date().timeIntervalSince1970
                let timeUntilExpiry = exp - currentTime
                // Add 60 second tolerance for clock skew between client and server
                let clockSkewTolerance: TimeInterval = 60
                let isValid = exp > (currentTime - clockSkewTolerance)
                
                print("🔐 APIService: Token expiry: \(exp) (\(Date(timeIntervalSince1970: exp)))")
                print("🔐 APIService: Current time: \(currentTime) (\(Date()))")
                print("🔐 APIService: Time until expiry: \(timeUntilExpiry) seconds (\(timeUntilExpiry/60) minutes)")
                print("🔐 APIService: Clock skew tolerance: \(clockSkewTolerance) seconds")
                print("🔐 APIService: Token valid (with tolerance): \(isValid)")
                
                return isValid
            }
        } catch {
            print("🔐❌ APIService: Error decoding token: \(error)")
        }
        
        return false
    }

    func inviteCoParent(firstName: String, lastName: String, email: String, phoneNumber: String?, completion: @escaping (Result<UserResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/family/invite")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = CoParentCreateRequest(first_name: firstName, last_name: lastName, email: email, phone_number: phoneNumber)

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }

            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }

            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                completion(.success(userResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func createChild(firstName: String, lastName: String, dob: String, completion: @escaping (Result<ChildResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/children/")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ChildCreateRequest(first_name: firstName, last_name: lastName, dob: dob)

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }

            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }

            do {
                let childResponse = try JSONDecoder().decode(ChildResponse.self, from: data)
                completion(.success(childResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchEvents(from startDate: String, to endDate: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/events/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let url = components.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for fetching events"])))
            return
        }
        
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
//            // Log the raw data as a string for debugging
//            if let jsonString = String(data: data, encoding: .utf8) {
//                print("--- Raw JSON for fetchEvents ---")
//                print(jsonString)
//                print("------------------------------")
//            }

            if httpResponse.statusCode == 401 {
                // Unauthorized, likely bad token
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }

            do {
                let events = try JSONDecoder().decode([Event].self, from: data)
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Fetch current and future weather data (forecast)
    func fetchWeather(latitude: Double, longitude: Double, startDate: String, endDate: String, completion: @escaping (Result<[String: WeatherInfo], Error>) -> Void) {
        // --- Adjust start date: always begin 2 days before "today" so we include yesterday & today in forecast ---
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let adjustedStartDate = dateFormatter.string(from: twoDaysAgo)

        var components = URLComponents(url: baseURL.appendingPathComponent("/weather/\(latitude)/\(longitude)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: adjustedStartDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit")
        ]

        guard let url = components.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("Weather API URL: \(url.absoluteString)")
        let request = createAuthenticatedRequest(url: url)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Weather API network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                print("Weather API: Invalid response from server")
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
//            // Log the raw data as a string for debugging
//            if let jsonString = String(data: data, encoding: .utf8) {
//                print("--- Raw JSON for fetchWeather (Status: \(httpResponse.statusCode)) ---")
//                print(jsonString)
//                print("----------------------------------------------------------")
//            }
            
            if httpResponse.statusCode == 401 {
                print("Weather API: Unauthorized (401)")
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Weather API: HTTP error \(httpResponse.statusCode)")
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"])))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
                print("Raw weather API response - days: \(apiResponse.daily.time.count)")
                for (index, date) in apiResponse.daily.time.enumerated() {
                    let temp = apiResponse.daily.temperature_2m_max[index]
                    print("  \(date): temp=\(temp ?? -999)°F")
                }
                
                let weatherInfos = self.transformWeatherData(from: apiResponse)
                print("Successfully decoded weather data for \(weatherInfos.count) days")
                completion(.success(weatherInfos))
            } catch {
                print("Weather API: JSON decode error - \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Fetch historic weather data (past 6 months)
    func fetchHistoricWeather(latitude: Double, longitude: Double, startDate: String, endDate: String, completion: @escaping (Result<[String: WeatherInfo], Error>) -> Void) {
        // --- Adjust end date: stop 2 days before the supplied endDate so forecast handles the remainder ---
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var adjustedEndDate = endDate
        if let providedEnd = dateFormatter.date(from: endDate),
           let twoDaysBefore = Calendar.current.date(byAdding: .day, value: -2, to: providedEnd) {
            adjustedEndDate = dateFormatter.string(from: twoDaysBefore)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("/weather/historic/\(latitude)/\(longitude)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: adjustedEndDate),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit")
        ]

        guard let url = components.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for historic weather"])))
            return
        }
        
        print("Historic Weather API URL: \(url.absoluteString)")
        let request = createAuthenticatedRequest(url: url)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Historic Weather API network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                print("Historic Weather API: Invalid response from server")
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
//            // Log the raw data as a string for debugging
//            if let jsonString = String(data: data, encoding: .utf8) {
//                print("--- Raw JSON for fetchHistoricWeather (Status: \(httpResponse.statusCode)) ---")
//                print(jsonString)
//                print("----------------------------------------------------------------")
//            }
            
            if httpResponse.statusCode == 401 {
                print("Historic Weather API: Unauthorized (401)")
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Historic Weather API: HTTP error \(httpResponse.statusCode)")
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"])))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
                print("Raw historic weather API response - days: \(apiResponse.daily.time.count)")
                for (index, date) in apiResponse.daily.time.enumerated() {
                    let temp = apiResponse.daily.temperature_2m_max[index]
                    print("  \(date): temp=\(temp ?? -999)°F")
                }
                
                let weatherInfos = self.transformWeatherData(from: apiResponse)
                print("Successfully decoded historic weather data for \(weatherInfos.count) days")
                completion(.success(weatherInfos))
            } catch {
                print("Historic Weather API: JSON decode error - \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func transformWeatherData(from apiResponse: WeatherAPIResponse) -> [String: WeatherInfo] {
        var weatherInfos: [String: WeatherInfo] = [:]
        
        let daily = apiResponse.daily
        for i in 0..<daily.time.count {
            let dateString = daily.time[i]
            
            // Check if we have valid temperature data - skip this day if temperature is nil
            guard let temp = daily.temperature_2m_max[i], temp > -200 else {
                print("⚠️ Skipping weather data for \(dateString) - invalid or missing temperature: \(daily.temperature_2m_max[i] ?? -999)")
                continue
            }
            
            // Use reasonable defaults for precipitation and cloud cover if nil
            let precip = daily.precipitation_probability_mean[i] ?? 0.0
            let cover = daily.cloudcover_mean[i] ?? 50.0 // Default to partly cloudy
            
            let info = WeatherInfo(
                temperature: temp,
                precipitation: precip,
                cloudCover: cover
            )
            weatherInfos[dateString] = info
            print("✅ Added weather data for \(dateString): \(temp)°F")
        }
        
        print("📊 Total weather days processed: \(weatherInfos.count)")
        return weatherInfos
    }

    // Placeholder for fetching school events
    func fetchSchoolEvents(from startDate: String, to endDate: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/events/school/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let url = components.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for fetching school events"])))
            return
        }
        
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }

            if httpResponse.statusCode == 401 {
                // Unauthorized, likely bad token
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }

            do {
                let events = try JSONDecoder().decode([Event].self, from: data)
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchDaycareEvents(from startDate: String, to endDate: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/events/daycare/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let url = components.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for fetching daycare events"])))
            return
        }
        
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }

            if httpResponse.statusCode == 401 {
                // Unauthorized, likely bad token
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }

            do {
                let events = try JSONDecoder().decode([Event].self, from: data)
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - User Preferences
    

    
    // MARK: - Custody API (New dedicated custody endpoints)
    
    func fetchCustodyRecords(year: Int, month: Int, completion: @escaping (Result<[CustodyResponse], Error>) -> Void) {
        fetchCustodyRecordsWithRetry(year: year, month: month, retryCount: 0, maxRetries: 3, completion: completion)
    }
    
    private func fetchCustodyRecordsWithRetry(year: Int, month: Int, retryCount: Int, maxRetries: Int, completion: @escaping (Result<[CustodyResponse], Error>) -> Void) {
        print("🏁🏁🏁 STARTING fetchCustodyRecords for \(year)-\(month) (attempt \(retryCount + 1)/\(maxRetries + 1)) 🏁🏁🏁")
        
        let url = baseURL.appendingPathComponent("/custody/\(year)/\(month)")
        print("🏁 Final URL: \(url.absoluteString)")
        
        let request = createAuthenticatedRequest(url: url)
        
        // Create a custom URLSession with shorter timeout for custody records
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30 seconds timeout
        config.timeoutIntervalForResource = 60.0 // 60 seconds total timeout
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                // Handle network errors with retry logic
                if retryCount < maxRetries {
                    let delay = Double(retryCount + 1) * 2.0 // Exponential backoff: 2s, 4s, 6s
                    print("🔄 Network error detected: \(error.localizedDescription). Retrying in \(delay) seconds... (attempt \(retryCount + 1)/\(maxRetries))")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.fetchCustodyRecordsWithRetry(year: year, month: month, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                    }
                    return
                }
                
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            // Log the raw data as a string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄📄📄 Raw JSON for fetchCustodyRecords (\(year)-\(month)) 📄📄📄")
                print("📄 URL: \(url.absoluteString)")
                print("📄 Status Code: \(httpResponse.statusCode)")
                print("📄 Response: \(jsonString)")
                print("📄📄📄 End Raw JSON 📄📄📄")
            }

            if httpResponse.statusCode == 401 {
                print("🚨 Received 401 Unauthorized for custody records")
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            // Check for other error status codes before JSON decoding
            if httpResponse.statusCode >= 400 {
                print("🚨 Received HTTP error status: \(httpResponse.statusCode)")
                
                // Try to extract error message from JSON
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("🚨 Error response body: \(jsonString)")
                }
                
                // Handle 504 Gateway Timeout with retry logic
                if httpResponse.statusCode == 504 && retryCount < maxRetries {
                    let delay = Double(retryCount + 1) * 2.0 // Exponential backoff: 2s, 4s, 6s
                    print("🔄 504 Gateway Timeout detected. Retrying in \(delay) seconds... (attempt \(retryCount + 1)/\(maxRetries))")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.fetchCustodyRecordsWithRetry(year: year, month: month, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                    }
                    return
                }
                
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])))
                return
            }

            do {
                print("📄 Attempting to decode as [CustodyResponse] array...")
                let custodyRecords = try JSONDecoder().decode([CustodyResponse].self, from: data)
                print("✅ Successfully decoded \(custodyRecords.count) custody records")
                completion(.success(custodyRecords))
            } catch {
                print("❌ JSON Decoding Error for \(year)-\(month): \(error)")
                if let decodingError = error as? DecodingError {
                    print("❌ Detailed Decoding Error: \(decodingError)")
                    
                    // Try to decode as error response first
                    print("📄 Checking if this is an error response...")
                    do {
                        let errorResponse = try JSONDecoder().decode([String: String].self, from: data)
                        if let errorMessage = errorResponse["error"] {
                            print("🚨 Server returned error response: \(errorMessage)")
                            print("🚨 HTTP Status was: \(httpResponse.statusCode)")
                            
                            // Check if this is an auth error
                            if httpResponse.statusCode == 401 {
                                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized: \(errorMessage)"])))
                            } else {
                                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"])))
                            }
                            return
                        }
                    } catch {
                        print("📄 Not an error response format, trying other strategies...")
                    }
                    
                    // Try to decode as a single object or different structure
                    print("📄 Attempting alternative decoding strategies...")
                    
                    // Try decoding as a single CustodyResponse
                    do {
                        let singleRecord = try JSONDecoder().decode(CustodyResponse.self, from: data)
                        print("✅ Successfully decoded as single CustodyResponse, wrapping in array")
                        completion(.success([singleRecord]))
                        return
                    } catch {
                        print("❌ Single object decode also failed: \(error)")
                    }
                    
                    // Try decoding as a dictionary with data field
                    do {
                        let responseWrapper = try JSONDecoder().decode([String: [CustodyResponse]].self, from: data)
                        if let records = responseWrapper["data"] ?? responseWrapper["custody_records"] ?? responseWrapper["records"] {
                            print("✅ Successfully decoded from wrapper object with \(records.count) records")
                            completion(.success(records))
                            return
                        }
                    } catch {
                        print("❌ Wrapper object decode also failed: \(error)")
                    }
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateHandoffDayOnly(for date: String, handoffDay: Bool, completion: @escaping (Result<CustodyResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/custody/")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Note: This function should get the current custodian_id from the caller
        // For now, we'll create a minimal request - this function may need refactoring
        let requestBody = [
            "date": date,
            "handoff_day": handoffDay
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("--- Raw JSON for updateHandoffDayOnly (Status: \(httpResponse.statusCode)) ---")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString)
                }
                print("--- End Raw JSON ---")
            }
            
            do {
                let custodyResponse = try JSONDecoder().decode(CustodyResponse.self, from: data)
                completion(.success(custodyResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateCustodyRecord(for date: String, custodianId: String, handoffDay: Bool? = nil, handoffTime: String? = nil, handoffLocation: String? = nil, completion: @escaping (Result<CustodyResponse, Error>) -> Void) {
        
        print("🌐🌐🌐 APIService.updateCustodyRecord called 🌐🌐🌐")
        print("🌐 Parameters: date='\(date)', custodianId='\(custodianId)', handoffDay=\(handoffDay?.description ?? "nil"), handoffTime='\(handoffTime ?? "nil")', handoffLocation='\(handoffLocation ?? "nil")'")
        
        // First try to update existing record using PUT
        let updateUrl = baseURL.appendingPathComponent("/custody/date/\(date)")
        print("🌐 Request URL: \(updateUrl.absoluteString)")
        
        var updateRequest = createAuthenticatedRequest(url: updateUrl)
        updateRequest.httpMethod = "PUT"
        updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let custodyRequest = CustodyRequest(date: date, custodian_id: custodianId, handoff_day: handoffDay, handoff_time: handoffTime, handoff_location: handoffLocation)
        
        print("🌐 Request payload: \(custodyRequest)")
        
        do {
            let requestData = try JSONEncoder().encode(custodyRequest)
            updateRequest.httpBody = requestData
            
            if let jsonString = String(data: requestData, encoding: .utf8) {
                print("🌐 Request JSON: \(jsonString)")
            }
        } catch {
            print("🌐❌ Failed to encode custody request: \(error)")
            completion(.failure(error))
            return
        }

        print("🌐 Sending PUT request...")
        
        // Configure request timeout for slow custody operations
        updateRequest.timeoutInterval = 120 // 2 minutes for custody updates
        
        URLSession.shared.dataTask(with: updateRequest) { data, response, error in
            print("🌐 PUT Response received")
            
            if let error = error {
                print("🌐❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🌐❌ Invalid response - not HTTP")
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server - not HTTP"])))
                return
            }
            
            print("🌐 HTTP Status Code: \(httpResponse.statusCode)")
            print("🌐 Response Headers: \(httpResponse.allHeaderFields)")
            
            guard let data = data else {
                print("🌐❌ No data received")
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received on custody update"])))
                return
            }
            
            print("🌐 Response data size: \(data.count) bytes")

            // Log the raw data as a string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for updateCustodyRecord PUT (Status: \(httpResponse.statusCode)) ---")
                print(jsonString)
                print("--------------------------------------------------------------------")
            }

            if (200...299).contains(httpResponse.statusCode) {
                // Update successful
                print("🌐✅ PUT request successful (status: \(httpResponse.statusCode))")
                do {
                    let updatedCustody = try JSONDecoder().decode(CustodyResponse.self, from: data)
                    print("🌐✅ Successfully decoded custody response: \(updatedCustody)")
                    completion(.success(updatedCustody))
                } catch {
                    print("🌐❌ Failed to decode custody response: \(error)")
                    completion(.failure(error))
                }
            } else if httpResponse.statusCode == 404 {
                // Record doesn't exist, try to create it with POST
                print("🌐⚠️ Custody record doesn't exist for \(date) (404), creating new one...")
                self.createCustodyRecord(for: date, custodianId: custodianId, handoffDay: handoffDay, handoffTime: handoffTime, handoffLocation: handoffLocation, completion: completion)
            } else {
                print("🌐❌ PUT request failed with status: \(httpResponse.statusCode)")
                
                // Handle specific error cases
                if httpResponse.statusCode == 504 {
                    print("🌐⏰ Gateway Timeout (504) - Backend server took too long to respond")
                    print("🌐⏰ This suggests server performance issues or complex custody logic")
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server timeout - custody update took too long to process. Please try again."])))
                } else if httpResponse.statusCode >= 500 {
                    print("🌐❌ Server Error (\(httpResponse.statusCode)) - Backend infrastructure issue")
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(httpResponse.statusCode)) - please try again later"])))
                } else {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update custody record"])))
                }
            }
        }.resume()
    }

    // MARK: - Medical - Presets
    func fetchMedicationPresets(completion: @escaping (Result<[MedicationPreset], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medications/presets")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            do {
                struct PresetList: Codable { let presets: [MedicationPreset] }
                let decoded = try JSONDecoder().decode(PresetList.self, from: data)
                completion(.success(decoded.presets))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func createCustodyRecord(for date: String, custodianId: String, handoffDay: Bool? = nil, handoffTime: String? = nil, handoffLocation: String? = nil, completion: @escaping (Result<CustodyResponse, Error>) -> Void) {
        
        print("🌐🌐🌐 APIService.createCustodyRecord called (fallback from PUT 404) 🌐🌐🌐")
        print("🌐 Parameters: date='\(date)', custodianId='\(custodianId)', handoffDay=\(handoffDay?.description ?? "nil"), handoffTime='\(handoffTime ?? "nil")', handoffLocation='\(handoffLocation ?? "nil")'")
        
        let url = baseURL.appendingPathComponent("/custody/")
        print("🌐 POST URL: \(url.absoluteString)")
        
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let custodyRequest = CustodyRequest(date: date, custodian_id: custodianId, handoff_day: handoffDay, handoff_time: handoffTime, handoff_location: handoffLocation)
        
        print("🌐 POST Request payload: \(custodyRequest)")
        
        do {
            let requestData = try JSONEncoder().encode(custodyRequest)
            request.httpBody = requestData
            
            if let jsonString = String(data: requestData, encoding: .utf8) {
                print("🌐 POST Request JSON: \(jsonString)")
            }
        } catch {
            print("🌐❌ Failed to encode POST custody request: \(error)")
            completion(.failure(error))
            return
        }
        
        print("🌐 Sending POST request...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server - not HTTP"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received on custody creation"])))
                return
            }

            // Log the raw data as a string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for createCustodyRecord POST (Status: \(httpResponse.statusCode)) ---")
                print(jsonString)
                print("--------------------------------------------------------------------")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create custody record"])))
                return
            }
            
            do {
                let createdCustody = try JSONDecoder().decode(CustodyResponse.self, from: data)
                completion(.success(createdCustody))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func bulkCreateCustodyRecords(_ records: [CustodyRequest], completion: @escaping (Result<BulkCustodyResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/custody/bulk")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(records)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server - not HTTP"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received on bulk custody creation"])))
                return
            }

            // Log the raw data as a string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for bulkCreateCustodyRecords (Status: \(httpResponse.statusCode)) ---")
                print(jsonString)
                print("--------------------------------------------------------------------")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to bulk create custody records"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(BulkCustodyResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Legacy Custody (REMOVED - use new custody API above)
    // The old updateCustody function has been removed to prevent accidental use.
    // Use updateCustodyRecord() instead.
    
    func deleteEvent(eventId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/events/\(eventId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "APIService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server on delete"])))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func saveEvent(eventDetails: [String: Any], existingEvent: Event?, completion: @escaping (Result<Event, Error>) -> Void) {
        let url: URL
        let httpMethod: String

        if let eventToUpdate = existingEvent {
            url = baseURL.appendingPathComponent("/events/\(eventToUpdate.id)")
            httpMethod = "PUT"
        } else {
            url = baseURL.appendingPathComponent("/events/")
            httpMethod = "POST"
        }
        
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = httpMethod
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: eventDetails)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server - not HTTP"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received on save"])))
                return
            }

            // Log the raw data as a string for debugging, especially on failure
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for saveEvent (Status: \(httpResponse.statusCode)) ---")
                print(jsonString)
                print("---------------------------------")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            do {
                let savedEvent = try JSONDecoder().decode(Event.self, from: data)
                completion(.success(savedEvent))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Notification Emails
    
    func fetchNotificationEmails(completion: @escaping (Result<[NotificationEmail], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/notifications/emails")
        let request = createAuthenticatedRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received for notification emails"])))
                return
            }
            do {
                let emails = try JSONDecoder().decode([NotificationEmail].self, from: data)
                completion(.success(emails))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func addNotificationEmail(email: String, completion: @escaping (Result<NotificationEmail, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/notifications/emails")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response data from add email"])))
                return
            }
            do {
                let newEmail = try JSONDecoder().decode(NotificationEmail.self, from: data)
                completion(.success(newEmail))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateNotificationEmail(emailId: Int, newEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/notifications/emails/\(emailId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": newEmail]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "APIService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response on update email"])))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func deleteNotificationEmail(emailId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/notifications/emails/\(emailId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "APIService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response on delete email"])))
                return
            }
            completion(.success(()))
        }.resume()
    }

    // MARK: - Authentication
    
    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // The API expects form URL-encoded data for this endpoint
        let bodyString = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Login failed"])))
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
                completion(.success(tokenResponse.access_token))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func signUp(firstName: String, lastName: String, email: String, password: String, phoneNumber: String?, coparentEmail: String?, coparentPhone: String? = nil, completion: @escaping (Result<(token: String, shouldSkipOnboarding: Bool), Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "password": password,
            "phone_number": phoneNumber
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if httpResponse.statusCode == 409 {
                completion(.failure(NSError(domain: "APIService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User with this email already exists"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Registration failed"])))
                return
            }
            
            do {
                let registrationResponse = try JSONDecoder().decode(UserRegistrationResponse.self, from: data)
                completion(.success((token: registrationResponse.access_token, shouldSkipOnboarding: registrationResponse.shouldSkipOnboarding)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func signUpWithFamily(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        phoneNumber: String?,
        enrollmentCode: String,
        familyId: Int?,
        completion: @escaping (Result<(token: String, shouldSkipOnboarding: Bool), Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent("/auth/register-with-family")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "password": password,
            "phone_number": phoneNumber,
            "enrollment_code": enrollmentCode,
            "family_id": familyId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if httpResponse.statusCode == 409 {
                completion(.failure(NSError(domain: "APIService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User with this email already exists"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Family registration failed"])))
                }
                return
            }
            
            do {
                let registrationResponse = try JSONDecoder().decode(UserRegistrationResponse.self, from: data)
                completion(.success((token: registrationResponse.access_token, shouldSkipOnboarding: registrationResponse.shouldSkipOnboarding)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func updatePassword(passwordUpdate: PasswordUpdate, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/me/password")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try? JSONEncoder().encode(passwordUpdate)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                if statusCode == 403 {
                    completion(.failure(NSError(domain: "APIService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invalid current password"])))
                } else {
                    completion(.failure(NSError(domain: "APIService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update password"])))
                }
                return
            }
            completion(.success(()))
        }.resume()
    }

    func updateUserProfile(userUpdate: UserProfileUpdate, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/profile")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(userUpdate)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update profile"])))
                return
            }
            
            do {
                let updatedProfile = try JSONDecoder().decode(UserProfile.self, from: data)
                completion(.success(updatedProfile))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func updateDeviceToken(token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/me/device-token")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        if let authToken = KeychainManager.shared.loadToken(for: "currentUser") {
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        } else {
            completion(.failure(APIError.unauthorized))
            return
        }
        
        let body = "token=\(token)".data(using: .utf8)
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }
        task.resume()
    }
    
    func updateLastSignin(completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/me/last-signin")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        
        print("🌐 Making API call to update last signin: \(url)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }

    func fetchCustodianNames(completion: @escaping (Result<[Custodian], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/family/custodians")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error fetching custodian names: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response for custodian names")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for fetchCustodianNames ---")
                print("Status Code: \(httpResponse.statusCode)")
                print("Response: \(jsonString)")
                print("--------------------------------------")
            } else {
                print("❌ No data received for custodian names (Status: \(httpResponse.statusCode))")
            }
            
            if httpResponse.statusCode == 401 {
                print("❌ Unauthorized access to custodian names")
                completion(.failure(APIError.unauthorized))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error \(httpResponse.statusCode) fetching custodian names")
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                print("❌ No data in successful response for custodian names")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                let custodians = try JSONDecoder().decode([Custodian].self, from: data)
                completion(.success(custodians))
            } catch {
                print("❌ JSON decoding error for custodian names: \(error)")
                if let decodingError = error as? DecodingError {
                    print("❌ Detailed decoding error: \(decodingError)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchFamilyMemberEmails(completion: @escaping (Result<[FamilyMemberEmail], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/family/emails")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                let familyEmails = try JSONDecoder().decode([FamilyMemberEmail].self, from: data)
                completion(.success(familyEmails))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchFamilyMembers(completion: @escaping (Result<[FamilyMember], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/family/members")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                let familyMembers = try JSONDecoder().decode([FamilyMember].self, from: data)
                completion(.success(familyMembers))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - User Profile
    
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func fetchUserProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/profile")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            // Log the raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for fetchUserProfile ---")
                print("Status Code: \(httpResponse.statusCode)")
                print(jsonString)
                print("------------------------------------")
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"])))
                return
            }
            
            do {
                let userProfile = try JSONDecoder().decode(UserProfile.self, from: data)
                completion(.success(userProfile))
            } catch {
                print("JSON Decoding Error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Failed to decode JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    func uploadProfilePhoto(image: UIImage, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/user/profile/photo")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        
        // Resize image to maximum 800x800 pixels to reduce file size
        let maxSize = CGSize(width: 800, height: 800)
        guard let resizedImage = resizeImage(image, to: maxSize) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"])))
            return
        }
        
        // Convert resized image to JPEG data with higher compression
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        // Log the file size for debugging
        let fileSize = imageData.count
        let fileSizeInKB = Double(fileSize) / 1024.0
        print("Upload image size: \(String(format: "%.2f", fileSizeInKB)) KB")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            if httpResponse.statusCode == 413 {
                completion(.failure(NSError(domain: "APIService", code: 413, userInfo: [NSLocalizedDescriptionKey: "Image too large. Please try a smaller image."])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(httpResponse.statusCode)"])))
                return
            }
            
            do {
                let updatedProfile = try JSONDecoder().decode(UserProfile.self, from: data)
                completion(.success(updatedProfile))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Authentication
    
    func validatePassword(password: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/validate-password")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = PasswordValidation(password: password)
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(.success(true))
            } else {
                // Assuming 401 or other error codes mean invalid password
                completion(.success(false))
            }
        }.resume()
    }
    
    // MARK: - Babysitters
    
    func fetchBabysitters(completion: @escaping (Result<[Babysitter], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/babysitters")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let babysitters = try JSONDecoder().decode([Babysitter].self, from: data)
                completion(.success(babysitters))
            } catch {
                print("Failed to decode babysitters: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createBabysitter(_ babysitter: BabysitterCreate, completion: @escaping (Result<Babysitter, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/babysitters")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(babysitter)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let createdBabysitter = try JSONDecoder().decode(Babysitter.self, from: data)
                completion(.success(createdBabysitter))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateBabysitter(id: Int, babysitter: BabysitterCreate, completion: @escaping (Result<Babysitter, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/babysitters/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(babysitter)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let updatedBabysitter = try JSONDecoder().decode(Babysitter.self, from: data)
                completion(.success(updatedBabysitter))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteBabysitter(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/babysitters/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete babysitter"])))
            }
        }.resume()
    }
    
    // MARK: - Emergency Contacts
    
    func fetchEmergencyContacts(completion: @escaping (Result<[EmergencyContact], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/emergency-contacts")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let contacts = try JSONDecoder().decode([EmergencyContact].self, from: data)
                completion(.success(contacts))
            } catch {
                print("Failed to decode emergency contacts: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createEmergencyContact(_ contact: EmergencyContactCreate, completion: @escaping (Result<EmergencyContact, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/emergency-contacts")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(contact)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let createdContact = try JSONDecoder().decode(EmergencyContact.self, from: data)
                completion(.success(createdContact))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateEmergencyContact(id: Int, contact: EmergencyContactCreate, completion: @escaping (Result<EmergencyContact, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/emergency-contacts/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(contact)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let updatedContact = try JSONDecoder().decode(EmergencyContact.self, from: data)
                completion(.success(updatedContact))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteEmergencyContact(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/emergency-contacts/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete emergency contact"])))
            }
        }.resume()
    }
    
    // MARK: - Group Chat
    
    func createOrGetGroupChat(contactType: String, contactId: Int, completion: @escaping (Result<GroupChatResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/group-chat")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatData = GroupChatCreate(contact_type: contactType, contact_id: contactId, group_identifier: nil)
        
        do {
            request.httpBody = try JSONEncoder().encode(chatData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let chatResponse = try JSONDecoder().decode(GroupChatResponse.self, from: data)
                completion(.success(chatResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Children
    
    func fetchChildren(completion: @escaping (Result<[Child], Error>) -> Void) {
        print("👶 APIService: fetchChildren() called")
        let url = baseURL.appendingPathComponent("/children/")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("👶❌ APIService: Network error in fetchChildren: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("👶❌ APIService: Invalid HTTP response in fetchChildren")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            print("👶 APIService: fetchChildren HTTP status: \(httpResponse.statusCode)")
            
            if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                print("👶 APIService: fetchChildren response: \(jsonString)")
            }
            
            if httpResponse.statusCode == 401 {
                print("👶❌🔐 APIService: 401 UNAUTHORIZED in fetchChildren - token invalid!")
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("👶❌ APIService: HTTP error \(httpResponse.statusCode) in fetchChildren")
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            guard let data = data else {
                print("👶❌ APIService: No data in successful fetchChildren response")
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let children = try JSONDecoder().decode([Child].self, from: data)
                print("👶✅ APIService: Successfully decoded \(children.count) children")
                completion(.success(children))
            } catch {
                print("👶❌ APIService: Failed to decode children: \(error)")
                if let decodingError = error as? DecodingError {
                    print("👶❌ APIService: Detailed decoding error: \(decodingError)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createChild(_ child: ChildCreate, completion: @escaping (Result<Child, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/children/")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(child)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let createdChild = try JSONDecoder().decode(Child.self, from: data)
                completion(.success(createdChild))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateChild(id: String, _ child: ChildCreate, completion: @escaping (Result<Child, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/children/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(child)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let updatedChild = try JSONDecoder().decode(Child.self, from: data)
                completion(.success(updatedChild))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteChild(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/children/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete child"])))
            }
        }.resume()
    }
    
    // MARK: - Schedule Template API Methods
    
    func fetchScheduleTemplates(completion: @escaping (Result<[ScheduleTemplate], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates/")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let templates = try JSONDecoder().decode([ScheduleTemplate].self, from: data)
                completion(.success(templates))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchScheduleTemplate(_ templateId: Int, completion: @escaping (Result<ScheduleTemplate, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates/\(templateId)")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON for schedule template: \(jsonString)")
                }
                let template = try JSONDecoder().decode(ScheduleTemplate.self, from: data)
                completion(.success(template))
            } catch {
                print("❌ Error decoding template: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createScheduleTemplate(_ templateData: ScheduleTemplateCreate, completion: @escaping (Result<ScheduleTemplate, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates/")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(templateData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON for schedule template: \(jsonString)")
                }
                let template = try JSONDecoder().decode(ScheduleTemplate.self, from: data)
                completion(.success(template))
            } catch {
                print("❌ Error decoding template: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateScheduleTemplate(_ templateId: Int, templateData: ScheduleTemplateCreate, completion: @escaping (Result<ScheduleTemplate, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates/\(templateId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(templateData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON for updated schedule template: \(jsonString)")
                }
                let template = try JSONDecoder().decode(ScheduleTemplate.self, from: data)
                completion(.success(template))
            } catch {
                print("❌ Error decoding schedule template update response: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteScheduleTemplate(_ templateId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates/\(templateId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func applyScheduleTemplate(_ application: ScheduleApplication, completion: @escaping (Result<ScheduleApplicationResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates/apply")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(application)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ScheduleApplicationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Reminders API
    
    func fetchReminders(startDate: String, endDate: String, completion: @escaping (Result<[Reminder], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/reminders")
        print("🔗 APIService.fetchReminders - baseURL: \(baseURL.absoluteString)")
        print("🔗 APIService.fetchReminders - intermediate URL: \(url.absoluteString)")
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let finalURL = urlComponents?.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("🔗 APIService.fetchReminders - final URL: \(finalURL.absoluteString)")
        print("🔗 APIService.fetchReminders - URL scheme: \(finalURL.scheme ?? "nil")")
        
        let request = createAuthenticatedRequest(url: finalURL)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔗❌ APIService.fetchReminders - Network error: \(error.localizedDescription)")
                print("🔗❌ Error domain: \((error as NSError).domain)")
                print("🔗❌ Error code: \((error as NSError).code)")
                
                // Check for ATS errors specifically
                if (error as NSError).code == -1022 {
                    print("🔗❌ ATS ERROR: App Transport Security is blocking this request")
                    print("🔗❌ This suggests the server redirected to HTTP or there's a TLS issue")
                }
                
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let reminders = try JSONDecoder().decode([Reminder].self, from: data)
                completion(.success(reminders))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createReminder(_ reminderData: ReminderCreate, completion: @escaping (Result<Reminder, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/reminders")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(reminderData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let reminder = try JSONDecoder().decode(Reminder.self, from: data)
                completion(.success(reminder))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateReminder(_ reminderId: Int, reminderData: ReminderUpdate, completion: @escaping (Result<Reminder, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/reminders/\(reminderId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(reminderData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let reminder = try JSONDecoder().decode(Reminder.self, from: data)
                completion(.success(reminder))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteReminder(_ reminderId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/reminders/\(reminderId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func fetchReminderByDate(_ date: String, completion: @escaping (Result<ReminderByDate, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/reminders/\(date)")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let reminder = try JSONDecoder().decode(ReminderByDate.self, from: data)
                completion(.success(reminder))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func requestLocation(for userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/family/request-location/\(userId)")
        
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func updateUserLocation(latitude: Double, longitude: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/user/location")
        
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["latitude": latitude, "longitude": longitude]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    // MARK: - Daycare Provider API Methods
    
    func fetchDaycareProviders(completion: @escaping (Result<[DaycareProvider], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let providers = try JSONDecoder().decode([DaycareProvider].self, from: data)
                completion(.success(providers))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createDaycareProvider(_ providerData: DaycareProviderCreate, completion: @escaping (Result<DaycareProvider, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(providerData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let provider = try JSONDecoder().decode(DaycareProvider.self, from: data)
                completion(.success(provider))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateDaycareProvider(_ providerId: Int, providerData: DaycareProviderCreate, completion: @escaping (Result<DaycareProvider, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers/\(providerId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(providerData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let provider = try JSONDecoder().decode(DaycareProvider.self, from: data)
                completion(.success(provider))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteDaycareProvider(_ providerId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers/\(providerId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func searchDaycareProviders(_ searchRequest: DaycareSearchRequest, completion: @escaping (Result<[DaycareSearchResult], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers/search")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(searchRequest)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let searchResults = try JSONDecoder().decode([DaycareSearchResult].self, from: data)
                completion(.success(searchResults))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func getDaycareProviders(completion: @escaping (Result<[DaycareProvider], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers")
        let request = createAuthenticatedRequest(url: url)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }

            do {
                let providers = try JSONDecoder().decode([DaycareProvider].self, from: data)
                completion(.success(providers))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func discoverDaycareCalendarURL(providerId: Int, completion: @escaping (Result<DaycareCalendarDiscoveryResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers/\(providerId)/discover-calendar")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(DaycareCalendarDiscoveryResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func parseDaycareEvents(providerId: Int, calendarURL: String, completion: @escaping (Result<DaycareEventsParseResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers/\(providerId)/parse-events")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["calendar_url": calendarURL]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(DaycareEventsParseResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - School Provider API Methods
    
    func fetchSchoolProviders(completion: @escaping (Result<[SchoolProvider], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let providers = try JSONDecoder().decode([SchoolProvider].self, from: data)
                completion(.success(providers))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createSchoolProvider(_ providerData: SchoolProviderCreate, completion: @escaping (Result<SchoolProvider, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(providerData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let provider = try JSONDecoder().decode(SchoolProvider.self, from: data)
                completion(.success(provider))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateSchoolProvider(_ providerId: Int, providerData: SchoolProviderCreate, completion: @escaping (Result<SchoolProvider, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers/\(providerId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(providerData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let provider = try JSONDecoder().decode(SchoolProvider.self, from: data)
                completion(.success(provider))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteSchoolProvider(_ providerId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers/\(providerId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func searchSchoolProviders(_ searchRequest: SchoolSearchRequest, completion: @escaping (Result<[SchoolSearchResult], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers/search")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(searchRequest)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let searchResults = try JSONDecoder().decode([SchoolSearchResult].self, from: data)
                completion(.success(searchResults))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func discoverSchoolCalendarURL(providerId: Int, completion: @escaping (Result<SchoolCalendarDiscoveryResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers/\(providerId)/discover-calendar")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(SchoolCalendarDiscoveryResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func parseSchoolEvents(providerId: Int, calendarURL: String, completion: @escaping (Result<SchoolEventsParseResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-providers/\(providerId)/parse-events")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["calendar_url": calendarURL]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(SchoolEventsParseResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Phone Verification
    
    func sendPhoneVerificationPin(phoneNumber: String, completion: @escaping (Result<PhoneVerificationResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/phone-verification/send-pin")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone_number": phoneNumber]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(PhoneVerificationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func verifyPhonePin(phoneNumber: String, pin: String, completion: @escaping (Result<PhoneVerificationResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/phone-verification/verify-pin")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone_number": phoneNumber, "pin": pin]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(PhoneVerificationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Email Verification
    
    func sendEmailVerificationCode(email: String, completion: @escaping (Result<EmailVerificationResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/email-verification/send-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EmailVerificationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func verifyEmailCode(email: String, code: String, completion: @escaping (Result<EmailVerificationResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/email-verification/verify-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EmailVerificationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func resendEmailVerificationCode(email: String, completion: @escaping (Result<EmailVerificationResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/email-verification/resend-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EmailVerificationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func loginAfterVerification(email: String, completion: @escaping (Result<(access_token: String, shouldSkipOnboarding: Bool), Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/auth/login-after-verification")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = jsonResponse["access_token"] as? String,
                   let shouldSkipOnboarding = jsonResponse["shouldSkipOnboarding"] as? Bool {
                    completion(.success((access_token: accessToken, shouldSkipOnboarding: shouldSkipOnboarding)))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Family Enrollment
    
    func createEnrollmentCode(completion: @escaping (Result<EnrollmentCodeResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/enrollment/create-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EnrollmentCodeResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func validateEnrollmentCode(code: String, completion: @escaping (Result<EnrollmentCodeResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/enrollment/validate-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["code": code]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detail])))
                } else {
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EnrollmentCodeResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Themes
    
    func fetchThemes(completion: @escaping (Result<[Theme], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/themes/")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let themes = try JSONDecoder().decode([Theme].self, from: data)
                completion(.success(themes))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createTheme(_ theme: Theme, completion: @escaping (Result<Theme, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/themes")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(theme)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let newTheme = try JSONDecoder().decode(Theme.self, from: data)
                completion(.success(newTheme))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateTheme(_ theme: Theme, completion: @escaping (Result<Theme, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/themes/\(theme.id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(theme)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let updatedTheme = try JSONDecoder().decode(Theme.self, from: data)
                completion(.success(updatedTheme))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteTheme(_ themeId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/themes/\(themeId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func setThemePreference(themeId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/themes/set-preference/\(themeId)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            // Handle specific error cases
            if httpResponse.statusCode == 404 {
                completion(.failure(APIError.themeNotFound))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    // MARK: - Journal Methods
    
    func fetchJournalEntries(startDate: String? = nil, endDate: String? = nil, limit: Int = 50, completion: @escaping (Result<[JournalEntry], Error>) -> Void) {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/journal"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let entries = try JSONDecoder().decode([JournalEntry].self, from: data)
                completion(.success(entries))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createJournalEntry(_ entryData: JournalEntryCreate, completion: @escaping (Result<JournalEntry, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/journal")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(entryData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let newEntry = try JSONDecoder().decode(JournalEntry.self, from: data)
                completion(.success(newEntry))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateJournalEntry(id: Int, entryData: JournalEntryUpdate, completion: @escaping (Result<JournalEntry, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/journal/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(entryData)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let updatedEntry = try JSONDecoder().decode(JournalEntry.self, from: data)
                completion(.success(updatedEntry))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteJournalEntry(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/journal/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func getJournalEntry(id: Int, completion: @escaping (Result<JournalEntry, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/journal/\(id)")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let entry = try JSONDecoder().decode(JournalEntry.self, from: data)
                completion(.success(entry))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func loginWithApple(code: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/auth/apple/callback")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "code=\(code)".data(using: .utf8)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)
                completion(.success(tokenResp.access_token))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func loginWithGoogle(idToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/auth/google/ios-login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "id_token=\(idToken)".data(using: .utf8)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)
                completion(.success(tokenResp.access_token))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func getDaycareCalendarSync(providerId: Int, completion: @escaping (Result<DaycareCalendarSyncInfo, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/daycare-providers/\(providerId)/calendar-sync")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let syncInfo = try JSONDecoder().decode(DaycareCalendarSyncInfo.self, from: data)
                completion(.success(syncInfo))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Medical Provider Management
    
    func fetchMedicalProviders(completion: @escaping (Result<[MedicalProvider], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medical-providers/")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let providers = try JSONDecoder().decode([MedicalProvider].self, from: data)
                completion(.success(providers))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createMedicalProvider(_ provider: MedicalProviderCreate, completion: @escaping (Result<MedicalProvider, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medical-providers/")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(provider)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let createdProvider = try JSONDecoder().decode(MedicalProvider.self, from: data)
                completion(.success(createdProvider))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateMedicalProvider(id: Int, provider: MedicalProviderUpdate, completion: @escaping (Result<MedicalProvider, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medical-providers/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(provider)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let updatedProvider = try JSONDecoder().decode(MedicalProvider.self, from: data)
                completion(.success(updatedProvider))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteMedicalProvider(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medical-providers/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    // MARK: - Medication Management
    
    func fetchMedications(completion: @escaping (Result<[Medication], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medications/")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                struct MedicationListEnvelope: Codable { let medications: [Medication] }
                let envelope = try JSONDecoder().decode(MedicationListEnvelope.self, from: data)
                completion(.success(envelope.medications))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createMedication(_ medication: MedicationCreate, completion: @escaping (Result<Medication, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medications/")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(medication)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let createdMedication = try JSONDecoder().decode(Medication.self, from: data)
                completion(.success(createdMedication))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateMedication(id: Int, medication: MedicationUpdate, completion: @escaping (Result<Medication, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medications/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(medication)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            do {
                let updatedMedication = try JSONDecoder().decode(Medication.self, from: data)
                completion(.success(updatedMedication))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteMedication(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medications/\(id)")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func searchMedicalProviders(_ searchRequest: MedicalSearchRequest, completion: @escaping (Result<[MedicalSearchResult], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/medical-providers/search")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(searchRequest)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            // Debug: Log the raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🏥 Medical Provider Search Response:")
                print("Status Code: \(httpResponse.statusCode)")
                print("Raw JSON Response:")
                print(jsonString)
                print("--- End Response ---")
            }
            
            do {
                let response = try JSONDecoder().decode(MedicalSearchResponse.self, from: data)
                print("✅ Successfully decoded \(response.results.count) medical search results (total: \(response.total))")
                completion(.success(response.results))
            } catch {
                print("❌ JSON Decoding Error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("❌ Data corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("❌ Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("❌ Type mismatch for type \(type): \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("❌ Value not found for type \(type): \(context.debugDescription)")
                    @unknown default:
                        print("❌ Unknown decoding error: \(error)")
                    }
                }
                completion(.failure(error))
            }
        }.resume()
    }

} 
