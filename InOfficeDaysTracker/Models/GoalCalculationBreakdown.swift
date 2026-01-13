//
//  GoalCalculationBreakdown.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import Foundation

/// Detailed breakdown of goal calculation for UI display
struct GoalCalculationBreakdown {
    let weekdaysInMonth: Int
    let holidays: [Date]
    let businessDays: Int
    let ptoDays: [Date]
    let workingDays: Int
    let policyPercentage: Double
    let requiredDays: Int
    
    /// Holiday count for display
    var holidayCount: Int { holidays.count }
    
    /// PTO count for display
    var ptoCount: Int { ptoDays.count }
    
    /// Formatted percentage string
    var percentageString: String {
        "\(Int(policyPercentage * 100))%"
    }
    
    /// Human-readable formula result
    var formulaDescription: String {
        if ptoCount > 0 {
            return "(\(businessDays) business days − \(ptoCount) PTO) × \(percentageString) = \(requiredDays)"
        } else {
            return "\(businessDays) business days × \(percentageString) = \(requiredDays)"
        }
    }
    
    /// Holiday names for the month (formatted)
    func holidayNames(using calendar: HolidayCalendar) -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        return holidays.map { date in
            dateFormatter.string(from: date)
        }
    }
}
