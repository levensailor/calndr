import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus
    
    private var locationCompletion: ((CLLocation?) -> Void)?
    
    override private init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }
    
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        self.locationCompletion = completion
        
        // Request permission if we don't have it
        if manager.authorizationStatus == .notDetermined {
            requestLocationPermission()
        } else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else {
            // Handle cases where permission is denied or restricted
            completion(nil)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            locationCompletion?(nil)
            return
        }
        locationCompletion?(location)
        // Reset completion handler to avoid calling it again
        locationCompletion = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed with error: \(error.localizedDescription)")
        locationCompletion?(nil)
        locationCompletion = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        
        // If permission was just granted, proceed with the location request
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            if locationCompletion != nil {
                manager.requestLocation()
            }
        } else {
            // If permission was denied, fire the completion handler with nil
            if locationCompletion != nil {
                locationCompletion?(nil)
                locationCompletion = nil
            }
        }
    }
} 