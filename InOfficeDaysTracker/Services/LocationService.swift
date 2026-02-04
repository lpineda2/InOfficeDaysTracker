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
#if canImport(WidgetKit)
import WidgetKit
#endif

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
    
    // Fallback timer for widget refresh reliability
    private var widgetRefreshTimer: Timer?
    
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
            // For upgrading to "Always" permission, iOS behavior varies:
            // - On first request, the system MAY show a dialog
            // - On subsequent requests, it will NOT show a dialog
            if !hasRequestedAlwaysPermission {
                // Try the system dialog first - iOS will show a prompt
                // if it decides to. We'll check the result after.
                requestAlwaysPermission()
            } else {
                // Already tried the system dialog, guide user to Settings
                locationError = "To enable background tracking, set location access to 'Always' in Settings."
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
        #if DEBUG
        debugLog("🎯", "[LocationService] setupGeofencing called")
        #endif
        guard let appData = appData,
              let officeLocation = appData.settings.officeLocation else {
            debugLog("❌", "[LocationService] Office location not set")
            locationError = "Office location not set"
            return
        }
        
        #if DEBUG
        debugLog("🎯", "[LocationService] Office location: \(officeLocation.latitude), \(officeLocation.longitude)")
        #endif
        
        guard authorizationStatus == .authorizedAlways else {
            debugLog("❌", "[LocationService] Always location permission required, current: \(authorizationStatus)")
            locationError = "Always location permission required for background tracking"
            return
        }
        
        guard isBackgroundLocationSupported else {
            debugLog("❌", "[LocationService] Background location not supported")
            locationError = "Background location monitoring not supported on this device"
            return
        }
        
        debugLog("✅", "[LocationService] All preconditions met, setting up geofencing")
        
        // Perform location services check asynchronously to avoid main thread blocking
        Task {
            let locationEnabled = await checkLocationServicesEnabled()
            await MainActor.run {
                guard locationEnabled else {
                    debugLog("❌", "[LocationService] Location services disabled")
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
        #if DEBUG
        debugLog("🎯", "[LocationService] configureGeofencing called")
        #endif
        
        // Clear existing geofences
        #if DEBUG
        debugLog("🎯", "[LocationService] Clearing \(locationManager.monitoredRegions.count) existing regions")
        #endif
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoring(for: region)
        }
        
        // Validate radius (iOS has limits)
        let radius = min(max(appData.settings.detectionRadius, 1), locationManager.maximumRegionMonitoringDistance)
        #if DEBUG
        debugLog("🎯", "[LocationService] Using radius: \(radius) meters (requested: \(appData.settings.detectionRadius), max: \(locationManager.maximumRegionMonitoringDistance))")
        #endif
        
        // Create office geofence
        let region = CLCircularRegion(
            center: officeLocation,
            radius: radius,
            identifier: "office_location"
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        #if DEBUG
        debugLog("🎯", "[LocationService] Created region: center=(\(officeLocation.latitude), \(officeLocation.longitude)), radius=\(radius)")
        #endif
        
        // Check if we can monitor this region
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            debugLog("❌", "[LocationService] Region monitoring not available")
            locationError = "Region monitoring not available"
            return
        }
        
        debugLog("✅", "[LocationService] Starting monitoring for office region")
        locationManager.startMonitoring(for: region)
        
        // Start periodic verification to handle intermittent status issues
        verificationService.startPeriodicVerification()
        
        // Request the current state of the region to handle cases where 
        // the user is already inside the geofence when it's created
        #if DEBUG
        debugLog("🎯", "[LocationService] Requesting current state for region")
        #endif
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
    
    // MARK: - Widget Refresh Management
    
    /// Trigger immediate widget refresh when office status changes
    /// This ensures widgets update quickly when entering/exiting office
    private func triggerWidgetRefresh(reason: String) {
        #if DEBUG
        debugLog("🔄", "[LocationService] Triggering widget refresh for: \(reason)")
        debugLog("🔍", "[LocationService] Current office status: \(appData?.isCurrentlyInOffice ?? false)")
        #endif
        
        #if canImport(WidgetKit)
        Task {
            await MainActor.run {
                // Force UserDefaults synchronization to ensure data is immediately available
                if let appData = appData {
                    appData.sharedUserDefaults.synchronize()
                    debugLog("🔄", "[LocationService] UserDefaults synchronized before widget refresh")
                }
                
                // Strategy 1: Immediate reload of all widget timelines
                WidgetCenter.shared.reloadAllTimelines()
                
                // Strategy 2: Specifically reload our office tracker widget
                WidgetCenter.shared.reloadTimelines(ofKind: "OfficeTrackerWidget")
                
                debugLog("🔄", "[LocationService] Widget refresh triggered for \(reason)")
                
                // Strategy 3: Multiple delayed refreshes for reliability
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    WidgetCenter.shared.reloadAllTimelines()
                    debugLog("🔄", "[LocationService] First delayed widget refresh completed for \(reason)")
                    
                    // Extra delayed refresh for stubborn cases
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                    WidgetCenter.shared.reloadAllTimelines()
                    debugLog("🔄", "[LocationService] Second delayed widget refresh completed for \(reason)")
                }
                
                // Start fallback timer for persistent refresh attempts
                startFallbackWidgetRefreshTimer(reason: reason)
            }
        }
        #else
        debugLog("⚠️", "[LocationService] WidgetKit not available for refresh")
        #endif
    }
    
    /// Start a fallback timer that periodically refreshes widgets to ensure they eventually update
    /// This handles cases where initial refresh attempts fail due to timing or system issues
    private func startFallbackWidgetRefreshTimer(reason: String) {
        // Cancel any existing timer
        widgetRefreshTimer?.invalidate()
        
        debugLog("⏰", "[LocationService] Starting fallback widget refresh timer for: \(reason)")
        
        // Create timer that fires every 15 seconds for the next 2 minutes
        var attempts = 0
        let maxAttempts = 8 // 8 attempts × 15 seconds = 2 minutes
        
        widgetRefreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] timer in
            attempts += 1
            debugLog("⏰", "[LocationService] Fallback widget refresh attempt \(attempts)/\(maxAttempts)")
            
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            
            if attempts >= maxAttempts {
                debugLog("⏰", "[LocationService] Completed fallback widget refresh attempts")
                timer.invalidate()
                Task { @MainActor in
                    self?.widgetRefreshTimer = nil
                }
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
            #if DEBUG
            debugLog("🎯", "[LocationService] didDetermineState: \(state.rawValue) for region: \(region.identifier)")
            #endif
            // Handle the case where user is already inside the geofence when monitoring starts
            if state == .inside && region.identifier == "office_location" {
                debugLog("✅", "[LocationService] User is already inside office region")
                handleRegionEntry(region)
            } else {
                debugLog("ℹ️", "[LocationService] User is outside office region or unknown state")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            #if DEBUG
            debugLog("🎯", "[LocationService] didEnterRegion: \(region.identifier)")
            #endif
            handleRegionEntry(region)
        }
    }
    
    private func handleRegionEntry(_ region: CLRegion) {
        #if DEBUG
        debugLog("🎯", "[LocationService] handleRegionEntry called for region: \(region.identifier)")
        #endif
        guard let appData = appData,
              region.identifier == "office_location" else {
            debugLog("❌", "[LocationService] Invalid region or no appData")
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        #if DEBUG
        debugLog("🎯", "[LocationService] Current time: weekday=\(weekday), hour=\(hour)")
        debugLog("🎯", "[LocationService] Tracking days: \(appData.settings.trackingDays)")
        #endif

        // Check if today is a tracking day
        guard appData.settings.trackingDays.contains(weekday) else {
            debugLog("❌", "[LocationService] Not a tracking day, ignoring entry")
            return
        }

        // Check if within office hours (with some flexibility)
        let officeStartHour = calendar.component(.hour, from: appData.settings.officeHours.startTime)
        let officeEndHour = calendar.component(.hour, from: appData.settings.officeHours.endTime)

        #if DEBUG
        debugLog("🎯", "[LocationService] Office hours: \(officeStartHour) - \(officeEndHour)")
        #endif

        // Allow 1 hour flexibility before and after office hours
        let flexibleStartHour = max(0, officeStartHour - 1)
        let flexibleEndHour = min(23, officeEndHour + 1)

        #if DEBUG
        debugLog("🎯", "[LocationService] Flexible hours: \(flexibleStartHour) - \(flexibleEndHour)")
        #endif

        guard hour >= flexibleStartHour && hour <= flexibleEndHour else {
            debugLog("❌", "[LocationService] Outside office hours, ignoring entry")
            return
        }

        // Prevent duplicate notifications if already marked as in office
        if appData.isCurrentlyInOffice {
            debugLog("ℹ️", "[LocationService] Already marked as in office")
            return
        }

        debugLog("✅", "[LocationService] Valid office entry detected")

        debugLog("🔍", "[LocationService] Office status before entry: \(appData.isCurrentlyInOffice)")
        
        // Start tracking visit
        if let officeLocation = appData.settings.officeLocation {
            appData.startVisit(at: officeLocation)
        }

        debugLog("🔍", "[LocationService] Office status after startVisit(): \(appData.isCurrentlyInOffice)")
        debugLog("🔍", "[LocationService] Current visit after entry: \(appData.currentVisit?.id.uuidString ?? "none")")
        
        // Force immediate data synchronization
        appData.sharedUserDefaults.synchronize()
        
        // Verify UserDefaults was updated
        let persistedStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
        debugLog("🔍", "[LocationService] Persisted office status in UserDefaults: \(persistedStatus)")

        // Trigger immediate widget refresh for office entry
        triggerWidgetRefresh(reason: "office entry")

        // Send notification
        if appData.settings.notificationsEnabled {
            NotificationService.shared.sendVisitNotification(type: .entry)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard let appData = appData,
                  region.identifier == "office_location" else {
                debugLog("❌", "[LocationService] Invalid region or no appData for exit")
                return
            }
            
            debugLog("🚪", "[LocationService] Office exit detected at \(Date())")
            debugLog("🔍", "[LocationService] Office status before exit: \(appData.isCurrentlyInOffice)")
            
            // End tracking visit
            appData.endVisit()
            
            debugLog("🔍", "[LocationService] Office status after endVisit(): \(appData.isCurrentlyInOffice)")
            debugLog("🔍", "[LocationService] Current visit after exit: \(appData.currentVisit?.id.uuidString ?? "none")")
            
            // Force immediate data synchronization
            appData.sharedUserDefaults.synchronize()
            
            // Verify UserDefaults was updated
            let persistedStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
            debugLog("🔍", "[LocationService] Persisted office status in UserDefaults: \(persistedStatus)")
            
            // Trigger immediate widget refresh for office exit
            triggerWidgetRefresh(reason: "office exit")
            
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
            debugLog("❌", "LocationService Error: \(errorMessage)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            let regionName = region?.identifier ?? "unknown"
            debugLog("❌", "[LocationService] Region monitoring failed for \(regionName): \(error.localizedDescription)")
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
            debugLog("❌", "[LocationService] Region Error: \(errorMessage)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Task { @MainActor in
            debugLog("✅", "[LocationService] Started monitoring region: \(region.identifier)")
            // Clear any previous errors when monitoring starts successfully
            locationError = nil
        }
    }
}