import SwiftUI

struct OnboardingStepThreeView: View {
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
    
    let primaryParentName: String
    let coparentName: String?
    var onComplete: () -> Void
    
    init(primaryParentName: String, coparentName: String?, onComplete: @escaping () -> Void) {
        self.primaryParentName = primaryParentName
        self.coparentName = coparentName
        self.onComplete = onComplete
        
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
        ScrollView {
            VStack(spacing: 20) {
                Text("Set Your Custody Schedule")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Choose which parent has custody on each day of the week")
                    .font(.subheadline)
                    .foregroundColor(.gray)
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
                
                // Weekly Schedule Section
                VStack(spacing: 15) {
                    Text("Weekly Schedule")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            HStack {
                                Text(day)
                                    .font(.body)
                                    .frame(width: 100, alignment: .leading)
                                
                                Spacer()
                                
                                Picker("", selection: Binding(
                                    get: { selectedDays[day] ?? 0 },
                                    set: { selectedDays[day] = $0 }
                                )) {
                                    Text(parentNames[0]).tag(0)
                                    Text(parentNames[1]).tag(1)
                                    Text("Shared").tag(2)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Quick Setup Templates
                VStack(spacing: 15) {
                    Text("Quick Setup Templates")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 10) {
                        Button("Alternating Weeks") {
                            setAlternatingWeeks()
                        }
                        .buttonStyle(TemplateButtonStyle())
                        
                        Button("Weekdays/Weekends") {
                            setWeekdaysWeekends()
                        }
                        .buttonStyle(TemplateButtonStyle())
                    }
                    
                    HStack(spacing: 10) {
                        Button("Equal Split") {
                            setEqualSplit()
                        }
                        .buttonStyle(TemplateButtonStyle())
                        
                        Button("Clear All") {
                            clearSchedule()
                        }
                        .buttonStyle(TemplateButtonStyle(backgroundColor: .red))
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
                    .background(isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
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
    
    private func setAlternatingWeeks() {
        // Simple alternating pattern - this would be enhanced for actual alternating weeks
        for (index, day) in daysOfWeek.enumerated() {
            selectedDays[day] = index % 2
        }
    }
    
    private func setWeekdaysWeekends() {
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        let weekends = ["Saturday", "Sunday"]
        
        for day in weekdays {
            selectedDays[day] = 0 // Parent 1 gets weekdays
        }
        for day in weekends {
            selectedDays[day] = 1 // Parent 2 gets weekends
        }
    }
    
    private func setEqualSplit() {
        selectedDays["Monday"] = 0
        selectedDays["Tuesday"] = 0
        selectedDays["Wednesday"] = 0
        selectedDays["Thursday"] = 1
        selectedDays["Friday"] = 1
        selectedDays["Saturday"] = 1
        selectedDays["Sunday"] = 0
    }
    
    private func clearSchedule() {
        for day in daysOfWeek {
            selectedDays[day] = 0
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
        
        var currentDate = startDate
        var recordsToCreate: [(date: String, custodianId: String)] = []
        
        // Generate custody records based on the selected schedule
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
        
        // Save records to backend
        saveCustodyRecords(recordsToCreate)
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
        // Convert to CustodyRequest format for bulk API
        let custodyRequests = records.map { record in
            CustodyRequest(
                date: record.date,
                custodian_id: record.custodianId,
                handoff_day: nil,
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
                    onComplete()
                case .failure(let error):
                    print("❌ Bulk custody creation failed: \(error.localizedDescription)")
                    errorMessage = "Failed to save custody schedule. Please try again or set up your schedule manually later."
                    // Still complete onboarding even if bulk save failed
                    onComplete()
                }
            }
        }
    }
}

struct TemplateButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(6)
    }
}
