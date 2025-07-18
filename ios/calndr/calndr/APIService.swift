import Foundation
import UIKit

enum APIError: Error, LocalizedError {
    case unauthorized
    case invalidResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized: Please check your credentials and try again."
        case .invalidResponse:
            return "Invalid response from the server. Please try again later."
        case .requestFailed(let statusCode):
            return "The request failed with a status code: \(statusCode)."
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
    let family_name: String?
}

struct UserRegistrationResponse: Codable {
    let user_id: String
    let family_id: String
    let access_token: String
    let token_type: String
    let message: String
}

class APIService {
    static let shared = APIService()
    private let baseURL = URL(string: "https://calndr.club/api/v1")!

    private init() {}

    // Helper function to create an authenticated request
    private func createAuthenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = KeychainManager.shared.loadToken(for: "currentUser") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func fetchEvents(from startDate: String, to endDate: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/events"), resolvingAgainstBaseURL: false)!
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
        var components = URLComponents(url: baseURL.appendingPathComponent("/weather/\(latitude)/\(longitude)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
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
        var components = URLComponents(url: baseURL.appendingPathComponent("/weather/historic/\(latitude)/\(longitude)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
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
            
            // Safely unwrap optional values, providing a default of 0.0 if nil
            let temp = daily.temperature_2m_max[i] ?? 0.0
            let precip = daily.precipitation_probability_mean[i] ?? 0.0
            let cover = daily.cloudcover_mean[i] ?? 0.0
            
            let info = WeatherInfo(
                temperature: temp,
                precipitation: precip,
                cloudCover: cover
            )
            weatherInfos[dateString] = info
        }
        
        return weatherInfos
    }

    // Placeholder for fetching school events
    func fetchSchoolEvents(completion: @escaping (Result<[SchoolEvent], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/school-events")
        let request = createAuthenticatedRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received for school events"])))
                return
            }
            do {
                let schoolEvents = try JSONDecoder().decode([SchoolEvent].self, from: data)
                completion(.success(schoolEvents))
            } catch {
                let nsError = error as NSError
                print("Decoding error: \(nsError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response on error: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - User Preferences
    
    func saveThemePreference(themeName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/preferences")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["selected_theme": themeName]
        
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
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "APIService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to save theme preference"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    // MARK: - Custody API (New dedicated custody endpoints)
    
    func fetchCustodyRecords(year: Int, month: Int, completion: @escaping (Result<[CustodyResponse], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/custody/\(year)/\(month)")
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
            
            // Log the raw data as a string for debugging
//            if let jsonString = String(data: data, encoding: .utf8) {
//                print("--- Raw JSON for fetchCustodyRecords ---")
//                print(jsonString)
//                print("--------------------------------------")
//            }

            if httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }

            do {
                let custodyRecords = try JSONDecoder().decode([CustodyResponse].self, from: data)
//                print("✅ Successfully decoded \(custodyRecords.count) custody records")
                completion(.success(custodyRecords))
            } catch {
                print("❌ JSON Decoding Error: \(error)")
                if let decodingError = error as? DecodingError {
                    print("❌ Detailed Decoding Error: \(decodingError)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateHandoffDayOnly(for date: String, handoffDay: Bool, completion: @escaping (Result<CustodyResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/custody/handoff-day")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        let url = baseURL.appendingPathComponent("/custody")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let custodyRequest = CustodyRequest(date: date, custodian_id: custodianId, handoff_day: handoffDay, handoff_time: handoffTime, handoff_location: handoffLocation)
        
        do {
            request.httpBody = try JSONEncoder().encode(custodyRequest)
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
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received on custody update"])))
                return
            }

            // Log the raw data as a string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for updateCustodyRecord (Status: \(httpResponse.statusCode)) ---")
                print(jsonString)
                print("--------------------------------------------------------------------")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            do {
                let updatedCustody = try JSONDecoder().decode(CustodyResponse.self, from: data)
                completion(.success(updatedCustody))
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
            url = baseURL.appendingPathComponent("/events")
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
    
    func signUp(firstName: String, lastName: String, email: String, password: String, phoneNumber: String?, familyName: String?, completion: @escaping (Result<String, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let registrationRequest = UserRegistrationRequest(
            first_name: firstName,
            last_name: lastName,
            email: email,
            password: password,
            phone_number: phoneNumber,
            family_name: familyName
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(registrationRequest)
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
                completion(.success(registrationResponse.access_token))
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
        let url = baseURL.appendingPathComponent("/children")
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
                let children = try JSONDecoder().decode([Child].self, from: data)
                completion(.success(children))
            } catch {
                print("Failed to decode children: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createChild(_ child: ChildCreate, completion: @escaping (Result<Child, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/children")
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
        let url = baseURL.appendingPathComponent("/schedule-templates")
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
    
    func createScheduleTemplate(_ templateData: ScheduleTemplateCreate, completion: @escaping (Result<ScheduleTemplate, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/schedule-templates")
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
                let template = try JSONDecoder().decode(ScheduleTemplate.self, from: data)
                completion(.success(template))
            } catch {
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
                let template = try JSONDecoder().decode(ScheduleTemplate.self, from: data)
                completion(.success(template))
            } catch {
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
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let finalURL = urlComponents?.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let request = createAuthenticatedRequest(url: finalURL)
        
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
    
    // MARK: - Themes
    
    func fetchThemes(completion: @escaping (Result<[Theme], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/themes")
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
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
} 
