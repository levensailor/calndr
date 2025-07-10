import Foundation
import SwiftUI

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
    let handoff_day: Bool?
    let handoff_time: String?
    let handoff_location: String?
    
    init(date: String, custodian_id: String, handoff_day: Bool? = nil, handoff_time: String? = nil, handoff_location: String? = nil) {
        self.date = date
        self.custodian_id = custodian_id
        self.handoff_day = handoff_day
        self.handoff_time = handoff_time
        self.handoff_location = handoff_location
    }
}

// Response model from custody API (compatible with frontend format)
struct CustodyResponse: Codable, Identifiable, Equatable {
    var id: Int
    var event_date: String
    var content: String
    var position: Int
    var custodian_id: String
    var handoff_day: Bool?
    var handoff_time: String?
    var handoff_location: String?
    
    enum CodingKeys: String, CodingKey {
        case id, event_date, content, position, custodian_id, handoff_day, handoff_time, handoff_location
    }
    
    // Custom memberwise initializer
    init(id: Int, event_date: String, content: String, position: Int, custodian_id: String, handoff_day: Bool?, handoff_time: String?, handoff_location: String?) {
        self.id = id
        self.event_date = event_date
        self.content = content
        self.position = position
        self.custodian_id = custodian_id
        self.handoff_day = handoff_day
        self.handoff_time = handoff_time
        self.handoff_location = handoff_location
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        event_date = try container.decode(String.self, forKey: .event_date)
        content = try container.decode(String.self, forKey: .content)
        position = try container.decode(Int.self, forKey: .position)
        custodian_id = try container.decode(String.self, forKey: .custodian_id)
        
        // Handle handoff_day more robustly - it could be bool or null
        handoff_day = try container.decodeIfPresent(Bool.self, forKey: .handoff_day)
        
        // Handle nullable string fields
        handoff_time = try container.decodeIfPresent(String.self, forKey: .handoff_time)
        handoff_location = try container.decodeIfPresent(String.self, forKey: .handoff_location)
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

struct FamilyMember: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let phone_number: String?
    let status: String?
    let last_signed_in: String?
    
    var fullName: String {
        return "\(first_name) \(last_name)"
    }
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

// MARK: - Comprehensive Family Models for Settings

struct Coparent: Codable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String
    let lastSignin: String?
    let notes: String?
    let isActive: Bool
    let familyId: Int
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case lastSignin = "last_signin"
        case notes
        case isActive = "is_active"
        case familyId = "family_id"
    }
}

struct Child: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let dateOfBirth: String
    let familyId: String
    
    var age: Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = dateFormatter.date(from: dateOfBirth) else { return 0 }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "dob"
        case familyId = "family_id"
    }
}

struct ChildCreate: Codable {
    let first_name: String
    let last_name: String
    let dob: String  // Date string in YYYY-MM-DD format
}

struct OtherFamilyMember: Codable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String?
    let phoneNumber: String?
    let relationship: String
    let familyId: Int
    let createdAt: String
    let updatedAt: String
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phoneNumber = "phone_number"
        case relationship
        case familyId = "family_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DaycareProvider: Codable, Identifiable {
    let id: Int
    let name: String
    let address: String?
    let phoneNumber: String?
    let email: String?
    let hours: String?
    let notes: String?
    let familyId: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case phoneNumber = "phone_number"
        case email
        case hours
        case notes
        case familyId = "family_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ScheduleTemplate: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let isActive: Bool
    let familyId: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isActive = "is_active"
        case familyId = "family_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Settings Section Models

struct SettingsSection: Identifiable {
    var id: SettingsDestination { destination }
    let title: String
    let icon: String
    let description: String
    let color: Color
    let destination: SettingsDestination
    let itemCount: Int?
}

enum SettingsDestination: Hashable {
    case account
    case security
    case preferences
    case daycare
    case sitters
    case schedules
    case family
}

// Handoff Time Models
 
