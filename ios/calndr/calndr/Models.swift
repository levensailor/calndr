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
    let selected_theme: String?
    
    enum CodingKeys: String, CodingKey {
        case id, first_name, last_name, email, phone_number, subscription_type, subscription_status, created_at, profile_photo_url, selected_theme
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
    let phone_number: String?
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
        case phone_number = "phone_number"
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

// MARK: - Enhanced Schedule Models

enum SchedulePatternType: String, Codable, CaseIterable {
    case weekly = "weekly"
    case alternatingWeeks = "alternating_weeks"
    case alternatingDays = "alternating_days"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .weekly:
            return "Weekly Pattern"
        case .alternatingWeeks:
            return "Alternating Weeks"
        case .alternatingDays:
            return "Alternating Days"
        case .custom:
            return "Custom Pattern"
        }
    }
    
    var description: String {
        switch self {
        case .weekly:
            return "Same pattern every week"
        case .alternatingWeeks:
            return "Alternate between parents each week"
        case .alternatingDays:
            return "Alternate between parents each day"
        case .custom:
            return "Custom arrangement"
        }
    }
}

struct WeeklySchedulePattern: Codable {
    let sunday: String?
    let monday: String?
    let tuesday: String?
    let wednesday: String?
    let thursday: String?
    let friday: String?
    let saturday: String?
    
    func custodianFor(weekday: Int) -> String? {
        // weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return nil
        }
    }
}

struct AlternatingWeeksPattern: Codable {
    let weekAPattern: WeeklySchedulePattern
    let weekBPattern: WeeklySchedulePattern
    let startingWeek: String // "A" or "B"
    let referenceDate: String // ISO date string to determine which week is A/B
}

struct ScheduleTemplateDetailed: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let patternType: SchedulePatternType
    let weeklyPattern: WeeklySchedulePattern?
    let alternatingWeeksPattern: AlternatingWeeksPattern?
    let isActive: Bool
    let familyId: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case patternType = "pattern_type"
        case weeklyPattern = "weekly_pattern"
        case alternatingWeeksPattern = "alternating_weeks_pattern"
        case isActive = "is_active"
        case familyId = "family_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ScheduleTemplateCreate: Codable {
    let name: String
    let description: String?
    let patternType: SchedulePatternType
    let weeklyPattern: WeeklySchedulePattern?
    let alternatingWeeksPattern: AlternatingWeeksPattern?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case patternType = "pattern_type"
        case weeklyPattern = "weekly_pattern"
        case alternatingWeeksPattern = "alternating_weeks_pattern"
        case isActive = "is_active"
    }
}

struct ScheduleApplication: Codable {
    let templateId: Int
    let startDate: String
    let endDate: String
    let overwriteExisting: Bool
    
    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case overwriteExisting = "overwrite_existing"
    }
}

struct ScheduleApplicationResponse: Codable {
    let success: Bool
    let message: String
    let daysApplied: Int
    let conflictsOverwritten: Int?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case daysApplied = "days_applied"
        case conflictsOverwritten = "conflicts_overwritten"
    }
}

struct SchedulePreset {
    let id: String
    let name: String
    let description: String
    let patternType: SchedulePatternType
    let weeklyPattern: WeeklySchedulePattern?
    let alternatingWeeksPattern: AlternatingWeeksPattern?
    let icon: String
    let isPopular: Bool
    
    static let commonPresets: [SchedulePreset] = [
        // Weekly patterns
        SchedulePreset(
            id: "weekdays_weekends",
            name: "Weekdays/Weekends",
            description: "One parent has weekdays, other has weekends",
            patternType: .weekly,
            weeklyPattern: WeeklySchedulePattern(
                sunday: "parent2",
                monday: "parent1",
                tuesday: "parent1",
                wednesday: "parent1",
                thursday: "parent1",
                friday: "parent1",
                saturday: "parent2"
            ),
            alternatingWeeksPattern: nil,
            icon: "calendar.badge.clock",
            isPopular: true
        ),
        
        SchedulePreset(
            id: "traditional_split",
            name: "Traditional Split",
            description: "Parent 1: Mon-Wed, Parent 2: Thu-Sun",
            patternType: .weekly,
            weeklyPattern: WeeklySchedulePattern(
                sunday: "parent2",
                monday: "parent1",
                tuesday: "parent1",
                wednesday: "parent1",
                thursday: "parent2",
                friday: "parent2",
                saturday: "parent2"
            ),
            alternatingWeeksPattern: nil,
            icon: "calendar.badge.clock",
            isPopular: true
        ),
        
        // Alternating weeks
        SchedulePreset(
            id: "alternating_weeks",
            name: "Alternating Weeks",
            description: "Switch between parents every week",
            patternType: .alternatingWeeks,
            weeklyPattern: nil,
            alternatingWeeksPattern: AlternatingWeeksPattern(
                weekAPattern: WeeklySchedulePattern(
                    sunday: "parent1",
                    monday: "parent1",
                    tuesday: "parent1",
                    wednesday: "parent1",
                    thursday: "parent1",
                    friday: "parent1",
                    saturday: "parent1"
                ),
                weekBPattern: WeeklySchedulePattern(
                    sunday: "parent2",
                    monday: "parent2",
                    tuesday: "parent2",
                    wednesday: "parent2",
                    thursday: "parent2",
                    friday: "parent2",
                    saturday: "parent2"
                ),
                startingWeek: "A",
                referenceDate: "2024-01-01" // Monday
            ),
            icon: "arrow.left.arrow.right",
            isPopular: true
        ),
        
        SchedulePreset(
            id: "two_two_three",
            name: "2-2-3 Schedule",
            description: "2 days, 2 days, 3 days alternating",
            patternType: .alternatingWeeks,
            weeklyPattern: nil,
            alternatingWeeksPattern: AlternatingWeeksPattern(
                weekAPattern: WeeklySchedulePattern(
                    sunday: "parent1",
                    monday: "parent1",
                    tuesday: "parent2",
                    wednesday: "parent2",
                    thursday: "parent1",
                    friday: "parent1",
                    saturday: "parent1"
                ),
                weekBPattern: WeeklySchedulePattern(
                    sunday: "parent2",
                    monday: "parent2",
                    tuesday: "parent1",
                    wednesday: "parent1",
                    thursday: "parent2",
                    friday: "parent2",
                    saturday: "parent2"
                ),
                startingWeek: "A",
                referenceDate: "2024-01-01"
            ),
            icon: "calendar.badge.clock",
            isPopular: true
        ),
        
        SchedulePreset(
            id: "two_two_five_five",
            name: "2-2-5-5 Schedule",
            description: "2 weekdays, 2 weekdays, 5 days, 5 days",
            patternType: .alternatingWeeks,
            weeklyPattern: nil,
            alternatingWeeksPattern: AlternatingWeeksPattern(
                weekAPattern: WeeklySchedulePattern(
                    sunday: "parent1",
                    monday: "parent1",
                    tuesday: "parent2",
                    wednesday: "parent2",
                    thursday: "parent1",
                    friday: "parent1",
                    saturday: "parent1"
                ),
                weekBPattern: WeeklySchedulePattern(
                    sunday: "parent1",
                    monday: "parent1",
                    tuesday: "parent2",
                    wednesday: "parent2",
                    thursday: "parent2",
                    friday: "parent2",
                    saturday: "parent2"
                ),
                startingWeek: "A",
                referenceDate: "2024-01-01"
            ),
            icon: "calendar.badge.clock",
            isPopular: false
        ),
        
        SchedulePreset(
            id: "every_other_day",
            name: "Every Other Day",
            description: "Alternate between parents daily",
            patternType: .alternatingDays,
            weeklyPattern: nil,
            alternatingWeeksPattern: AlternatingWeeksPattern(
                weekAPattern: WeeklySchedulePattern(
                    sunday: "parent1",
                    monday: "parent2",
                    tuesday: "parent1",
                    wednesday: "parent2",
                    thursday: "parent1",
                    friday: "parent2",
                    saturday: "parent1"
                ),
                weekBPattern: WeeklySchedulePattern(
                    sunday: "parent2",
                    monday: "parent1",
                    tuesday: "parent2",
                    wednesday: "parent1",
                    thursday: "parent2",
                    friday: "parent1",
                    saturday: "parent2"
                ),
                startingWeek: "A",
                referenceDate: "2024-01-01"
            ),
            icon: "arrow.left.arrow.right.circle",
            isPopular: false
        )
    ]
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

// MARK: - Reminder Models
struct Reminder: Codable, Identifiable {
    let id: Int
    let date: String
    let text: String
    let notificationEnabled: Bool
    let notificationTime: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, date, text
        case notificationEnabled = "notification_enabled"
        case notificationTime = "notification_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ReminderCreate: Codable {
    let date: String
    let text: String
    let notificationEnabled: Bool
    let notificationTime: String?
    
    enum CodingKeys: String, CodingKey {
        case date, text
        case notificationEnabled = "notification_enabled"
        case notificationTime = "notification_time"
    }
    
    init(date: String, text: String, notificationEnabled: Bool = false, notificationTime: String? = nil) {
        self.date = date
        self.text = text
        self.notificationEnabled = notificationEnabled
        self.notificationTime = notificationTime
    }
}

struct ReminderUpdate: Codable {
    let text: String
    let notificationEnabled: Bool
    let notificationTime: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case notificationEnabled = "notification_enabled"
        case notificationTime = "notification_time"
    }
    
    init(text: String, notificationEnabled: Bool = false, notificationTime: String? = nil) {
        self.text = text
        self.notificationEnabled = notificationEnabled
        self.notificationTime = notificationTime
    }
}

struct ReminderByDate: Codable {
    let id: Int?
    let date: String
    let text: String
    let hasReminder: Bool
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, date, text
        case hasReminder = "has_reminder"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
 
