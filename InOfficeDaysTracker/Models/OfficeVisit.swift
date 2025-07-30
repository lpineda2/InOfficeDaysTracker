//
//  OfficeVisit.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import Foundation
import CoreLocation

struct OfficeVisit: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let entryTime: Date
    let exitTime: Date?
    let duration: TimeInterval?
    let coordinate: CLLocationCoordinate2D
    
    var isValidVisit: Bool {
        guard let duration = duration else { return false }
        return duration >= 3600 // At least 1 hour to count as a valid office visit
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "In progress" }
        guard !duration.isNaN && !duration.isInfinite && duration >= 0 else { return "Invalid duration" }
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %dm", hours, minutes)
    }
    
    enum CodingKeys: String, CodingKey {
        case date, entryTime, exitTime, duration
        case latitude, longitude
    }
    
    init(date: Date, entryTime: Date, exitTime: Date? = nil, duration: TimeInterval? = nil, coordinate: CLLocationCoordinate2D) {
        self.date = date
        self.entryTime = entryTime
        self.exitTime = exitTime
        self.duration = duration
        
        // Validate coordinates
        if coordinate.latitude.isFinite && coordinate.longitude.isFinite &&
           coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
           coordinate.longitude >= -180 && coordinate.longitude <= 180 {
            self.coordinate = coordinate
        } else {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        entryTime = try container.decode(Date.self, forKey: .entryTime)
        exitTime = try container.decodeIfPresent(Date.self, forKey: .exitTime)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        
        // Validate coordinates during decoding
        if latitude.isFinite && longitude.isFinite &&
           latitude >= -90 && latitude <= 90 &&
           longitude >= -180 && longitude <= 180 {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(entryTime, forKey: .entryTime)
        try container.encodeIfPresent(exitTime, forKey: .exitTime)
        try container.encodeIfPresent(duration, forKey: .duration)
        // Validate coordinates before encoding
        if coordinate.latitude.isFinite && coordinate.longitude.isFinite &&
           coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
           coordinate.longitude >= -180 && coordinate.longitude <= 180 {
            try container.encode(coordinate.latitude, forKey: .latitude)
            try container.encode(coordinate.longitude, forKey: .longitude)
        } else {
            try container.encode(0.0, forKey: .latitude)
            try container.encode(0.0, forKey: .longitude)
        }
    }
}
