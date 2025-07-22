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
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: { showingEventsModal = true }) {
                        Label("Calendar Sync", systemImage: "calendar.badge.plus")
                    }
                    
                    Divider()
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                }
            }
            
            // Contact Information
            VStack(alignment: .leading, spacing: 8) {
                if let phone = provider.phoneNumber, !phone.isEmpty {
                    ContactInfoRow(icon: "phone.fill", text: phone, color: .green)
                }
                
                if let email = provider.email, !email.isEmpty {
                    ContactInfoRow(icon: "envelope.fill", text: email, color: .blue)
                }
                
                if let hours = provider.hours, !hours.isEmpty {
                    ContactInfoRow(icon: "clock.fill", text: hours, color: .orange)
                }
                
                if let website = provider.website, !website.isEmpty {
                    ContactInfoRow(icon: "globe", text: website, color: .purple)
                }
                
                if let notes = provider.notes, !notes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 16)
                        
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(themeManager.currentTheme.secondaryBackgroundColor.color)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .alert("Delete School", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSchool()
            }
        } message: {
            Text("Are you sure you want to delete \(provider.name)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEventsModal) {
            SchoolCalendarSyncView(provider: provider)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
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

struct ContactInfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
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
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchType: LocationSearchType = .currentLocation
    @State private var zipCode = ""
    @State private var searchResults: [SchoolSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingLocationPermissionAlert = false
    
    let onSchoolSelected: (SchoolSearchResult) -> Void
    
    enum LocationSearchType: CaseIterable {
        case currentLocation
        case zipCode
        
        var title: String {
            switch self {
            case .currentLocation: return "Current Location"
            case .zipCode: return "ZIP Code"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Type Picker
            Picker("Search Type", selection: $searchType) {
                ForEach(LocationSearchType.allCases, id: \.self) { type in
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
        
        if searchType == .currentLocation {
            // Check location permission
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                showingLocationPermissionAlert = true
                isSearching = false
                return
            }
            
            // Request current location
            locationManager.requestCurrentLocation { [self] location in
                guard let location = location else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Unable to get current location"
                        self.isSearching = false
                    }
                    return
                }
                
                let searchRequest = SchoolSearchRequest(
                    locationType: "current",
                    zipcode: nil,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: 5000 // 5km radius
                )
                
                performSearch(searchRequest)
            }
        } else {
            // ZIP code search
            let searchRequest = SchoolSearchRequest(
                locationType: "zipcode",
                zipcode: zipCode,
                latitude: nil,
                longitude: nil,
                radius: 5000
            )
            
            performSearch(searchRequest)
        }
    }
    
    private func performSearch(_ searchRequest: SchoolSearchRequest) {
        viewModel.searchSchoolProviders(searchRequest) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let results):
                    self.searchResults = results
                    if results.isEmpty {
                        self.errorMessage = "No schools found in this area"
                    }
                case .failure(let error):
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.searchResults = []
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

struct SchoolCalendarSyncView: View {
    let provider: SchoolProvider
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var eventURL = ""
    @State private var isLoading = false
    @State private var showingSuccessMessage = false
    @State private var showingErrorMessage = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar Sync")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("Sync \(provider.name)'s calendar to automatically import school events and closures")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                .padding(.horizontal)
                
                // URL Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Calendar URL")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("Enter the school's calendar URL (usually ends with .ics)")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    
                    TextField("https://school.edu/calendar.ics", text: $eventURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    if let website = provider.website, !website.isEmpty {
                        Text("Tip: Check \(website) for calendar links")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Sync Button
                Button(action: syncEventsCalendar) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isLoading ? "Syncing..." : "Sync Calendar")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(eventURL.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(eventURL.isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Calendar Sync")
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
            .alert("Success!", isPresented: $showingSuccessMessage) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("School calendar has been synced successfully!")
            }
            .alert("Sync Failed", isPresented: $showingErrorMessage) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            if let website = provider.website {
                eventURL = website
            }
        }
    }
    
    private func syncEventsCalendar() {
        guard !eventURL.isEmpty else { return }
        
        isLoading = true
        
        // Call the backend to sync events from the calendar URL
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
                    errorMessage = "Unable to sync events: \(error.localizedDescription)"
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