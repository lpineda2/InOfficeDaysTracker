//
//  AppData.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 7/6/25.
//

import Foundation
import CoreLocation

@MainActor
class AppData: ObservableObject {
    @Published var settings = AppSettings()
    @Published var visits: [OfficeVisit] = []
    @Published var currentVisit: OfficeVisit?
    @Published var isCurrentlyInOffice = false
    
    private let settingsKey = "AppSettings"
    private let visitsKey = "OfficeVisits"
    
    init() {
        loadSettings()
        loadVisits()
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }
    
    func completeSetup() {
        settings.isSetupComplete = true
        saveSettings()
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }
    
    // MARK: - Visit Management
    
    func startVisit(at location: CLLocationCoordinate2D) {
        let now = Date()
        let visit = OfficeVisit(
            date: now,
            entryTime: now,
            coordinate: location
        )
        currentVisit = visit
        isCurrentlyInOffice = true
    }
    
    func endVisit() {
        guard let visit = currentVisit else { return }
        
        let exitTime = Date()
        let duration = exitTime.timeIntervalSince(visit.entryTime)
        
        let completedVisit = OfficeVisit(
            date: visit.date,
            entryTime: visit.entryTime,
            exitTime: exitTime,
            duration: duration,
            coordinate: visit.coordinate
        )
        
        // Only save valid visits (at least 1 hour)
        if completedVisit.isValidVisit {
            visits.append(completedVisit)
            saveVisits()
        }
        
        currentVisit = nil
        isCurrentlyInOffice = false
    }
    
    func getVisits(for month: Date) -> [OfficeVisit] {
        let calendar = Calendar.current
        return visits.filter { visit in
            calendar.isDate(visit.date, equalTo: month, toGranularity: .month)
        }
    }
    
    func getValidVisits(for month: Date) -> [OfficeVisit] {
        return getVisits(for: month).filter { $0.isValidVisit }
    }
    
    func getCurrentMonthProgress() -> (current: Int, goal: Int, percentage: Double) {
        let currentMonth = Date()
        let validVisits = getValidVisits(for: currentMonth)
        let current = validVisits.count
        let goal = settings.monthlyGoal
        let percentage = goal > 0 ? Double(current) / Double(goal) : 0.0
        return (current, goal, min(percentage, 1.0))
    }
    
    private func saveVisits() {
        if let encoded = try? JSONEncoder().encode(visits) {
            UserDefaults.standard.set(encoded, forKey: visitsKey)
        }
    }
    
    private func loadVisits() {
        if let data = UserDefaults.standard.data(forKey: visitsKey),
           let decoded = try? JSONDecoder().decode([OfficeVisit].self, from: data) {
            visits = decoded
        }
    }
    
    // MARK: - Utility Methods
    
    func deleteVisit(_ visit: OfficeVisit) {
        visits.removeAll { $0.id == visit.id }
        saveVisits()
    }
    
    func clearAllData() {
        visits.removeAll()
        currentVisit = nil
        isCurrentlyInOffice = false
        settings = AppSettings()
        saveVisits()
        saveSettings()
    }
}
