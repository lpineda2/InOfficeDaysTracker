//
//  Typography.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//

import SwiftUI

/// Typography scale for consistent text styling across the app
enum Typography {
    
    // MARK: - Hero Numbers (Large progress displays)
    
    /// Extra large number display (e.g., main progress count)
    static var heroNumber: Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }
    
    /// Large number for ring centers
    static var ringNumber: Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }
    
    /// Medium number for secondary stats
    static var statNumber: Font {
        .system(size: 24, weight: .bold, design: .rounded)
    }
    
    /// Small number for mini cards
    static var miniNumber: Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
    
    // MARK: - Titles
    
    /// Large title for screen headers
    static var screenTitle: Font {
        .largeTitle.weight(.bold)
    }
    
    /// Card title
    static var cardTitle: Font {
        .headline.weight(.semibold)
    }
    
    /// Section header
    static var sectionHeader: Font {
        .subheadline.weight(.semibold)
    }
    
    // MARK: - Body Text
    
    /// Primary body text
    static var body: Font {
        .body
    }
    
    /// Secondary/supporting text
    static var bodySecondary: Font {
        .subheadline
    }
    
    /// Small caption text
    static var caption: Font {
        .caption
    }
    
    /// Extra small caption
    static var captionSmall: Font {
        .caption2
    }
    
    // MARK: - Labels
    
    /// Label under progress rings
    static var ringLabel: Font {
        .caption.weight(.medium)
    }
    
    /// Metric label (e.g., "158g left")
    static var metricLabel: Font {
        .subheadline.weight(.medium)
    }
    
    /// Accent label (colored, e.g., "Carbohydrates")
    static var accentLabel: Font {
        .caption.weight(.semibold)
    }

    // MARK: - Icon Sizes

    /// Extra large icon (used on welcome screen)
    static var iconXL: Font {
        .system(size: DesignTokens.iconBackgroundSize * 2.25)
    }

    /// Large icon
    static var iconL: Font {
        .system(size: DesignTokens.iconBackgroundSize * 1.6667)
    }

    /// Medium icon
    static var iconM: Font {
        .system(size: DesignTokens.iconBackgroundSize * 1.3333)
    }

    /// Inline icon used in compact contexts
    static var icon: Font {
        .system(size: DesignTokens.iconSize, weight: .semibold)
    }
}

// MARK: - View Extensions for Typography

extension View {
    /// Apply hero number styling
    func heroNumberStyle() -> some View {
        self
            .font(Typography.heroNumber)
            .foregroundColor(DesignTokens.textPrimary)
    }
    
    /// Apply ring number styling
    func ringNumberStyle() -> some View {
        self
            .font(Typography.ringNumber)
            .foregroundColor(DesignTokens.textPrimary)
    }
    
    /// Apply card title styling
    func cardTitleStyle() -> some View {
        self
            .font(Typography.cardTitle)
            .foregroundColor(DesignTokens.textPrimary)
    }
    
    /// Apply secondary text styling
    func secondaryTextStyle() -> some View {
        self
            .font(Typography.bodySecondary)
            .foregroundColor(DesignTokens.textSecondary)
    }
    
    /// Apply caption styling
    func captionStyle() -> some View {
        self
            .font(Typography.caption)
            .foregroundColor(DesignTokens.textSecondary)
    }
}
