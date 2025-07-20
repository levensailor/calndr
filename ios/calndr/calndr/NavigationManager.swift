import Foundation
import Combine

// Define notification names
extension NSNotification.Name {
    static let deepLinkToSchedule = NSNotification.Name("deepLinkToSchedule")
}

class NavigationManager: ObservableObject {
    @Published var shouldNavigateToSchedule = false
    
    init() {
        // Listen for deep link notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeepLinkToSchedule),
            name: .deepLinkToSchedule,
            object: nil
        )
    }
    
    @objc private func handleDeepLinkToSchedule() {
        shouldNavigateToSchedule = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 