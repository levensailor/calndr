import Foundation
import Combine
import UIKit

class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var custodyRecords: [CustodyResponse] = [] // New: custody data from dedicated API
    @Published var schoolEvents: [SchoolEvent] = []
    @Published var showSchoolEvents: Bool = false
    @Published var weatherData: [String: WeatherInfo] = [:]
    @Published var showWeather: Bool = false
    @Published var currentDate: Date = Date()
    @Published var custodyStreak: Int = 0
    @Published var custodianWithStreak: Int = 0 // 1 for custodian one, 2 for custodian two, 0 for none
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
    private var handoffTimer: Timer?
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
        setupHandoffTimer()
        setupAppLifecycleObservers()
    }
    
    deinit {
        handoffTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
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
        
        // Fetch both regular events and custody records
        fetchRegularEvents(from: firstDateString, to: lastDateString)
        fetchCustodyRecords()
    }
    
    private func fetchRegularEvents(from startDate: String, to endDate: String) {
        APIService.shared.fetchEvents(from: startDate, to: endDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let events):
                    self?.events = events
                    print("Successfully fetched \(events.count) regular events for the visible date range.")
                case .failure(let error):
                    if (error as NSError).code == 401 {
                        self?.authManager.logout()
                    }
                    print("Error fetching regular events: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetchCustodyRecords() {
        guard !isOffline else {
            print("Offline, not fetching custody records.")
            return
        }
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        
        APIService.shared.fetchCustodyRecords(year: year, month: month) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyRecords):
                    self?.custodyRecords = custodyRecords
                    self?.updateCustodyStreak()
                    self?.updateCustodyPercentages()
                    print("Successfully fetched \(custodyRecords.count) custody records for \(year)-\(month).")
                case .failure(let error):
                    if (error as NSError).code == 401 {
                        self?.authManager.logout()
                    }
                    print("Error fetching custody records: \(error.localizedDescription)")
                    // Fall back to empty custody records
                    self?.custodyRecords = []
                }
            }
        }
    }
    
    func fetchCustodyRecordsForYear() {
        guard !isOffline else {
            print("Offline, not fetching custody records for year.")
            return
        }
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        
        var allCustodyRecords: [CustodyResponse] = []
        let dispatchGroup = DispatchGroup()
        
        // Fetch custody data for all 12 months
        for month in 1...12 {
            dispatchGroup.enter()
            APIService.shared.fetchCustodyRecords(year: year, month: month) { result in
                switch result {
                case .success(let custodyRecords):
                    allCustodyRecords.append(contentsOf: custodyRecords)
                case .failure(let error):
                    print("Error fetching custody records for \(year)-\(month): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.custodyRecords = allCustodyRecords.sorted { $0.event_date < $1.event_date }
            print("Successfully fetched \(allCustodyRecords.count) custody records for year \(year).")
        }
    }
    
    func getYearlyCustodyTotals() -> (custodianOneDays: Int, custodianTwoDays: Int) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        
        var custodianOneDays = 0
        var custodianTwoDays = 0
        
        // Calculate for the entire year
        for month in 1...12 {
            guard let monthDate = calendar.date(from: DateComponents(year: year, month: month)),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
                  let daysInMonth = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day else {
                continue
            }
            
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
        }
        
        return (custodianOneDays, custodianTwoDays)
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
            fetchEvents() // This now calls both fetchRegularEvents and fetchCustodyRecords
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
        
        // NEW: Check custody records first (from dedicated custody API)
        if let custodyRecord = custodyRecords.first(where: { $0.event_date == dateString }) {
            // Map the content back to custodian names and IDs
            if custodyRecord.content.lowercased() == self.custodianOneName.lowercased() {
                return (self.custodianOne?.id ?? "", self.custodianOneName)
            } else if custodyRecord.content.lowercased() == self.custodianTwoName.lowercased() {
                return (self.custodianTwo?.id ?? "", self.custodianTwoName)
            }
        }
        
        // LEGACY: Check for old custody events in events array (position 4) for backward compatibility
        if let custodyEvent = events.first(where: { $0.event_date == dateString && $0.position == 4 }) {
            if custodyEvent.content.lowercased() == self.custodianOneName.lowercased() {
                return (self.custodianOne?.id ?? "", self.custodianOneName)
            } else if custodyEvent.content.lowercased() == self.custodianTwoName.lowercased() {
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
        let now = Date()
        
        // Determine the effective "current day" based on handoff times
        let currentEffectiveDate = getEffectiveCustodyDate(for: now)
        let currentOwner = getCustodyInfo(for: currentEffectiveDate).owner
        
        // If no one has custody today, reset streak
        guard !currentOwner.isEmpty else {
            self.custodyStreak = 0
            self.custodianWithStreak = 0
            return
        }
        
        var streak = 1 // Include current day in streak
        var dateToCheck = calendar.date(byAdding: .day, value: -1, to: currentEffectiveDate)!

        // Count consecutive days that the same person had custody
        for _ in 0..<365 { // Check up to a year back
            let dayOwner = getCustodyInfo(for: dateToCheck).owner
            if dayOwner == currentOwner {
                streak += 1
            } else {
                break
            }
            dateToCheck = calendar.date(byAdding: .day, value: -1, to: dateToCheck)!
        }
        
        self.custodyStreak = streak
        
        // Determine which custodian has the streak
        if currentOwner == self.custodianOne?.id {
            self.custodianWithStreak = 1
        } else if currentOwner == self.custodianTwo?.id {
            self.custodianWithStreak = 2
        } else {
            self.custodianWithStreak = 0
        }
    }
    
    // Helper function to determine effective custody date based on handoff times
    private func getEffectiveCustodyDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let weekday = components.weekday ?? 1 // 1=Sunday, 7=Saturday
        
        // Convert time to minutes for easier comparison
        let currentTimeInMinutes = hour * 60 + minute
        
        // Determine handoff time based on day of week
        let handoffTimeInMinutes: Int
        if weekday == 1 || weekday == 7 { // Sunday or Saturday (weekends)
            handoffTimeInMinutes = 12 * 60 // Noon (12:00 PM)
        } else { // Monday through Friday (weekdays)
            handoffTimeInMinutes = 17 * 60 // 5:00 PM
        }
        
        // If current time is before handoff time, custody hasn't switched yet
        // so we should use the previous day for custody calculation
        if currentTimeInMinutes < handoffTimeInMinutes {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        } else {
            return calendar.startOfDay(for: date)
        }
    }
    
    // Setup timer to check for handoff times and update streak accordingly
    private func setupHandoffTimer() {
        // Check every minute to see if we've crossed a handoff time
        handoffTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkForHandoffTimeUpdate()
        }
    }
    
    // Check if we need to update custody streak due to handoff time
    private func checkForHandoffTimeUpdate() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let weekday = components.weekday ?? 1
        
        // Convert current time to minutes
        let currentTimeInMinutes = hour * 60 + minute
        
        // Determine if we're at a handoff time (within 1 minute)
        var isHandoffTime = false
        
        if weekday == 1 || weekday == 7 { // Weekend
            // Check if we're at noon (12:00 PM)
            if currentTimeInMinutes == 12 * 60 {
                isHandoffTime = true
            }
        } else { // Weekday
            // Check if we're at 5:00 PM
            if currentTimeInMinutes == 17 * 60 {
                isHandoffTime = true
            }
        }
        
                 // If we're at a handoff time, update the custody streak
         if isHandoffTime {
             print("Handoff time reached, updating custody streak...")
             updateCustodyStreak()
         }
     }
     
     // Setup app lifecycle observers to update streak when app becomes active
     private func setupAppLifecycleObservers() {
         NotificationCenter.default.addObserver(
             forName: UIApplication.didBecomeActiveNotification,
             object: nil,
             queue: .main
         ) { [weak self] _ in
             // When app becomes active, check if we need to update custody streak
             // in case handoff time was crossed while app was in background
             self?.updateCustodyStreak()
         }
     }
    
    func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current // Use user's local timezone
        return formatter.string(from: date)
    }

    func toggleCustodian(for date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDate = calendar.startOfDay(for: date)
        
        // Check if trying to edit a past date
        if selectedDate < today {
            let allowPastEditing = UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")
            guard allowPastEditing else {
                print("Editing past custody days is disabled in preferences")
                return
            }
        }
        
        let (currentOwner, _) = getCustodyInfo(for: date)
        
        // Determine the new custodian and their ID
        let newCustodianId: String
        if currentOwner == self.custodianOne?.id {
            newCustodianId = self.custodianTwo?.id ?? ""
        } else {
            newCustodianId = self.custodianOne?.id ?? ""
        }
        
        guard !newCustodianId.isEmpty else {
            print("Error: Could not determine new custodian ID")
            return
        }
        
        // Use the new custody API
        APIService.shared.updateCustodyRecord(for: isoDateString(from: date), custodianId: newCustodianId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    // Update the local custody records array
                    if let index = self?.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self?.custodyRecords[index] = custodyResponse
                    } else {
                        self?.custodyRecords.append(custodyResponse)
                    }
                    
                    self?.updateCustodyStreak()
                    self?.updateCustodyPercentages()
                    print("Successfully toggled custodian for \(date) using new custody API")
                case .failure(let error):
                    print("Error toggling custodian with new API: \(error.localizedDescription)")
                    // Could fall back to legacy API here if needed
                }
            }
        }
    }

    func toggleWeather() {
        showWeather.toggle()
        print("Weather toggled to: \(showWeather)")
        if showWeather && weatherData.isEmpty {
            print("Weather is enabled and data is empty, fetching weather...")
            fetchWeather()
        } else if showWeather {
            print("Weather is enabled but data already exists (\(weatherData.count) entries)")
        }
    }

    func fetchWeather(from startDate: String? = nil, to endDate: String? = nil) {
        guard !isOffline else {
            print("Offline, not fetching weather.")
            return
        }
        print("fetchWeather called with startDate: \(startDate ?? "nil"), endDate: \(endDate ?? "nil")")
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate date ranges for both historic and forecast data
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let maxForecastDate = calendar.date(byAdding: .day, value: 15, to: today)! // 16 days total (today + 15)
        
        let historicStartDate = isoDateString(from: sixMonthsAgo)
        let historicEndDate = isoDateString(from: yesterday)
        let forecastStartDate = isoDateString(from: today)
        let forecastEndDate = isoDateString(from: maxForecastDate)
        
        print("Fetching weather data:")
        print("Historic: \(historicStartDate) to \(historicEndDate)")
        print("Forecast: \(forecastStartDate) to \(forecastEndDate)")
        
        // Create a dispatch group to coordinate both API calls
        let weatherGroup = DispatchGroup()
        var forecastData: [String: WeatherInfo] = [:]
        var historicData: [String: WeatherInfo] = [:]
        var hasErrors = false
        
        // Fetch forecast weather (16 days from today)
        weatherGroup.enter()
        APIService.shared.fetchWeather(latitude: 34.29, longitude: -77.97, startDate: forecastStartDate, endDate: forecastEndDate) { result in
            defer { weatherGroup.leave() }
            switch result {
            case .success(let weatherInfos):
                forecastData = weatherInfos
                print("Successfully fetched forecast weather for \(weatherInfos.count) days.")
            case .failure(let error):
                print("Error fetching forecast weather: \(error.localizedDescription)")
                hasErrors = true
            }
        }
        
        // Fetch historic weather (previous 6 months)
        weatherGroup.enter()
        APIService.shared.fetchHistoricWeather(latitude: 34.29, longitude: -77.97, startDate: historicStartDate, endDate: historicEndDate) { result in
            defer { weatherGroup.leave() }
            switch result {
            case .success(let weatherInfos):
                historicData = weatherInfos
                print("Successfully fetched historic weather for \(weatherInfos.count) days.")
            case .failure(let error):
                print("Error fetching historic weather: \(error.localizedDescription)")
                // Don't set hasErrors for historic data - forecast is more important
                print("Historic weather failed, but continuing with forecast data only")
            }
        }
        
        // Combine both datasets when complete
        weatherGroup.notify(queue: .main) {
            guard !hasErrors else {
                print("Critical error in weather fetching - forecast data failed")
                return
            }
            
            // Combine historic and forecast data
            var combinedWeatherData: [String: WeatherInfo] = [:]
            
            // Add historic data first
            for (dateString, weatherInfo) in historicData {
                combinedWeatherData[dateString] = weatherInfo
            }
            
            // Add forecast data (will override any overlapping dates)
            for (dateString, weatherInfo) in forecastData {
                combinedWeatherData[dateString] = weatherInfo
            }
            
            self.weatherData = combinedWeatherData
            print("Successfully combined weather data: \(historicData.count) historic + \(forecastData.count) forecast = \(combinedWeatherData.count) total days")
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
        
        // FIX: Actually call the backend API instead of local-only update
        let passwordUpdate = PasswordUpdate(
            current_password: currentPassword,
            new_password: newPassword
        )
        
        APIService.shared.updatePassword(passwordUpdate: passwordUpdate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.passwordUpdateMessage = "Password updated successfully!"
                    self?.isPasswordUpdateSuccessful = true
                    // Clear fields after successful update
                    self?.currentPassword = ""
                    self?.newPassword = ""
                    self?.confirmPassword = ""
                case .failure(let error):
                    self?.passwordUpdateMessage = "Failed to update password: \(error.localizedDescription)"
                    self?.isPasswordUpdateSuccessful = false
                }
            }
        }
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
        // Guard against custody events (position 4) - these should use the custody API
        guard position != 4 else {
            print("ERROR: Position 4 (custody) events should use toggleCustodian() and the custody API, not saveEvent()")
            return
        }
        
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
