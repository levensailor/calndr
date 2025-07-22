import Foundation
import MapKit
import CoreLocation

// MARK: - Enhanced School Search Models

struct EnhancedSchoolResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let phoneNumber: String?
    let category: String?
    let coordinate: CLLocationCoordinate2D
    let distance: Double?
    let placemark: MKPlacemark
    
    // Enhanced details from Google Places API
    var website: String?
    var rating: Double?
    var hours: String?
    var priceLevel: Int?
    var googlePlaceId: String?
    var isEnhanced: Bool = false // Flag to track if Google details were fetched
    
    // Convert to the existing SchoolSearchResult format for compatibility
    func toSchoolSearchResult() -> SchoolSearchResult {
        let placeId = googlePlaceId ?? "mapkit_\(coordinate.latitude)_\(coordinate.longitude)"
        
        return SchoolSearchResult(
            id: placeId,
            placeId: placeId,
            name: name,
            address: address,
            phoneNumber: phoneNumber,
            rating: rating,
            website: website,
            hours: hours,
            distance: distance
        )
    }
}

// MARK: - Google Places API Models

struct GooglePlacesTextSearchResponse: Codable {
    let candidates: [GooglePlaceCandidate]
    let status: String
}

struct GooglePlaceCandidate: Codable {
    let placeId: String
    let name: String
    let formattedAddress: String?
    let geometry: GooglePlaceGeometry?
    let rating: Double?
    let priceLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case geometry
        case rating
        case priceLevel = "price_level"
    }
}

struct GooglePlaceGeometry: Codable {
    let location: GooglePlaceLocation
}

struct GooglePlaceLocation: Codable {
    let lat: Double
    let lng: Double
}

struct GooglePlaceDetailsResponse: Codable {
    let result: GooglePlaceDetails?
    let status: String
}

struct GooglePlaceDetails: Codable {
    let placeId: String
    let name: String
    let formattedAddress: String?
    let formattedPhoneNumber: String?
    let website: String?
    let rating: Double?
    let priceLevel: Int?
    let openingHours: GooglePlaceOpeningHours?
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case formattedPhoneNumber = "formatted_phone_number"
        case website
        case rating
        case priceLevel = "price_level"
        case openingHours = "opening_hours"
    }
}

struct GooglePlaceOpeningHours: Codable {
    let weekdayText: [String]?
    
    enum CodingKeys: String, CodingKey {
        case weekdayText = "weekday_text"
    }
}

// MARK: - Enhanced School Search Manager

@MainActor
class EnhancedSchoolSearchManager: ObservableObject {
    static let shared = EnhancedSchoolSearchManager()
    
    @Published var isSearching = false
    @Published var isEnhancing = false
    @Published var searchResults: [EnhancedSchoolResult] = []
    @Published var errorMessage: String?
    
    private let baseSchoolSearchManager = SchoolSearchManager.shared
    private let googleApiKey: String?
    
    private init() {
        // Try to get Google API key from environment or config
        self.googleApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String
    }
    
    // MARK: - Enhanced Search Methods
    
    func searchAndEnhanceSchools(
        type: SchoolSearchType,
        zipCode: String = "",
        userLocation: CLLocation? = nil
    ) async -> [SchoolSearchResult] {
        
        isSearching = true
        errorMessage = nil
        
        // Step 1: Get schools from MapKit
        let mapKitResults = await baseSchoolSearchManager.searchForSchools(
            type: type,
            zipCode: zipCode,
            userLocation: userLocation
        )
        
        // Convert to enhanced results
        let enhancedResults: [EnhancedSchoolResult] = mapKitResults.compactMap { result in
            convertToEnhancedResult(from: result)
        }
        
        isSearching = false
        
        // Step 2: Don't enhance during search - wait for user selection
        DispatchQueue.main.async {
            self.searchResults = enhancedResults
        }
        
        return enhancedResults.map { $0.toSchoolSearchResult() }
    }
    
    func enhanceSchoolWithGoogleData(_ school: EnhancedSchoolResult) async -> EnhancedSchoolResult {
        guard googleApiKey != nil else {
            print("⚠️ Google Places API key not available - skipping enhancement")
            return school
        }
        
        isEnhancing = true
        
        var enhancedSchool = school
        
        // Step 1: Find the school on Google Places using text search
        if let googlePlace = await findSchoolOnGoogle(name: school.name, coordinate: school.coordinate) {
            // Step 2: Get detailed information
            if let details = await getGooglePlaceDetails(placeId: googlePlace.placeId) {
                enhancedSchool.googlePlaceId = details.placeId
                enhancedSchool.website = details.website
                enhancedSchool.rating = details.rating
                enhancedSchool.priceLevel = details.priceLevel
                
                // Format opening hours
                if let weekdayText = details.openingHours?.weekdayText {
                    enhancedSchool.hours = weekdayText.joined(separator: "\n")
                }
                
                enhancedSchool.isEnhanced = true
                print("✅ Enhanced school '\(school.name)' with Google data")
            }
        }
        
        isEnhancing = false
        return enhancedSchool
    }
    
    // MARK: - Google Places API Methods
    
    private func findSchoolOnGoogle(name: String, coordinate: CLLocationCoordinate2D) async -> GooglePlaceCandidate? {
        guard let googleApiKey = googleApiKey else { return nil }
        
        // Use Google Places Text Search to find the school
        let query = "\(name) school".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let location = "\(coordinate.latitude),\(coordinate.longitude)"
        let radius = "1000" // 1km radius
        
        let urlString = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=\(query)&inputtype=textquery&fields=place_id,name,formatted_address,geometry,rating,price_level&locationbias=circle:\(radius)@\(location)&key=\(googleApiKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlacesTextSearchResponse.self, from: data)
            
            // Return the closest match
            return response.candidates.first { candidate in
                // Verify it's actually close to our MapKit result
                guard let geometry = candidate.geometry else { return false }
                let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    .distance(from: CLLocation(latitude: geometry.location.lat, longitude: geometry.location.lng))
                
                // Must be within 500 meters to be considered the same place
                return distance < 500
            }
        } catch {
            print("❌ Google Places text search failed: \(error)")
            return nil
        }
    }
    
    private func getGooglePlaceDetails(placeId: String) async -> GooglePlaceDetails? {
        guard let googleApiKey = googleApiKey else { return nil }
        
        let fields = "place_id,name,formatted_address,formatted_phone_number,website,rating,price_level,opening_hours"
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(placeId)&fields=\(fields)&key=\(googleApiKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
            
            if response.status == "OK" {
                return response.result
            } else {
                print("❌ Google Places details API returned status: \(response.status)")
                return nil
            }
        } catch {
            print("❌ Google Places details request failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToEnhancedResult(from result: SchoolSearchResult) -> EnhancedSchoolResult? {
        // Parse coordinates from the MapKit-generated place_id
        let components = result.placeId.replacingOccurrences(of: "mapkit_", with: "").components(separatedBy: "_")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lng = Double(components[1]) else {
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        
        return EnhancedSchoolResult(
            name: result.name,
            address: result.address,
            phoneNumber: result.phoneNumber,
            category: nil,
            coordinate: coordinate,
            distance: result.distance,
            placemark: placemark,
            website: result.website,
            rating: result.rating,
            hours: result.hours,
            isEnhanced: false
        )
    }
}

// MARK: - SwiftUI Integration

extension EnhancedSchoolSearchManager {
    func searchForSchools(
        type: SchoolSearchType,
        zipCode: String = "",
        userLocation: CLLocation? = nil
    ) async -> [SchoolSearchResult] {
        return await searchAndEnhanceSchools(
            type: type,
            zipCode: zipCode,
            userLocation: userLocation
        )
    }
} 