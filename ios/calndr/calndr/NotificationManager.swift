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
} 