//
//  LocationVerificationService.swift
//  InOfficeDaysTracker
//
//  Created to improve location accuracy and handle intermittent status issues
//

import Foundation
import CoreLocation

@MainActor
class LocationVerificationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var verificationTimer: Timer?
    private var lastKnownLocation: CLLocation?
    
    weak var appData: AppData?
    weak var locationService: LocationService?
    
    // Verification settings
    private let verificationInterval: TimeInterval = 300 // 5 minutes
    private let locationAccuracyThreshold: CLLocationAccuracy = 100 // meters
    private let maxLocationAge: TimeInterval = 600 // 10 minutes
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    func setServices(appData: AppData, locationService: LocationService) {
        self.appData = appData
        self.locationService = locationService
    }
    
    func startPeriodicVerification() {
        stopPeriodicVerification()
        
        guard let appData = appData else { return }
        
        // Only start verification if we have proper permissions and at least one office location
        guard locationService?.isLocationEnabled == true,
              (!appData.settings.officeLocations.isEmpty || appData.settings.officeLocation != nil) else {
            return
        }
        
        verificationTimer = Timer.scheduledTimer(withTimeInterval: verificationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.verifyCurrentLocation()
            }
        }
        
        // Perform initial verification
        Task {
            await verifyCurrentLocation()
        }
    }
    
    func stopPeriodicVerification() {
        verificationTimer?.invalidate()
        verificationTimer = nil
        locationManager.stopUpdatingLocation()
    }
    
    private func verifyCurrentLocation() async {
        guard let appData = appData else {
            return
        }
        
        // Get office locations - prioritize array, fallback to legacy single location
        let officeLocations: [(coordinate: CLLocationCoordinate2D, name: String, radius: Double)]
        
        if !appData.settings.officeLocations.isEmpty {
            // Use multi-location array
            officeLocations = appData.settings.officeLocations.compactMap { office in
                guard let coord = office.coordinate else { return nil }
                return (coord, office.name, office.detectionRadius)
            }
        } else if let legacyLocation = appData.settings.officeLocation {
            // Fallback to legacy single location
            officeLocations = [(legacyLocation, "Office", appData.settings.detectionRadius)]
        } else {
            return
        }
        
        guard !officeLocations.isEmpty else { return }
        
        // Request a fresh location update
        locationManager.requestLocation()
        
        // Wait for location update with timeout
        let location = await waitForLocationUpdate(timeout: 30.0)
        
        guard let currentLocation = location else {
            debugLog("📍", "[LocationVerification] Failed to get current location")
            return
        }
        
        // Find closest office and check if within any geofence
        var closestOffice: (coordinate: CLLocationCoordinate2D, name: String, distance: Double)? = nil
        var isWithinAnyGeofence = false
        
        for office in officeLocations {
            let officeCL = CLLocation(latitude: office.coordinate.latitude, longitude: office.coordinate.longitude)
            let distance = currentLocation.distance(from: officeCL)
            
            if distance <= office.radius {
                isWithinAnyGeofence = true
                if closestOffice == nil || distance < closestOffice!.distance {
                    closestOffice = (office.coordinate, office.name, distance)
                }
            } else if closestOffice == nil || distance < closestOffice!.distance {
                closestOffice = (office.coordinate, office.name, distance)
            }
        }
        
        if let closest = closestOffice {
            debugLog("📍", "[LocationVerification] Distance to \(closest.name): \(Int(closest.distance))m")
        }
        
        // Only correct if there's a significant status mismatch
        // Allow a small delay buffer to avoid conflicts with geofencing
        if isWithinAnyGeofence && !appData.isCurrentlyInOffice {
            // Add a small delay to allow geofencing to handle the entry first
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check again after delay in case geofencing already handled it
            if !appData.isCurrentlyInOffice, let closest = closestOffice {
                debugLog("📍", "[LocationVerification] User is in \(closest.name) but status shows away - correcting after delay")
                await handleManualEntry(at: closest.coordinate, officeName: closest.name)
            } else {
                debugLog("📍", "[LocationVerification] Geofencing already handled entry, no correction needed")
            }
        } else if !isWithinAnyGeofence && appData.isCurrentlyInOffice {
            debugLog("📍", "[LocationVerification] User is away from all offices but status shows in office - correcting")
            await handleManualExit()
        } else {
            debugLog("📍", "[LocationVerification] Status is correct, no action needed")
        }
    }
    
    private func waitForLocationUpdate(timeout: TimeInterval) async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            var hasReturned = false
            
            // Capture the current location value to avoid main actor isolation issues
            let currentLocation = self.lastKnownLocation
            
            // Set up timeout
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                if !hasReturned {
                    hasReturned = true
                    continuation.resume(returning: currentLocation)
                }
            }
            
            // Store continuation for location delegate
            self.locationContinuation = { location in
                timeoutTimer.invalidate()
                if !hasReturned {
                    hasReturned = true
                    continuation.resume(returning: location)
                }
            }
        }
    }
    
    private var locationContinuation: ((CLLocation?) -> Void)?
    
    private func handleManualEntry(at location: CLLocationCoordinate2D, officeName: String) async {
        guard let appData = appData else { return }
        
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        // Check if today is a tracking day
        guard appData.settings.trackingDays.contains(weekday) else {
            return
        }
        
        // Check if within reasonable office hours (more flexible than geofence)
        let officeStartHour = calendar.component(.hour, from: appData.settings.officeHours.startTime)
        let officeEndHour = calendar.component(.hour, from: appData.settings.officeHours.endTime)
        let flexibleStartHour = max(0, officeStartHour - 2)
        let flexibleEndHour = min(23, officeEndHour + 2)
        
        guard hour >= flexibleStartHour && hour <= flexibleEndHour else {
            return
        }
        
        // Start visit if not already in progress
        if !appData.isCurrentlyInOffice {
            appData.startVisit(at: location)
            debugLog("📍", "[LocationVerification] Manually started office visit at \(officeName)")
        }
    }
    
    private func handleManualExit() async {
        guard let appData = appData else { return }
        
        if appData.isCurrentlyInOffice {
            appData.endVisit()
            debugLog("📍", "[LocationVerification] Manually ended office visit")
        }
    }
}

extension LocationVerificationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.lastKnownLocation = location
            self.locationContinuation?(location)
            self.locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            debugLog("📍", "[LocationVerification] Location update failed: \(error.localizedDescription)")
            self.locationContinuation?(self.lastKnownLocation)
            self.locationContinuation = nil
        }
    }
}