import SwiftUI
import MapKit
import CoreLocation

struct EnhancedMedicalSearchView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let defaultSearchTerms: String?
    let onProviderSelected: (MedicalSearchResult) -> Void
    
    init(defaultSearchTerms: String? = nil, onProviderSelected: @escaping (MedicalSearchResult) -> Void) {
        self.defaultSearchTerms = defaultSearchTerms
        self.onProviderSelected = onProviderSelected
    }
    
    @State private var searchType: SearchType = .currentLocation
    @State private var zipCode = ""
    @State private var searchTerms = ""
    @State private var searchRadius: Double = 5000 // meters
    @State private var searchResults: [MedicalSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingLocationPermissionAlert = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var mapPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var showingRadiusEditor = false
    
    @FocusState private var isZipCodeFocused: Bool
    @FocusState private var isSearchTermsFocused: Bool
    
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
    
    var radiusInMiles: Double {
        searchRadius / 1609.34 // Convert meters to miles
    }
    
    var radiusInKm: Double {
        searchRadius / 1000 // Convert meters to km
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Controls Header
                VStack(spacing: 16) {
                    // Search Type Picker
                    Picker("Search Type", selection: $searchType) {
                        ForEach(SearchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Search Terms (Optional)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            Text("Search Terms (Optional)")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        }
                        
                        TextField("e.g. pediatrician, cardiologist, urgent care", text: $searchTerms)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                            .focused($isSearchTermsFocused)
                            .onSubmit {
                                // Trigger search when return key is pressed
                                if searchType == .currentLocation || !zipCode.isEmpty {
                                    isSearchTermsFocused = false
                                    searchMedicalProviders()
                                }
                            }
                    }
                    
                    // Location-specific controls
                    if searchType == .zipCode {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ZIP Code")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                TextField("Enter ZIP code", text: $zipCode)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .focused($isZipCodeFocused)
                                    .onChange(of: zipCode) {
                                        // Auto-dismiss keyboard when ZIP code is complete (5 digits)
                                        if zipCode.count >= 5 {
                                            isZipCodeFocused = false
                                        }
                                    }
                            }
                            
                            Button("Search") {
                                // Dismiss keyboard first
                                isZipCodeFocused = false
                                isSearchTermsFocused = false
                                searchMedicalProviders()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(zipCode.isEmpty || isSearching)
                        }
                    } else {
                        // Current Location Search Button
                        Button(action: {
                            // Dismiss keyboard first
                            isSearchTermsFocused = false
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
                            .background(themeManager.currentTheme.accentColor.color)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSearching)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(themeManager.currentTheme.mainBackgroundColor.color)
                
                // Map and Radius Controls
                VStack(spacing: 12) {
                    // Map with radius circle
                    ZStack {
                        Map(position: $mapPosition) {
                            ForEach(searchResults) { result in
                                Annotation("Medical Provider", coordinate: coordinateForResult(result)) {
                                    Image(systemName: "cross.case.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(.white))
                                        .font(.title2)
                                        .shadow(radius: 2)
                                        .onTapGesture {
                                            onProviderSelected(result)
                                        }
                                }
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    // Convert pinch gesture to radius adjustment
                                    let newRadius = max(500, min(25000, searchRadius / value))
                                    searchRadius = newRadius
                                    updateMapRegion()
                                }
                        )
                        
                        // Radius circle overlay
                        if let currentLocation = currentLocation {
                            Circle()
                                .stroke(themeManager.currentTheme.accentColor.color.opacity(0.3), lineWidth: 2)
                                .frame(width: radiusCircleSize, height: radiusCircleSize)
                                .position(mapPositionForCoordinate(currentLocation))
                        }
                        
                        // Map controls overlay
                        VStack {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Button(action: { zoomIn() }) {
                                        Image(systemName: "plus")
                                            .padding(8)
                                            .background(Circle().fill(.white.opacity(0.9)))
                                            .shadow(radius: 2)
                                    }
                                    Button(action: { zoomOut() }) {
                                        Image(systemName: "minus")
                                            .padding(8)
                                            .background(Circle().fill(.white.opacity(0.9)))
                                            .shadow(radius: 2)
                                    }
                                }
                                .padding(.trailing, 8)
                            }
                            Spacer()
                        }
                    }
                    
                    // Radius Controls
                    VStack(spacing: 8) {
                        HStack {
                            Text("Search Radius")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
                            Spacer()
                            
                            Button(action: { showingRadiusEditor = true }) {
                                Text(String(format: "%.1f miles (%.1f km)", radiusInMiles, radiusInKm))
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.accentColor.color)
                            }
                        }
                        
                        // Radius Slider
                        HStack {
                            Text("0.3mi")
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            
                            Slider(value: $searchRadius, in: 500...25000, step: 500) { isEditing in
                                if !isEditing {
                                    updateMapRegion()
                                    // Auto-search if we have results
                                    if !searchResults.isEmpty {
                                        searchMedicalProviders()
                                    }
                                }
                            }
                            .accentColor(themeManager.currentTheme.accentColor.color)
                            
                            Text("15.5mi")
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Search Results with "expand search" notice
                if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                        
                        Text("Find Medical Providers")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Use the map to set your search area, then search for nearby medical facilities")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Results header with count and expand notice
                        HStack {
                            Text("\(searchResults.count) provider\(searchResults.count == 1 ? "" : "s") found")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
                            Spacer()
                            
                            if searchResults.count < 3 && searchResults.count > 0 {
                                Button(action: { expandSearch() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass.circle")
                                        Text("Expand Search")
                                    }
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.accentColor.color)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        if searchResults.count < 3 && searchResults.count > 0 {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Try expanding your search radius or adjusting search terms to find more providers")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                        }
                        
                        // Results list
                        List(searchResults) { result in
                            EnhancedMedicalSearchResultRow(result: result, onSelect: {
                                onProviderSelected(result)
                            })
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Find Medical Provider")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                isZipCodeFocused = false
                isSearchTermsFocused = false
            }
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
            .sheet(isPresented: $showingRadiusEditor) {
                RadiusEditorView(radius: $searchRadius) {
                    updateMapRegion()
                    if !searchResults.isEmpty {
                        searchMedicalProviders()
                    }
                }
            }
        }
        .onAppear {
            setupInitialLocation()
            if let defaultTerms = defaultSearchTerms {
                searchTerms = defaultTerms
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestCurrentLocation { location in
                DispatchQueue.main.async {
                    if let location = location {
                        self.currentLocation = location.coordinate
                        let newRegion = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        self.mapRegion = newRegion
                        self.mapPosition = .region(newRegion)
                        updateMapRegion()
                    }
                }
            }
        }
    }
    
    private func updateMapRegion() {
        guard let center = currentLocation else { return }
        
        // Calculate the span based on radius
        let radiusInDegrees = searchRadius / 111320.0 // Rough conversion from meters to degrees
        let newRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: radiusInDegrees * 2.5,
                longitudeDelta: radiusInDegrees * 2.5
            )
        )
        mapRegion = newRegion
        mapPosition = .region(newRegion)
    }
    
    private var radiusCircleSize: CGFloat {
        // Calculate circle size based on map zoom and radius
        let meterPerPoint = mapRegion.span.latitudeDelta * 111320.0 / 200 // Rough calculation
        return CGFloat(searchRadius / meterPerPoint)
    }
    
    private func mapPositionForCoordinate(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        // This is a simplified calculation - in a real implementation,
        // you'd need to properly convert map coordinates to view coordinates
        return CGPoint(x: 100, y: 100) // Center of map view
    }
    
    private func coordinateForResult(_ result: MedicalSearchResult) -> CLLocationCoordinate2D {
        // In a real implementation, you'd extract coordinates from the place ID
        // For now, return a coordinate near the current location
        guard let center = currentLocation else {
            return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
        
        // Generate a random coordinate within the search radius
        let randomLatOffset = Double.random(in: -0.01...0.01)
        let randomLonOffset = Double.random(in: -0.01...0.01)
        
        return CLLocationCoordinate2D(
            latitude: center.latitude + randomLatOffset,
            longitude: center.longitude + randomLonOffset
        )
    }
    
    private func zoomIn() {
        searchRadius = max(500, searchRadius * 0.7)
        updateMapRegion()
    }
    
    private func zoomOut() {
        searchRadius = min(25000, searchRadius * 1.4)
        updateMapRegion()
    }
    
    private func expandSearch() {
        // Increase radius by 50%
        searchRadius = min(25000, searchRadius * 1.5)
        updateMapRegion()
        searchMedicalProviders()
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
            
            // Use current location if available, otherwise request it
            if let location = currentLocation {
                performLocationSearch(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
            } else {
                // Request current location
                locationManager.requestCurrentLocation { [self] location in
                    guard let location = location else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Unable to get current location"
                            self.isSearching = false
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.currentLocation = location.coordinate
                        updateMapRegion()
                    }
                    
                    performLocationSearch(coordinate: location.coordinate)
                }
            }
        } else {
            // ZIP code search
            let searchRequest = MedicalSearchRequest(
                locationType: "zipcode",
                zipcode: zipCode,
                latitude: nil,
                longitude: nil,
                radius: Int(searchRadius),
                specialty: searchTerms.isEmpty ? nil : searchTerms,
                query: searchTerms.isEmpty ? nil : searchTerms
            )
            
            performSearch(searchRequest)
        }
    }
    
    private func performLocationSearch(coordinate: CLLocationCoordinate2D) {
        let searchRequest = MedicalSearchRequest(
            locationType: "current",
            zipcode: nil,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: Int(searchRadius),
            specialty: searchTerms.isEmpty ? nil : searchTerms,
            query: searchTerms.isEmpty ? nil : searchTerms
        )
        
        performSearch(searchRequest)
    }
    
    private func performSearch(_ searchRequest: MedicalSearchRequest) {
        viewModel.searchMedicalProviders(searchRequest) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let results):
                    self.searchResults = results
                    
                    // Show helpful message if no results
                    if results.isEmpty {
                        self.errorMessage = "No providers found. Try expanding your search radius or adjusting search terms."
                    }
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.searchResults = []
                }
            }
        }
    }
}

// MARK: - Enhanced Search Result Row

struct EnhancedMedicalSearchResultRow: View {
    let result: MedicalSearchResult
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main provider row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .multilineTextAlignment(.leading)
                    
                    if let specialty = result.specialty {
                        Text(specialty)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    
                    if let distance = result.distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.circle")
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                                .font(.caption)
                            Text(String(format: "%.1f km away", distance / 1000))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let rating = result.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption2)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        }
                    }
                    
                    // Add button with better styling (explicit button to avoid nested Buttons in List)
                    Button(action: onSelect) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.white)
                                .font(.body)
                            Text("Add Provider")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.currentTheme.accentColor.color)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            
            // Address and phone in a more compact layout
            VStack(alignment: .leading, spacing: 6) {
                // Address - tappable for directions
                Button(action: {
                    openMapsForDirections(to: result.address)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption)
                            .frame(width: 16)
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
                        HStack(spacing: 8) {
                            Image(systemName: "phone")
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                                .font(.caption)
                                .frame(width: 16)
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 3, x: 0, y: 2)
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

// MARK: - Radius Editor Modal

struct RadiusEditorView: View {
    @Binding var radius: Double
    let onRadiusChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var radiusText = ""
    @State private var unit: RadiusUnit = .miles
    
    enum RadiusUnit: String, CaseIterable {
        case miles = "miles"
        case kilometers = "km"
        
        var conversionFactor: Double {
            switch self {
            case .miles:
                return 1609.34 // meters per mile
            case .kilometers:
                return 1000.0 // meters per kilometer
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Search Radius")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("Set how far you want to search for medical providers")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    // Unit picker
                    Picker("Unit", selection: $unit) {
                        ForEach(RadiusUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Text input
                    HStack(spacing: 12) {
                        TextField("Radius", text: $radiusText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        Text(unit.rawValue)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    
                    // Quick preset buttons
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(presetValues, id: \.self) { preset in
                            Button(action: {
                                radiusText = String(format: "%.1f", preset)
                                updateRadius()
                            }) {
                                Text("\(String(format: "%.1f", preset)) \(unit.rawValue)")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Search Radius")
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
                        updateRadius()
                        onRadiusChanged()
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.accentColor.color)
                }
            }
        }
        .onAppear {
            setupInitialValue()
        }
        .onChange(of: unit) {
            updateDisplayValue()
        }
    }
    
    private var presetValues: [Double] {
        switch unit {
        case .miles:
            return [0.5, 1.0, 2.0, 5.0, 10.0, 15.0]
        case .kilometers:
            return [1.0, 2.0, 5.0, 10.0, 15.0, 25.0]
        }
    }
    
    private func setupInitialValue() {
        updateDisplayValue()
    }
    
    private func updateDisplayValue() {
        let valueInUnit = radius / unit.conversionFactor
        radiusText = String(format: "%.1f", valueInUnit)
    }
    
    private func updateRadius() {
        if let value = Double(radiusText) {
            radius = value * unit.conversionFactor
        }
    }
}

struct EnhancedMedicalSearchView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        EnhancedMedicalSearchView(onProviderSelected: { _ in
            // Preview provider selected callback
        })
        .environmentObject(calendarViewModel)
        .environmentObject(themeManager)
    }
}