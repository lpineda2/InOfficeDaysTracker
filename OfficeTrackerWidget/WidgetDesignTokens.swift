//
//  WidgetDesignTokens.swift
//  OfficeTrackerWidget
//
//  Shared design tokens for widget styling (mirrors main app DesignTokens)
//

import SwiftUI

/// Centralized design tokens for consistent widget theming
/// Mirrors the main app's DesignTokens for visual consistency
enum WidgetDesignTokens {
    
    // MARK: - Background Colors
    
    /// Widget background
    static var widgetBackground: Color {
        Color(.systemBackground)
    }
    
    // MARK: - Progress Ring Colors
    
    /// Background stroke for progress rings
    static var ringBackground: Color {
        Color(.systemGray5)
    }
    
    /// Primary accent gradient (Cyan theme)
    static var accentCyan: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "00D4AA"), Color(hex: "00B4D8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Secondary accent gradient (Purple theme)
    static var accentPurple: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "A855F7"), Color(hex: "7C3AED")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Tertiary accent gradient (Orange theme)
    static var accentOrange: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F59E0B"), Color(hex: "EF4444")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Success/celebration gradient
    static var accentSuccess: LinearGradient {
        LinearGradient(
            colors: [.green, Color(hex: "10B981")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Standard blue gradient (original style)
    static var accentBlue: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Solid Accent Colors
    
    static var cyanAccent: Color { Color(hex: "00D4AA") }
    static var purpleAccent: Color { Color(hex: "A855F7") }
    static var orangeAccent: Color { Color(hex: "F59E0B") }
    static var successGreen: Color { Color(hex: "10B981") }
    
    // MARK: - Text Colors
    
    static var textPrimary: Color { Color(.label) }
    static var textSecondary: Color { Color(.secondaryLabel) }
    static var textTertiary: Color { Color(.tertiaryLabel) }
    
    // MARK: - Status Colors
    
    static var statusInOffice: Color { .green }
    static var statusAway: Color { .orange }
    
    // MARK: - Sizing
    
    static let ringStrokeWidth: CGFloat = 8
    static let ringStrokeWidthSmall: CGFloat = 6
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
