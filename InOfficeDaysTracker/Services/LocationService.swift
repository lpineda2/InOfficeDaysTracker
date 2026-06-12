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
    
    // Exit grace period to prevent false exits from GPS drift
    private var exitGraceTimer: Timer?
    private var pendingExitRegion: CLRegion?
    
    // Track when user exited - public so verification service can check minimum away duration
    private(set) var exitTime: Date?
    
    // Grace period duration (5 minutes default)
    private let exitGracePeriod: TimeInterval = 300 // 5 minutes
    
    // Minimum away duration to confirm user actually left (3 minutes)
    private let minimumAwayDuration: TimeInterval = 180 // 3 minutes
    
    // UserDefaults keys for persisting exit grace period state
    private let pendingExitTimeKey = "PendingExitTime"
    private let pendingExitRegionIdKey = "PendingExitRegionId"
    private let gracePeriodExpiresKey = "GracePeriodExpires"
    
    // iOS region monitoring limit
    private let maxMonitoredRegions = 20
    
    // Continuation for one-shot location requests (used by verification service)
    private var locationRequestContinuation: ((CLLocation?) -> Void)?
    
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
        
        // Restore any pending exit grace period that was interrupted by app termination
        restoreExitGracePeriodIfNeeded()
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
        
        // iOS 14+: Check for precise location authorization
        // Reduced accuracy breaks geofencing completely
        if #available(iOS 14.0, *) {
            if locationManager.accuracyAuthorization == .reducedAccuracy {
                locationError = "Precise Location is required for automatic office tracking. Please enable in Settings."
                debugLog("⚠️", "[LocationService] Precise location is disabled - geofencing will not work")
                return false
            }
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
        guard let appData = appData else {
            debugLog("❌", "[LocationService] AppData not available")
            locationError = "AppData not available"
            return
        }
        
        // Support both new multi-location array and legacy single location
        let locationsToMonitor: [OfficeLocation]
        if !appData.settings.officeLocations.isEmpty {
            // Use new multi-location array
            locationsToMonitor = appData.settings.officeLocations
            debugLog("🎯", "[LocationService] Using \(locationsToMonitor.count) office locations from array")
        } else if let legacyLocation = appData.settings.officeLocation {
            // Fallback to legacy single location for backward compatibility
            let legacyOffice = OfficeLocation(
                name: "Office",
                coordinate: legacyLocation,
                address: appData.settings.officeAddress,
                detectionRadius: appData.settings.detectionRadius,
                isPrimary: true
            )
            locationsToMonitor = [legacyOffice]
            debugLog("🎯", "[LocationService] Using legacy single office location")
        } else {
            debugLog("❌", "[LocationService] No office locations configured")
            locationError = "No office locations configured"
            return
        }
        
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
                
                // Continue with geofencing setup for all locations
                self.configureGeofencing(for: appData, locations: locationsToMonitor)
            }
        }
    }
    
    /// Configure geofencing with the provided parameters (called from main thread)
    private func configureGeofencing(for appData: AppData, locations: [OfficeLocation]) {
        #if DEBUG
        debugLog("🎯", "[LocationService] configureGeofencing called for \(locations.count) locations")
        #endif
        
        // Clear existing geofences
        #if DEBUG
        debugLog("🎯", "[LocationService] Clearing \(locationManager.monitoredRegions.count) existing regions")
        #endif
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoring(for: region)
        }
        
        // Check if we can monitor regions
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            debugLog("❌", "[LocationService] Region monitoring not available")
            locationError = "Region monitoring not available"
            return
        }
        
        // iOS enforces a limit of 20 monitored regions per app
        // Prioritize primary locations and truncate if necessary
        let locationsToMonitor: [OfficeLocation]
        if locations.count > maxMonitoredRegions {
            debugLog("⚠️", "[LocationService] \(locations.count) locations exceed iOS limit of \(maxMonitoredRegions)")
            // Sort by isPrimary (primary first) then take first 20
            locationsToMonitor = Array(locations.sorted { $0.isPrimary && !$1.isPrimary }.prefix(maxMonitoredRegions))
            locationError = "Monitoring \(maxMonitoredRegions) of \(locations.count) office locations (iOS limit)"
            debugLog("⚠️", "[LocationService] Monitoring only first \(maxMonitoredRegions) locations")
        } else {
            locationsToMonitor = locations
        }
        
        // Create geofence for each office location
        var monitoredCount = 0
        for office in locationsToMonitor {
            guard let coordinate = office.coordinate else {
                debugLog("⚠️", "[LocationService] Skipping \(office.name) - no coordinate")
                continue
            }
            
            // Validate radius (iOS has limits)
            let radius = min(max(office.detectionRadius, 1), locationManager.maximumRegionMonitoringDistance)
            
            // Create region with unique identifier based on office ID
            let region = CLCircularRegion(
                center: coordinate,
                radius: radius,
                identifier: office.id.uuidString
            )
            
            region.notifyOnEntry = true
            region.notifyOnExit = true
            
            debugLog("✅", "[LocationService] Monitoring \(office.name) at (\(coordinate.latitude), \(coordinate.longitude)), radius=\(radius)m")
            locationManager.startMonitoring(for: region)
            monitoredCount += 1
            
            // Request the current state of the region to handle cases where 
            // the user is already inside the geofence when it's created
            locationManager.requestState(for: region)
        }
        
        if monitoredCount > 0 {
            debugLog("✅", "[LocationService] Successfully monitoring \(monitoredCount) office location(s)")
            
            // Start periodic verification to handle intermittent status issues
            verificationService.startPeriodicVerification()
        } else {
            debugLog("❌", "[LocationService] No valid office locations to monitor")
            locationError = "No valid office locations configured"
        }
    }
    
    /// Trigger location verification when app enters foreground
    /// Public API for view layer to request immediate verification
    func verifyLocationOnForeground() async {
        guard authorizationStatus == .authorizedAlways else {
            debugLog("⚠️", "[LocationService] Foreground verification skipped - always permission required")
            return
        }
        
        debugLog("🔍", "[LocationService] Foreground verification requested")
        
        // CRITICAL FIX: Check for expired exit grace periods when returning from background
        // The timer gets suspended in background, so we need to manually check on foreground
        checkExpiredGracePeriod()
        
        await verificationService.verifyLocationNow()
    }
    
    /// Check if exit grace period has expired while app was in background
    /// Call this when app returns to foreground to handle suspended timers
    func checkExpiredGracePeriod() {
        guard let appData = appData else { return }
        
        // Check if there's a persisted exit grace period
        guard let persistedExitTime = appData.sharedUserDefaults.object(forKey: pendingExitTimeKey) as? Date,
              let _ = appData.sharedUserDefaults.string(forKey: pendingExitRegionIdKey) else {
            return // No pending exit to check
        }
        
        let elapsed = Date().timeIntervalSince(persistedExitTime)
        
        debugLog("🔄", "[LocationService] Checking persisted exit grace period, elapsed: \(Int(elapsed))s")
        
        if elapsed >= exitGracePeriod {
            // Grace period expired while app was in background - complete the exit
            debugLog("⏰", "[LocationService] Grace period expired in background, ending visit now")
            
            // Cancel any active timer (may be out of sync)
            exitGraceTimer?.invalidate()
            exitGraceTimer = nil
            
            Task { @MainActor in
                // End visit with the original exit time
                await appData.endVisit(at: persistedExitTime)
                
                debugLog("🔍", "[LocationService] Office status after background exit: \(appData.isCurrentlyInOffice)")
                
                // Force immediate data synchronization
                appData.sharedUserDefaults.synchronize()
                
                // CRITICAL: Trigger widget refresh for delayed exit
                self.triggerWidgetRefresh(reason: "delayed exit after background")
                
                // Clear state
                self.pendingExitRegion = nil
                self.exitTime = nil
                self.clearPersistedExitGracePeriod()
            }
        } else {
            debugLog("ℹ️", "[LocationService] Grace period still active (\(Int(exitGracePeriod - elapsed))s remaining)")
        }
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
    
    /// Request a single location update with proper delegate callback handling.
    /// Used by LocationVerificationService to avoid needing its own CLLocationManager.
    /// Returns CLLocation or nil if the request times out.
    func requestSingleLocation(timeout: TimeInterval = 30.0) async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            debugLog("📍", "[LocationService] requestSingleLocation: no authorization")
            return nil
        }
        
        // Temporarily increase accuracy for verification
        let previousAccuracy = locationManager.desiredAccuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        defer { locationManager.desiredAccuracy = previousAccuracy }
        
        return await withCheckedContinuation { continuation in
            var hasReturned = false
            
            // Set up timeout
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, !hasReturned else { return }
                    hasReturned = true
                    self.locationRequestContinuation = nil
                    continuation.resume(returning: self.locationManager.location)
                }
            }
            
            // Set up callback for location update
            self.locationRequestContinuation = { location in
                timeoutTimer.invalidate()
                guard !hasReturned else { return }
                hasReturned = true
                continuation.resume(returning: location)
            }
            
            // Request the location
            locationManager.requestLocation()
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
        Task { @MainActor in
            // Single reload call - WidgetKit has a daily budget (~40-70 reloads).
            // Previous code fired 8+ reloads per event, exhausting the budget quickly.
            WidgetCenter.shared.reloadTimelines(ofKind: "OfficeTrackerWidget")
            debugLog("🔄", "[LocationService] Widget refresh triggered for \(reason)")
        }
        #else
        debugLog("⚠️", "[LocationService] WidgetKit not available for refresh")
        #endif
    }
    
    /// Start a fallback timer that periodically refreshes widgets to ensure they eventually update
    /// This handles cases where initial refresh attempts fail due to timing or system issues
    private func startFallbackWidgetRefreshTimer(reason: String) {
        // No-op: Removed excessive fallback reloads to preserve WidgetKit daily budget.
        // The widget timeline now independently detects expired grace periods.
        widgetRefreshTimer?.invalidate()
        widgetRefreshTimer = nil
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
            
            guard let appData = appData else { return }
            
            switch state {
            case .inside:
                // User is already inside when monitoring starts
                debugLog("✅", "[LocationService] User is already inside office region")
                handleRegionEntry(region)
                
            case .outside:
                // User is outside - end any active visit if one exists
                // BUT: Don't interfere with active exit grace period
                if appData.isCurrentlyInOffice {
                    if exitGraceTimer != nil {
                        debugLog("ℹ️", "[LocationService] User outside but grace period active, not ending visit")
                    } else {
                        debugLog("🔍", "[LocationService] User outside office on app launch, ending stale visit")
                        Task { await appData.endVisit() }
                    }
                } else {
                    debugLog("ℹ️", "[LocationService] User is outside office region")
                }
                
            case .unknown:
                debugLog("ℹ️", "[LocationService] Region state unknown")
                
            @unknown default:
                debugLog("⚠️", "[LocationService] Unexpected region state: \(state.rawValue)")
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
        guard let appData = appData else {
            debugLog("❌", "[LocationService] No appData available")
            return
        }
        
        // Cancel exit grace timer if user re-entered during grace period
        if let pendingRegion = pendingExitRegion, pendingRegion.identifier == region.identifier {
            exitGraceTimer?.invalidate()
            exitGraceTimer = nil
            pendingExitRegion = nil
            
            // Cancel scheduled exit notification
            NotificationService.shared.cancelPendingExitNotification()
            
            if let exitTime = exitTime {
                let awayDuration = Date().timeIntervalSince(exitTime)
                debugLog("✅", "[LocationService] Re-entry detected during grace period (away for \(Int(awayDuration))s), canceling exit")
            }
            
            exitTime = nil
            
            // Clear persisted grace period state
            clearPersistedExitGracePeriod()
            
            // CRITICAL: Revert optimistic calendar exit since user returned
            // The calendar was written with exit info during the exit detection window;
            // now restore it to "currently in office" state
            if let visit = appData.currentVisit {
                Task {
                    await appData.revertOptimisticCalendarExit(visit: visit)
                }
            }
            
            // CRITICAL FIX: Trigger widget refresh to show user is back in office
            // Widget may be showing "away" status from when exit was initiated
            debugLog("🔄", "[LocationService] Triggering widget refresh for cancelled exit")
            triggerWidgetRefresh(reason: "exit cancelled - user returned")
            
            // User re-entered quickly - don't end/restart session
            return
        }
        
        // Find which office location was entered
        let enteredOffice: OfficeLocation?
        if region.identifier == "office_location" {
            // Legacy single location identifier
            if let legacyCoord = appData.settings.officeLocation {
                enteredOffice = OfficeLocation(
                    name: "Office",
                    coordinate: legacyCoord,
                    address: appData.settings.officeAddress,
                    detectionRadius: appData.settings.detectionRadius,
                    isPrimary: true
                )
            } else {
                enteredOffice = nil
            }
        } else {
            // New multi-location: find by UUID
            enteredOffice = appData.settings.officeLocations.first { $0.id.uuidString == region.identifier }
        }
        
        guard let office = enteredOffice, let officeCoordinate = office.coordinate else {
            debugLog("❌", "[LocationService] Could not identify entered office")
            return
        }
        
        debugLog("🎯", "[LocationService] Entered office: \(office.name)")

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
        
        // Start tracking visit at the entered office location
        appData.startVisit(at: officeCoordinate)

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
            guard let appData = appData else {
                debugLog("❌", "[LocationService] No appData for exit")
                return
            }
            
            // Find which office location was exited
            let exitedOffice: OfficeLocation?
            if region.identifier == "office_location" {
                // Legacy identifier
                if let legacyCoord = appData.settings.officeLocation {
                    exitedOffice = OfficeLocation(
                        name: "Office",
                        coordinate: legacyCoord,
                        address: appData.settings.officeAddress,
                        detectionRadius: appData.settings.detectionRadius,
                        isPrimary: true
                    )
                } else {
                    exitedOffice = nil
                }
            } else {
                // New multi-location: find by UUID
                exitedOffice = appData.settings.officeLocations.first { $0.id.uuidString == region.identifier }
            }
            
            guard let office = exitedOffice, let officeCoordinate = office.coordinate else {
                debugLog("❌", "[LocationService] Could not identify exited office")
                return
            }
            
            debugLog("🚪", "[LocationService] Detected exit event from: \(office.name) at \(Date())")
            
            // CRITICAL FIX: Verify the user is actually outside the detection radius
            // iOS region monitoring can be inaccurate and trigger false exit events
            debugLog("🔍", "[LocationService] Verifying actual location before processing exit...")
            
            // CRASH FIX: Check authorization before calling requestLocation()
            // requestLocation() will crash if called without proper authorization or setup
            var currentLocation = locationManager.location
            
            // Only request a fresh location if we have authorization and don't have a recent location
            let authStatus = locationManager.authorizationStatus
            if (authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse) {
                // Check if we have a recent location (within last 5 minutes)
                let locationAge = currentLocation?.timestamp.timeIntervalSinceNow ?? -.infinity
                let needsFreshLocation = abs(locationAge) > 300 // Older than 5 minutes
                
                if needsFreshLocation {
                    debugLog("🔍", "[LocationService] Requesting fresh location for exit verification...")
                    locationManager.requestLocation()
                    
                    // Wait briefly for location update
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    // Update with fresh location if we got one
                    currentLocation = locationManager.location
                } else {
                    debugLog("📍", "[LocationService] Using cached location (age: \(Int(abs(locationAge)))s)")
                }
            } else {
                debugLog("⚠️", "[LocationService] Location authorization not granted (status: \(authStatus.rawValue)), using cached location")
            }
            
            guard let currentLocation = currentLocation else {
                debugLog("⚠️", "[LocationService] Could not get current location for exit verification, proceeding with exit")
                // If we can't verify, proceed with exit to avoid getting stuck in office state
                await processConfirmedExit(office: office, region: region, appData: appData)
                return
            }
            
            // Calculate actual distance from office
            let officeCLLocation = CLLocation(latitude: officeCoordinate.latitude, longitude: officeCoordinate.longitude)
            let distanceFromOffice = currentLocation.distance(from: officeCLLocation)
            
            debugLog("📍", "[LocationService] Current location: (\(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude))")
            debugLog("📍", "[LocationService] Distance from \(office.name): \(Int(distanceFromOffice))m (radius: \(Int(office.detectionRadius))m)")
            debugLog("📍", "[LocationService] Currently marked as in office: \(appData.isCurrentlyInOffice)")
            
            // CRITICAL: Only process exits if user was actually marked as being in the office
            // This prevents processing stale exit events when user was never in the geofence
            guard appData.isCurrentlyInOffice else {
                debugLog("🚫", "[LocationService] Exit rejected - user was not marked as in office")
                debugLog("ℹ️", "[LocationService] This was likely a stale or duplicate exit event")
                NotificationService.shared.cancelPendingExitNotification()
                return
            }
            
            // Only process exit if user is actually outside the detection radius
            // Add a small buffer (10m) to account for GPS accuracy
            let bufferMargin = 10.0
            if distanceFromOffice > (office.detectionRadius + bufferMargin) {
                // Additional check: If user is very far from office (>2x radius), the exit detection
                // may be significantly delayed. Warn but still process to avoid stuck state.
                if distanceFromOffice > (office.detectionRadius * 2) {
                    debugLog("⚠️", "[LocationService] User is \(Int(distanceFromOffice))m away (>2x radius: \(Int(office.detectionRadius * 2))m)")
                    debugLog("⚠️", "[LocationService] Exit detection may be delayed - actual exit time may be earlier")
                }
                
                debugLog("✅", "[LocationService] Exit confirmed - user is outside detection radius")
                await processConfirmedExit(office: office, region: region, appData: appData)
            } else {
                debugLog("🚫", "[LocationService] Exit rejected - user is still within \(Int(distanceFromOffice))m of office (radius: \(Int(office.detectionRadius))m)")
                debugLog("ℹ️", "[LocationService] This was likely a false exit event from GPS drift or iOS region monitoring inaccuracy")
                
                // Cancel any pending exit notification since this was a false alarm
                NotificationService.shared.cancelPendingExitNotification()
            }
        }
    }
    
    /// Process a confirmed exit after location verification
    private func processConfirmedExit(office: OfficeLocation, region: CLRegion, appData: AppData) async {
        debugLog("🔍", "[LocationService] Starting exit grace period (\(exitGracePeriod)s)")
        
        // Cancel any existing grace timer
        exitGraceTimer?.invalidate()
        
        // Store the region and exit time
        pendingExitRegion = region
        exitTime = Date()
        
        // Persist grace period state to survive app termination
        persistExitGracePeriod()
        
        // CRITICAL: Write calendar event with exit time NOW during the geofence background window.
        // iOS only gives ~10s of background execution — the 5-min grace timer won't fire if suspended.
        // If user re-enters (false exit), handleVisitStart will revert the calendar on re-entry.
        await appData.writeOptimisticCalendarExit(at: exitTime!)
        
        // CRITICAL: Trigger immediate widget refresh when exit is detected
        // iOS briefly wakes the app in background for geofence events
        // This ensures widget gets a chance to update its timeline before app suspends
        debugLog("🔄", "[LocationService] Triggering immediate widget refresh for exit detection")
        triggerWidgetRefresh(reason: "exit detected - grace period starting")
        
        // Schedule exit notification immediately using iOS notification system
        // This ensures notification fires even if app is suspended
        if appData.settings.notificationsEnabled {
            NotificationService.shared.scheduleExitNotification(afterDelay: exitGracePeriod)
        }
        
        // Start grace period timer for ending the visit
        // Timer runs in foreground; notification fires independently via iOS
        exitGraceTimer = Timer.scheduledTimer(withTimeInterval: exitGracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let appData = self.appData else { return }
                
                // Grace period expired - confirm exit
                debugLog("⏰", "[LocationService] Grace period expired, confirming exit from \(office.name)")
                debugLog("🔍", "[LocationService] Office status before exit: \(appData.isCurrentlyInOffice)")
                
                // End tracking visit with stored exit time for accuracy
                await appData.endVisit(at: self.exitTime)
                
                debugLog("🔍", "[LocationService] Office status after endVisit(): \(appData.isCurrentlyInOffice)")
                debugLog("🔍", "[LocationService] Current visit after exit: \(appData.currentVisit?.id.uuidString ?? "none")")
                
                // Force immediate data synchronization
                appData.sharedUserDefaults.synchronize()
                
                // Verify UserDefaults was updated
                let persistedStatus = appData.sharedUserDefaults.bool(forKey: "IsCurrentlyInOffice")
                debugLog("🔍", "[LocationService] Persisted office status in UserDefaults: \(persistedStatus)")
                
                // Trigger immediate widget refresh for office exit
                self.triggerWidgetRefresh(reason: "office exit after grace period")
                
                // Clear pending exit
                self.pendingExitRegion = nil
                self.exitTime = nil
                self.clearPersistedExitGracePeriod()
            }
        }
    }
    
    // MARK: - Exit Grace Period Persistence
    
    /// Persist exit grace period state to survive app termination
    /// Critical fix: Prevents sessions from remaining open indefinitely if app is killed during grace period
    private func persistExitGracePeriod() {
        guard let appData = appData,
              let exitTime = exitTime,
              let region = pendingExitRegion else { return }
        
        let graceExpires = exitTime.addingTimeInterval(exitGracePeriod)
        
        appData.sharedUserDefaults.set(exitTime, forKey: pendingExitTimeKey)
        appData.sharedUserDefaults.set(region.identifier, forKey: pendingExitRegionIdKey)
        appData.sharedUserDefaults.set(graceExpires, forKey: gracePeriodExpiresKey)
        appData.sharedUserDefaults.synchronize()
        
        debugLog("💾", "[LocationService] Persisted exit grace period for region: \(region.identifier), expires: \(graceExpires)")
    }
    
    /// Restore exit grace period that was interrupted by app termination
    /// Called when app launches and AppData is connected
    private func restoreExitGracePeriodIfNeeded() {
        guard let appData = appData else { return }
        
        guard let persistedExitTime = appData.sharedUserDefaults.object(forKey: pendingExitTimeKey) as? Date,
              let regionId = appData.sharedUserDefaults.string(forKey: pendingExitRegionIdKey) else {
            return // No pending exit to restore
        }
        
        let elapsed = Date().timeIntervalSince(persistedExitTime)
        
        debugLog("🔄", "[LocationService] Found persisted exit grace period, elapsed: \(Int(elapsed))s")
        
        if elapsed >= exitGracePeriod {
            // Grace period expired while app was terminated - complete the exit
            debugLog("⏰", "[LocationService] Grace period expired during app termination, ending visit")
            Task { await appData.endVisit(at: persistedExitTime) }
            clearPersistedExitGracePeriod()
        } else {
            // Grace period still active - resume the timer with remaining time
            let remainingTime = exitGracePeriod - elapsed
            debugLog("⏰", "[LocationService] Resuming grace period with \(Int(remainingTime))s remaining")
            
            // Find the region by identifier to restore full state
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == regionId }) {
                pendingExitRegion = region
                exitTime = persistedExitTime
                
                // Resume grace timer with remaining time
                exitGraceTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self, let appData = self.appData else { return }
                        
                        debugLog("⏰", "[LocationService] Restored grace period expired, ending visit")
                        await appData.endVisit(at: self.exitTime)
                        
                        // Clear state
                        self.pendingExitRegion = nil
                        self.exitTime = nil
                        self.clearPersistedExitGracePeriod()
                    }
                }
            } else {
                // Region no longer exists, complete the exit
                debugLog("⚠️", "[LocationService] Region no longer monitored, ending visit")
                Task { await appData.endVisit(at: persistedExitTime) }
                clearPersistedExitGracePeriod()
            }
        }
    }
    
    /// Clear persisted exit grace period state
    private func clearPersistedExitGracePeriod() {
        guard let appData = appData else { return }
        
        appData.sharedUserDefaults.removeObject(forKey: pendingExitTimeKey)
        appData.sharedUserDefaults.removeObject(forKey: pendingExitRegionIdKey)
        appData.sharedUserDefaults.removeObject(forKey: gracePeriodExpiresKey)
        appData.sharedUserDefaults.synchronize()
        
        debugLog("🗑️", "[LocationService] Cleared persisted exit grace period")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Resolve any pending location request continuation
            if let continuation = self.locationRequestContinuation {
                self.locationRequestContinuation = nil
                continuation(nil)
            }
            
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
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            if let continuation = self.locationRequestContinuation {
                self.locationRequestContinuation = nil
                continuation(location)
            }
        }
    }
}
