import SwiftUI
import CoreLocation
import MapKit

struct AddDoctorView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var specialty = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""
    @State private var zipCode = ""
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedLocation: MKMapItem?
    @State private var showingLocationPicker = false
    
    private let locationManager = CLLocationManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Doctor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Text("Add a new doctor or medical provider")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Location Search Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Find Medical Provider")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        HStack {
                            TextField("Search for doctors, pediatricians, clinics...", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    searchLocations()
                                }
                            
                            Button(action: searchLocations) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }
                        
                        if isSearching {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching...")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            }
                        }
                        
                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Search Results")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        selectLocation(item)
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name ?? "Unknown")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(themeManager.currentTheme.textColor.color)
                                            
                                            if let address = item.placemark.thoroughfare {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Manual Entry Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Or Enter Details Manually")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        VStack(spacing: 16) {
                            TextField("Doctor Name *", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Specialty (e.g., Pediatrician, Cardiologist)", text: $specialty)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Address", text: $address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Phone Number", text: $phone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            TextField("Website", text: $website)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                            
                            TextField("Zip Code", text: $zipCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            TextField("Notes", text: $notes, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .background(themeManager.currentTheme.mainBackgroundColor.color)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.textColor.color)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveDoctor()
                }
                .foregroundColor(.red)
                .disabled(name.isEmpty)
            }
        }
    }
    
    private func searchLocations() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        // Medical provider search terms to include in the search
        let medicalTerms = [
            "pediatrician",
            "primary care",
            "family doctor",
            "family physician",
            "general practitioner",
            "internal medicine",
            "family practice",
            "medical clinic",
            "doctor office",
            "physician",
            "medical center",
            "healthcare",
            "medical practice"
        ]
        
        // Create multiple search requests with different medical terms
        let searchGroup = DispatchGroup()
        var allResults: [MKMapItem] = []
        
        for term in medicalTerms {
            searchGroup.enter()
            
            let request = MKLocalSearch.Request()
            // Combine the user's search text with medical terms
            let searchQuery = "\(searchText) \(term)"
            request.naturalLanguageQuery = searchQuery
            request.resultTypes = .pointOfInterest
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                defer { searchGroup.leave() }
                
                if let error = error {
                    print("❌ Location search error for '\(searchQuery)': \(error.localizedDescription)")
                    return
                }
                
                if let response = response {
                    DispatchQueue.main.async {
                        allResults.append(contentsOf: response.mapItems)
                    }
                }
            }
        }
        
        // Also do a direct search with the original text in case it's already medical-specific
        searchGroup.enter()
        let directRequest = MKLocalSearch.Request()
        directRequest.naturalLanguageQuery = searchText
        directRequest.resultTypes = .pointOfInterest
        
        let directSearch = MKLocalSearch(request: directRequest)
        directSearch.start { response, error in
            defer { searchGroup.leave() }
            
            if let error = error {
                print("❌ Direct location search error: \(error.localizedDescription)")
                return
            }
            
            if let response = response {
                DispatchQueue.main.async {
                    allResults.append(contentsOf: response.mapItems)
                }
            }
        }
        
        searchGroup.notify(queue: .main) {
            self.isSearching = false
            
            // Remove duplicates and filter for medical-related results
            let uniqueResults = Array(Set(allResults.map { $0.name ?? "" }))
                .compactMap { name in
                    allResults.first { $0.name == name }
                }
                .filter { item in
                    // Filter for medical-related businesses
                    let name = item.name?.lowercased() ?? ""
                    let category = item.pointOfInterestCategory?.rawValue.lowercased() ?? ""
                    
                    return name.contains("doctor") || 
                           name.contains("medical") || 
                           name.contains("clinic") || 
                           name.contains("health") || 
                           name.contains("physician") || 
                           name.contains("pediatric") || 
                           name.contains("family") || 
                           category.contains("medical") ||
                           category.contains("health")
                }
            
            self.searchResults = uniqueResults
            print("🔍 Found \(uniqueResults.count) medical providers for search: '\(self.searchText)'")
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        
        // Auto-fill the form with location data
        name = item.name ?? ""
        address = formatAddress(item.placemark)
        
        if let phoneNumber = item.phoneNumber {
            phone = phoneNumber
        }
        
        if let url = item.url {
            website = url.absoluteString
        }
        
        // Clear search results
        searchResults = []
        searchText = ""
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func saveDoctor() {
        guard !name.isEmpty else { return }
        
        let doctorData = MedicalProviderCreate(
            name: name,
            specialty: specialty.isEmpty ? nil : specialty,
            address: address.isEmpty ? nil : address,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            website: website.isEmpty ? nil : website,
            latitude: selectedLocation?.placemark.coordinate.latitude,
            longitude: selectedLocation?.placemark.coordinate.longitude,
            zipCode: zipCode.isEmpty ? nil : zipCode,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.saveMedicalProvider(doctorData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully saved medical provider: \(name)")
                    dismiss()
                } else {
                    print("❌ Failed to save medical provider: \(name)")
                }
            }
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