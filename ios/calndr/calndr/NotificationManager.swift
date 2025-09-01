import Foundation
import UserNotifications
import UIKit // Required for UIApplication

class NotificationManager {
    static let shared = NotificationManager()
    private var apiService = APIService.shared
    
    private init() {}
    
    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
                // This must be called on the main thread.
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendDeviceTokenToServer(token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token: \(tokenString)")
        
        // Use the APIService to send the token
        apiService.updateDeviceToken(token: tokenString) { result in
            switch result {
            case .success:
                print("Successfully sent device token to server.")
            case .failure(let error):
                print("Error sending device token to server: \(error.localizedDescription)")
                
                // Check if this is the specific endpoint already exists error
                if let deviceError = error as? APIService.DeviceRegistrationError {
                    switch deviceError {
                    case .endpointAlreadyExists(let endpointArn):
                        self.handleExistingEndpoint(endpointArn: endpointArn, token: tokenString)
                    }
                }
            }
        }
    }
    
    private func handleExistingEndpoint(endpointArn: String, token: String) {
        DispatchQueue.main.async {
            // Show an alert to the user
            let alertController = UIAlertController(
                title: "Device Already Registered",
                message: "It looks like this device is already enrolled for Apple push notifications. Do you wish to enroll this account instead?",
                preferredStyle: .alert
            )
            
            alertController.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
                // User wants to update the endpoint to use their account
                self.updateExistingEndpoint(endpointArn: endpointArn, token: token)
            })
            
            alertController.addAction(UIAlertAction(title: "No", style: .cancel))
            
            // Find the top-most view controller to present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                var topController = rootViewController
                while let presentedController = topController.presentedViewController {
                    topController = presentedController
                }
                topController.present(alertController, animated: true)
            }
        }
    }
    
    private func updateExistingEndpoint(endpointArn: String, token: String) {
        apiService.updateExistingDeviceEndpoint(endpointArn: endpointArn, token: token) { result in
            switch result {
            case .success:
                print("Successfully updated existing endpoint to use current account.")
            case .failure(let error):
                print("Error updating existing endpoint: \(error.localizedDescription)")
            }
        }
    }

    func handleRemoteNotification(payload: [AnyHashable: Any]) {
        // Potentially handle incoming notification while app is open
        print("Received remote notification payload: \(payload)")
        // Here you could refresh the calendar data, for example
    }

    func scheduleCustodyChangeNotification(for date: Date, for user: String) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Updated"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: date)
        
        content.body = "\(user) now has custody on \(dateString)."
        content.sound = .default
        
        // Schedule for 1 second from now to make it "immediate"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: "custody-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling custody change notification: \(error.localizedDescription)")
            } else {
                print("Custody change notification scheduled for \(dateString)")
            }
        }
    }

    // MARK: - Medication Reminders
    func scheduleMedicationReminders(medicationName: String, nextDose: Date, frequency: String, occurrences: Int = 8) {
        // Map frequency to an interval or pattern
        guard let interval = intervalForFrequency(frequency) else {
            print("⏰ Skipping reminder scheduling for frequency: \(frequency)")
            return
        }
        let center = UNUserNotificationCenter.current()
        var scheduledCount = 0
        var doseDate = nextUpcomingDate(from: nextDose)
        while scheduledCount < max(1, occurrences) {
            scheduleSingleMedicationReminder(center: center, name: medicationName, at: doseDate)
            doseDate = doseDate.addingTimeInterval(interval)
            scheduledCount += 1
        }
        print("⏰ Scheduled \(scheduledCount) reminders for \(medicationName) starting at \(doseDate))")
    }

    private func scheduleSingleMedicationReminder(center: UNUserNotificationCenter, name: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Next dose: \(name)"
        content.body = "It's time to take \(name)."
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "medication-\(name)-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling medication reminder: \(error.localizedDescription)")
            }
        }
    }

    private func nextUpcomingDate(from date: Date) -> Date {
        let now = Date()
        if date > now { return date }
        // If in the past within the same minute, push to next minute
        return Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now
    }

    private func intervalForFrequency(_ frequency: String) -> TimeInterval? {
        let f = frequency.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch f {
        case "once daily":
            return 24 * 3600
        case "twice daily":
            return 12 * 3600
        case "three times daily":
            return 8 * 3600
        case "every 4 hours":
            return 4 * 3600
        case "every 6 hours":
            return 6 * 3600
        case "every 8 hours":
            return 8 * 3600
        case "every 12 hours":
            return 12 * 3600
        case "weekly":
            return 7 * 24 * 3600
        case "monthly":
            return 30 * 24 * 3600
        case "as needed":
            // Do not auto-schedule for PRN meds
            return nil
        default:
            // Try to parse patterns like "every X hours"
            if f.hasPrefix("every ") && f.hasSuffix(" hours") {
                let middle = f.dropFirst("every ".count).dropLast(" hours".count)
                if let hours = Double(middle) {
                    return hours * 3600
                }
            }
            return nil
        }
    }
}