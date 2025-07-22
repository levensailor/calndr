import SwiftUI

struct DaycareView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddDaycare = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daycare")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Text("Manage daycare providers and childcare information")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Add Button
                    HStack {
                        Spacer()
                        Button(action: { showingAddDaycare = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Daycare Provider")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Daycare Providers List
                    if viewModel.daycareProviders.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.2")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                            
                            Text("No daycare providers added yet")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            
                            Text("Add your first daycare provider to get started")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.daycareProviders) { provider in
                            DaycareProviderCard(provider: provider)
                                .padding(.horizontal)
                                .environmentObject(viewModel)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
        }
        .sheet(isPresented: $showingAddDaycare) {
            AddDaycareView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

struct DaycareProviderCard: View {
    let provider: DaycareProvider
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingEventsModal = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(.green)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if let address = provider.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Action buttons in top right
                HStack(spacing: 8) {
                    // Events button
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
            
            if let hours = provider.hours {
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
                if let phone = provider.phoneNumber {
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
                
                if let email = provider.email {
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
            
            if let notes = provider.notes {
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
            DaycareEventsModal(provider: provider)
                .environmentObject(themeManager)
        }
        .alert("Delete Daycare Provider", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteDaycareProvider()
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
    
    private func deleteDaycareProvider() {
        viewModel.deleteDaycareProvider(provider.id) { success in
            if success {
                print("✅ Successfully deleted daycare provider: \(provider.name)")
            } else {
                print("❌ Failed to delete daycare provider: \(provider.name)")
            }
        }
    }
}

struct AddDaycareView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSearch = false
    @State private var name = ""
    @State private var address = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var hours = ""
    @State private var notes = ""
    @State private var website = ""
    @State private var rating: Double? = nil
    @State private var googlePlaceId: String? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button(action: {
                        showingSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                            Text("Search for Daycare Providers")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Find Daycare")
                } footer: {
                    Text("Search for local daycare providers or add your own manually")
                }
                
                Section("Daycare Information") {
                    FloatingLabelTextField(
                        title: "Daycare Name",
                        text: $name,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Address (Optional)",
                        text: $address,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Phone Number (Optional)",
                        text: $phoneNumber,
                        isSecure: false
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Hours (Optional)",
                        text: $hours,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Website (Optional)",
                        text: $website,
                        isSecure: false
                    )
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    
                    if let rating = rating {
                        HStack {
                            Text("Rating:")
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            Spacer()
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                                Text(String(format: "%.1f", rating))
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                            }
                        }
                    }
                    
                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Add Daycare Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDaycareProvider()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingSearch) {
                DaycareSearchView(
                    onDaycareSelected: { searchResult in
                        populateFromSearchResult(searchResult)
                        showingSearch = false
                    }
                )
                .environmentObject(viewModel)
                .environmentObject(themeManager)
            }
        }
    }
    
    private func saveDaycareProvider() {
        let provider = DaycareProviderCreate(
            name: name,
            address: address.isEmpty ? nil : address,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            email: email.isEmpty ? nil : email,
            hours: hours.isEmpty ? nil : hours,
            notes: notes.isEmpty ? nil : notes,
            googlePlaceId: googlePlaceId,
            rating: rating,
            website: website.isEmpty ? nil : website
        )
        
        viewModel.saveDaycareProvider(provider) { success in
            if success {
                dismiss()
            }
        }
    }
    
    private func populateFromSearchResult(_ result: DaycareSearchResult) {
        name = result.name
        address = result.address
        phoneNumber = result.phoneNumber ?? ""
        email = ""
        hours = result.hours ?? ""
        notes = ""
        website = result.website ?? ""
        rating = result.rating
        googlePlaceId = result.placeId
    }
}

struct DaycareSearchView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let onDaycareSelected: (DaycareSearchResult) -> Void
    
    @State private var searchType: SearchType = .currentLocation
    @State private var zipCode = ""
    @State private var searchResults: [DaycareSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingLocationPermissionAlert = false
    
    @StateObject private var locationManager = LocationManager.shared
    
    enum SearchType: String, CaseIterable {
        case currentLocation = "current"
        case zipCode = "zipcode"
        
        var displayName: String {
            switch self {
            case .currentLocation:
                return "Current Location"
            case .zipCode:
                return "ZIP Code"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Controls
                VStack(spacing: 16) {
                    // Search Type Picker
                    Picker("Search Type", selection: $searchType) {
                        ForEach(SearchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // ZIP Code Input (if needed)
                    if searchType == .zipCode {
                        HStack(spacing: 12) {
                            FloatingLabelTextField(
                                title: "ZIP Code",
                                text: $zipCode,
                                isSecure: false
                            )
                            .keyboardType(.numberPad)
                            
                            Button("Search") {
                                searchDaycares()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(zipCode.isEmpty || isSearching)
                        }
                    } else {
                        // Current Location Search
                        Button(action: {
                            searchDaycares()
                        }) {
                            HStack {
                                if isSearching {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                }
                                Text(isSearching ? "Searching..." : "Search Near Me")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSearching)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(themeManager.currentTheme.mainBackgroundColor.color)
                
                Divider()
                
                // Search Results
                if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                        
                        Text("Search for daycare providers")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Use your current location or enter a ZIP code to find nearby daycare facilities")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { result in
                        DaycareSearchResultRow(result: result, onSelect: {
                            onDaycareSelected(result)
                        })
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Find Daycare")
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
                Text("Please enable location access in Settings to search for nearby daycare providers.")
            }
        }
    }
    
    private func searchDaycares() {
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
                
                let searchRequest = DaycareSearchRequest(
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
            let searchRequest = DaycareSearchRequest(
                locationType: "zipcode",
                zipcode: zipCode,
                latitude: nil,
                longitude: nil,
                radius: 5000
            )
            
            performSearch(searchRequest)
        }
    }
    
    private func performSearch(_ searchRequest: DaycareSearchRequest) {
        viewModel.searchDaycareProviders(searchRequest) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let results):
                    self.searchResults = results
                    if results.isEmpty {
                        self.errorMessage = "No daycare providers found in this area"
                    }
                case .failure(let error):
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.searchResults = []
                }
            }
        }
    }
}

struct DaycareSearchResultRow: View {
    let result: DaycareSearchResult
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(result.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Spacer()
                    
                    if let rating = result.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        }
                    }
                }
                
                Text(result.address)
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    .multilineTextAlignment(.leading)
                
                HStack {
                    if let phoneNumber = result.phoneNumber {
                        Label(phoneNumber, systemImage: "phone")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if let distance = result.distance {
                        let distanceInKm = distance / 1000
                        Text(String(format: "%.1f km", distanceInKm))
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    }
                }
                
                if let hours = result.hours {
                    Text(hours)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.secondaryBackgroundColor.color)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DaycareEventsModal: View {
    let provider: DaycareProvider
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var eventURL = ""
    @State private var discoveredURL: String? = nil
    @State private var isDiscovering = false
    @State private var isLoading = false
    @State private var isLoadingSync = false
    @State private var showingSuccessMessage = false
    @State private var showingErrorMessage = false
    @State private var errorMessage = ""
    @State private var syncInfo: DaycareCalendarSyncInfo?
    
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
                    
                    // Sync Status Info
                    if let syncInfo = syncInfo {
                        if syncInfo.syncEnabled {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Calendar sync is active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    if let lastSync = syncInfo.lastSyncAt {
                                        Text("Last synced: \(formatDate(lastSync))")
                                            .font(.caption2)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                                    }
                                    Text("\(syncInfo.eventsCount) events synced")
                                        .font(.caption2)
                                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Warning Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Important")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• This will parse events from the daycare's public calendar")
                        Text("• Events will be added to your family calendar")
                        Text("• This feature is experimental and may not work with all calendar formats")
                        Text("• Contact support if you experience issues")
                    }
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
                
                // Auto-discover button
                Button(action: discoverCalendarURL) {
                    HStack {
                        if isDiscovering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(isDiscovering ? "Discovering..." : "Auto Discover Calendar URL")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(provider.website?.isEmpty == false ? Color.blue : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(provider.website?.isEmpty != false || isDiscovering)
                .padding(.horizontal)
                
                // URL Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Events Calendar URL")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text(discoveredURL != nil ? "Discovered URL (you can edit if needed):" : syncInfo?.calendarURL != nil ? "Currently synced URL (you can change it):" : "Enter the URL manually:")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    
                    TextField("https://daycare.com/calendar", text: $eventURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal)
                
                // Parse Button
                Button(action: syncEventsCalendar) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.doc")
                        }
                        Text(isLoading ? "Syncing..." : syncInfo?.calendarURL != nil ? "Update Events Calendar" : "Sync Events Calendar")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(eventURL.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(eventURL.isEmpty || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
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
        .onAppear {
            loadCalendarSyncInfo()
        }
        .alert("Success", isPresented: $showingSuccessMessage) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Events have been successfully parsed and added to your calendar!")
        }
        .alert("Error", isPresented: $showingErrorMessage) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadCalendarSyncInfo() {
        isLoadingSync = true
        
        APIService.shared.getDaycareCalendarSync(providerId: provider.id) { result in
            DispatchQueue.main.async {
                isLoadingSync = false
                
                switch result {
                case .success(let info):
                    syncInfo = info
                    // Pre-populate the URL field if we have a stored URL
                    if let storedURL = info.calendarURL, eventURL.isEmpty {
                        eventURL = storedURL
                    }
                case .failure(let error):
                    print("Failed to load calendar sync info: \(error.localizedDescription)")
                    // Don't show error to user - just means no sync is configured yet
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func discoverCalendarURL() {
        isDiscovering = true
        
        // Call the backend to discover the calendar URL
        APIService.shared.discoverDaycareCalendarURL(providerId: provider.id) { result in
            DispatchQueue.main.async {
                isDiscovering = false
                
                switch result {
                case .success(let response):
                    if let calendarURL = response.discoveredCalendarURL {
                        discoveredURL = calendarURL
                        eventURL = calendarURL
                    } else {
                        errorMessage = "Could not automatically discover a calendar URL for \(provider.name). Please enter the URL manually."
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
        
        // Call the backend to sync events from the calendar URL
        APIService.shared.parseDaycareEvents(providerId: provider.id, calendarURL: eventURL) { result in
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

struct DaycareView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        DaycareView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 
