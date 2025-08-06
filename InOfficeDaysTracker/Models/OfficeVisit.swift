//
//  OfficeVisit.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import Foundation
import CoreLocation

// Represents a single entry/exit event within an office session
struct OfficeEvent: Codable {
    let entryTime: Date
    let exitTime: Date?
    
    var duration: TimeInterval? {
        guard let exitTime = exitTime else { return nil }
        return exitTime.timeIntervalSince(entryTime)
    }
}

struct OfficeVisit: Identifiable, Codable {
    let id = UUID()
    let date: Date
    var events: [OfficeEvent]
    let coordinate: CLLocationCoordinate2D
    
    // Legacy properties for backward compatibility and UI
    var entryTime: Date {
        return events.first?.entryTime ?? date
    }
    
    var exitTime: Date? {
        // Return the exit time of the last event if all events are completed
        guard !events.isEmpty,
              events.allSatisfy({ $0.exitTime != nil }) else { return nil }
        return events.last?.exitTime
    }
    
    var duration: TimeInterval? {
        guard !events.isEmpty else { return nil }
        
        // If session is still active (last event has no exit time), return nil
        guard events.allSatisfy({ $0.exitTime != nil }) else { return nil }
        
        // Calculate total duration across all events
        return events.compactMap { $0.duration }.reduce(0, +)
    }
    
    // Check if currently in an active session (last event has no exit time)
    var isActiveSession: Bool {
        guard let lastEvent = events.last else { return false }
        return lastEvent.exitTime == nil
    }
    
    var isValidVisit: Bool {
        guard let duration = duration else { return false }
        return duration >= 3600 // At least 1 hour total to count as a valid office visit
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
    
    // MARK: - Session Management Methods
    
    mutating func startNewSession(at time: Date = Date()) {
        let newEvent = OfficeEvent(entryTime: time, exitTime: nil)
        events.append(newEvent)
    }
    
    mutating func endCurrentSession(at time: Date = Date()) {
        guard let lastEvent = events.last,
              lastEvent.exitTime == nil else { return }
        
        let completedEvent = OfficeEvent(entryTime: lastEvent.entryTime, exitTime: time)
        events[events.count - 1] = completedEvent
    }
    
    mutating func resumeSession(at time: Date = Date()) {
        // End current session if active
        endCurrentSession(at: time)
        // Start new session immediately
        startNewSession(at: time)
    }
    
    enum CodingKeys: String, CodingKey {
        case date, events
        case latitude, longitude
        // Legacy keys for backward compatibility
        case entryTime, exitTime, duration
    }
    
    init(date: Date, entryTime: Date, exitTime: Date? = nil, duration: TimeInterval? = nil, coordinate: CLLocationCoordinate2D) {
        self.date = date
        
        // Create initial event
        let initialEvent = OfficeEvent(entryTime: entryTime, exitTime: exitTime)
        self.events = [initialEvent]
        
        // Validate coordinates
        if coordinate.latitude.isFinite && coordinate.longitude.isFinite &&
           coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
           coordinate.longitude >= -180 && coordinate.longitude <= 180 {
            self.coordinate = coordinate
        } else {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }
    
    // Session-based initializer
    init(date: Date, coordinate: CLLocationCoordinate2D) {
        self.date = date
        self.events = []
        
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
        
        // Try to decode new format first
        if let decodedEvents = try? container.decode([OfficeEvent].self, forKey: .events) {
            events = decodedEvents
        } else {
            // Fallback to legacy format for backward compatibility
            let legacyEntryTime = try container.decode(Date.self, forKey: .entryTime)
            let legacyExitTime = try? container.decodeIfPresent(Date.self, forKey: .exitTime)
            let legacyEvent = OfficeEvent(entryTime: legacyEntryTime, exitTime: legacyExitTime)
            events = [legacyEvent]
        }
        
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
        try container.encode(events, forKey: .events)
        
        // Also encode legacy format for backward compatibility
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
