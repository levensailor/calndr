import UIKit
import UserNotifications
import FacebookCore

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Override point for customization after application launch.
        UNUserNotificationCenter.current().delegate = self
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        let handledByFacebook = ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )

        if handledByFacebook {
            return true
        }

        if url.scheme == "calndr" {
            if url.host == "schedule" {
                NotificationCenter.default.post(name: .deepLinkToSchedule, object: nil)
            }
        }
        return false
    }
    // MARK: - Remote Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.sendDeviceTokenToServer(token: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // This method is called when a remote notification arrives and the app is in the background or foreground.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("Received remote notification: \(userInfo)")
        
        // Check if this is a location request notification
        if let aps = userInfo["aps"] as? [String: Any],
           let _ = aps["content-available"] as? Int,
           let type = userInfo["type"] as? String, type == "location_request" {
            
            print("Received silent location request notification.")
            
            // Use the LocationManager to get the current location
            LocationManager.shared.requestCurrentLocation { location in
                guard let location = location else {
                    print("Failed to get location.")
                    completionHandler(.failed)
                    return
                }
                
                print("Successfully retrieved location: \(location.coordinate)")
                
                // Send the location to the server
                let latitude = location.coordinate.latitude
                let longitude = location.coordinate.longitude
                
                APIService.shared.updateUserLocation(latitude: latitude, longitude: longitude) { result in
                    switch result {
                    case .success:
                        print("Successfully sent location to server.")
                        completionHandler(.newData)
                    case .failure(let error):
                        print("Failed to send location to server: \(error.localizedDescription)")
                        completionHandler(.failed)
                    }
                }
            }
        } else {
            // This is a standard notification, so no background fetch is needed.
            completionHandler(.noData)
        }
    }

    // This method is called when a notification arrives while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        NotificationManager.shared.handleRemoteNotification(payload: notification.request.content.userInfo)
        
        // Show a banner and play a sound for the notification.
        completionHandler([.banner, .sound])
    }

    // This method is called when a user taps on a notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        NotificationManager.shared.handleRemoteNotification(payload: response.notification.request.content.userInfo)
        
        completionHandler()
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
} 
