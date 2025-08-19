import SwiftUI
import CoreLocation

struct AddPharmacyView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingManualEntry = false
    @State private var showingEnhancedSearch = false
    @State private var name = ""
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
                        searchPharmacies()
                    }) {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text(isSearching ? "Searching Pharmacies..." : "Quick Search Pharmacies Near Me")
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
                            Text("Enter Pharmacy Manually")
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
                        Image(systemName: "cross.vial.fill")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                        
                        Text("Search for pharmacies")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Use your current location to find nearby pharmacies")
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
            .navigationTitle("Add Pharmacy")
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
                Text("Please enable location access in Settings to search for nearby pharmacies.")
            }
            .sheet(isPresented: $showingEnhancedSearch) {
                EnhancedPharmacySearchView { result in
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
                        Section(header: Text("Pharmacy Information")
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                            FloatingLabelTextField(
                                title: "Pharmacy Name",
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
                    .navigationTitle("Enter Pharmacy Details")
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
                                savePharmacy()
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
    
    private func searchPharmacies() {
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
                query: "pharmacy"
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
    
    private func savePharmacy() {
        let provider = MedicalProviderCreate(
            name: name,
            specialty: "Pharmacy",
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
        address = result.address
        phone = result.phoneNumber ?? ""
        email = ""
        website = result.website ?? ""
        notes = result.distance != nil ? "Distance: \(String(format: "%.1f km", result.distance! / 1000))" : ""
        
        // Automatically save the pharmacy from search result
        let provider = MedicalProviderCreate(
            name: result.name,
            specialty: "Pharmacy",
            address: result.address,
            phone: result.phoneNumber,
            email: nil,
            website: result.website,
            latitude: nil,
            longitude: nil,
            zipCode: nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        print("💾 Auto-saving pharmacy from search: \(result.name)")
        viewModel.saveMedicalProvider(provider) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully auto-saved pharmacy: \(result.name)")
                } else {
                    print("❌ Failed to auto-save pharmacy: \(result.name)")
                }
            }
        }
    }
}

// MARK: - Enhanced Pharmacy Search View
struct EnhancedPharmacySearchView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let onPharmacySelected: (MedicalSearchResult) -> Void
    
    var body: some View {
        EnhancedMedicalSearchView(
            defaultSearchTerms: "pharmacy",
            onProviderSelected: onPharmacySelected
        )
        .navigationTitle("Find Pharmacy")
    }
}

struct AddPharmacyView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        AddPharmacyView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
}