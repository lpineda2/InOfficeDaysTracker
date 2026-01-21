//
//  DesignTokens.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//

import SwiftUI

/// Centralized design tokens for consistent theming across the app
/// Supports both light and dark modes with adaptive colors
enum DesignTokens {
    
    // MARK: - Background Colors
    
    /// Main app background
    static var appBackground: Color {
        Color(.systemBackground)
    }
    
    /// Card/elevated surface background - adapts to light/dark mode
    static var cardBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }
    
    /// Tertiary background for nested elements
    static var surfaceElevated: Color {
        Color(.tertiarySystemGroupedBackground)
    }
    
    // MARK: - Progress Ring Colors
    
    /// Background stroke for progress rings
    static var ringBackground: Color {
        Color(.systemGray5)
    }
    
    /// Primary accent gradient (Days) - Cyan theme
    static var accentCyan: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "00D4AA"), Color(hex: "00B4D8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Secondary accent gradient (Fat/Goal) - Purple theme
    static var accentPurple: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "A855F7"), Color(hex: "7C3AED")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Tertiary accent gradient (Protein/Pace) - Orange/Yellow theme
    static var accentOrange: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F59E0B"), Color(hex: "EF4444")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Success gradient for completed goals
    static var accentSuccess: LinearGradient {
        LinearGradient(
            colors: [.green, Color(hex: "10B981")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Standard blue gradient (original app style)
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
    static var statusNeutral: Color { .blue }
    
    // MARK: - Chart Colors
    
    static var chartLine: Color { Color(hex: "10B981") }
    static var chartFill: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "10B981").opacity(0.3), Color(hex: "10B981").opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    static var chartGrid: Color { Color(.systemGray4) }
    
    // MARK: - Shadows
    
    /// Shadow for cards in light mode (no shadow in dark mode)
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.clear
    }
    
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2
    
    // MARK: - Spacing & Sizing
    
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let gridSpacing: CGFloat = 12
    
    static let ringStrokeWidth: CGFloat = 12
    static let ringStrokeWidthSmall: CGFloat = 8
    
    static let iconBackgroundSize: CGFloat = 36
    static let iconSize: CGFloat = 18
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
