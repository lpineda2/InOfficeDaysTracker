//
//  AddressAutocompleteService.swift
//  InOfficeDaysTracker
//
//  Address autocomplete functionality using MKLocalSearchCompleter
//

import Foundation
import MapKit
import Combine

@MainActor
class AddressAutocompleteService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let completer = MKLocalSearchCompleter()
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupCompleter()
    }
    
    deinit {
        searchTask?.cancel()
    }
    
    // MARK: - Setup
    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = .address
        completer.pointOfInterestFilter = .excludingAll
        
        // Set region for better results (can be customized based on user location)
        if let userLocation = getCurrentUserLocation() {
            let region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000, // 50km radius
                longitudinalMeters: 50000
            )
            completer.region = region
        }
    }
    
    // MARK: - Public Methods
    func searchForLocations(matching query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        // Clear error message
        errorMessage = nil
        
        // Handle empty query
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.count >= 2 else {
            suggestions = []
            isLoading = false
            return
        }
        
        // Start loading
        isLoading = true
        
        // Debounce search with 300ms delay
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            await performSearch(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    func clearSuggestions() {
        suggestions = []
        isLoading = false
        errorMessage = nil
        searchTask?.cancel()
    }
    
    func selectSuggestion(_ completion: MKLocalSearchCompletion) async -> (address: String, coordinate: CLLocationCoordinate2D)? {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            
            if let mapItem = response.mapItems.first {
                let coordinate = mapItem.placemark.coordinate
                let address = formatAddress(from: mapItem.placemark)
                
                await MainActor.run {
                    self.clearSuggestions()
                }
                
                return (address: address, coordinate: coordinate)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Unable to find location details"
            }
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    private func performSearch(query: String) async {
        await MainActor.run {
            self.completer.queryFragment = query
        }
        
        // The results will be delivered via delegate methods
        // Set a timeout for the search
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds timeout
        
        await MainActor.run {
            if self.isLoading {
                self.isLoading = false
                if self.suggestions.isEmpty {
                    self.errorMessage = "No address suggestions found"
                }
            }
        }
    }
    
    private func getCurrentUserLocation() -> CLLocationCoordinate2D? {
        // This could be enhanced to get actual user location if needed
        // For now, return nil to use default behavior
        return nil
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // Combine street number and street name with a space, not comma
        var streetAddress: [String] = []
        if let subThoroughfare = placemark.subThoroughfare {
            streetAddress.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            streetAddress.append(thoroughfare)
        }
        if !streetAddress.isEmpty {
            components.append(streetAddress.joined(separator: " "))
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension AddressAutocompleteService: MKLocalSearchCompleterDelegate {
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = Array(completer.results.prefix(7)) // Limit to 7 suggestions
            self.isLoading = false
            self.errorMessage = nil
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            self.errorMessage = "Search failed. Please try again."
            print("Address autocomplete error: \(error.localizedDescription)")
        }
    }
}
