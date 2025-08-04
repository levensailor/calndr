import SwiftUI
import CoreLocation

struct AddDoctorView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingManualEntry = false
    @State private var showingEnhancedSearch = false
    @State private var name = ""
    @State private var specialty = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""
    @State private var searchResults: [MedicalSearchResult] = []
    
    @StateObject private var locationManager = LocationManager.shared
    @State private var showingLocationPermissionAlert = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Controls
                VStack(spacing: 16) {
                    // Enhanced Map Search
                    Button(action: {
                        showingEnhancedSearch = true
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Search with Map")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.accentColor.color)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Quick Search Near Me
                    Button(action: {
                        searchMedicalProviders()
                    }) {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text(isSearching ? "Quick Search Near Me" : "Quick Search Near Me")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .cornerRadius(10)
                    }
                    .disabled(isSearching)
                    
                    // Manual Entry Option
                    Button(action: {
                        showingManualEntry = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Enter Provider Manually")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .cornerRadius(10)
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
                
                Divider()
                
                // Search Results
                if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                        
                        Text("Search for medical providers")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Use your current location to find nearby medical facilities")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { result in
                        MedicalSearchResultRow(result: result, onSelect: {
                            populateFromSearchResult(result)
                            dismiss()
                        })
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Add Medical Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor.color)
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
                Text("Please enable location access in Settings to search for nearby medical providers.")
            }
                        .sheet(isPresented: $showingEnhancedSearch) {
                EnhancedMedicalSearchView { result in
                    populateFromSearchResult(result)
                    showingEnhancedSearch = false
                    dismiss()
                }
                .environmentObject(viewModel)
                .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingManualEntry) {
                NavigationView {
                    Form {
                        Section(header: Text("Medical Provider Information")
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                            FloatingLabelTextField(
                                title: "Provider Name",
                                text: $name,
                                isSecure: false
                            )
                            
                            FloatingLabelTextField(
                                title: "Specialty (Optional)",
                                text: $specialty,
                                isSecure: false
                            )
                            
                            FloatingLabelTextField(
                                title: "Address (Optional)",
                                text: $address,
                                isSecure: false
                            )
                            
                            FloatingLabelTextField(
                                title: "Phone Number (Optional)",
                                text: $phone,
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
                                title: "Website (Optional)",
                                text: $website,
                                isSecure: false
                            )
                            .keyboardType(.URL)
                            .autocapitalization(.none)

                            FloatingLabelTextField(
                                title: "Notes (Optional)",
                                text: $notes,
                                isSecure: false
                            )
                        }
                        .listRowBackground(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                    }
                    .scrollContentBackground(.hidden)
                    .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
                    .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
                    .navigationTitle("Enter Provider Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingManualEntry = false
                            }
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                saveMedicalProvider()
                                showingManualEntry = false
                            }
                            .disabled(name.isEmpty)
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                }
            }
        }
    }
    
    private func searchMedicalProviders() {
        errorMessage = nil
        isSearching = true
        
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
            
            let searchRequest = MedicalSearchRequest(
                locationType: "current",
                zipcode: nil,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 5000, // 5km radius
                specialty: nil,
                query: nil
            )
            
            viewModel.searchMedicalProviders(searchRequest) { result in
                DispatchQueue.main.async {
                    self.isSearching = false
                    
                    switch result {
                    case .success(let results):
                        self.searchResults = results
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func saveMedicalProvider() {
        let provider = MedicalProviderCreate(
            name: name,
            specialty: specialty.isEmpty ? nil : specialty,
            address: address.isEmpty ? nil : address,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            website: website.isEmpty ? nil : website,
            latitude: nil,
            longitude: nil,
            zipCode: nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.saveMedicalProvider(provider) { success in
            if success {
                dismiss()
            }
        }
    }
    
    private func populateFromSearchResult(_ result: MedicalSearchResult) {
        name = result.name
        specialty = result.specialty ?? ""
        address = result.address
        phone = result.phoneNumber ?? ""
        email = ""
        website = result.website ?? ""
        notes = result.distance != nil ? "Distance: \(String(format: "%.1f km", result.distance! / 1000))" : ""
        
        // Automatically save the provider from search result
        let provider = MedicalProviderCreate(
            name: result.name,
            specialty: result.specialty,
            address: result.address,
            phone: result.phoneNumber,
            email: nil,
            website: result.website,
            latitude: nil, // Could extract from placeId if needed
            longitude: nil, // Could extract from placeId if needed
            zipCode: nil,
            notes: notes.isEmpty ? "Added from search results" : notes
        )
        
        print("💾 Auto-saving medical provider from search: \(result.name)")
        viewModel.saveMedicalProvider(provider) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully auto-saved medical provider: \(result.name)")
                } else {
                    print("❌ Failed to auto-save medical provider: \(result.name)")
                    // Note: We still populate the form as fallback so user can manually save
                }
            }
        }
    }
}

// MARK: - Medical Search View

struct MedicalSearchView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let onProviderSelected: (MedicalSearchResult) -> Void
    
    @State private var searchType: SearchType = .currentLocation
    @State private var zipCode = ""
    @State private var searchResults: [MedicalSearchResult] = []
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
                                searchMedicalProviders()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(zipCode.isEmpty || isSearching)
                        }
                    } else {
                        // Current Location Search
                        Button(action: {
                            searchMedicalProviders()
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
                            .background(Color.red)
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
                        
                        Text("Search for medical providers")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Use your current location or enter a ZIP code to find nearby medical facilities")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { result in
                        MedicalSearchResultRow(result: result, onSelect: {
                            onProviderSelected(result)
                        })
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Find Medical Provider")
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
                Text("Please enable location access in Settings to search for nearby medical providers.")
            }
        }
    }
    
    private func searchMedicalProviders() {
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
                
                let searchRequest = MedicalSearchRequest(
                    locationType: "current",
                    zipcode: nil,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: 5000, // 5km radius
                    specialty: nil,
                    query: nil
                )
                
                performSearch(searchRequest)
            }
        } else {
            // ZIP code search
            let searchRequest = MedicalSearchRequest(
                locationType: "zipcode",
                zipcode: zipCode,
                latitude: nil,
                longitude: nil,
                radius: 5000,
                specialty: nil,
                query: nil
            )
            
            performSearch(searchRequest)
        }
    }
    
    private func performSearch(_ searchRequest: MedicalSearchRequest) {
        viewModel.searchMedicalProviders(searchRequest) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let results):
                    self.searchResults = results
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Medical Search Result Row

struct MedicalSearchResultRow: View {
    let result: MedicalSearchResult
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main provider info - tappable to select/add
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        if let specialty = result.specialty {
                            Text(specialty)
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        }
                        
                        if let distance = result.distance {
                            Text(String(format: "%.1f km away", distance / 1000))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let rating = result.rating {
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                            }
                        }
                        
                        // Add button
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                                .font(.caption)
                            Text("Add")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Address - tappable for directions
            Button(action: {
                openMapsForDirections(to: result.address)
            }) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(themeManager.currentTheme.accentColor.color)
                        .font(.caption)
                    Text(result.address)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(themeManager.currentTheme.accentColor.color)
                        .font(.caption2)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Phone number - tappable to call
            if let phone = result.phoneNumber {
                Button(action: {
                    makePhoneCall(to: phone)
                }) {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption)
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func makePhoneCall(to phoneNumber: String) {
        // Clean the phone number - remove spaces, dashes, parentheses
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let phoneURL = URL(string: "tel://\(cleanNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL)
                print("📞 Opening phone call to: \(phoneNumber)")
            } else {
                print("❌ Device cannot make phone calls")
            }
        }
    }
    
    private func openMapsForDirections(to address: String) {
        // URL encode the address
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try to open in Apple Maps first
        if let mapsURL = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)") {
            if UIApplication.shared.canOpenURL(mapsURL) {
                UIApplication.shared.open(mapsURL)
                print("🗺️ Opening Apple Maps for directions to: \(address)")
                return
            }
        }
        
        // Fallback to Google Maps if available
        if let googleMapsURL = URL(string: "comgooglemaps://?daddr=\(encodedAddress)") {
            if UIApplication.shared.canOpenURL(googleMapsURL) {
                UIApplication.shared.open(googleMapsURL)
                print("🗺️ Opening Google Maps for directions to: \(address)")
                return
            }
        }
        
        // Final fallback to web-based maps
        if let webMapsURL = URL(string: "https://maps.google.com/maps?daddr=\(encodedAddress)") {
            UIApplication.shared.open(webMapsURL)
            print("🗺️ Opening web maps for directions to: \(address)")
        }
    }
}

struct AddDoctorView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        AddDoctorView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 