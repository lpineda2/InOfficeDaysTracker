//
//  OfficeLocationsView.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import SwiftUI
import CoreLocation

struct OfficeLocationsView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddLocation = false
    @State private var editingLocation: OfficeLocation?
    
    var body: some View {
        Form {
            infoSection
            locationsListSection
            addLocationSection
        }
        .navigationTitle("Office Locations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddLocation) {
            EditLocationView(appData: appData, location: nil)
        }
        .sheet(item: $editingLocation) { location in
            EditLocationView(appData: appData, location: location)
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            Text("Visits to any configured location count toward your monthly goal.")
                .font(.subheadline)
                .foregroundColor(DesignTokens.textSecondary)
        }
    }
    
    // MARK: - Locations List Section
    
    private var locationsListSection: some View {
        Section {
            if appData.settings.officeLocations.isEmpty {
                Text("No office locations configured")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(appData.settings.officeLocations) { location in
                    LocationRow(location: location) {
                        editingLocation = location
                    }
                }
                .onDelete(perform: deleteLocations)
            }
        } header: {
            Text("Locations")
        }
    }
    
    // MARK: - Add Location Section
    
    private var addLocationSection: some View {
        Section {
            Button {
                showingAddLocation = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(canAddLocation ? DesignTokens.cyanAccent : DesignTokens.textSecondary)
                    Text("Add Location")
                        .foregroundColor(canAddLocation ? DesignTokens.textPrimary : DesignTokens.textSecondary)
                }
            }
            .disabled(!canAddLocation)
        } footer: {
            Text("Maximum \(OfficeLocation.maxLocations) locations allowed.")
        }
    }
    
    // MARK: - Helpers
    
    private var canAddLocation: Bool {
        appData.settings.officeLocations.count < OfficeLocation.maxLocations
    }
    
    private func deleteLocations(at offsets: IndexSet) {
        appData.settings.officeLocations.remove(atOffsets: offsets)
        
        // Ensure at least one location is primary if locations remain
        if !appData.settings.officeLocations.isEmpty &&
           !appData.settings.officeLocations.contains(where: { $0.isPrimary }) {
            appData.settings.officeLocations[0].isPrimary = true
        }
        
        appData.updateSettings(appData.settings)
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: OfficeLocation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "building.2")
                    .foregroundColor(DesignTokens.cyanAccent)
                    .font(.title2)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(location.name)
                            .font(.headline)
                            .foregroundColor(DesignTokens.textPrimary)
                        
                        if location.isPrimary {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    Text(location.address.isEmpty ? "No address" : location.address)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.textSecondary)
                        .lineLimit(2)
                    
                    Text("Radius: \(location.radiusFormatted)")
                        .font(.caption)
                        .foregroundColor(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(DesignTokens.textSecondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Location View

struct EditLocationView: View {
    @ObservedObject var appData: AppData
    let location: OfficeLocation?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = "Office"
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var detectionRadius: Double = 1609.34  // Default 1 mile in meters
    @State private var isPrimary: Bool = false
    
    @State private var showingDeleteAlert = false
    
    private var isEditing: Bool { location != nil }
    
    private var usesImperial: Bool {
        Locale.current.measurementSystem == .us
    }
    
    init(appData: AppData, location: OfficeLocation?) {
        self.appData = appData
        self.location = location
        
        if let loc = location {
            _name = State(initialValue: loc.name)
            _address = State(initialValue: loc.address)
            _coordinate = State(initialValue: loc.coordinate)
            _detectionRadius = State(initialValue: loc.detectionRadius)
            _isPrimary = State(initialValue: loc.isPrimary)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                nameSection
                addressSection
                radiusSection
                primarySection
                
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "Edit Location" : "Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Delete Location", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteLocation()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this office location?")
            }
        }
    }
    
    // MARK: - Sections
    
    private var nameSection: some View {
        Section {
            TextField("Location Name", text: $name)
        } header: {
            Text("Name")
        } footer: {
            Text("A friendly name for this office (e.g., \"Main Office\", \"Branch Office\")")
        }
    }
    
    private var addressSection: some View {
        Section {
            AddressAutocompleteField(
                selectedAddress: $address,
                selectedCoordinate: $coordinate,
                placeholder: "Enter office address",
                useCurrentLocationAction: nil
            )
        } header: {
            Text("Address")
        }
    }
    
    private var radiusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Detection Radius")
                        .font(.body)
                    Spacer()
                    Text(radiusDisplayText)
                        .font(.body)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Slider stores meters, but endpoints are region-specific
                // Imperial: 0.25 to 1 mile (402.335m to 1609.34m), step 0.25 mile
                // Metric: 0.25 to 1 km (250m to 1000m), step 0.25 km
                Slider(value: $detectionRadius,
                       in: usesImperial ? 402.335...1609.34 : 250...1000,
                       step: usesImperial ? 402.335 : 250)
                    .tint(.blue)
                
                HStack {
                    Text(usesImperial ? "0.25 mi" : "0.25 km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(usesImperial ? "1 mi" : "1 km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Detection Radius")
        } footer: {
            Text("How close you need to be for automatic check-in.")
        }
    }
    
    private var primarySection: some View {
        Section {
            Toggle("Set as primary location", isOn: $isPrimary)
        } footer: {
            Text("Primary location is used for widgets and notifications.")
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Location")
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var radiusDisplayText: String {
        if usesImperial {
            let miles = detectionRadius / 1609.34
            return String(format: "%.2f miles", miles)
        } else {
            let km = detectionRadius / 1000.0
            return String(format: "%.2f km", km)
        }
    }
    
    private var canSave: Bool {
        !name.isEmpty && !address.isEmpty && coordinate != nil
    }
    
    private func saveLocation() {
        var newLocation = OfficeLocation(
            name: name,
            coordinate: coordinate,
            address: address,
            detectionRadius: detectionRadius,
            isPrimary: isPrimary
        )
        
        // If editing, preserve the ID
        if let existingLocation = location {
            newLocation.id = existingLocation.id
        }
        
        // Create a copy of settings to modify
        var newSettings = appData.settings
        
        // If setting as primary, unset other primaries
        if isPrimary {
            for i in newSettings.officeLocations.indices {
                newSettings.officeLocations[i].isPrimary = false
            }
        }
        
        if let existingLocation = location,
           let index = newSettings.officeLocations.firstIndex(where: { $0.id == existingLocation.id }) {
            // Update existing
            newSettings.officeLocations[index] = newLocation
        } else {
            // Add new
            // If this is the first location, make it primary
            if newSettings.officeLocations.isEmpty {
                newLocation.isPrimary = true
            }
            newSettings.officeLocations.append(newLocation)
        }
        
        // Also update legacy single location for backwards compatibility
        if let primary = newSettings.officeLocations.first(where: { $0.isPrimary }) ?? newSettings.officeLocations.first {
            newSettings.officeLocation = primary.coordinate
            newSettings.officeAddress = primary.address
            newSettings.detectionRadius = primary.detectionRadius
        }
        
        appData.updateSettings(newSettings)
        dismiss()
    }
    
    private func deleteLocation() {
        guard let locationToDelete = location else { return }
        
        // Create a copy of settings to modify
        var newSettings = appData.settings
        
        newSettings.officeLocations.removeAll { $0.id == locationToDelete.id }
        
        // Ensure at least one location is primary if locations remain
        if !newSettings.officeLocations.isEmpty &&
           !newSettings.officeLocations.contains(where: { $0.isPrimary }) {
            newSettings.officeLocations[0].isPrimary = true
        }
        
        // Update legacy single location
        if let primary = newSettings.officeLocations.first(where: { $0.isPrimary }) ?? newSettings.officeLocations.first {
            newSettings.officeLocation = primary.coordinate
            newSettings.officeAddress = primary.address
            newSettings.detectionRadius = primary.detectionRadius
        } else {
            newSettings.officeLocation = nil
            newSettings.officeAddress = ""
        }
        
        appData.updateSettings(newSettings)
        dismiss()
    }
}

#Preview {
    NavigationView {
        OfficeLocationsView(appData: AppData())
    }
}
