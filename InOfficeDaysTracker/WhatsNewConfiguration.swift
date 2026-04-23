//
//  WhatsNewConfiguration.swift
//  InOfficeDaysTracker
//
//  WhatsNew configuration for showcasing new features
//

import SwiftUI
import WhatsNewKit

struct WhatsNewConfiguration {
    
    // MARK: - Version 1.9.0: Auto-Calculate Office Days
    
    /// The WhatsNew instance for version 1.9.0 auto-calculate office days
    static var autoCalculateGoal: WhatsNew {
        WhatsNew(
            version: "1.9.0",
            title: WhatsNew.Title(
                text: "Smart Goal Calculation",
                foregroundColor: DesignTokens.textPrimary
            ),
            features: [
                // Auto-Calculate Feature
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "function",
                        foregroundColor: DesignTokens.cyanAccent
                    ),
                    title: "Auto-Calculate Goals",
                    subtitle: "Set your company's hybrid policy and let the app calculate your required office days automatically"
                ),
                
                // Holiday Calendar
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "calendar.badge.clock",
                        foregroundColor: DesignTokens.orangeAccent
                    ),
                    title: "Holiday Calendar",
                    subtitle: "Built-in US holiday presets (NYSE, Federal). Customize to match your company"
                ),
                
                // PTO Tracking
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "figure.walk",
                        foregroundColor: DesignTokens.successGreen
                    ),
                    title: "PTO & Sick Days",
                    subtitle: "Mark your time off and the goal adjusts automatically—no manual recalculation needed"
                ),
                
                // Multiple Office Locations
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "building.2",
                        foregroundColor: DesignTokens.purpleAccent
                    ),
                    title: "Multiple Offices",
                    subtitle: "Configure up to 2 office locations. Visits to any location count toward your goal"
                )
            ],
            primaryAction: WhatsNew.PrimaryAction(
                title: "Configure in Settings",
                backgroundColor: .accentColor,
                foregroundColor: .white,
                hapticFeedback: .notification(.success),
                onDismiss: {
                    debugLog("✅", "[WhatsNew] Auto-calculate goal showcase dismissed")
                }
            )
        )
    }
    
    // MARK: - Version 1.13.0: PTO Management & Rounding Options
    
    /// The WhatsNew instance for version 1.13.0 PTO management and rounding control
    static var ptoManagementAndRounding: WhatsNew {
        WhatsNew(
            version: "1.13.0",
            title: WhatsNew.Title(
                text: "Enhanced Control & Flexibility",
                foregroundColor: DesignTokens.textPrimary
            ),
            features: [
                // View and Delete PTO/Sick Days
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "calendar.badge.minus",
                        foregroundColor: DesignTokens.successGreen
                    ),
                    title: "Manage Your Time Off",
                    subtitle: "View all your PTO and sick days in one place. Easily delete past entries when plans change"
                ),
                
                // Rounding Mode Control
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "arrow.up.arrow.down.circle",
                        foregroundColor: DesignTokens.cyanAccent
                    ),
                    title: "Goal Rounding Control",
                    subtitle: "Choose how to round fractional office days—round up (default) or down. Find it in Settings → Goals"
                )
            ],
            primaryAction: WhatsNew.PrimaryAction(
                title: "Got It",
                backgroundColor: .accentColor,
                foregroundColor: .white,
                hapticFeedback: .notification(.success),
                onDismiss: {
                    debugLog("✅", "[WhatsNew] PTO management and rounding showcase dismissed")
                }
            )
        )
    }
    
    // MARK: - Version 1.7.0: Lock Screen Widgets
    
    /// The WhatsNew instance for version 1.7.0 lock screen and home screen widgets
    static var lockScreenWidgets: WhatsNew {
        WhatsNew(
            version: "1.7.0",
            title: WhatsNew.Title(
                text: "New Lock Screen & Home Widgets",
                foregroundColor: DesignTokens.textPrimary
            ),
            features: [
                // Lock Screen - Circular Widget
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "chart.line.uptrend.xyaxis",
                        foregroundColor: DesignTokens.cyanAccent
                    ),
                    title: "Lock Screen Progress",
                    subtitle: "See your monthly office progress at a glance on your lock screen"
                ),
                
                // Lock Screen - Rectangular Widget  
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "list.bullet.rectangle",
                        foregroundColor: DesignTokens.successGreen
                    ),
                    title: "Lock Screen Status",
                    subtitle: "Detailed view with office status, progress count, and visual ring"
                ),
                
                // Home Screen - Medium Widget
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "rectangle.grid.3x2",
                        foregroundColor: DesignTokens.orangeAccent
                    ),
                    title: "Enhanced Home Widgets",
                    subtitle: "Rich interface with office status and weekly stats. Also available on Mac with macOS Tahoe"
                )
            ],
            primaryAction: WhatsNew.PrimaryAction(
                title: "Get Started",
                backgroundColor: .accentColor,
                foregroundColor: .white,
                hapticFeedback: .notification(.success),
                onDismiss: {
                    debugLog("✅", "[WhatsNew] Lock screen widgets showcase dismissed")
                }
            )
        )
    }
    
    /// Custom layout matching app design
    static var customLayout: WhatsNew.Layout {
        WhatsNew.Layout(
            showsScrollViewIndicators: false,
            contentSpacing: 30,
            contentPadding: EdgeInsets(
                top: 60,
                leading: 20,
                bottom: 20,
                trailing: 20
            ),
            featureListSpacing: 25,
            featureImageWidth: 60,
            featureHorizontalSpacing: 16,
            footerActionSpacing: 16
        )
    }
}

// MARK: - WhatsNewCollectionProvider Extension

extension InOfficeDaysTrackerApp: WhatsNewCollectionProvider {
    
    /// Provide all WhatsNew instances for different versions
    var whatsNewCollection: WhatsNewCollection {
        WhatsNewConfiguration.ptoManagementAndRounding  // 1.13.0
        WhatsNewConfiguration.autoCalculateGoal          // 1.9.0
        WhatsNewConfiguration.lockScreenWidgets          // 1.7.0
    }
}