#!/usr/bin/env swift

import Foundation

let calendar = Calendar.current
let now = Date()

print("Current date: \(now)")
print("Current date formatted: \(DateFormatter.localizedString(from: now, dateStyle: .full, timeStyle: .medium))")

let formatter = DateFormatter()
formatter.dateFormat = "EEEE, MMMM d, yyyy"
print("Today is: \(formatter.string(from: now))")
print("Weekday: \(calendar.component(.weekday, from: now))")

guard let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end else {
    print("Failed to get end of month")
    exit(1)
}

print("End of current month: \(endOfMonth)")

let trackingDays = [2, 3, 4, 5, 6] // Monday-Friday
var count = 0
var date = calendar.startOfDay(for: now)

print("\nCounting from today:")
var dayCount = 0
while date < endOfMonth && dayCount < 10 { // Just show first 10 days
    let weekday = calendar.component(.weekday, from: date)
    let isTrackingDay = trackingDays.contains(weekday)
    
    let formatter2 = DateFormatter()
    formatter2.dateFormat = "EEEE, MMM d"
    print("\(formatter2.string(from: date)) (weekday \(weekday)): \(isTrackingDay ? "YES" : "NO")")
    
    if isTrackingDay {
        count += 1
    }
    date = calendar.date(byAdding: .day, value: 1, to: date) ?? endOfMonth
    dayCount += 1
}

print("... (continuing to count all days)")

// Reset and count all
count = 0
date = calendar.startOfDay(for: now)
while date < endOfMonth {
    let weekday = calendar.component(.weekday, from: date)
    if trackingDays.contains(weekday) {
        count += 1
    }
    date = calendar.date(byAdding: .day, value: 1, to: date) ?? endOfMonth
}

print("Total working days remaining from TODAY: \(count)")