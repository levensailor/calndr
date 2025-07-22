import Foundation
import MapKit
import CoreLocation

// MARK: - School Search Models

struct MapKitSchoolResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let phoneNumber: String?
    let category: String?
    let coordinate: CLLocationCoordinate2D
    let distance: Double?
    let placemark: MKPlacemark
    
    // Convert to the existing SchoolSearchResult format for compatibility
    func toSchoolSearchResult() -> SchoolSearchResult {
        // Generate a synthetic place_id using coordinates
        let placeId = "mapkit_\(coordinate.latitude)_\(coordinate.longitude)"
        
        return SchoolSearchResult(
            id: placeId,
            placeId: placeId,
            name: name,
            address: address,
            phoneNumber: phoneNumber,
            rating: nil, // MapKit doesn't provide ratings
            website: nil, // MapKit doesn't provide websites directly
            hours: nil, // MapKit doesn't provide hours directly
            distance: distance
        )
    }
}

// MARK: - School Search Manager

@MainActor
class SchoolSearchManager: ObservableObject {
    static let shared = SchoolSearchManager()
    
    @Published var isSearching = false
    @Published var searchResults: [MapKitSchoolResult] = []
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Search Methods
    
    func searchSchoolsNearLocation(_ location: CLLocation, radius: CLLocationDistance = 5000) async -> [MapKitSchoolResult] {
        await performSearch(center: location.coordinate, radius: radius)
    }
    
    func searchSchoolsInRegion(_ region: MKCoordinateRegion) async -> [MapKitSchoolResult] {
        let center = region.center
        let radius = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111000 / 2 // Convert degrees to meters
        return await performSearch(center: center, radius: min(radius, 50000)) // Cap at 50km
    }
    
    func searchSchoolsByZipCode(_ zipCode: String) async -> [MapKitSchoolResult] {
        // First geocode the ZIP code to get coordinates
        guard let coordinate = await geocodeZipCode(zipCode) else {
            errorMessage = "Could not find location for ZIP code: \(zipCode)"
            return []
        }
        
        return await performSearch(center: coordinate, radius: 10000) // 10km radius for ZIP searches
    }
    
    func searchSchoolsByText(_ searchText: String, region: MKCoordinateRegion? = nil) async -> [MapKitSchoolResult] {
        isSearching = true
        errorMessage = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(searchText) schools"
        
        if let region = region {
            request.region = region
        }
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let results = response.mapItems.compactMap { mapItem -> MapKitSchoolResult? in
                createSchoolResult(from: mapItem, relativeTo: region?.center)
            }
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
            
            return results
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func performSearch(center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [MapKitSchoolResult] {
        isSearching = true
        errorMessage = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "schools"
        
        // Create region based on center and radius
        let regionRadius = radius / 111000 // Convert meters to degrees (approximate)
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: regionRadius * 2,
                longitudeDelta: regionRadius * 2
            )
        )
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            
            let results = response.mapItems.compactMap { mapItem -> MapKitSchoolResult? in
                createSchoolResult(from: mapItem, relativeTo: center, centerLocation: centerLocation, maxDistance: radius)
            }
            
            // Sort by distance
            let sortedResults = results.sorted { result1, result2 in
                (result1.distance ?? Double.max) < (result2.distance ?? Double.max)
            }
            
            DispatchQueue.main.async {
                self.searchResults = sortedResults
                self.isSearching = false
            }
            
            return sortedResults
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
            return []
        }
    }
    
    private func createSchoolResult(
        from mapItem: MKMapItem,
        relativeTo center: CLLocationCoordinate2D? = nil,
        centerLocation: CLLocation? = nil,
        maxDistance: CLLocationDistance? = nil
    ) -> MapKitSchoolResult? {
        
        let placemark = mapItem.placemark
        let coordinate = placemark.coordinate
        
        // Filter out results that are clearly not schools
        let name = mapItem.name ?? "Unknown School"
        let category = mapItem.pointOfInterestCategory?.rawValue
        
        // Basic filtering for school-like places
        let schoolKeywords = ["school", "academy", "college", "university", "education", "learning", "elementary", "middle", "high", "primary", "secondary"]
        let nameContainsSchoolKeyword = schoolKeywords.contains { keyword in
            name.lowercased().contains(keyword)
        }
        
        let categoryIsEducational = category?.contains("school") == true || 
                                   category?.contains("education") == true ||
                                   category?.contains("university") == true
        
        // Only include if it seems like a school
        guard nameContainsSchoolKeyword || categoryIsEducational else {
            return nil
        }
        
        // Calculate distance if reference point provided
        var distance: Double?
        if let centerLocation = centerLocation {
            let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            distance = centerLocation.distance(from: itemLocation)
            
            // Filter by maximum distance if specified
            if let maxDistance = maxDistance, distance! > maxDistance {
                return nil
            }
        }
        
        // Format address
        let addressComponents = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ].compactMap { $0 }
        
        let address = addressComponents.joined(separator: ", ")
        
        return MapKitSchoolResult(
            name: name,
            address: address.isEmpty ? "Address not available" : address,
            phoneNumber: mapItem.phoneNumber,
            category: category,
            coordinate: coordinate,
            distance: distance,
            placemark: placemark
        )
    }
    
    private func geocodeZipCode(_ zipCode: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(zipCode)
            return placemarks.first?.location?.coordinate
        } catch {
            print("Geocoding failed for ZIP code \(zipCode): \(error)")
            return nil
        }
    }
}

// MARK: - SwiftUI Integration Helper

extension SchoolSearchManager {
    func searchForSchools(
        type: SchoolSearchType,
        zipCode: String = "",
        userLocation: CLLocation? = nil
    ) async -> [SchoolSearchResult] {
        
        var results: [MapKitSchoolResult] = []
        
        switch type {
        case .currentLocation:
            guard let location = userLocation else {
                errorMessage = "Current location not available"
                return []
            }
            results = await searchSchoolsNearLocation(location)
            
        case .zipCode:
            guard !zipCode.isEmpty else {
                errorMessage = "ZIP code is required"
                return []
            }
            results = await searchSchoolsByZipCode(zipCode)
        }
        
        return results.map { $0.toSchoolSearchResult() }
    }
}

// MARK: - Search Type Enum

enum SchoolSearchType: CaseIterable {
    case currentLocation
    case zipCode
    
    var title: String {
        switch self {
        case .currentLocation: return "Current Location"
        case .zipCode: return "ZIP Code"
        }
    }
} 