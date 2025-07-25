import Foundation
import Combine
import UIKit

class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var custodyRecords: [CustodyResponse] = [] // New: custody data from dedicated API

    @Published var schoolEvents: [SchoolEvent] = []
    @Published var showSchoolEvents: Bool = UserDefaults.standard.bool(forKey: "showSchoolEvents") {
        didSet {
            UserDefaults.standard.set(showSchoolEvents, forKey: "showSchoolEvents")
            if showSchoolEvents && !oldValue && schoolEvents.isEmpty {
                fetchSchoolEvents()
            }
        }
    }
    @Published var weatherData: [String: WeatherInfo] = [:]
    @Published var showWeather: Bool = UserDefaults.standard.bool(forKey: "showWeather") {
        didSet {
            UserDefaults.standard.set(showWeather, forKey: "showWeather")
        }
    }
    @Published var currentDate: Date = Date()
    @Published var custodyStreak: Int = 0
    @Published var custodianWithStreak: Int = 0 // 1 for custodian one, 2 for custodian two, 0 for none
    @Published var custodianOneName: String = "Parent 1"
    @Published var custodianTwoName: String = "Parent 2"
    @Published var custodianOneId: String?
    @Published var custodianTwoId: String?
    @Published var custodianOnePercentage: Double = 0.0
    @Published var custodianTwoPercentage: Double = 0.0
    @Published var notificationEmails: [NotificationEmail] = []
    @Published var isOffline: Bool = false
    
    // MARK: - Family Management Properties
    @Published var coparents: [Coparent] = []
    @Published var children: [Child] = []
    @Published var otherFamilyMembers: [OtherFamilyMember] = []
    @Published var daycareProviders: [DaycareProvider] = []
    @Published var schoolProviders: [SchoolProvider] = []
    @Published var scheduleTemplates: [ScheduleTemplate] = []
    @Published var babysitters: [Babysitter] = []
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var reminders: [Reminder] = []
    @Published var journalEntries: [JournalEntry] = []
    @Published var showHandoffTimeline: Bool = false // Toggle for handoff timeline view
    @Published var custodiansLoaded: Bool = false // DEPRECATED: Use isHandoffDataReady instead
    @Published var isHandoffDataReady: Bool = false // NEW: True when all handoff data is loaded
    @Published var isDataLoading: Bool = false
    
    // Password Update
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var passwordUpdateMessage = ""
    @Published var isPasswordUpdateSuccessful = false

    private var cancellables = Set<AnyCancellable>()
    private var isDataLoaded: Bool = false
    private let networkMonitor: NetworkMonitor
    var authManager: AuthenticationManager
    private var themeManager: ThemeManager
    private var handoffTimer: Timer?
    
    // Track in-flight custody updates to prevent duplicates
    private var inFlightCustodyUpdates: Set<String> = []
    var currentUserID: String? {
        authManager.userID
    }
    
    let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for consistency
        return formatter
    }()
    
    init(authManager: AuthenticationManager, themeManager: ThemeManager) {
        self.authManager = authManager
        self.themeManager = themeManager
        self.networkMonitor = NetworkMonitor()
        self.isOffline = !self.networkMonitor.isConnected
        
        setupBindings()
        setupAppLifecycleObservers()
        // fetchInitialData() - Removed, will be called from setupBindings when auth is ready
        
        // Prune the weather cache on app launch
        WeatherCacheManager.shared.pruneCache()
    }
    
    deinit {
        handoffTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupBindings() {
        print("📱 CalendarViewModel: setupBindings() called")
        // When the user logs in AND has a family ID, fetch initial data.
        AuthenticationService.shared.$isLoggedIn
            .combineLatest(AuthenticationService.shared.$familyId)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main) // Debounce rapid changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoggedIn, familyId in
                guard let self = self else { return }

                print("📱 CalendarViewModel: Auth state changed - isLoggedIn: \(isLoggedIn), familyId: \(familyId ?? "nil")")
                print("📱 CalendarViewModel: Current isDataLoaded: \(self.isDataLoaded)")

                if isLoggedIn, familyId != nil {
                    // Only fetch data if it hasn't been loaded yet for this session.
                    if !self.isDataLoaded {
                        print("📱✅ CalendarViewModel: Login detected and data not loaded. Fetching initial data...")
                        self.fetchInitialData()
                    } else {
                        print("📱 CalendarViewModel: Login detected but data already loaded, skipping fetch")
                    }
                } else {
                    // User logged out or familyId is nil
                    print("📱❌ CalendarViewModel: Logout detected or missing familyId. Resetting data.")
                    print("📱❌ CalendarViewModel: isLoggedIn = \(isLoggedIn), familyId = \(familyId ?? "nil")")
                    self.resetData()
                }
            }
            .store(in: &cancellables)
    }

    func fetchInitialData() {
        // isDataLoaded guard is now handled in setupBindings to allow re-fetch on new login
        print("📅 CalendarViewModel: fetchInitialData() called")
        print("📅 CalendarViewModel: AuthenticationService.shared.isLoggedIn = \(AuthenticationService.shared.isLoggedIn)")
        print("📅 CalendarViewModel: AuthenticationService.shared.familyId = \(AuthenticationService.shared.familyId ?? "nil")")
        
        guard AuthenticationService.shared.isLoggedIn else {
            print("📅❌ CalendarViewModel: User not logged in, aborting initial data fetch.")
            return
        }
        print("📅 CalendarViewModel: --- Starting initial data fetch ---")
        self.isDataLoaded = true // Set this immediately to prevent re-entry for the same session
        
        print("📅 CalendarViewModel: Starting fetchHandoffsAndCustody()...")
        fetchHandoffsAndCustody()
        
        print("📅 CalendarViewModel: Starting fetchFamilyData()...")
        fetchFamilyData()
        
        print("📅 CalendarViewModel: Loading themes and applying user preference...")
        // Load themes first, then apply user preference
        themeManager.loadThemes { [weak self] in
            print("📅 CalendarViewModel: Themes loaded, now fetching user theme preference...")
            self?.fetchUserThemePreference()
        }
        
        print("📅 CalendarViewModel: Starting fetchReminders()...")
        fetchReminders() // Load reminders
        
        print("📅 CalendarViewModel: Starting fetchJournalEntries()...")
        fetchJournalEntries() // Load journal entries
        
        // Fetch school events if enabled
        if showSchoolEvents && schoolEvents.isEmpty {
            print("📅 CalendarViewModel: Starting fetchSchoolEvents()...")
            fetchSchoolEvents()
        }
        
        print("📅 CalendarViewModel: All initial fetch methods started")
    }
    
    func resetData() {
        print("Resetting all local data.")
        isDataLoaded = false
        events = []
        custodyRecords = []
        schoolEvents = []
        weatherData = [:]
        custodianOneName = "Parent 1"
        custodianTwoName = "Parent 2"
        custodianOneId = nil
        custodianTwoId = nil
        isHandoffDataReady = false
        isDataLoading = false
        
        // Reset family data
        coparents = []
        children = []
        otherFamilyMembers = []
        daycareProviders = []
        scheduleTemplates = []
        babysitters = []
        emergencyContacts = []
        reminders = []
        journalEntries = []
    }

    func fetchHandoffsAndCustody() {
        print("🏠 CalendarViewModel: fetchHandoffsAndCustody() called")
        print("🏠 CalendarViewModel: familyId = \(AuthenticationService.shared.familyId ?? "nil")")
        
        guard AuthenticationService.shared.familyId != nil else {
            print("🏠❌ CalendarViewModel: No family ID, cannot fetch handoffs or custody.")
            return
        }

        print("🏠 CalendarViewModel: Setting loading states...")
        self.isDataLoading = true
        self.isHandoffDataReady = false
        
        let dispatchGroup = DispatchGroup()

        // Fetch custodian names
        print("🏠 CalendarViewModel: Starting custodian names fetch...")
        dispatchGroup.enter()
        APIService.shared.fetchCustodianNames { [weak self] result in
            defer { dispatchGroup.leave() }
            DispatchQueue.main.async {
                print("🏠 CalendarViewModel: Custodian names fetch completed")
                switch result {
                case .success(let custodians):
                    print("🏠✅ CalendarViewModel: Custodian names fetch success - received \(custodians.count) custodians")
                    if custodians.count >= 2 {
                        self?.custodianOneName = custodians[0].first_name
                        self?.custodianTwoName = custodians[1].first_name
                        self?.custodianOneId = custodians[0].id
                        self?.custodianTwoId = custodians[1].id
                        print("🏠✅ CalendarViewModel: Successfully set custodian names: \(custodians[0].first_name), \(custodians[1].first_name)")
                        print("🏠✅ CalendarViewModel: Custodian IDs: \(custodians[0].id), \(custodians[1].id)")
                    } else {
                        print("🏠❌ CalendarViewModel: Error: Not enough custodians in response (found \(custodians.count))")
                    }
                case .failure(let error):
                    print("🏠❌ CalendarViewModel: Error fetching custodian names: \(error.localizedDescription)")
                    print("🏠❌ CalendarViewModel: Error code: \((error as NSError).code)")
                    if (error as NSError).code == 401 {
                        print("🏠❌🔐 CalendarViewModel: 401 error in custodian fetch - this will likely trigger logout")
                    }
                }
            }
        }

        // Fetch custody records
        dispatchGroup.enter()
        fetchCustodyRecords {
            dispatchGroup.leave()
        }

        // When both are done, update the UI
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Check if we have the essential data before flagging as ready
            if self.custodianOneId != nil && self.custodianTwoId != nil && !self.custodyRecords.isEmpty {
                print("✅ All initial handoff data is ready.")
                self.isHandoffDataReady = true
            } else {
                print("❌ Failed to fetch all necessary handoff data. Custodian IDs or records are missing.")
                print("   - Custodian 1 ID: \(self.custodianOneId ?? "nil")")
                print("   - Custodian 2 ID: \(self.custodianTwoId ?? "nil")")
                print("   - Custody Records count: \(self.custodyRecords.count)")
                self.isHandoffDataReady = false
                
                // If we failed to load handoff data, hide the timeline
                if self.showHandoffTimeline {
                    print("⚠️ Hiding handoff timeline due to data load failure")
                    self.showHandoffTimeline = false
                }
            }
            self.isDataLoading = false // End loading state
            
            // Calculate custody percentages after all data is loaded
            self.updateCustodyPercentages()
        }
    }

    func fetchEvents() {
        guard !isOffline else {
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
        fetchCustodyRecords() // Keep this for subsequent fetches
    }
    
    private func fetchRegularEvents(from startDate: String, to endDate: String) {
        print("📅 CalendarViewModel: fetchRegularEvents() called for \(startDate) to \(endDate)")
        
        // The main /events/ API already returns ALL events (family, school, daycare) combined
        // via the family_all_events view, so we don't need separate API calls
        APIService.shared.fetchEvents(from: startDate, to: endDate) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let events):
                    self.events = events
                    
                    // Update the legacy schoolEvents array for compatibility with old UI components
                    let schoolEventsList = events.filter { $0.source_type == "school" }
                        .compactMap { event -> SchoolEvent? in
                            return SchoolEvent(date: event.event_date, event: event.content)
                        }
                    self.schoolEvents = schoolEventsList
                    
                    // Log breakdown for debugging
                    let familyCount = events.filter { $0.source_type == "family" || $0.source_type == nil }.count
                    let schoolCount = events.filter { $0.source_type == "school" }.count
                    let daycareCount = events.filter { $0.source_type == "daycare" }.count
                    
                    print("📅✅ CalendarViewModel: Fetched \(events.count) total events - Family: \(familyCount), School: \(schoolCount), Daycare: \(daycareCount)")
                    
                case .failure(let error):
                    print("📅❌ CalendarViewModel: Error fetching events: \(error.localizedDescription)")
                    if (error as NSError).code == 401 {
                        print("📅❌🔐 CalendarViewModel: 401 UNAUTHORIZED ERROR - TRIGGERING LOGOUT!")
                        self.authManager.logout()
                    }
                }
            }
        }
    }
    
    func fetchCustodyRecords(completion: (() -> Void)? = nil) {
        guard !isOffline else {
            completion?()
            return
        }
        
        let calendar = Calendar.current
        
        // Get unique year-month combinations for the visible range
        var monthsToFetch: Set<String> = []
        
        // Instead of jumping by months, iterate through each visible date to ensure we capture all months
        let allVisibleDates = getVisibleDates()
        for date in allVisibleDates {
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let monthKey = "\(year)-\(month)"
            monthsToFetch.insert(monthKey)
        }
        
        var allCustodyRecords: [CustodyResponse] = []
        let dispatchGroup = DispatchGroup()
        
        // Fetch custody data for all required months
        for monthKey in monthsToFetch {
            let components = monthKey.split(separator: "-")
            guard components.count == 2,
                  let year = Int(components[0]),
                  let month = Int(components[1]) else { continue }
            
            dispatchGroup.enter()
            APIService.shared.fetchCustodyRecords(year: year, month: month) { result in
                // Process result in the background
                switch result {
                case .success(let custodyRecords):
                    DispatchQueue.main.async {
                        // Defensive check: if we get an empty response but already have custody data 
                        // for this month, don't replace it (could be cache expiry issue)
                        if custodyRecords.isEmpty {
                            let monthKey = "\(year)-\(String(format: "%02d", month))"
                            let hasExistingData = allCustodyRecords.contains { record in
                                record.event_date.hasPrefix(monthKey)
                            } || self.custodyRecords.contains { record in
                                record.event_date.hasPrefix(monthKey)
                            } == true
                            
                            if hasExistingData {
                                print("⚠️ Received empty custody response for \(year)-\(month) but have existing data - preserving existing records")
                                // Don't update allCustodyRecords with empty data
                            } else {
                                print("ℹ️ Received empty custody response for \(year)-\(month) - no existing data to preserve")
                                allCustodyRecords.append(contentsOf: custodyRecords)
                            }
                        } else {
                            print("✅ Received \(custodyRecords.count) custody records for \(year)-\(month)")
                            allCustodyRecords.append(contentsOf: custodyRecords)
                        }
                    }
                case .failure(let error):
                    print("Error fetching custody records for \(year)-\(month): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Merge new data with existing data instead of replacing entirely
            if !allCustodyRecords.isEmpty {
                // Create a dictionary of new records by date for efficient lookup
                let newRecordsByDate = Dictionary(uniqueKeysWithValues: allCustodyRecords.map { ($0.event_date, $0) })
                
                // Update existing records or add new ones
                for (date, newRecord) in newRecordsByDate {
                    if let existingIndex = self.custodyRecords.firstIndex(where: { $0.event_date == date }) {
                        self.custodyRecords[existingIndex] = newRecord
                    } else {
                        self.custodyRecords.append(newRecord)
                    }
                }
                
                // Sort the combined records
                self.custodyRecords.sort { $0.event_date < $1.event_date }
                print("🔄 Merged custody data: \(self.custodyRecords.count) total records")
            } else {
                print("ℹ️ No new custody data to merge")
            }
            
            self.updateCustodyStreak()
            self.updateCustodyPercentages()
            completion?() // Signal completion
        }
    }
    
    // Helper function to get the full date range visible in the calendar view
    private func getVisibleCalendarDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        
        // Get the month interval for the current date
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else {
            return (start: currentDate, end: currentDate)
        }
        
        let firstDayOfMonth = monthInterval.start
        let lastDayOfMonth = monthInterval.end
        
        // Find the first day of the week containing the first day of the month
        guard let firstDayOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDayOfMonth)),
              let lastDayOfMonthWithTime = calendar.date(byAdding: .day, value: -1, to: lastDayOfMonth),
              let lastDayOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastDayOfMonthWithTime)) else {
            return (start: firstDayOfMonth, end: lastDayOfMonth)
        }
        
        let startDate = firstDayOfWeek
        let endDate = calendar.date(byAdding: .day, value: 6, to: lastDayOfWeek)!
        
        return (start: startDate, end: endDate)
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
            self?.updateCustodyStreak()
            self?.updateCustodyPercentages()
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
                    if owner == self.custodianOneId {
                        custodianOneDays += 1
                    } else if owner == self.custodianTwoId {
                        custodianTwoDays += 1
                    }
                }
            }
        }
        
        return (custodianOneDays, custodianTwoDays)
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
        
        // Get the current visible date range
        let visibleDates = getVisibleDates()
        guard let firstDate = visibleDates.first, let lastDate = visibleDates.last else {
            return
        }
        
        let firstDateString = isoDateString(from: firstDate)
        let lastDateString = isoDateString(from: lastDate)
        
        APIService.shared.fetchSchoolEvents(from: firstDateString, to: lastDateString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let events):
                    // Convert [Event] to [SchoolEvent] for compatibility with old system
                    let schoolEvents = events.compactMap { event -> SchoolEvent? in
                        // School events from the new API are prefixed with provider name in brackets
                        // e.g., "[Gregory Elementary] Event Title"
                        guard event.content.hasPrefix("[") && event.content.contains("]") else { return nil }
                        return SchoolEvent(date: event.event_date, event: event.content)
                    }
                    self?.schoolEvents = schoolEvents
                    print("Successfully fetched \(schoolEvents.count) school events for legacy system.")
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
    
    func daycareEventForDate(_ date: Date) -> String? {
        let dateString = isoDateString(from: date)
        // Find daycare events by checking the source_type field
        let daycareEvent = events.first { event in
            event.event_date == dateString &&
            event.source_type == "daycare"
        }
        return daycareEvent?.content
    }
    
    func getCustodyInfo(for date: Date) -> (owner: String, text: String) {
        let dateString = isoDateString(from: date)
        
        // Special debugging for Monday the 21st issue
        if dateString.contains("-21") {
            print("🔍 DEBUG: getCustodyInfo called for Monday 21st (\(dateString))")
            print("🔍 DEBUG: isHandoffDataReady = \(isHandoffDataReady)")
            print("🔍 DEBUG: custodyRecords.count = \(custodyRecords.count)")
            print("🔍 DEBUG: custodianOneId = '\(custodianOneId ?? "nil")', custodianTwoId = '\(custodianTwoId ?? "nil")'")
            print("🔍 DEBUG: custodianOneName = '\(custodianOneName)', custodianTwoName = '\(custodianTwoName)'")
        }
        
        // If custodian data isn't loaded yet, return empty info to avoid race conditions
        guard isHandoffDataReady else {
            if dateString.contains("-21") {
                print("🔍 DEBUG: Monday 21st - Data not ready, returning empty")
            }
            return ("", "")
        }
        
        // NEW: Check custody records first (from dedicated custody API)
        if let custodyRecord = custodyRecords.first(where: { $0.event_date == dateString }) {
            if dateString.contains("-21") {
                print("🔍 DEBUG: Monday 21st - Found custody record:")
                print("   - Record ID: \(custodyRecord.id)")
                print("   - Record custodian_id: '\(custodyRecord.custodian_id)'")
                print("   - Record content: '\(custodyRecord.content)'")
                print("   - Record handoff_day: \(custodyRecord.handoff_day ?? false)")
            }
            
            // CORRECTED: Compare the custodian_id directly
            if custodyRecord.custodian_id == self.custodianOneId {
                if dateString.contains("-21") {
                    print("🔍 DEBUG: Monday 21st - Returning custodian ONE (Jeff): '\(self.custodianOneName)'")
                }
                return (self.custodianOneId ?? "", self.custodianOneName)
            } else if custodyRecord.custodian_id == self.custodianTwoId {
                if dateString.contains("-21") {
                    print("🔍 DEBUG: Monday 21st - Returning custodian TWO (Deanna): '\(self.custodianTwoName)'")
                }
                return (self.custodianTwoId ?? "", self.custodianTwoName)
            } else {
                print("⚠️ getCustodyInfo(\(dateString)): Custody record found but custodian_id doesn't match known IDs")
                print("   Record custodian_id: '\(custodyRecord.custodian_id)'")
                print("   Custodian one ID: '\(self.custodianOneId ?? "nil")'")
                print("   Custodian two ID: '\(self.custodianTwoId ?? "nil")'")
            }
        } else {
            if dateString.contains("-21") {
                print("🔍 DEBUG: Monday 21st - No custody record found in custodyRecords array")
                print("🔍 DEBUG: Available custody records:")
                for record in custodyRecords.prefix(5) {
                    print("   - \(record.event_date): \(record.content) (ID: \(record.custodian_id))")
                }
                if custodyRecords.count > 5 {
                    print("   - ... and \(custodyRecords.count - 5) more records")
                }
            }
        }
        
        // LEGACY: Check for old custody events in events array (position 4) for backward compatibility
        if let custodyEvent = events.first(where: { $0.event_date == dateString && $0.position == 4 }) {
            if custodyEvent.content.lowercased() == self.custodianOneName.lowercased() {
                return (self.custodianOneId ?? "", self.custodianOneName)
            } else if custodyEvent.content.lowercased() == self.custodianTwoName.lowercased() {
                return (self.custodianTwoId ?? "", self.custodianTwoName)
            }
        }
        
        // No custody record found
        // For past dates, return empty to avoid showing "No custody assigned" 
        // For future dates, show "No custody assigned" to prompt user action
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateToCheck = calendar.startOfDay(for: date)
        
        if dateToCheck < today {
            // Past date - return empty to hide custody display
            return ("", "")
        } else {
            // Future date - show assignment prompt
            return ("", "No custody assigned")
        }
    }
    
    func getHandoffTimeForDate(_ date: Date) -> (hour: Int, minute: Int, location: String?) {
        let dateString = isoDateString(from: date)
        let dayOfWeek = Calendar.current.component(.weekday, from: date) // 1=Sun, 2=Mon, 7=Sat
        
        // First check for any custody record with handoff data (regardless of handoff_day flag)
        if let custodyRecord = custodyRecords.first(where: { $0.event_date == dateString && ($0.handoff_time != nil || $0.handoff_location != nil) }) {
            var hour: Int?
            var minute: Int?
            
            // Parse the handoff time if available
            if let handoffTime = custodyRecord.handoff_time {
                let components = handoffTime.split(separator: ":")
                if components.count == 2,
                   let parsedHour = Int(components[0]),
                   let parsedMinute = Int(components[1]) {
                    hour = parsedHour
                    minute = parsedMinute
                } else {
                    print("⚠️ Invalid time format in custody handoff record for \(dateString): '\(handoffTime)'")
                }
            }
            
            // If we have a valid time, return it with the location
            if let validHour = hour, let validMinute = minute {
                return (validHour, validMinute, custodyRecord.handoff_location)
            }
        }
        
        // Fallback: Check custody record for handoff time with handoff_day flag
        if let custodyRecord = custodyRecords.first(where: { $0.event_date == dateString && $0.handoff_day == true }) {
            var hour: Int?
            var minute: Int?
            
            // Parse the handoff time if available
            if let handoffTime = custodyRecord.handoff_time {
                let components = handoffTime.split(separator: ":")
                if components.count == 2,
                   let parsedHour = Int(components[0]),
                   let parsedMinute = Int(components[1]) {
                    hour = parsedHour
                    minute = parsedMinute
                } else {
                    print("⚠️ Invalid time format in custody handoff record for \(dateString): '\(handoffTime)'")
                }
            }
            
            // If we have a valid time, return it with the location
            if let validHour = hour, let validMinute = minute {
                return (validHour, validMinute, custodyRecord.handoff_location)
            }
        }
        
        // Default logic: Noon (12:00) for weekends, 5:00 PM for weekdays
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7 // Sunday or Saturday
        let defaultHour = isWeekend ? 12 : 17
        let defaultLocation = isWeekend ? "neutral ground" : "daycare" // Example default locations
        
        print("🔄 Using default handoff time for \(dateString): \(defaultHour):00 at \(defaultLocation)")
        return (defaultHour, 0, defaultLocation)
    }

    func updateCustodyPercentages() {
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
                if owner == self.custodianOneId {
                    custodianOneDays += 1
                } else if owner == self.custodianTwoId {
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
        if currentOwner == self.custodianOneId {
            self.custodianWithStreak = 1
        } else if currentOwner == self.custodianTwoId {
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
        if weekday == 1 || weekday == 7 { // Weekend
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
         print("🔧 Setting up app lifecycle observers")
         NotificationCenter.default.addObserver(
             forName: UIApplication.didBecomeActiveNotification,
             object: nil,
             queue: .main
         ) { [weak self] _ in
             print("📱 App became active - running lifecycle tasks")
             // When app becomes active, check if we need to update custody streak
             // in case handoff time was crossed while app was in background
             self?.updateCustodyStreak()
             
             // Update last signin time when app becomes active
             self?.updateLastSigninTime()
         }
     }
    
    func isoDateString(from date: Date) -> String {
        return isoDateFormatter.string(from: date)
    }
    
    private func updateLastSigninTime() {
        print("🕐 updateLastSigninTime called")
        
        // Only update if user is authenticated
        guard AuthenticationService.shared.isLoggedIn else {
            print("⚠️ User not logged in, skipping last signin update")
            return
        }
        
        print("🔐 User is authenticated, calling API to update last signin")
        APIService.shared.updateLastSignin { result in
            switch result {
            case .success:
                print("✅ Last signin time updated successfully")
            case .failure(let error):
                print("❌ Failed to update last signin time: \(error.localizedDescription)")
            }
        }
    }

    func toggleCustodian(for date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDate = calendar.startOfDay(for: date)
        let dateString = isoDateString(from: date)
        
        print("🔄 toggleCustodian called for \(dateString)")
        print("🔍 Current state: isHandoffDataReady=\(isHandoffDataReady), custodyRecords.count=\(custodyRecords.count)")
        
        // Check if data is ready before proceeding
        guard isHandoffDataReady else {
            print("⚠️ Cannot toggle custodian for \(dateString) - handoff data not ready yet")
            return
        }
        
        // Check if there's already an in-flight request for this date
        guard !inFlightCustodyUpdates.contains(dateString) else {
            print("⚠️ Custody update already in progress for \(dateString), ignoring duplicate request")
            return
        }
        
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
        if currentOwner == self.custodianOneId {
            newCustodianId = self.custodianTwoId ?? ""
        } else {
            newCustodianId = self.custodianOneId ?? ""
        }
        
        guard !newCustodianId.isEmpty else {
            print("Error: Could not determine new custodian ID")
            return
        }
        
        // Mark this date as having an in-flight request
        inFlightCustodyUpdates.insert(dateString)
        print("🔄 Starting custody update for \(dateString)")
        
        // Check if this should be a handoff day by comparing with previous day
        let previousDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let (previousOwner, _) = getCustodyInfo(for: previousDate)
        let isHandoffDay = !previousOwner.isEmpty && previousOwner != newCustodianId
        
        var handoffTime: String? = nil
        var handoffLocation: String? = nil
        
        if isHandoffDay {
            // Determine handoff time and location based on day of week
            let weekday = calendar.component(.weekday, from: date) // 1=Sunday, 7=Saturday
            let isWeekend = weekday == 1 || weekday == 7 // Sunday or Saturday
            
            if isWeekend {
                // Weekend: noon at target custodian's home
                handoffTime = "12:00"
                let targetCustodianName = newCustodianId == self.custodianOneId ? self.custodianOneName : self.custodianTwoName
                handoffLocation = "\(targetCustodianName.lowercased())'s home"
            } else {
                // Weekday: 5pm at daycare
                handoffTime = "17:00"
                handoffLocation = "daycare"
            }
            
            print("Setting handoff for \(isoDateString(from: date)): \(handoffTime!) at \(handoffLocation!)")
        }
        
        // Use the new custody API with handoff information
        APIService.shared.updateCustodyRecord(
            for: dateString, 
            custodianId: newCustodianId,
            handoffDay: isHandoffDay,
            handoffTime: handoffTime,
            handoffLocation: handoffLocation
        ) { [weak self] result in
            DispatchQueue.main.async {
                // Always remove from in-flight set when request completes
                self?.inFlightCustodyUpdates.remove(dateString)
                
                switch result {
                case .success(let custodyResponse):
                    // Update the local custody records array
                    if let index = self?.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self?.custodyRecords[index] = custodyResponse
                        print("🔄 Updated existing custody record at index \(index) for \(dateString)")
                    } else {
                        self?.custodyRecords.append(custodyResponse)
                        print("🔄 Added new custody record for \(dateString)")
                    }
                    
                    // Ensure custody records stay sorted by date
                    self?.custodyRecords.sort { $0.event_date < $1.event_date }
                    
                    // Force multiple UI refresh signals to ensure all views update
                    self?.objectWillChange.send()
                    
                    // Additional refresh with slight delay to catch any lazy-loaded views
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self?.objectWillChange.send()
                    }
                    
                    self?.updateCustodyStreak()
                    self?.updateCustodyPercentages()
                    
                    // Debug: print current custody state
                    print("✅ Successfully toggled custodian for \(dateString) using new custody API")
                    print("🔍 Updated custody record: \(custodyResponse.event_date) -> \(custodyResponse.content) (ID: \(custodyResponse.custodian_id))")
                    print("🔍 Total custody records in memory: \(self?.custodyRecords.count ?? 0)")
                    print("🔍 isHandoffDataReady: \(self?.isHandoffDataReady ?? false)")
                    
                    // Verify the update by checking what getCustodyInfo returns now
                    if let strongSelf = self {
                        let verifyInfo = strongSelf.getCustodyInfo(for: date)
                        print("🔍 Verification: getCustodyInfo now returns: owner='\(verifyInfo.owner)', text='\(verifyInfo.text)'")
                    }
                case .failure(let error):
                    print("❌ Error toggling custodian for \(dateString) with new API: \(error.localizedDescription)")
                    print("❌ Error code: \((error as NSError).code)")
                    
                    if (error as NSError).code == 401 {
                        print("❌🔐 CalendarViewModel: 401 UNAUTHORIZED ERROR in toggleCustodian - TRIGGERING LOGOUT!")
                        print("❌🔐 CalendarViewModel: This means the token is invalid/expired")
                        self?.authManager.logout()
                    }
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
        
        // First, load any valid cached data to display immediately
        let cachedWeather = WeatherCacheManager.shared.getValidCache()
        if !cachedWeather.isEmpty {
            DispatchQueue.main.async {
                self.weatherData = cachedWeather
                print("Loaded weather data from cache.")
            }
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
            
            // Combine historic and forecast data, preferring fresh data
            var combinedWeatherData = self.weatherData // Start with existing (cached) data
            
            // Add historic data first
            for (dateString, weatherInfo) in historicData {
                combinedWeatherData[dateString] = weatherInfo
            }
            
            // Add forecast data (will override any overlapping dates)
            for (dateString, weatherInfo) in forecastData {
                combinedWeatherData[dateString] = weatherInfo
            }
            
            self.weatherData = combinedWeatherData
            
            // Save the newly fetched data to the cache
            var dataToCache: [String: WeatherInfo] = [:]
            historicData.forEach { dataToCache[$0] = $1 }
            forecastData.forEach { dataToCache[$0] = $1 }
            WeatherCacheManager.shared.save(weatherData: dataToCache)
            
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
        
        print("🗓️ getVisibleDates() - first: \(isoDateString(from: dates.first!)), last: \(isoDateString(from: dates.last!))")
        return dates
    }

    func saveEvent(date: Date, title: String) {
        let dateString = isoDateString(from: date)
        
        // Find if an event already exists for this date to update it, otherwise create a new one.
        // Only consider family events (exclude custody, school, and daycare events)
        let existingEvent = events.first { 
            $0.event_date == dateString && 
            $0.position != 4 && // Exclude custody events
            $0.source_type != "school" && // Exclude school events
            $0.source_type != "daycare" // Exclude daycare events
        }
        
        let eventDetails: [String: Any] = [
            "event_date": dateString,
            "content": title
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
    
    func deleteEvent(date: Date) {
        let dateString = isoDateString(from: date)
        // Find the first non-custody event for this date
        guard let eventToDelete = events.first(where: { $0.event_date == dateString && $0.position != 4 }) else {
            print("No event found to delete for date: \(dateString)")
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
    
    // Update only the handoff_day field for a custody record
    func updateHandoffDayOnly(for date: Date, handoffDay: Bool, completion: @escaping () -> Void = {}) {
        let dateString = isoDateString(from: date)
        
        // Check if there's already an in-flight request for this date
        guard !inFlightCustodyUpdates.contains(dateString) else {
            print("⚠️ Custody update already in progress for \(dateString), ignoring duplicate updateHandoffDayOnly request")
            completion()
            return
        }
        
        // Mark this date as having an in-flight request
        inFlightCustodyUpdates.insert(dateString)
        
        // Get current custodian for this date
        let (currentCustodianId, _) = getCustodyInfo(for: date)
        
        // Use the main updateCustodyRecord function instead of the broken updateHandoffDayOnly
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: currentCustodianId, handoffDay: handoffDay) { result in
            DispatchQueue.main.async {
                // Always remove from in-flight set when request completes
                self.inFlightCustodyUpdates.remove(dateString)
                
                switch result {
                case .success(let custodyResponse):
                    if let index = self.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self.custodyRecords[index] = custodyResponse
                    } else {
                        self.custodyRecords.append(custodyResponse)
                    }
                    print("✅ Successfully updated handoff_day for \(dateString) to \(handoffDay)")
                case .failure(let error):
                    print("❌ Error updating handoff_day for \(dateString): \(error.localizedDescription)")
                    
                    if (error as NSError).code == 401 {
                        print("❌🔐 CalendarViewModel: 401 UNAUTHORIZED ERROR in updateHandoffDayOnly - TRIGGERING LOGOUT!")
                        self.authManager.logout()
                    }
                }
                completion()
            }
        }
    }
    
    // Custody update for a single day
    func updateCustodyForSingleDay(date: Date, newCustodianId: String, completion: @escaping () -> Void) {
        let dateString = isoDateString(from: date)
        
        // Check if there's already an in-flight request for this date
        guard !inFlightCustodyUpdates.contains(dateString) else {
            print("⚠️ Custody update already in progress for \(dateString), ignoring duplicate updateCustodyForSingleDay request")
            completion()
            return
        }
        
        // Mark this date as having an in-flight request
        inFlightCustodyUpdates.insert(dateString)
        
        if let index = custodyRecords.firstIndex(where: { $0.event_date == dateString }) {
            custodyRecords[index].custodian_id = newCustodianId
            updateCustodyPercentages()
            objectWillChange.send()
        }
        
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: newCustodianId, handoffDay: false) { result in
            DispatchQueue.main.async {
                // Always remove from in-flight set when request completes
                self.inFlightCustodyUpdates.remove(dateString)
                
                switch result {
                case .success(let custodyResponse):
                    if let index = self.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self.custodyRecords[index] = custodyResponse
                    } else {
                        self.custodyRecords.append(custodyResponse)
                    }
                case .failure(let error):
                    print("Error updating custody record: \(error.localizedDescription)")
                    
                    if (error as NSError).code == 401 {
                        print("❌🔐 CalendarViewModel: 401 UNAUTHORIZED ERROR in updateCustodyForSingleDay - TRIGGERING LOGOUT!")
                        self.authManager.logout()
                    }
                }
                completion()
            }
        }
    }
    
    // MARK: - Family Data Loading
    
    func fetchFamilyData() {
        print("📱 Fetching family data...")
        isDataLoading = true
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        fetchBabysitters {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchEmergencyContacts {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchFamilyMembers {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchChildren {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchDaycareProviders {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchSchoolProviders {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchScheduleTemplates {
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isDataLoading = false
            print("✅ All family data loaded")
        }
    }
    
    func fetchBabysitters(completion: (() -> Void)? = nil) {
        APIService.shared.fetchBabysitters { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let babysitters):
                    self?.babysitters = babysitters
                    print("✅ Successfully fetched \(babysitters.count) babysitters")
                case .failure(let error):
                    print("❌ Error fetching babysitters: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func fetchEmergencyContacts(completion: (() -> Void)? = nil) {
        APIService.shared.fetchEmergencyContacts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let contacts):
                    self?.emergencyContacts = contacts
                    print("✅ Successfully fetched \(contacts.count) emergency contacts")
                case .failure(let error):
                    print("❌ Error fetching emergency contacts: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func fetchFamilyMembers(completion: (() -> Void)? = nil) {
        APIService.shared.fetchFamilyMembers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let members):
                    // Filter out the current logged-in user from the coparents list
                    let filteredMembers = members.filter { member in
                        return member.id != self?.currentUserID
                    }
                    
                    // Map FamilyMember to Coparent for the settings display
                    self?.coparents = filteredMembers.enumerated().compactMap { (index, member) in
                        // Convert FamilyMember to Coparent format
                        // Using hash of UUID string to generate unique integer ID
                        let uniqueId = abs(member.id.hashValue) % 1000000 // Ensure positive ID under 1 million
                        return Coparent(
                            id: uniqueId,
                            firstName: member.first_name,
                            lastName: member.last_name,
                            email: member.email,
                            lastSignin: member.last_signed_in, // Now available from API
                            notes: nil, // Not available in current API
                            phone_number: member.phone_number,
                            isActive: member.status == "active", // Map status to isActive
                            familyId: 0 // Not available in current API
                        )
                    }
                    print("✅ Successfully fetched \(members.count) family members, filtered to \(filteredMembers.count) coparents (excluding current user)")
                case .failure(let error):
                    print("❌ Error fetching family members: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func fetchChildren(completion: (() -> Void)? = nil) {
        APIService.shared.fetchChildren { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let children):
                    self?.children = children
                    print("✅ Successfully fetched \(children.count) children")
                case .failure(let error):
                    print("❌ Error fetching children: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    // MARK: - Family Data Saving
    
    func saveBabysitter(_ babysitter: BabysitterCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.createBabysitter(babysitter) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedBabysitter):
                    self?.babysitters.append(savedBabysitter)
                    print("✅ Successfully saved babysitter: \(savedBabysitter.fullName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error saving babysitter: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateBabysitter(id: Int, babysitter: BabysitterCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateBabysitter(id: id, babysitter: babysitter) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedBabysitter):
                    if let index = self?.babysitters.firstIndex(where: { $0.id == id }) {
                        self?.babysitters[index] = updatedBabysitter
                    }
                    print("✅ Successfully updated babysitter: \(updatedBabysitter.fullName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating babysitter: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteBabysitter(_ babysitter: Babysitter, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteBabysitter(id: babysitter.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.babysitters.removeAll { $0.id == babysitter.id }
                    print("✅ Successfully deleted babysitter: \(babysitter.fullName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting babysitter: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func saveEmergencyContact(_ contact: EmergencyContactCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.createEmergencyContact(contact) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedContact):
                    self?.emergencyContacts.append(savedContact)
                    print("✅ Successfully saved emergency contact: \(savedContact.fullName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error saving emergency contact: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func saveChild(_ child: ChildCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.createChild(child) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedChild):
                    self?.children.append(savedChild)
                    print("✅ Successfully saved child: \(savedChild.firstName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error saving child: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Family Data Updating
    
    func updateChild(_ id: String, childData: ChildCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateChild(id: id, childData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedChild):
                    if let index = self?.children.firstIndex(where: { $0.id == id }) {
                        self?.children[index] = updatedChild
                    }
                    print("✅ Successfully updated child: \(updatedChild.firstName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating child: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateEmergencyContact(_ id: Int, contactData: EmergencyContactCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateEmergencyContact(id: id, contact: contactData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedContact):
                    if let index = self?.emergencyContacts.firstIndex(where: { $0.id == id }) {
                        self?.emergencyContacts[index] = updatedContact
                    }
                    print("✅ Successfully updated emergency contact: \(updatedContact.fullName)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating emergency contact: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Family Data Deleting
    
    func deleteChild(_ id: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteChild(id: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.children.removeAll { $0.id == id }
                    print("✅ Successfully deleted child")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting child: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteEmergencyContact(_ id: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteEmergencyContact(id: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.emergencyContacts.removeAll { $0.id == id }
                    print("✅ Successfully deleted emergency contact")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting emergency contact: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }


    
    func fetchUserThemePreference() {
        APIService.shared.fetchUserProfile { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let userProfile):
                    if let savedThemeId = userProfile.selected_theme_id, let themeUUID = UUID(uuidString: savedThemeId) {
                        print("🎨 Found saved theme ID in database: \(savedThemeId)")
                        // Apply the theme if it exists in available themes
                        if let theme = self?.themeManager.themes.first(where: { $0.id == themeUUID }) {
                            self?.themeManager.setTheme(to: theme)
                            print("✅ Applied saved theme: \(theme.name) (ID: \(savedThemeId))")
                        } else {
                            print("⚠️ Saved theme ID '\(savedThemeId)' not found in available themes")
                            print("📋 Available themes: \(self?.themeManager.themes.map { "\($0.name) (\($0.id))" } ?? [])")
                            print("🔄 Falling back to default theme and clearing invalid preference")
                            
                            // Fall back to default theme
                            self?.themeManager.currentTheme = Theme.defaultTheme
                            
                            // The user preference will be updated when they next select a valid theme
                        }
                    } else {
                        print("ℹ️ No saved theme ID found in database, using default")
                    }
                case .failure(let error):
                    print("❌ Error fetching user theme preference: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Schedule Template Management
    
    func fetchScheduleTemplates(completion: (() -> Void)? = nil) {
        APIService.shared.fetchScheduleTemplates { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let templates):
                    self?.scheduleTemplates = templates
                    print("✅ Successfully fetched \(templates.count) schedule templates")
                case .failure(let error):
                    print("❌ Error fetching schedule templates: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func fetchScheduleTemplate(_ templateId: Int, completion: @escaping (Result<ScheduleTemplate, Error>) -> Void) {
        APIService.shared.fetchScheduleTemplate(templateId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let template):
                    print("✅ Successfully fetched detailed template: \(template.name)")
                    completion(.success(template))
                case .failure(let error):
                    print("❌ Error fetching detailed template: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func createScheduleTemplate(_ templateData: ScheduleTemplateCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.createScheduleTemplate(templateData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let template):
                    self?.scheduleTemplates.append(template)
                    print("✅ Successfully created schedule template: \(template.name)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error creating schedule template: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateScheduleTemplate(_ templateId: Int, templateData: ScheduleTemplateCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateScheduleTemplate(templateId, templateData: templateData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedTemplate):
                    // If the template was set to active, refresh all templates to get updated active states
                    if updatedTemplate.isActive {
                        self?.fetchScheduleTemplates()
                    } else {
                        // For non-active updates, just update the specific template
                        if let index = self?.scheduleTemplates.firstIndex(where: { $0.id == templateId }) {
                            self?.scheduleTemplates[index] = updatedTemplate
                        }
                    }
                    print("✅ Successfully updated schedule template: \(updatedTemplate.name)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating schedule template: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteScheduleTemplate(_ templateId: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteScheduleTemplate(templateId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.scheduleTemplates.removeAll { $0.id == templateId }
                    print("✅ Successfully deleted schedule template")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting schedule template: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func applyScheduleTemplate(_ application: ScheduleApplication, completion: @escaping (Bool, String?) -> Void) {
        APIService.shared.applyScheduleTemplate(application) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Refresh custody data after applying schedule
                    self?.fetchHandoffsAndCustody()
                    // Refresh schedule templates to update active status
                    self?.fetchScheduleTemplates()
                    let message = "Applied schedule to \(response.daysApplied) days"
                    print("✅ Successfully applied schedule template: \(message)")
                    completion(true, message)
                case .failure(let error):
                    print("❌ Error applying schedule template: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Schedule Validation and Utilities
    
    func validateSchedulePattern(_ pattern: WeeklySchedulePattern) -> (isValid: Bool, message: String?) {
        let assignedDays = [
            pattern.sunday, pattern.monday, pattern.tuesday, pattern.wednesday,
            pattern.thursday, pattern.friday, pattern.saturday
        ].compactMap { $0 }
        
        print("🔍 Validating schedule pattern:")
        print("  - Sunday: \(pattern.sunday ?? "nil")")
        print("  - Monday: \(pattern.monday ?? "nil")")
        print("  - Tuesday: \(pattern.tuesday ?? "nil")")
        print("  - Wednesday: \(pattern.wednesday ?? "nil")")
        print("  - Thursday: \(pattern.thursday ?? "nil")")
        print("  - Friday: \(pattern.friday ?? "nil")")
        print("  - Saturday: \(pattern.saturday ?? "nil")")
        print("  - Assigned days: \(assignedDays)")
        
        if assignedDays.isEmpty {
            return (false, "At least one day must be assigned")
        }
        
        // Check for valid custodian assignments - accept parent1/parent2 OR actual custodian IDs
        let validLogicalAssignments = ["parent1", "parent2"]
        let validActualIds = [custodianOneId, custodianTwoId].compactMap { $0 }
        let allValidAssignments = validLogicalAssignments + validActualIds
        
        let invalidAssignments = assignedDays.filter { !allValidAssignments.contains($0) }
        
        print("  - Valid assignments: \(allValidAssignments)")
        print("  - Invalid assignments: \(invalidAssignments)")
        
        if !invalidAssignments.isEmpty {
            return (false, "Invalid custodian assignments found: \(invalidAssignments)")
        }
        
        return (true, nil)
    }
    
    func generateSchedulePreview(pattern: WeeklySchedulePattern, startDate: Date, numberOfWeeks: Int = 4) -> [(date: Date, custodian: String?)] {
        var preview: [(date: Date, custodian: String?)] = []
        let calendar = Calendar.current
        
        for week in 0..<numberOfWeeks {
            for day in 0..<7 {
                let date = calendar.date(byAdding: .day, value: week * 7 + day, to: startDate) ?? startDate
                let weekday = calendar.component(.weekday, from: date) // 1=Sunday, 2=Monday, etc.
                let custodian = pattern.custodianFor(weekday: weekday)
                preview.append((date: date, custodian: custodian))
            }
        }
        
        return preview
    }
    
    func getCustodianNameFromId(_ custodianId: String?) -> String {
        guard let custodianId = custodianId else { return "Unassigned" }
        
        if custodianId == "parent1" || custodianId == custodianOneId {
            return custodianOneName
        } else if custodianId == "parent2" || custodianId == custodianTwoId {
            return custodianTwoName
        } else {
            return "Unknown"
        }
    }
    
    func convertPatternToAPIFormat(_ pattern: WeeklySchedulePattern) -> WeeklySchedulePattern {
        // Convert "parent1"/"parent2" to actual custodian IDs
        return WeeklySchedulePattern(
            sunday: convertCustodianToId(pattern.sunday),
            monday: convertCustodianToId(pattern.monday),
            tuesday: convertCustodianToId(pattern.tuesday),
            wednesday: convertCustodianToId(pattern.wednesday),
            thursday: convertCustodianToId(pattern.thursday),
            friday: convertCustodianToId(pattern.friday),
            saturday: convertCustodianToId(pattern.saturday)
        )
    }
    
    private func convertCustodianToId(_ custodian: String?) -> String? {
        guard let custodian = custodian else { return nil }
        
        switch custodian {
        case "parent1":
            return custodianOneId
        case "parent2":
            return custodianTwoId
        default:
            return custodian // Already an ID
        }
    }
    
    // MARK: - Reminders Management
    
    func fetchReminders() {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        let endDate = calendar.date(byAdding: .month, value: 2, to: currentDate) ?? currentDate
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        APIService.shared.fetchReminders(startDate: startDateString, endDate: endDateString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let reminders):
                    self?.reminders = reminders
                    print("✅ Fetched \(reminders.count) reminders")
                case .failure(let error):
                    print("❌ Error fetching reminders: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func createReminder(date: Date, text: String, notificationEnabled: Bool = false, notificationTime: String? = nil, completion: @escaping (Bool) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let reminderData = ReminderCreate(date: dateString, text: text, notificationEnabled: notificationEnabled, notificationTime: notificationTime)
        
        APIService.shared.createReminder(reminderData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let reminder):
                    self?.reminders.append(reminder)
                    self?.reminders.sort { $0.date < $1.date }
                    print("✅ Created reminder for \(dateString)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error creating reminder: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateReminder(_ reminderId: Int, text: String, notificationEnabled: Bool = false, notificationTime: String? = nil, completion: @escaping (Bool) -> Void) {
        let reminderData = ReminderUpdate(text: text, notificationEnabled: notificationEnabled, notificationTime: notificationTime)
        
        APIService.shared.updateReminder(reminderId, reminderData: reminderData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedReminder):
                    if let index = self?.reminders.firstIndex(where: { $0.id == reminderId }) {
                        self?.reminders[index] = updatedReminder
                    }
                    print("✅ Updated reminder \(reminderId)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating reminder: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteReminder(_ reminderId: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteReminder(reminderId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.reminders.removeAll { $0.id == reminderId }
                    print("✅ Deleted reminder \(reminderId)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting reminder: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func getReminderForDate(_ date: Date) -> Reminder? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        return reminders.first { $0.date == dateString }
    }
    
    func hasReminderForDate(_ date: Date) -> Bool {
        return getReminderForDate(date) != nil
    }
    
    func getReminderTextForDate(_ date: Date) -> String {
        return getReminderForDate(date)?.text ?? ""
    }
    
    // MARK: - Daycare Provider Management
    
    func fetchDaycareProviders(completion: (() -> Void)? = nil) {
        APIService.shared.fetchDaycareProviders { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let providers):
                    self?.daycareProviders = providers
                    print("✅ Successfully fetched \(providers.count) daycare providers")
                case .failure(let error):
                    print("❌ Error fetching daycare providers: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func saveDaycareProvider(_ provider: DaycareProviderCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.createDaycareProvider(provider) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedProvider):
                    self?.daycareProviders.append(savedProvider)
                    print("✅ Successfully saved daycare provider: \(savedProvider.name)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error saving daycare provider: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateDaycareProvider(_ providerId: Int, provider: DaycareProviderCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateDaycareProvider(providerId, providerData: provider) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedProvider):
                    if let index = self?.daycareProviders.firstIndex(where: { $0.id == providerId }) {
                        self?.daycareProviders[index] = updatedProvider
                    }
                    print("✅ Successfully updated daycare provider: \(updatedProvider.name)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating daycare provider: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteDaycareProvider(_ providerId: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteDaycareProvider(providerId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.daycareProviders.removeAll { $0.id == providerId }
                    print("✅ Successfully deleted daycare provider")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting daycare provider: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func searchDaycareProviders(_ searchRequest: DaycareSearchRequest, completion: @escaping (Result<[DaycareSearchResult], Error>) -> Void) {
        APIService.shared.searchDaycareProviders(searchRequest) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - School Provider Management
    
    func fetchSchoolProviders(completion: (() -> Void)? = nil) {
        APIService.shared.fetchSchoolProviders { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let providers):
                    self?.schoolProviders = providers
                    print("✅ Successfully fetched \(providers.count) school providers")
                case .failure(let error):
                    print("❌ Error fetching school providers: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func saveSchoolProvider(_ provider: SchoolProviderCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.createSchoolProvider(provider) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedProvider):
                    self?.schoolProviders.append(savedProvider)
                    print("✅ Successfully saved school provider: \(savedProvider.name)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error saving school provider: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateSchoolProvider(_ providerId: Int, provider: SchoolProviderCreate, completion: @escaping (Bool) -> Void) {
        APIService.shared.updateSchoolProvider(providerId, providerData: provider) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedProvider):
                    if let index = self?.schoolProviders.firstIndex(where: { $0.id == providerId }) {
                        self?.schoolProviders[index] = updatedProvider
                    }
                    print("✅ Successfully updated school provider: \(updatedProvider.name)")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating school provider: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteSchoolProvider(_ providerId: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteSchoolProvider(providerId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.schoolProviders.removeAll { $0.id == providerId }
                    print("✅ Successfully deleted school provider")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting school provider: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    

    
    // MARK: - Journal Management
    
    func fetchJournalEntries(startDate: String? = nil, endDate: String? = nil, completion: (() -> Void)? = nil) {
        APIService.shared.fetchJournalEntries(startDate: startDate, endDate: endDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let entries):
                    self?.journalEntries = entries
                    print("✅ Successfully fetched \(entries.count) journal entries")
                case .failure(let error):
                    print("❌ Error fetching journal entries: \(error.localizedDescription)")
                }
                completion?()
            }
        }
    }
    
    func createJournalEntry(title: String?, content: String, entryDate: Date, completion: @escaping (Bool) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: entryDate)
        
        let entryData = JournalEntryCreate(title: title, content: content, entry_date: dateString)
        
        APIService.shared.createJournalEntry(entryData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newEntry):
                    self?.journalEntries.insert(newEntry, at: 0) // Add to beginning of list
                    self?.journalEntries.sort { $0.entry_date > $1.entry_date } // Sort by date descending
                    print("✅ Successfully created journal entry")
                    completion(true)
                case .failure(let error):
                    print("❌ Error creating journal entry: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func updateJournalEntry(id: Int, title: String?, content: String?, entryDate: Date?, completion: @escaping (Bool) -> Void) {
        var dateString: String? = nil
        if let entryDate = entryDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateString = dateFormatter.string(from: entryDate)
        }
        
        let entryData = JournalEntryUpdate(title: title, content: content, entry_date: dateString)
        
        APIService.shared.updateJournalEntry(id: id, entryData: entryData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedEntry):
                    if let index = self?.journalEntries.firstIndex(where: { $0.id == id }) {
                        self?.journalEntries[index] = updatedEntry
                        self?.journalEntries.sort { $0.entry_date > $1.entry_date }
                    }
                    print("✅ Successfully updated journal entry")
                    completion(true)
                case .failure(let error):
                    print("❌ Error updating journal entry: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    func deleteJournalEntry(id: Int, completion: @escaping (Bool) -> Void) {
        APIService.shared.deleteJournalEntry(id: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.journalEntries.removeAll { $0.id == id }
                    print("✅ Successfully deleted journal entry")
                    completion(true)
                case .failure(let error):
                    print("❌ Error deleting journal entry: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
} 
