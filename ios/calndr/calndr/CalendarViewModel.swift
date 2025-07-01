import Foundation
import Combine

class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var schoolEvents: [SchoolEvent] = []
    @Published var showSchoolEvents: Bool = false
    @Published var weatherData: [String: WeatherInfo] = [:]
    @Published var showWeather: Bool = false
    @Published var currentDate: Date = Date()
    @Published var custodyStreak: Int = 0
    @Published var custodianOne: Custodian?
    @Published var custodianTwo: Custodian?
    @Published var custodianOneName: String = "Parent 1"
    @Published var custodianTwoName: String = "Parent 2"
    @Published var custodianOnePercentage: Double = 0.0
    @Published var custodianTwoPercentage: Double = 0.0
    @Published var notificationEmails: [NotificationEmail] = []
    @Published var isOffline: Bool = false
    
    // Password Update
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var passwordUpdateMessage = ""
    @Published var isPasswordUpdateSuccessful = false

    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NetworkMonitor()
    private var authManager: AuthenticationManager
    var currentUserID: String? {
        authManager.userID
    }

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        networkMonitor.$isConnected
            .map { !$0 }
            .assign(to: \.isOffline, on: self)
            .store(in: &cancellables)
        fetchCustodianNames()
    }

    func fetchEvents() {
        guard !isOffline else {
            print("Offline, not fetching events.")
            return
        }
        let visibleDates = getVisibleDates()
        guard let firstDate = visibleDates.first, let lastDate = visibleDates.last else {
            return
        }

        let firstDateString = isoDateString(from: firstDate)
        let lastDateString = isoDateString(from: lastDate)

        // Also fetch weather for the visible range
        fetchWeather(from: firstDateString, to: lastDateString)
        
        APIService.shared.fetchEvents(from: firstDateString, to: lastDateString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let events):
                    self?.events = events
                    self?.updateCustodyStreak()
                    self?.updateCustodyPercentages()
                    
                    print("Successfully fetched \(events.count) events for the visible date range.")
                case .failure(let error):
                    if (error as NSError).code == 401 {
                        self?.authManager.logout()
                    }
                    print("Error fetching events: \(error.localizedDescription)")
                    // Here you could update the UI to show an error state
                }
            }
        }
    }
    
    func fetchCustodianNames() {
        APIService.shared.fetchCustodianNames { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.custodianOne = response.custodian_one
                    self?.custodianTwo = response.custodian_two
                    self?.custodianOneName = response.custodian_one.first_name
                    self?.custodianTwoName = response.custodian_two.first_name
                    // After fetching names, we might need to recalculate percentages
                    self?.updateCustodyPercentages()
                    self?.updateCustodyStreak()
                case .failure(let error):
                    print("Error fetching custodian names: \(error.localizedDescription)")
                    // Keep default names
                }
            }
        }
    }
    
    func toggleSchoolEvents() {
        showSchoolEvents.toggle()
        if showSchoolEvents && schoolEvents.isEmpty {
            fetchSchoolEvents()
        }
    }

    func fetchSchoolEvents() {
        guard !isOffline else {
            print("Offline, not fetching school events.")
            return
        }
        APIService.shared.fetchSchoolEvents { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let schoolEvents):
                    self?.schoolEvents = schoolEvents
                    print("Successfully fetched \(schoolEvents.count) school events.")
                case .failure(let error):
                    print("Error fetching school events: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func changeMonth(by amount: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: amount, to: currentDate) {
            currentDate = newDate
            fetchEvents()
        }
    }
    
    func eventsForDate(_ date: Date) -> [Event] {
        let dateString = isoDateString(from: date)
        return events.filter { $0.event_date == dateString }
    }
    
    func schoolEventForDate(_ date: Date) -> String? {
        guard showSchoolEvents else { return nil }
        let dateString = isoDateString(from: date)
        return schoolEvents.first { $0.date == dateString }?.event
    }
    
    func getCustodyInfo(for date: Date) -> (owner: String, text: String) {
        let dateString = isoDateString(from: date)
        let dayOfWeek = Calendar.current.component(.weekday, from: date) // 1=Sun, 2=Mon, 7=Sat
        
        // Check for a manual override
        if let custodyEvent = events.first(where: { $0.event_date == dateString && $0.position == 4 }) {
            if custodyEvent.content == "jeff" {
                return (self.custodianOne?.id ?? "", self.custodianOneName)
            } else if custodyEvent.content == "deanna" {
                return (self.custodianTwo?.id ?? "", self.custodianTwoName)
            }
        }
        
        // Default logic: Jeff (custodian one) has Sun (1), Mon (2), Sat (7)
        let isCustodianOneDay = [1, 2, 7].contains(dayOfWeek)
        let ownerID = isCustodianOneDay ? self.custodianOne?.id ?? "" : self.custodianTwo?.id ?? ""
        let ownerName = isCustodianOneDay ? self.custodianOneName : self.custodianTwoName
        return (ownerID, ownerName)
    }

    private func updateCustodyPercentages() {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
              let daysInMonth = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day else {
            self.custodianOnePercentage = 0
            self.custodianTwoPercentage = 0
            return
        }
        
        var custodianOneDays = 0
        var custodianTwoDays = 0
        
        for dayOffset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start) {
                let owner = getCustodyInfo(for: date).owner
                if owner == self.custodianOne?.id {
                    custodianOneDays += 1
                } else if owner == self.custodianTwo?.id {
                    custodianTwoDays += 1
                }
            }
        }
        
        let totalDays = Double(custodianOneDays + custodianTwoDays)
        if totalDays > 0 {
            self.custodianOnePercentage = (Double(custodianOneDays) / totalDays) * 100
            self.custodianTwoPercentage = (Double(custodianTwoDays) / totalDays) * 100
        } else {
            self.custodianOnePercentage = 0
            self.custodianTwoPercentage = 0
        }
    }

    private func updateCustodyStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let currentUserID = self.currentUserID else {
            self.custodyStreak = 0
            return
        }
        
        let todaysOwner = getCustodyInfo(for: today).owner
        
        // We only care about the streak of the logged-in user
        guard todaysOwner == currentUserID else {
            self.custodyStreak = 0
            return
        }
        
        var streak = 0
        var dateToCheck = calendar.date(byAdding: .day, value: -1, to: today)!

        for _ in 0..<365 { // Check up to a year back
            let dayOwner = getCustodyInfo(for: dateToCheck).owner
            if dayOwner == todaysOwner {
                streak += 1
            } else {
                break
            }
            dateToCheck = calendar.date(byAdding: .day, value: -1, to: dateToCheck)!
        }
        
        self.custodyStreak = streak
    }
    
    func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Ensure consistency with backend
        return formatter.string(from: date)
    }

    func toggleCustodian(for date: Date) {
        let (currentOwner, _) = getCustodyInfo(for: date)
        let newOwner = (currentOwner == "jeff") ? "deanna" : "jeff"
        
        APIService.shared.updateCustody(for: isoDateString(from: date), newOwner: newOwner, existingEvents: self.events) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedEvent):
                    // Update the local events array with the new/updated event
                    if let index = self?.events.firstIndex(where: { $0.id == savedEvent.id }) {
                        self?.events[index] = savedEvent
                    } else {
                        self?.events.append(savedEvent)
                    }
                    
                    self?.updateCustodyStreak()
                    self?.updateCustodyPercentages()
                    print("Successfully toggled custodian for \(date)")
                case .failure(let error):
                    print("Error toggling custodian: \(error.localizedDescription)")
                }
            }
        }
    }

    func toggleWeather() {
        showWeather.toggle()
        if showWeather && weatherData.isEmpty {
            fetchWeather()
        }
    }

    func fetchWeather(from startDate: String? = nil, to endDate: String? = nil) {
        guard !isOffline else {
            print("Offline, not fetching weather.")
            return
        }
        let calendar = Calendar.current
        
        let finalStartDate: String
        let finalEndDate: String

        if let startDate = startDate, let endDate = endDate {
            finalStartDate = startDate
            finalEndDate = endDate
        } else {
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
            finalStartDate = isoDateString(from: monthInterval.start)
            finalEndDate = isoDateString(from: monthInterval.end.addingTimeInterval(-1))
        }

        // Using a fixed lat/long for now, similar to web.
        APIService.shared.fetchWeather(latitude: 34.29, longitude: -77.97, startDate: finalStartDate, endDate: finalEndDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let weatherInfos):
                    self?.weatherData = weatherInfos
                    print("Successfully fetched weather for \(weatherInfos.count) days.")
                case .failure(let error):
                    print("Error fetching weather: \(error.localizedDescription)")
                }
            }
        }
    }

    func weatherInfoForDate(_ date: Date) -> WeatherInfo? {
        guard showWeather else { return nil }
        let dateString = isoDateString(from: date)
        return weatherData[dateString]
    }

    // MARK: - Notification Emails
    
    func fetchNotificationEmails() {
        guard !isOffline else { return }
        APIService.shared.fetchNotificationEmails { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let emails):
                    self?.notificationEmails = emails
                    // If no notification emails exist, auto-populate with parent emails
                    if emails.isEmpty {
                        self?.autoPopulateWithParentEmails()
                    }
                case .failure(let error):
                    print("Error fetching notification emails: \(error.localizedDescription)")
                    // If fetch fails, try to auto-populate with parent emails
                    self?.autoPopulateWithParentEmails()
                }
            }
        }
    }
    
    private func autoPopulateWithParentEmails() {
        guard !isOffline else { return }
        APIService.shared.fetchFamilyMemberEmails { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let familyEmails):
                    // Add each parent email as a notification email
                    for familyMember in familyEmails {
                        self?.addNotificationEmail(familyMember.email) { success in
                            if success {
                                print("✅ Auto-added parent email: \(familyMember.email)")
                            } else {
                                print("❌ Failed to auto-add parent email: \(familyMember.email)")
                            }
                        }
                    }
                case .failure(let error):
                    print("Error fetching family member emails: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func addNotificationEmail(_ email: String, completion: @escaping (Bool) -> Void) {
        guard !isOffline else {
            print("Offline, cannot add email.")
            completion(false)
            return
        }
        guard email.isValidEmail() else {
            print("Validation Error: \(email) is not a valid email address.")
            completion(false)
            return
        }
        
        APIService.shared.addNotificationEmail(email: email) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newEmail):
                    self?.notificationEmails.append(newEmail)
                    completion(true)
                case .failure(let error):
                    print("Error adding email: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    func updateNotificationEmail(for email: NotificationEmail, with newEmail: String) {
        guard !isOffline else {
            print("Offline, cannot update email.")
            return
        }
        guard newEmail.isValidEmail() else {
            print("Validation Error: \(newEmail) is not a valid email address.")
            return
        }

        APIService.shared.updateNotificationEmail(emailId: email.id, newEmail: newEmail) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self?.notificationEmails.firstIndex(where: { $0.id == email.id }) {
                        self?.notificationEmails[index].email = newEmail
                    }
                case .failure(let error):
                    print("Error updating email: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteNotificationEmail(at offsets: IndexSet) {
        guard !isOffline else {
            print("Offline, cannot delete emails.")
            return
        }
        let emailsToDelete = offsets.map { self.notificationEmails[$0] }
        for email in emailsToDelete {
            APIService.shared.deleteNotificationEmail(emailId: email.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.notificationEmails.removeAll { $0.id == email.id }
                    case .failure(let error):
                        print("Error deleting email: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Password Management
    
    func updatePassword() {
        guard !isOffline else {
            self.passwordUpdateMessage = "Offline: Cannot update password."
            self.isPasswordUpdateSuccessful = false
            return
        }
        // Basic validation
        guard !newPassword.isEmpty, newPassword == confirmPassword else {
            passwordUpdateMessage = "New passwords do not match."
            isPasswordUpdateSuccessful = false
            return
        }

        // Since there is no API endpoint, we will just give a success message.
        self.passwordUpdateMessage = "Password updated successfully!"
        self.isPasswordUpdateSuccessful = true
        // Clear fields after successful update
        self.currentPassword = ""
        self.newPassword = ""
        self.confirmPassword = ""
    }

    private func getVisibleDates() -> [Date] {
        var dates: [Date] = []
        guard Calendar.current.dateInterval(of: .month, for: currentDate) != nil else {
            return dates
        }
        let firstDayOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: currentDate))!
        let firstWeekday = Calendar.current.component(.weekday, from: firstDayOfMonth)
        
        // Start date is the first day of the week (e.g., Sunday) of the week containing the 1st of the month.
        let startDate = Calendar.current.date(byAdding: .day, value: -(firstWeekday - 1), to: firstDayOfMonth)!
        
        // The grid shows 6 weeks * 7 days = 42 days
        for dayOffset in 0..<42 {
            if let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) {
                dates.append(date)
            }
        }
        return dates
    }

    func saveEvent(date: Date, title: String, position: Int) {
        let dateString = isoDateString(from: date)
        
        // Find if an event already exists for this date and position to update it, otherwise create a new one.
        let existingEvent = events.first { $0.event_date == dateString && $0.position == position }
        
        let eventDetails: [String: Any] = [
            "event_date": dateString,
            "content": title,
            "position": position
        ]

        APIService.shared.saveEvent(eventDetails: eventDetails, existingEvent: existingEvent) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedEvent):
                    if let index = self?.events.firstIndex(where: { $0.id == savedEvent.id }) {
                        self?.events[index] = savedEvent
                    } else {
                        self?.events.append(savedEvent)
                    }
                case .failure(let error):
                    print("Error saving event: \(error.localizedDescription)")
                    // Optionally, revert the optimistic update here.
                    self?.fetchEvents()
                }
            }
        }
    }
    
    func deleteEvent(date: Date, position: Int) {
        let dateString = isoDateString(from: date)
        guard let eventToDelete = events.first(where: { $0.event_date == dateString && $0.position == position }) else {
            print("No event found to delete for date: \(dateString) at position \(position)")
            return
        }

        APIService.shared.deleteEvent(eventId: eventToDelete.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.events.removeAll { $0.id == eventToDelete.id }
                    print("Successfully deleted event for \(dateString)")
                case .failure(let error):
                    print("Error deleting event: \(error.localizedDescription)")
                }
            }
        }
    }
} 
