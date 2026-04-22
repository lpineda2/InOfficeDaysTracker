//
//  OfficeLocation.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import Foundation
import CoreLocation

/// Represents a configured office location for tracking visits
struct OfficeLocation: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Office"
    var coordinate: CLLocationCoordinate2D?
    var address: String = ""
    var detectionRadius: Double = 200  // meters
    var isPrimary: Bool = false
    
    /// Maximum number of office locations allowed
    static let maxLocations = 2
    
    /// Default detection radius options (in meters)
    static let radiusOptions: [(label: String, value: Double)] = [
        ("50 meters", 50),
        ("100 meters", 100),
        ("200 meters", 200),
        ("300 meters", 300),
        ("500 meters", 500)
    ]
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, detectionRadius, isPrimary
        case latitude, longitude
    }
    
    init() {}
    
    init(name: String, coordinate: CLLocationCoordinate2D?, address: String, detectionRadius: Double = 200, isPrimary: Bool = false) {
        self.id = UUID()
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.detectionRadius = detectionRadius
        self.isPrimary = isPrimary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        detectionRadius = try container.decode(Double.self, forKey: .detectionRadius)
        isPrimary = try container.decode(Bool.self, forKey: .isPrimary)
        
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude),
           latitude.isFinite && longitude.isFinite,
           latitude >= -90 && latitude <= 90,
           longitude >= -180 && longitude <= 180 {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(detectionRadius, forKey: .detectionRadius)
        try container.encode(isPrimary, forKey: .isPrimary)
        
        if let coord = coordinate,
           coord.latitude.isFinite && coord.longitude.isFinite,
           coord.latitude >= -90 && coord.latitude <= 90,
           coord.longitude >= -180 && coord.longitude <= 180 {
            try container.encode(coord.latitude, forKey: .latitude)
            try container.encode(coord.longitude, forKey: .longitude)
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: OfficeLocation, rhs: OfficeLocation) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Helpers
    
    /// Check if a coordinate is within this location's detection radius
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        guard let officeCoord = self.coordinate else { return false }
        
        let officeLocation = CLLocation(latitude: officeCoord.latitude, longitude: officeCoord.longitude)
        let checkLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return checkLocation.distance(from: officeLocation) <= detectionRadius
    }
    
    /// Formatted radius for display
    var radiusFormatted: String {
        if detectionRadius >= 1000 {
            return String(format: "%.1f km", detectionRadius / 1000)
        } else {
            return "\(Int(detectionRadius)) meters"
        }
    }
    
    /// Short address (first line only)
    var shortAddress: String {
        address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? address
    }
}
