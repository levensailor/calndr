import SwiftUI

struct OnboardingStepThreeView: View {
    enum ScheduleTemplate: String, Codable {
        case weekly = "weekly"
        case alternatingWeeks = "alternating_weeks"
        case custom = "custom"
    }
    
    @State private var selectedTemplate: ScheduleTemplate?
    @State private var selectedDays: [String: Int] = [
        "Monday": 0,
        "Tuesday": 0,
        "Wednesday": 0,
        "Thursday": 0,
        "Friday": 0,
        "Saturday": 0,
        "Sunday": 0
    ]
    
    @State private var parentNames: [String]
    @State private var showingCustomNames = false
    @State private var customParent1Name = ""
    @State private var customParent2Name = ""
    @State private var custodians: [Custodian] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var themeManager: ThemeManager
    
    let primaryParentName: String
    let coparentName: String?
    var onComplete: () -> Void
    var onBack: () -> Void
    
    init(primaryParentName: String, coparentName: String?, onComplete: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.primaryParentName = primaryParentName
        self.coparentName = coparentName
        self.onComplete = onComplete
        self.onBack = onBack
        
        // Initialize parent names based on the provided data
        self._parentNames = State(initialValue: [
            primaryParentName,
            coparentName ?? "Co-Parent"
        ])
        self._customParent1Name = State(initialValue: primaryParentName)
        self._customParent2Name = State(initialValue: coparentName ?? "Co-Parent")
    }
    
    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        return ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button(action: onBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Text("Set Your Custody Schedule")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding(.top)
                    
                    Text("Choose which parent has custody on each day of the week")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Parent Names Section
                    VStack(spacing: 15) {
                        Text("Parent Names")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Button(action: {
                                showingCustomNames.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "person.2")
                                    Text("\(parentNames[0]) & \(parentNames[1])")
                                    Image(systemName: "pencil")
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Schedule Templates Section
                    VStack(spacing: 15) {
                        Text("Choose a Schedule Template")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                // Weekly Schedule Template
                                Button(action: { selectTemplate(.weekly) }) {
                                    VStack(alignment: .leading) {
                                        Image(systemName: "calendar")
                                            .font(.title)
                                            .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                                        Text("Weekly Schedule")
                                            .font(.headline)
                                        Text("Same schedule every week")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .frame(width: 160, height: 120)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                // Alternating Weeks Template
                                Button(action: { selectTemplate(.alternatingWeeks) }) {
                                    VStack(alignment: .leading) {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.title)
                                            .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                                        Text("Alternating Weeks")
                                            .font(.headline)
                                        Text("Switch every week")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .frame(width: 160, height: 120)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                // Custom Schedule Template
                                Button(action: { selectTemplate(.custom) }) {
                                    VStack(alignment: .leading) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.title)
                                            .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                                        Text("Custom Schedule")
                                            .font(.headline)
                                        Text("Set your own pattern")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .frame(width: 160, height: 120)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    
                    // Weekly Schedule Section
                    if selectedTemplate == .custom {
                        VStack(spacing: 15) {
                            Text("Custom Weekly Schedule")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 12) {
                                ForEach(daysOfWeek, id: \.self) { day in
                                    HStack {
                                        Text(day)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                            .frame(width: 120, alignment: .leading)
                                        
                                        Spacer()
                                        
                                        Picker("Select parent for \(day)", selection: Binding(
                                            get: { selectedDays[day] ?? 0 },
                                            set: { selectedDays[day] = $0 }
                                        )) {
                                            Text(parentNames[0]).tag(0)
                                            Text(parentNames[1]).tag(1)
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        
                        
                        Spacer(minLength: 30)
                        
                        // Error message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Complete Button
                        Button(action: {
                            saveScheduleAndComplete()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Saving Schedule..." : "Complete Setup")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isLoading ? Color.gray : themeManager.currentTheme.accentColorSwiftUI)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .sheet(isPresented: $showingCustomNames) {
                NavigationView {
                    VStack(spacing: 20) {
                        Text("Customize Parent Names")
                            .font(.headline)
                            .padding(.top)
                        
                        FloatingLabelTextField(title: "First Parent Name", text: $customParent1Name, isSecure: false)
                            .padding(.horizontal)
                        
                        FloatingLabelTextField(title: "Second Parent Name", text: $customParent2Name, isSecure: false)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingCustomNames = false
                        },
                        trailing: Button("Save") {
                            if !customParent1Name.isEmpty && !customParent2Name.isEmpty {
                                parentNames[0] = customParent1Name
                                parentNames[1] = customParent2Name
                            }
                            showingCustomNames = false
                        }
                    )
                }
            }
            .onAppear {
                // Set default names if empty
                if customParent1Name.isEmpty {
                    customParent1Name = parentNames[0]
                }
                if customParent2Name.isEmpty {
                    customParent2Name = parentNames[1]
                }
            }
         }
    }
    
    private func saveScheduleAndComplete() {
            // First, fetch custodian IDs if we don't have them
            if custodians.isEmpty {
                fetchCustodiansAndSave()
            } else {
                saveScheduleToBackend()
            }
        }
        
    private func fetchCustodiansAndSave() {
            isLoading = true
            errorMessage = nil
            
            APIService.shared.fetchCustodianNames { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fetchedCustodians):
                        custodians = fetchedCustodians
                        saveScheduleToBackend()
                    case .failure(let error):
                        isLoading = false
                        errorMessage = "Failed to fetch family information: \(error.localizedDescription)"
                        print("❌ Error fetching custodians during onboarding: \(error)")
                    }
                }
            }
        }
        
    private func saveScheduleToBackend() {
            guard custodians.count >= 2 else {
                isLoading = false
                errorMessage = "Family must have at least 2 members to create a custody schedule"
                return
            }
            
            // Map parent names to custodian IDs
            let custodianOne = custodians[0] // Primary parent (the one signing up)
            let custodianTwo = custodians[1] // Co-parent
            
            // Generate custody records for the next 24 months
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .month, value: 24, to: startDate) ?? startDate
            
            generateCustodyRecords(from: startDate, to: endDate, custodianOne: custodianOne, custodianTwo: custodianTwo)
        }
        
    private func generateCustodyRecords(from startDate: Date, to endDate: Date, custodianOne: Custodian, custodianTwo: Custodian) {
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // Start from today (not historical dates) to avoid "No Custody Assigned" on past dates
            let today = calendar.startOfDay(for: Date())
            var currentDate = max(startDate, today)
            var recordsToCreate: [(date: String, custodianId: String)] = []
            
            print("🗓️ Generating custody records from \(currentDate) to \(endDate) (excluding historical dates)")
            
            // Generate custody records based on the selected template
            switch selectedTemplate ?? .custom {
            case .weekly:
                // Generate weekly schedule (same every week)
                while currentDate <= endDate {
                    let weekday = calendar.component(.weekday, from: currentDate)
                    let dayName = getDayName(for: weekday)
                    let dateString = dateFormatter.string(from: currentDate)
                    recordsToCreate.append((date: dateString, custodianId: custodianOne.id))
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                }
                
            case .alternatingWeeks:
                // Generate alternating weeks schedule
                var isParentOneWeek = true
                while currentDate <= endDate {
                    // Get the start of the week
                    let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)) ?? currentDate
                    
                    // Generate records for the entire week
                    var dayInWeek = weekStart
                    while dayInWeek <= endDate && calendar.isDate(dayInWeek, equalTo: weekStart, toGranularity: .weekOfYear) {
                        let dateString = dateFormatter.string(from: dayInWeek)
                        let custodianId = isParentOneWeek ? custodianOne.id : custodianTwo.id
                        recordsToCreate.append((date: dateString, custodianId: custodianId))
                        dayInWeek = calendar.date(byAdding: .day, value: 1, to: dayInWeek) ?? dayInWeek
                    }
                    
                    // Move to next week and alternate parent
                    currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? currentDate
                    isParentOneWeek.toggle()
                }
                
            case .custom:
                // Generate custom schedule based on selected days
                while currentDate <= endDate {
                    let weekday = calendar.component(.weekday, from: currentDate)
                    let dayName = getDayName(for: weekday)
                    
                    if let parentIndex = selectedDays[dayName] {
                        let custodianId = (parentIndex == 0) ? custodianOne.id : custodianTwo.id
                        let dateString = dateFormatter.string(from: currentDate)
                        recordsToCreate.append((date: dateString, custodianId: custodianId))
                    }
                    
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                }
            }
            
            print("🗓️ Created \(recordsToCreate.count) custody records starting from today")
            
            // Save records to backend
            update(recordsToCreate)
        }
        
    private func selectTemplate(_ template: ScheduleTemplate) {
            selectedTemplate = template
            
            // Apply template defaults
            switch template {
            case .weekly:
                // Set all days to parent 1
                for day in daysOfWeek {
                    selectedDays[day] = 0
                }
                
            case .alternatingWeeks:
                // Set all days to parent 1 for now
                // The actual alternating pattern will be handled in saveScheduleToBackend
                for day in daysOfWeek {
                    selectedDays[day] = 0
                }
                
            case .custom:
                // Reset all days
                for day in daysOfWeek {
                    selectedDays[day] = 0
                }
            }
        }
        
    private func getDayName(for weekday: Int) -> String {
            // weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
            switch weekday {
            case 1: return "Sunday"
            case 2: return "Monday"
            case 3: return "Tuesday"
            case 4: return "Wednesday"
            case 5: return "Thursday"
            case 6: return "Friday"
            case 7: return "Saturday"
            default: return "Monday"
            }
        }
        
    private func saveCustodyRecords(_ records: [(date: String, custodianId: String)]) {
            // First, create the schedule template
            createScheduleTemplate { templateCreated in
                if templateCreated {
                    // Then create the custody records
                    self.createCustodyRecords(records)
                } else {
                    // If template creation fails, still create custody records but show warning
                    print("⚠️ Template creation failed, proceeding with custody records only")
                    self.createCustodyRecords(records)
                }
            }
        }
        
    private func convertDayAssignment(_ parentIndex: Int?) -> String? {
            guard let parentIndex = parentIndex else { return nil }
            return parentIndex == 0 ? "parent1" : "parent2"
        }
        
        private func createCustodyRecords(_ records: [(date: String, custodianId: String)]) {
            // Convert to CustodyRequest format for bulk API
            let custodyRequests = records.map { record in
                CustodyRequest(
                    date: record.date,
                    custodian_id: record.custodianId,
                    handoff_day: false,
                    handoff_time: nil,
                    handoff_location: nil
                )
            }
            
            print("🚀 Starting bulk creation of \(custodyRequests.count) custody records...")
            
            APIService.shared.bulkCreateCustodyRecords(custodyRequests) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success(let response):
                        print("✅ Bulk custody creation successful: \(response.message)")
                        print("✅ Created \(response.records_created) custody records")
                        // Ensure records are created before transitioning to main app
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onComplete()
                        }
                    case .failure(let error):
                        print("❌ Bulk custody creation failed: \(error.localizedDescription)")
                        errorMessage = "Failed to save custody schedule. Please try again or set up your schedule manually later."
                        // Still complete onboarding even if bulk save failed, but with a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            onComplete()
                        }
                    }
                }
            }
        }
        
    private func createScheduleTemplate(completion: @escaping (Bool) -> Void) {
            // Convert the onboarding selection to a weekly pattern
            // Only assign days that have been explicitly set, otherwise leave as nil
            let weeklyPattern = WeeklySchedulePattern(
                sunday: convertDayAssignment(selectedDays["Sunday"]),
                monday: convertDayAssignment(selectedDays["Monday"]),
                tuesday: convertDayAssignment(selectedDays["Tuesday"]),
                wednesday: convertDayAssignment(selectedDays["Wednesday"]),
                thursday: convertDayAssignment(selectedDays["Thursday"]),
                friday: convertDayAssignment(selectedDays["Friday"]),
                saturday: convertDayAssignment(selectedDays["Saturday"])
            )
            
            let templateName = "My Custody Schedule"
            let templateDescription = "Schedule created during onboarding on \(Date().formatted(date: .abbreviated, time: .omitted))"
            
            let templateData = ScheduleTemplateCreate(
                name: templateName,
                description: templateDescription,
                patternType: .weekly,
                weeklyPattern: weeklyPattern,
                alternatingWeeksPattern: nil,
                isActive: true
            )
            
            print("📋 Creating schedule template: \(templateName)")
            
            APIService.shared.createScheduleTemplate(templateData) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let template):
                        print("✅ Schedule template created successfully: \(template.name)")
                        completion(true)
                    case .failure(let error):
                        print("❌ Failed to create schedule template: \(error.localizedDescription)")
                        completion(false)
                    }
                }
            }
        }
        
    }
    
    

