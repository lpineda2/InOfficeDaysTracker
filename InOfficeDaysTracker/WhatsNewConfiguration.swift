//
//  WhatsNewConfiguration.swift
//  InOfficeDaysTracker
//
//  WhatsNew configuration for showcasing lock screen widgets
//

import SwiftUI
import WhatsNewKit

struct WhatsNewConfiguration {
    
    /// The WhatsNew instance for version 1.7.0 lock screen and home screen widgets
    static var lockScreenWidgets: WhatsNew {
        WhatsNew(
            version: "1.7.0",
            title: WhatsNew.Title(
                text: "New Lock Screen & Home Widgets",
                foregroundColor: .primary
            ),
            features: [
                // Lock Screen - Circular Widget
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "chart.line.uptrend.xyaxis",
                        foregroundColor: .blue
                    ),
                    title: "Lock Screen Progress",
                    subtitle: "See your monthly office progress at a glance on your lock screen"
                ),
                
                // Lock Screen - Rectangular Widget  
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "list.bullet.rectangle",
                        foregroundColor: .green
                    ),
                    title: "Lock Screen Status",
                    subtitle: "Detailed view with office status, progress count, and visual ring"
                ),
                
                // Home Screen - Medium Widget
                WhatsNew.Feature(
                    image: WhatsNew.Feature.Image(
                        systemName: "rectangle.grid.3x2",
                        foregroundColor: .orange
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
                    print("✅ [WhatsNew] Lock screen widgets showcase dismissed")
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
        WhatsNewConfiguration.lockScreenWidgets
    }
}