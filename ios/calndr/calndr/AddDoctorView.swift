import SwiftUI
import CoreLocation

struct AddDoctorView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSearch = false
    @State private var name = ""
    @State private var specialty = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button(action: {
                        showingSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.red)
                            Text("Search for Medical Providers")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Find Medical Provider")
                } footer: {
                    Text("Search for local medical providers or add your own manually")
                }
                
                Section("Medical Provider Information") {
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
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Add Medical Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMedicalProvider()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingSearch) {
                MedicalSearchView(
                    onProviderSelected: { searchResult in
                        populateFromSearchResult(searchResult)
                        showingSearch = false
                    }
                )
                .environmentObject(viewModel)
                .environmentObject(themeManager)
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
        notes = ""
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
                    radius: 5000 // 5km radius
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
                radius: 5000
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
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
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
                    }
                    
                    Spacer()
                    
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
                }
                
                Text(result.address)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                
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