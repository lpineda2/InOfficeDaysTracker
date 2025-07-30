//
//  SetupView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import SwiftUI
import CoreLocation

struct SetupView: View {
    @ObservedObject var appData: AppData
    @ObservedObject var locationService: LocationService
    @ObservedObject var notificationService: NotificationService
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var currentStep = 0
    @State private var officeAddress = ""
    @State private var detectionRadius = 1609.34 // 1 mile
    @State private var trackingDays: Set<Int> = [2, 3, 4, 5, 6] // Monday-Friday
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var monthlyGoal = 12
    @State private var notificationsEnabled = true
    
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let totalSteps = 6

    private var usesImperial: Bool {
        if #available(iOS 16.0, *) {
            return Locale.current.measurementSystem != .metric
        } else {
            return !Locale.current.usesMetricSystem
        }
    }

    private var regionSpecificRadius: String {
        if usesImperial {
            let miles = detectionRadius / 1609.34
            return String(format: "%.2f miles", miles)
        } else {
            let km = detectionRadius / 1000.0
            return String(format: "%.2f km", km)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding()
                
                // Step content
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(0)
                    
                    officeLocationStep
                        .tag(1)
                    
                    trackingDaysStep
                        .tag(2)
                    
                    officeHoursStep
                        .tag(3)
                    
                    goalSettingStep
                        .tag(4)
                    
                    permissionsStep
                        .tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .disabled(isLoading)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("Next") {
                            nextStep()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceed)
                    } else {
                        Button("Complete Setup") {
                            completeSetup()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || !canCompleteSetup)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && currentStep == 5 {
                    // Refresh permissions when returning from Settings
                    locationService.checkAuthorizationStatus()
                    Task {
                        await notificationService.checkAuthorizationStatus()
                    }
                }
            }
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 30) {
            Image(systemName: "building.2")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Welcome to\nIn Office Days Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Track your office visits automatically and reach your monthly goals with smart geofencing technology.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                FeatureRow(icon: "location", title: "Automatic Detection", description: "Uses your location to track office visits")
                FeatureRow(icon: "chart.pie", title: "Goal Tracking", description: "Set and monitor your monthly office goals")
                FeatureRow(icon: "bell", title: "Smart Notifications", description: "Get notified about visits and progress")
                FeatureRow(icon: "lock.shield", title: "Privacy First", description: "All data stays on your device")
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var officeLocationStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Office Location")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your office address so we can set up automatic tracking.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                TextField("Enter office address", text: $officeAddress)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Detection Radius")
                            .font(.headline)
                        Spacer()
                        Text(regionSpecificRadius)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    // Slider always stores meters, but endpoints are region-specific
                    // Step is .25 miles (402.335 meters) or .25 km (250 meters)
                    // Range: 0.25 to 1 mile (402.335m to 1609.34m) or 0.25 to 1 km (250m to 1000m)
                    Slider(value: $detectionRadius,
                           in: usesImperial ? 402.335...1609.34 : 250...1000,
                           step: usesImperial ? 402.335 : 250)
                        .tint(.blue)
                    HStack {
                        Text(usesImperial ? "0.25 mile" : "0.25 km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(usesImperial ? "1 mile" : "1 km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var trackingDaysStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "calendar")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Tracking Days")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose which days you want to track office visits.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 8) {
                ForEach(Array(zip(1...7, ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])), id: \.0) { dayIndex, dayName in
                    DayToggleRow(
                        dayName: dayName,
                        isSelected: trackingDays.contains(dayIndex),
                        onToggle: {
                            if trackingDays.contains(dayIndex) {
                                trackingDays.remove(dayIndex)
                            } else {
                                trackingDays.insert(dayIndex)
                            }
                        }
                    )
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var officeHoursStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "clock")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Office Hours")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Set your typical office hours for more accurate tracking.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Start Time")
                        .font(.headline)
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                
                VStack(spacing: 8) {
                    Text("End Time")
                        .font(.headline)
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var goalSettingStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Monthly Goal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("How many office days do you want to aim for each month?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                Text("\(monthlyGoal) days")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
                
                Slider(value: Binding(
                    get: { Double(monthlyGoal) },
                    set: { monthlyGoal = Int($0) }
                ), in: 1...31, step: 1)
                
                HStack {
                    Text("1 day")
                        .font(.caption)
                    Spacer()
                    Text("31 days")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var permissionsStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Permissions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Grant the necessary permissions to enable automatic office visit tracking.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "location",
                    title: "Location Access",
                    description: locationPermissionDescription,
                    status: locationPermissionStatus,
                    action: {
                        locationService.requestLocationPermission()
                    }
                )
                
                // Show error message if there's a location error
                if let error = locationService.locationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                PermissionRow(
                    icon: "bell",
                    title: "Notifications",
                    description: "Get notified when you arrive at or leave the office (Optional)",
                    status: notificationService.authorizationStatus == .authorized ? .granted : .notGranted,
                    action: {
                        Task {
                            await notificationService.requestPermission()
                        }
                    }
                )
            }
            
            // Add explanation for why "Always" permission is needed
            if locationService.authorizationStatus == .authorizedWhenInUse {
                VStack(spacing: 12) {
                    Text("Background Location Needed")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("To automatically track your office visits when the app is closed, we need 'Always' location access. This allows the app to detect when you enter or leave your office area.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Refresh permission status when view appears
            locationService.checkAuthorizationStatus()
            Task {
                await notificationService.checkAuthorizationStatus()
            }
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !officeAddress.isEmpty
        case 2:
            return !trackingDays.isEmpty
        default:
            return true
        }
    }
    
    private var canCompleteSetup: Bool {
        // Allow completion with "When in Use" permission, but prefer "Always"
        let hasLocationPermission = locationService.authorizationStatus == .authorizedAlways || 
                                   locationService.authorizationStatus == .authorizedWhenInUse
        return hasLocationPermission && !officeAddress.isEmpty
    }
    
    private var locationPermissionStatus: PermissionStatus {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            return .granted
        case .authorizedWhenInUse:
            return .partiallyGranted
        default:
            return .notGranted
        }
    }
    
    private var locationPermissionDescription: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Tap to allow location access for automatic office detection"
        case .denied:
            return "Location access denied. Please enable in Settings > Privacy & Security > Location Services"
        case .restricted:
            return "Location access is restricted on this device"
        case .authorizedWhenInUse:
            return "✓ Basic access granted. Tap for background tracking (Recommended)"
        case .authorizedAlways:
            return "✓ Full location access enabled for automatic tracking"
        @unknown default:
            return "Required for automatic office detection"
        }
    }
    
    private func nextStep() {
        withAnimation {
            currentStep += 1
        }
    }
    
    private func completeSetup() {
        isLoading = true
        
        Task {
            do {
                // Geocode the office address
                let coordinate = try await locationService.geocodeAddress(officeAddress)
                
                // Update settings
                var newSettings = appData.settings
                newSettings.officeLocation = coordinate
                newSettings.officeAddress = officeAddress
                newSettings.detectionRadius = detectionRadius
                newSettings.trackingDays = Array(trackingDays)
                newSettings.officeHours.startTime = startTime
                newSettings.officeHours.endTime = endTime
                newSettings.monthlyGoal = monthlyGoal
                newSettings.notificationsEnabled = notificationsEnabled
                
                await MainActor.run {
                    appData.updateSettings(newSettings)
                    appData.completeSetup()
                    locationService.setupGeofencing()
                    
                    if notificationsEnabled {
                        notificationService.scheduleWeeklyGoalReminder()
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Could not find the office location. Please check the address and try again."
                    showingError = true
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct DayToggleRow: View {
    let dayName: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(dayName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    
    @EnvironmentObject var locationService: LocationService
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusView
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            
            if status == .notGranted {
                Button(buttonText) {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var buttonText: String {
        if icon == "location" {
            switch locationService.authorizationStatus {
            case .notDetermined:
                return "Grant Permission"
            case .denied, .restricted:
                return "Open Settings"
            case .authorizedWhenInUse:
                return "Enable Always Access"
            case .authorizedAlways:
                return "Permission Granted"
            @unknown default:
                return "Grant Permission"
            }
        } else {
            return "Grant Permission"
        }
    }
    
    private var statusView: some View {
        Group {
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            case .partiallyGranted:
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            case .notGranted:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
    }
}

enum PermissionStatus {
    case granted
    case partiallyGranted
    case notGranted
}

#Preview {
    SetupView(
        appData: AppData(),
        locationService: LocationService(),
        notificationService: NotificationService.shared
    )
}
