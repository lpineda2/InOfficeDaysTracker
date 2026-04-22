//
//  CompanyPolicy.swift
//  InOfficeDaysTracker
//
//  Created by Luis Pineda on 1/13/26.
//

import Foundation

/// Rounding mode for calculating required days from fractional values
enum RoundingMode: String, Codable, CaseIterable, Identifiable {
    case roundUp = "up"       // ceil() - rounds up (e.g., 9.5 → 10)
    case roundDown = "down"   // floor() - rounds down (e.g., 9.5 → 9)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .roundUp: return "Round Up"
        case .roundDown: return "Round Down"
        }
    }
    
    var description: String {
        switch self {
        case .roundUp: return "Rounds up fractional days (e.g., 9.5 → 10)"
        case .roundDown: return "Rounds down fractional days (e.g., 9.5 → 9)"
        }
    }
    
    /// Apply rounding to a value
    func apply(_ value: Double) -> Int {
        switch self {
        case .roundUp: return Int(ceil(value))
        case .roundDown: return Int(floor(value))
        }
    }
}

/// Represents the company's in-office attendance policy
struct CompanyPolicy: Codable, Equatable {
    var policyType: PolicyType = .hybrid50
    var customPercentage: Int = 50  // Used when policyType is .custom
    var roundingMode: RoundingMode = .roundUp  // Default: round up (maintains backward compatibility)
    
    // MARK: - Codable Implementation (Backward Compatible)
    
    enum CodingKeys: String, CodingKey {
        case policyType, customPercentage, roundingMode
    }
    
    init() {}
    
    init(policyType: PolicyType, customPercentage: Int = 50, roundingMode: RoundingMode = .roundUp) {
        self.policyType = policyType
        self.customPercentage = customPercentage
        self.roundingMode = roundingMode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        policyType = try container.decode(PolicyType.self, forKey: .policyType)
        customPercentage = try container.decode(Int.self, forKey: .customPercentage)
        // Use decodeIfPresent for new properties to maintain backward compatibility
        // Old saved data won't have this field - use default value
        roundingMode = try container.decodeIfPresent(RoundingMode.self, forKey: .roundingMode) ?? .roundUp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(policyType, forKey: .policyType)
        try container.encode(customPercentage, forKey: .customPercentage)
        try container.encode(roundingMode, forKey: .roundingMode)
    }
    
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
    /// Formula: workingDays × percentage, then apply selected rounding mode
    func calculateRequiredDays(workingDays: Int) -> Int {
        let exactValue = Double(workingDays) * requiredPercentage
        return roundingMode.apply(exactValue)
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
        let roundingText = roundingMode == .roundUp ? "rounded up" : "rounded down"
        return "(Business Days − PTO) × \(percentageText), \(roundingText)"
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
