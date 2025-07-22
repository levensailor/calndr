import SwiftUI

struct SchoolView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddSchool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schools")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Text("Manage schools and educational institutions")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Add Button
                    HStack {
                        Spacer()
                        Button(action: { showingAddSchool = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add School")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // School Providers List
                    if viewModel.schoolProviders.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.columns")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                            
                            Text("No schools added yet")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            
                            Text("Add your first school to get started")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.schoolProviders) { provider in
                            SchoolProviderCard(provider: provider)
                                .padding(.horizontal)
                                .environmentObject(viewModel)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
        }
        .sheet(isPresented: $showingAddSchool) {
            AddSchoolView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

struct SchoolProviderCard: View {
    let provider: SchoolProvider
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingEventsModal = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.columns")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if let address = provider.address, !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Action buttons in top right (matching daycare style)
                HStack(spacing: 8) {
                    // Events/Calendar sync button
                    Button(action: {
                        showingEventsModal = true
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(themeManager.currentTheme.secondaryBackgroundColor.color)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                    }
                    
                    // Delete button
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(themeManager.currentTheme.secondaryBackgroundColor.color)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                    }
                }
            }
            
            if let hours = provider.hours, !hours.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    
                    Text(hours)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
            }
            
            HStack {
                if let phone = provider.phoneNumber, !phone.isEmpty {
                    Button(action: {
                        makePhoneCall(phone)
                    }) {
                        HStack {
                            Image(systemName: "phone")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(phone)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                }
                
                Spacer()
                
                if let email = provider.email, !email.isEmpty {
                    HStack {
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text(email)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
            }
            
            if let notes = provider.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColor.color)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .sheet(isPresented: $showingEventsModal) {
            SchoolEventsModal(provider: provider)
                .environmentObject(themeManager)
        }
        .alert("Delete School", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSchool()
            }
        } message: {
            Text("Are you sure you want to delete \(provider.name)? This will also remove any calendar sync configurations and cannot be undone.")
        }
    }
    
    private func makePhoneCall(_ phoneNumber: String) {
        let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func deleteSchool() {
        viewModel.deleteSchoolProvider(provider.id) { success in
            if success {
                print("✅ Successfully deleted school provider")
            } else {
                print("❌ Failed to delete school provider")
            }
        }
    }
}



struct AddSchoolView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var searchType: SearchType = .search
    @State private var showingSearchResults = false
    
    enum SearchType: CaseIterable {
        case search
        case manual
        
        var title: String {
            switch self {
            case .search: return "Search"
            case .manual: return "Manual"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Add Method", selection: $searchType) {
                    ForEach(SearchType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(themeManager.currentTheme.secondaryBackgroundColor.color)
                
                // Content based on selected type
                if searchType == .search {
                    SchoolSearchView(onSchoolSelected: { selectedSchool in
                        // Create provider from search result
                        let provider = SchoolProviderCreate(
                            name: selectedSchool.name,
                            address: selectedSchool.address,
                            phoneNumber: selectedSchool.phoneNumber,
                            email: nil,
                            hours: selectedSchool.hours,
                            notes: nil,
                            googlePlaceId: selectedSchool.placeId,
                            rating: selectedSchool.rating,
                            website: selectedSchool.website
                        )
                        
                        saveSchool(provider)
                    })
                } else {
                    ManualSchoolEntryView(onSave: { provider in
                        saveSchool(provider)
                    })
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Add School")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                }
            }
        }
    }
    
    private func saveSchool(_ provider: SchoolProviderCreate) {
        viewModel.saveSchoolProvider(provider) { success in
            if success {
                dismiss()
            } else {
                // Handle error - could show alert
                print("Failed to save school provider")
            }
        }
    }
}

struct SchoolSearchView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var searchManager = SchoolSearchManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchType: SchoolSearchType = .currentLocation
    @State private var zipCode = ""
    @State private var searchResults: [SchoolSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingLocationPermissionAlert = false
    
    let onSchoolSelected: (SchoolSearchResult) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Type Picker
            Picker("Search Type", selection: $searchType) {
                ForEach(SchoolSearchType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Search Input
            if searchType == .zipCode {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Enter ZIP code", text: $zipCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Button("Search") {
                            searchSchools()
                        }
                        .disabled(zipCode.isEmpty || isSearching)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Button(action: searchSchools) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Search Near Me")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSearching)
                    .padding(.horizontal)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
            }
            
            // Loading or Results
            if isSearching {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Searching for schools...")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                    
                    Text("Search for schools")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    
                    Text("Use your current location or enter a ZIP code to find nearby schools")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults) { result in
                    SchoolSearchResultRow(result: result, onSelect: {
                        onSchoolSelected(result)
                    })
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(themeManager.currentTheme.mainBackgroundColor.color)
        .navigationTitle("Find Schools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access in Settings to search for nearby schools.")
        }
    }
    
    private func searchSchools() {
        errorMessage = nil
        isSearching = true
        
        Task {
            var userLocation: CLLocation?
            
            if searchType == .currentLocation {
                // Check location permission
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    DispatchQueue.main.async {
                        self.showingLocationPermissionAlert = true
                        self.isSearching = false
                    }
                    return
                }
                
                // Request current location
                userLocation = await withCheckedContinuation { continuation in
                    locationManager.requestCurrentLocation { location in
                        continuation.resume(returning: location)
                    }
                }
                
                guard userLocation != nil else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Unable to get current location"
                        self.isSearching = false
                    }
                    return
                }
            }
            
            // Perform MapKit search
            let results = await searchManager.searchForSchools(
                type: searchType,
                zipCode: zipCode,
                userLocation: userLocation
            )
            
            DispatchQueue.main.async {
                self.isSearching = false
                self.searchResults = results
                
                if let searchError = self.searchManager.errorMessage {
                    self.errorMessage = searchError
                } else if results.isEmpty {
                    self.errorMessage = "No schools found in this area"
                } else {
                    self.errorMessage = nil
                }
            }
        }
    }
}

struct SchoolSearchResultRow: View {
    let result: SchoolSearchResult
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                            .multilineTextAlignment(.leading)
                        
                        Text(result.address)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if let rating = result.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(rating, specifier: "%.1f")")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                        }
                    }
                }
                
                if let phone = result.phoneNumber {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ManualSchoolEntryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var name = ""
    @State private var address = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var hours = ""
    @State private var website = ""
    @State private var notes = ""
    
    let onSave: (SchoolProviderCreate) -> Void
    
    var body: some View {
        Form {
            Section(header: Text("School Information")
                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))) {
                
                TextField("School name *", text: $name)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                
                TextField("Address", text: $address, axis: .vertical)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .lineLimit(2...4)
                
                TextField("Phone number", text: $phoneNumber)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .keyboardType(.phonePad)
                
                TextField("Email", text: $email)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                TextField("Hours (e.g., 8:00 AM - 3:00 PM)", text: $hours)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                
                TextField("Website", text: $website)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor.color)
            
            Section(header: Text("Notes")
                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))) {
                
                TextField("Additional notes", text: $notes, axis: .vertical)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .lineLimit(3...6)
            }
            .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor.color)
            
            Section {
                Button("Save School") {
                    saveSchool()
                }
                .disabled(name.isEmpty)
                .foregroundColor(name.isEmpty ? .gray : .blue)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor.color)
        }
        .background(themeManager.currentTheme.mainBackgroundColor.color)
        .scrollContentBackground(.hidden)
        .navigationTitle("Add School Manually")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveSchool() {
        let provider = SchoolProviderCreate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines),
            hours: hours.isEmpty ? nil : hours.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            googlePlaceId: nil,
            rating: nil,
            website: website.isEmpty ? nil : website.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        onSave(provider)
    }
}

struct SchoolEventsModal: View {
    let provider: SchoolProvider
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var eventURL = ""
    @State private var discoveredURL: String? = nil
    @State private var isDiscovering = false
    @State private var isLoading = false
    @State private var showingSuccessMessage = false
    @State private var showingErrorMessage = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync Events Calendar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("For \(provider.name)")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                .padding(.horizontal)
                
                // Warning Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Best Effort Parsing")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                    }
                    
                    Text("Event parsing is experimental and works on a best-effort basis. Results may vary depending on the website structure and format. We recommend verifying important dates manually.")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                
                // URL Discovery Section
                if let website = provider.website, !website.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Auto-Discovery")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Text("We'll try to find the calendar page automatically from \(provider.name)'s website")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Button(action: discoverCalendarURL) {
                            HStack {
                                if isDiscovering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(isDiscovering ? "Discovering..." : "Discover Calendar URL")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isDiscovering || isLoading)
                        
                        if let discovered = discoveredURL {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Found: \(discovered)")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Manual URL Entry Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manual Entry")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("Enter the calendar URL directly (usually ends with .ics or contains 'calendar')")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    
                    TextField("https://school.edu/calendar.ics", text: $eventURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                
                // Parse Events Button
                Button(action: syncEventsCalendar) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isLoading ? "Parsing Events..." : "Parse Events")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(eventURL.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(eventURL.isEmpty || isLoading || isDiscovering)
                .padding(.horizontal)
                
                Spacer()
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("School Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                }
            }
            .alert("Events Parsed Successfully!", isPresented: $showingSuccessMessage) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("School calendar events have been synced successfully!")
            }
            .alert("Parsing Failed", isPresented: $showingErrorMessage) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            if let website = provider.website, !website.isEmpty {
                eventURL = website
            }
        }
    }
    
    private func discoverCalendarURL() {
        isDiscovering = true
        errorMessage = ""
        
        APIService.shared.discoverSchoolCalendarURL(providerId: provider.id) { result in
            DispatchQueue.main.async {
                isDiscovering = false
                
                switch result {
                case .success(let response):
                    if let calendarURL = response.discoveredCalendarURL {
                        discoveredURL = calendarURL
                        eventURL = calendarURL
                    } else {
                        errorMessage = "No calendar URL found on the school's website. Try entering one manually."
                        showingErrorMessage = true
                    }
                case .failure(let error):
                    errorMessage = "Failed to discover calendar URL: \(error.localizedDescription)"
                    showingErrorMessage = true
                }
            }
        }
    }
    
    private func syncEventsCalendar() {
        guard !eventURL.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        APIService.shared.parseSchoolEvents(providerId: provider.id, calendarURL: eventURL) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.eventsCount > 0 {
                        showingSuccessMessage = true
                    } else {
                        errorMessage = "No events found at the provided URL. The calendar might be empty or in an unsupported format."
                        showingErrorMessage = true
                    }
                case .failure(let error):
                    errorMessage = "Unable to parse events: \(error.localizedDescription)"
                    showingErrorMessage = true
                }
            }
        }
    }
}

struct SchoolView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        SchoolView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 