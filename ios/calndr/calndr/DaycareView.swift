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
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage daycare providers and childcare information")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
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
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.3))
                            
                            Text("No daycare providers added yet")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                            
                            Text("Add your first daycare provider to get started")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.daycareProviders) { provider in
                            DaycareProviderCard(provider: provider)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
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
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    if let address = provider.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            
            if let hours = provider.hours {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    
                    Text(hours)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
            }
            
            HStack {
                if let phone = provider.phoneNumber {
                    HStack {
                        Image(systemName: "phone")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if let email = provider.email {
                    HStack {
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        
                        Text(email)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
            }
            
            if let notes = provider.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
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
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Address (Optional)",
                        text: $address,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Phone Number (Optional)",
                        text: $phoneNumber,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Hours (Optional)",
                        text: $hours,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Website (Optional)",
                        text: $website,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    
                    if let rating = rating {
                        HStack {
                            Text("Rating:")
                                .foregroundColor(themeManager.currentTheme.textColor)
                            Spacer()
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                                Text(String(format: "%.1f", rating))
                                    .foregroundColor(themeManager.currentTheme.textColor)
                            }
                        }
                    }
                    
                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false,
                        themeManager: themeManager
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
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
                        HStack {
                            FloatingLabelTextField(
                                title: "ZIP Code",
                                text: $zipCode,
                                isSecure: false,
                                themeManager: themeManager
                            )
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 120)
                            
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
                .background(themeManager.currentTheme.mainBackgroundColor)
                
                Divider()
                
                // Search Results
                if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.3))
                        
                        Text("Search for daycare providers")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        
                        Text("Use your current location or enter a ZIP code to find nearby daycare facilities")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
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
            .background(themeManager.currentTheme.mainBackgroundColor)
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
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Spacer()
                    
                    if let rating = result.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                        }
                    }
                }
                
                Text(result.address)
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    .multilineTextAlignment(.leading)
                
                HStack {
                    if let phoneNumber = result.phoneNumber {
                        Label(phoneNumber, systemImage: "phone")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if let distance = result.distance {
                        let distanceInKm = distance / 1000
                        Text(String(format: "%.1f km", distanceInKm))
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    }
                }
                
                if let hours = result.hours {
                    Text(hours)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.otherMonthBackgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
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