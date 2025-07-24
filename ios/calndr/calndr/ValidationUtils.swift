import Foundation

extension String {
    func isValidEmail() -> Bool {
        // A simple regex for email validation
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}

// Time formatting utilities
struct TimeFormatter {
    /// Formats hour and minute into 12-hour AM/PM format
    /// - Parameters:
    ///   - hour: Hour in 24-hour format (0-23)
    ///   - minute: Minute (0-59)
    /// - Returns: Time string in 12-hour AM/PM format (e.g., "12:00 PM", "5:00 PM", "9:00 AM")
    static func format12Hour(hour: Int, minute: Int) -> String {
        let calendar = Calendar.current
        let dateComponents = DateComponents(hour: hour, minute: minute)
        guard let date = calendar.date(from: dateComponents) else {
            return String(format: "%02d:%02d", hour, minute) // Fallback to 24-hour format
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
} 