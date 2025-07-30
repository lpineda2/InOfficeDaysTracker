//
//  LocationService.swift (Updated Version)
//  InOfficeDaysTracker
//
//  Updated to integrate LocationVerificationService for fixing intermittent status issues
//

import Foundation
import CoreLocation
import UserNotifications
import UIKit

@MainActor
class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var locationError: String?
    
    weak var appData: AppData?
    
    // Add verification service to handle intermittent status issues
    private let verificationService = LocationVerificationService()
    
    // Track if we've already requested "Always" permission to avoid repeated requests
    private var hasRequestedAlwaysPermission = false
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        
        // Configure location manager for optimal geofencing performance
        // Use significant location changes for better battery life when monitoring regions
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // Pause location updates when not needed to save battery
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // Set activity type to help iOS optimize location tracking
        locationManager.activityType = .other
        
        // Check if background location updates are supported before enabling
        if isBackgroundLocationSupported {
            locationManager.allowsBackgroundLocationUpdates = false // Will be enabled only when "Always" permission is granted
        }
        
        authorizationStatus = locationManager.authorizationStatus
        updateLocationEnabled()
    }
    
    func setAppData(_ appData: AppData) {
        self.appData = appData
        // Connect verification service to handle intermittent status issues
        verificationService.setServices(appData: appData, locationService: self)
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        updateLocationEnabled()
        locationError = nil
    }
    
    /// Request location permission following Apple's best practices
    /// Start with "When in Use" and only upgrade to "Always" when user has granted the first level
    func requestLocationPermission() {
        locationError = nil
        
        switch authorizationStatus {
        case .notDetermined:
            // Always start with "When in Use" permission per Apple guidelines
            // Use background task to avoid blocking main thread
            Task.detached { [weak self] in
                await self?.performWhenInUseRequest()
            }
            
        case .denied:
            locationError = "Location access is required for automatic office tracking. Please enable in Settings."
            openAppSettings()
            
        case .restricted:
            locationError = "Location services are restricted on this device."
            
        case .authorizedWhenInUse:
            // Only request "Always" permission if we haven't already asked
            // This prevents repeated prompts and follows Apple's recommendation
            if !hasRequestedAlwaysPermission {
                requestAlwaysPermission()
            } else {
                // If user has already been asked and chose "When in Use", 
                // guide them to Settings for manual upgrade
                openAppSettings()
            }
            
        case .authorizedAlways:
            // Already have the permission we need
            break
            
        @unknown default:
            locationError = "Unknown location authorization status."
        }
    }
    
    /// Request "Always" permission after user has granted "When in Use"
    /// This follows Apple's recommended progressive permission pattern
    /// Only called once per app lifecycle to avoid repeated prompts
    private func requestAlwaysPermission() {
        guard authorizationStatus == .authorizedWhenInUse else {
            return
        }
        
        // Check if background location updates are supported
        guard isBackgroundLocationSupported else {
            locationError = "Background location is not supported on this device"
            return
        }
        
        hasRequestedAlwaysPermission = true
        
        // Use background task to avoid blocking main thread and check location services
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Check if location services are enabled globally (non-blocking)
            let locationEnabled = await self.checkLocationServicesEnabled()
            guard locationEnabled else {
                await MainActor.run {
                    self.locationError = "Location services are disabled on this device"
                }
                return
            }
            
            await self.performAlwaysRequest()
        }
    }
    
    /// Perform "When in Use" permission request off main thread
    @MainActor
    private func performWhenInUseRequest() async {
        // Request permission on background queue to avoid UI blocking
        await withCheckedContinuation { continuation in
            Task.detached { [weak self] in
                await self?.locationManager.requestWhenInUseAuthorization()
                // Give time for system to process the request
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                continuation.resume()
            }
        }
    }
    
    /// Perform "Always" permission request off main thread
    @MainActor
    private func performAlwaysRequest() async {
        // Request permission on background queue to avoid UI blocking
        await withCheckedContinuation { continuation in
            Task.detached { [weak self] in
                await self?.locationManager.requestAlwaysAuthorization()
                // Give time for system to process the request
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                continuation.resume()
            }
        }
    }
    
    /// Check if device supports background location and region monitoring (non-blocking)
    var isBackgroundLocationSupported: Bool {
        // Check for region monitoring support and that location services aren't restricted
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return false
        }
        
        // Check that we're not in a restricted state
        guard authorizationStatus != .restricted else {
            return false
        }
        
        return true
    }
    
    /// Async check if location services are enabled globally (avoids main thread blocking)
    private func checkLocationServicesEnabled() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task.detached {
                let enabled = CLLocationManager.locationServicesEnabled()
                continuation.resume(returning: enabled)
            }
        }
    }
    
    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func updateLocationEnabled() {
        isLocationEnabled = authorizationStatus == .authorizedAlways
    }
    
    func setupGeofencing() {
        guard let appData = appData,
              let officeLocation = appData.settings.officeLocation else {
            locationError = "Office location not set"
            return
        }
        
        guard authorizationStatus == .authorizedAlways else {
            locationError = "Always location permission required for background tracking"
            return
        }
        
        guard isBackgroundLocationSupported else {
            locationError = "Background location monitoring not supported on this device"
            return
        }
        
        // Perform location services check asynchronously to avoid main thread blocking
        Task {
            let locationEnabled = await checkLocationServicesEnabled()
            await MainActor.run {
                guard locationEnabled else {
                    self.locationError = "Location services are disabled on this device"
                    return
                }
                
                // Clear any existing location error
                self.locationError = nil
                
                // Continue with geofencing setup
                self.configureGeofencing(for: appData, at: officeLocation)
            }
        }
    }
    
    /// Configure geofencing with the provided parameters (called from main thread)
    private func configureGeofencing(for appData: AppData, at officeLocation: CLLocationCoordinate2D) {
        
        // Clear existing geofences
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoring(for: region)
        }
        
        // Validate radius (iOS has limits)
        let radius = min(max(appData.settings.detectionRadius, 1), locationManager.maximumRegionMonitoringDistance)
        
        // Create office geofence
        let region = CLCircularRegion(
            center: officeLocation,
            radius: radius,
            identifier: "office_location"
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        // Check if we can monitor this region
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            locationError = "Region monitoring not available"
            return
        }
        
        locationManager.startMonitoring(for: region)
        
        // Start periodic verification to handle intermittent status issues
        verificationService.startPeriodicVerification()
        
        // Request the current state of the region to handle cases where 
        // the user is already inside the geofence when it's created
        locationManager.requestState(for: region)
    }
    
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    continuation.resume(throwing: NSError(domain: "LocationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find location"]))
                    return
                }
                
                continuation.resume(returning: location.coordinate)
            }
        }
    }
    
    func getCurrentLocation() async throws -> CLLocationCoordinate2D? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw NSError(domain: "LocationService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Location permission not granted"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Request a single location update
                locationManager.requestLocation()
                
                // Wait for location or timeout
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                if let location = locationManager.location {
                    continuation.resume(returning: location.coordinate)
                } else {
                    continuation.resume(throwing: NSError(domain: "LocationService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to get current location"]))
                }
            }
        }
    }
    
    func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: NSError(domain: "LocationService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not reverse geocode location"]))
                    return
                }
                
                let address = [
                    placemark.name,
                    placemark.thoroughfare,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode
                ].compactMap { $0 }.joined(separator: ", ")
                
                continuation.resume(returning: address)
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            updateLocationEnabled()
            locationError = nil
            
            switch status {
            case .authorizedAlways:
                // Enable background location updates only when we have "Always" permission
                if isBackgroundLocationSupported {
                    locationManager.allowsBackgroundLocationUpdates = true
                }
                setupGeofencing()
                
            case .authorizedWhenInUse:
                // User granted "When in Use" - this is good progress
                // Disable background updates to respect the permission level
                locationManager.allowsBackgroundLocationUpdates = false
                
            case .denied, .restricted:
                locationError = status == .denied ? "Location access denied. Enable in Settings for automatic tracking." : "Location access is restricted on this device."
                locationManager.allowsBackgroundLocationUpdates = false
                // Stop verification service when permission is lost
                verificationService.stopPeriodicVerification()
                
            case .notDetermined:
                // Still waiting for user decision
                locationManager.allowsBackgroundLocationUpdates = false
                
            @unknown default:
                locationError = "Unknown location authorization status."
                locationManager.allowsBackgroundLocationUpdates = false
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        Task { @MainActor in
            // Handle the case where user is already inside the geofence when monitoring starts
            if state == .inside && region.identifier == "office_location" {
                handleRegionEntry(region)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            handleRegionEntry(region)
        }
    }
    
    private func handleRegionEntry(_ region: CLRegion) {
        guard let appData = appData,
              region.identifier == "office_location" else {
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        // Check if today is a tracking day
        guard appData.settings.trackingDays.contains(weekday) else {
            print("[LocationService] Not a tracking day, ignoring entry")
            return
        }

        // Check if within office hours (with some flexibility)
        let officeStartHour = calendar.component(.hour, from: appData.settings.officeHours.startTime)
        let officeEndHour = calendar.component(.hour, from: appData.settings.officeHours.endTime)

        // Allow 1 hour flexibility before and after office hours
        let flexibleStartHour = max(0, officeStartHour - 1)
        let flexibleEndHour = min(23, officeEndHour + 1)

        guard hour >= flexibleStartHour && hour <= flexibleEndHour else {
            print("[LocationService] Outside office hours, ignoring entry")
            return
        }

        // Prevent duplicate notifications if already marked as in office
        if appData.isCurrentlyInOffice {
            print("[LocationService] Already marked as in office")
            return
        }

        print("[LocationService] Valid office entry detected")

        // Start tracking visit
        if let officeLocation = appData.settings.officeLocation {
            appData.startVisit(at: officeLocation)
        }

        // Send notification
        if appData.settings.notificationsEnabled {
            NotificationService.shared.sendVisitNotification(type: .entry)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard let appData = appData,
                  region.identifier == "office_location" else {
                return
            }
            
            print("[LocationService] Office exit detected")
            
            // End tracking visit
            appData.endVisit()
            
            // Send notification
            if appData.settings.notificationsEnabled {
                NotificationService.shared.sendVisitNotification(type: .exit)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            var errorMessage = "Location service error: \(error.localizedDescription)"
            
            // Provide more specific error messages for common issues
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    errorMessage = "Location access denied. Please enable in Settings."
                case .locationUnknown:
                    errorMessage = "Unable to determine location. Please try again."
                case .network:
                    errorMessage = "Network error occurred while getting location."
                case .headingFailure:
                    errorMessage = "Heading information unavailable."
                case .regionMonitoringDenied:
                    errorMessage = "Region monitoring denied. Please enable location services."
                case .regionMonitoringFailure:
                    errorMessage = "Region monitoring failed. Please try again."
                case .regionMonitoringSetupDelayed:
                    errorMessage = "Region monitoring setup delayed. Please wait."
                case .regionMonitoringResponseDelayed:
                    errorMessage = "Region monitoring response delayed."
                default:
                    errorMessage = "Location error: \(error.localizedDescription)"
                }
            }
            
            locationError = errorMessage
            print("LocationService Error: \(errorMessage)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            let regionName = region?.identifier ?? "unknown"
            var errorMessage = "Region monitoring failed for \(regionName): \(error.localizedDescription)"
            
            // Provide more specific error messages for region monitoring issues
            if let clError = error as? CLError {
                switch clError.code {
                case .regionMonitoringDenied:
                    errorMessage = "Region monitoring denied. Please enable location services in Settings."
                case .regionMonitoringFailure:
                    errorMessage = "Region monitoring failed. Please check your location settings."
                case .regionMonitoringSetupDelayed:
                    errorMessage = "Region monitoring setup delayed. Please wait and try again."
                case .regionMonitoringResponseDelayed:
                    errorMessage = "Region monitoring response delayed."
                default:
                    errorMessage = "Region monitoring error for \(regionName): \(error.localizedDescription)"
                }
            }
            
            locationError = errorMessage
            print("LocationService Region Error: \(errorMessage)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Task { @MainActor in
            print("Started monitoring region: \(region.identifier)")
            // Clear any previous errors when monitoring starts successfully
            locationError = nil
        }
    }
}