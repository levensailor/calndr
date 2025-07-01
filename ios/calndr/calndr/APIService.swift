import Foundation

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

struct CustodianNamesResponse: Codable {
    let custodian_one: String
    let custodian_two: String
}

class APIService {
    static let shared = APIService()
    private let baseURL = URL(string: "https://calndr.club/api")!

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
            
            // Log the raw data as a string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for fetchEvents ---")
                print(jsonString)
                print("------------------------------")
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

    // Placeholder for fetching weather data
    func fetchWeather(latitude: Double, longitude: Double, startDate: String, endDate: String, completion: @escaping (Result<[String: WeatherInfo], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/weather/\(latitude)/\(longitude)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]

        guard let url = components.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No weather data received"])))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
                let weatherInfos = self.transformWeatherData(from: apiResponse)
                completion(.success(weatherInfos))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func transformWeatherData(from apiResponse: WeatherAPIResponse) -> [String: WeatherInfo] {
        var weatherInfos: [String: WeatherInfo] = [:]
        
        let daily = apiResponse.daily
        for i in 0..<daily.time.count {
            let dateString = daily.time[i]
            let info = WeatherInfo(
                temperature: daily.temperature_2m_max[i],
                precipitation: daily.precipitation_probability_mean[i],
                cloudCover: daily.cloudcover_mean[i]
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
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- Raw JSON for fetchCustodyRecords ---")
                print(jsonString)
                print("--------------------------------------")
            }

            if httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                return
            }

            do {
                let custodyRecords = try JSONDecoder().decode([CustodyResponse].self, from: data)
                completion(.success(custodyRecords))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateCustodyRecord(for date: String, custodianId: String, completion: @escaping (Result<CustodyResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/custody")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let custodyRequest = CustodyRequest(date: date, custodian_id: custodianId)
        
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
    
    // MARK: - Legacy Custody (Deprecated - use new custody API above)
    
    func updateCustody(for date: String, newOwner: String, existingEvents: [Event], completion: @escaping (Result<Event, Error>) -> Void) {
        let custodyEventForDay = existingEvents.first { $0.event_date == date && $0.position == 4 }

        var eventData: [String: Any] = [
            "event_date": date,
            "content": newOwner,
            "position": 4
        ]
        
        if let event = custodyEventForDay {
            eventData["id"] = event.id
        }

        // Pass the full details and let saveEvent handle create/update
        saveEvent(eventDetails: eventData, existingEvent: custodyEventForDay, completion: completion)
    }
    
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
        guard let url = URL(string: "\(baseURL)/api/users/me/device-token") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }

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

    func fetchCustodianNames(completion: @escaping (Result<CustodianResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/family/custodians")
        let request = createAuthenticatedRequest(url: url)
        
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
                let custodianResponse = try JSONDecoder().decode(CustodianResponse.self, from: data)
                completion(.success(custodianResponse))
            } catch {
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

    func fetchUserProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/me")
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
                let userProfile = try JSONDecoder().decode(UserProfile.self, from: data)
                completion(.success(userProfile))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Password Management
extension APIService {
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
} 