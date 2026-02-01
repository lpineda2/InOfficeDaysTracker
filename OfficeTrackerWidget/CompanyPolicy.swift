//
//  CompanyPolicy.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import Foundation

/// Represents the company's in-office attendance policy
struct CompanyPolicy: Codable, Equatable {
    var policyType: PolicyType = .hybrid50
    var customPercentage: Int = 50  // Used when policyType is .custom
    
    /// The percentage of business days required in office
    var requiredPercentage: Double {
        switch policyType {
        case .hybrid50:
            return 0.50
        case .hybrid40:
            return 0.40
        case .hybrid60:
            return 0.60
        case .fullOffice:
            return 1.0
        case .fullRemote:
            return 0.0
        case .custom:
            return Double(customPercentage) / 100.0
        }
    }
    
    /// Calculate required days from working days (business days minus PTO)
    /// Formula: ceil(workingDays × percentage)
    func calculateRequiredDays(workingDays: Int) -> Int {
        return Int(ceil(Double(workingDays) * requiredPercentage))
    }
    
    /// Human-readable description of the policy
    var displayName: String {
        switch policyType {
        case .hybrid50:
            return "Hybrid 50%"
        case .hybrid40:
            return "Hybrid 40%"
        case .hybrid60:
            return "Hybrid 60%"
        case .fullOffice:
            return "Full Office"
        case .fullRemote:
            return "Full Remote"
        case .custom:
            return "Custom (\(customPercentage)%)"
        }
    }
    
    /// Formula description for UI display
    var formulaDescription: String {
        let percentageText = policyType == .custom ? "\(customPercentage)%" : "\(Int(requiredPercentage * 100))%"
        return "(Business Days − PTO) × \(percentageText), rounded up"
    }
}

/// Available policy types
enum PolicyType: String, Codable, CaseIterable, Identifiable {
    case hybrid50 = "hybrid_50"
    case hybrid40 = "hybrid_40"
    case hybrid60 = "hybrid_60"
    case fullOffice = "full_office"
    case fullRemote = "full_remote"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hybrid50: return "Hybrid 50%"
        case .hybrid40: return "Hybrid 40%"
        case .hybrid60: return "Hybrid 60%"
        case .fullOffice: return "Full Office (100%)"
        case .fullRemote: return "Full Remote (0%)"
        case .custom: return "Custom Percentage"
        }
    }
    
    var description: String {
        switch self {
        case .hybrid50: return "Half of business days in office"
        case .hybrid40: return "40% of business days in office"
        case .hybrid60: return "60% of business days in office"
        case .fullOffice: return "All business days in office"
        case .fullRemote: return "No required office days"
        case .custom: return "Set your own percentage"
        }
    }
}
