//
//  LocationManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/21/25.
//

import Foundation
import SwiftUI
import CoreLocation



// MARK: - Location Manager for Real Device Heading
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var deviceHeading: Double = 0
    @Published var headingAccuracy: Double = 0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use magnetic heading, adjust for true heading if needed
        let heading = newHeading.magneticHeading
        if heading >= 0 {
            DispatchQueue.main.async {
                let oldHeading = self.deviceHeading
                self.deviceHeading = heading
                self.headingAccuracy = newHeading.headingAccuracy
                
                // Log significant heading changes for debugging
                if abs(heading - oldHeading) > 5.0 {
                    print("🧭 Device Heading: \(String(format: "%.1f", heading))° (was \(String(format: "%.1f", oldHeading))°) Accuracy: \(String(format: "%.1f", newHeading.headingAccuracy))°")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
}
