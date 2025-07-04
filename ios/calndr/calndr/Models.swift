import Foundation

// Represents a single calendar event
struct Event: Codable, Identifiable {
    var id: Int
    let family_id: String?
    let event_date: String
    let content: String
    let position: Int
    
    enum CodingKeys: String, CodingKey {
        case id, family_id, event_date, content, position
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0 // Default to 0 if id is nil
        family_id = try container.decodeIfPresent(String.self, forKey: .family_id)
        event_date = try container.decode(String.self, forKey: .event_date)
        content = try container.decode(String.self, forKey: .content)
        position = try container.decode(Int.self, forKey: .position)
    }
    
    // Convenience init for creating new events locally
    init(id: Int = 0, family_id: String? = nil, event_date: String, content: String, position: Int) {
        self.id = id
        self.family_id = family_id
        self.event_date = event_date
        self.content = content
        self.position = position
    }
}

struct Custodian: Codable, Identifiable {
    let id: String
    let first_name: String
}

struct CustodianResponse: Codable {
    let custodian_one: Custodian
    let custodian_two: Custodian
}

// Represents a custody record for the new custody API
struct CustodyRecord: Codable, Identifiable {
    let id: Int
    let date: String
    let custodian_id: String
    
    enum CodingKeys: String, CodingKey {
        case id, date, custodian_id
    }
}

// Request model for creating/updating custody
struct CustodyRequest: Codable {
    let date: String
    let custodian_id: String
}

// Response model from custody API (compatible with frontend format)
struct CustodyResponse: Codable, Identifiable {
    let id: Int
    let event_date: String
    let content: String
    let position: Int
    
    enum CodingKeys: String, CodingKey {
        case id, event_date, content, position
    }
}

// Represents a school event
struct SchoolEvent: Codable, Identifiable, Hashable {
    let date: String
    let event: String

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case event = "title"
    }
}

// Represents the full JSON response from the weather API
struct WeatherAPIResponse: Codable {
    let daily: DailyWeather
}

// Represents the "daily" object in the weather API response
struct DailyWeather: Codable {
    let time: [String]
    let temperature_2m_max: [Double]
    let precipitation_probability_mean: [Double]
    let cloudcover_mean: [Double]
}

// A simplified representation for weather data for a single day
struct WeatherInfo: Codable {
    let temperature: Double
    let precipitation: Double
    let cloudCover: Double
}

// Represents a single notification email address
struct NotificationEmail: Codable, Identifiable {
    let id: Int
    var email: String
}

struct PasswordUpdate: Codable {
    let current_password: String
    let new_password: String
}

struct PasswordValidation: Codable {
    let password: String
}

// User Profile Model
struct UserProfile: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let phone_number: String?
    let subscription_type: String?
    let subscription_status: String?
    let created_at: String?
    let profile_photo_url: String?
    
    enum CodingKeys: String, CodingKey {
        case id, first_name, last_name, email, phone_number, subscription_type, subscription_status, created_at, profile_photo_url
    }
}

struct FamilyMemberEmail: Codable {
    let id: String
    let first_name: String
    let email: String
} 

struct Babysitter: Codable, Identifiable {
    let id: Int
    let first_name: String
    let last_name: String
    let phone_number: String
    let rate: Double?
    let notes: String?
    let created_by_user_id: String
    let created_at: String
    
    var fullName: String {
        return "\(first_name) \(last_name)"
    }
    
    var formattedRate: String {
        if let rate = rate {
            return String(format: "$%.2f/hr", rate)
        }
        return "Rate not specified"
    }
}

struct BabysitterCreate: Codable {
    let first_name: String
    let last_name: String
    let phone_number: String
    let rate: Double?
    let notes: String?
}

struct EmergencyContact: Codable, Identifiable {
    let id: Int
    let first_name: String
    let last_name: String
    let phone_number: String
    let relationship: String?
    let notes: String?
    let created_by_user_id: String
    let created_at: String
    
    var fullName: String {
        return "\(first_name) \(last_name)"
    }
    
    var displayRelationship: String {
        return relationship ?? "Emergency Contact"
    }
}

struct EmergencyContactCreate: Codable {
    let first_name: String
    let last_name: String
    let phone_number: String
    let relationship: String?
    let notes: String?
}

struct GroupChatCreate: Codable {
    let contact_type: String
    let contact_id: Int
    let group_identifier: String?
}

struct GroupChatResponse: Codable {
    let group_identifier: String
    let exists: Bool
    let created_at: String
}

// Handoff Time Models
struct HandoffTimeCreate: Codable {
    let date: String
    let time: String
    let location: String?
    let from_parent_id: String?
    let to_parent_id: String?
    
    init(date: String, time: String, location: String? = "daycare", from_parent_id: String? = nil, to_parent_id: String? = nil) {
        self.date = date
        self.time = time
        self.location = location
        self.from_parent_id = from_parent_id
        self.to_parent_id = to_parent_id
    }
}

struct HandoffTimeResponse: Codable, Identifiable {
    let id: Int
    let date: String
    let time: String
    let location: String?
    let from_parent_id: String?
    let to_parent_id: String?
    let from_parent_name: String?
    let to_parent_name: String?
    let family_id: String
    let created_at: String
    let updated_at: String
} 
