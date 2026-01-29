//
//  CardStyle.swift
//  InOfficeDaysTracker
//
//  Created for MFP-style redesign
//

import SwiftUI

/// A view modifier that applies consistent card styling
/// Adapts to light/dark mode with appropriate backgrounds and shadows
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    var cornerRadius: CGFloat = DesignTokens.cardCornerRadius
    var padding: CGFloat = DesignTokens.cardPadding
    var includePadding: Bool = true
    
    func body(content: Content) -> some View {
        content
            .padding(includePadding ? padding : 0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignTokens.cardBackground)
                    .shadow(
                        color: DesignTokens.cardShadow(for: colorScheme),
                        radius: DesignTokens.cardShadowRadius,
                        x: 0,
                        y: DesignTokens.cardShadowY
                    )
            )
    }
}

/// A view modifier for elevated/nested cards within other cards
struct ElevatedCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 12
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignTokens.surfaceElevated)
            )
    }
}

/// A view modifier for icon backgrounds (colored circles)
struct IconBackgroundStyle: ViewModifier {
    let color: Color
    var size: CGFloat = DesignTokens.iconBackgroundSize
    
    func body(content: Content) -> some View {
        content
            .font(Typography.icon)
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling with adaptive background and shadow
    func cardStyle(
        cornerRadius: CGFloat = DesignTokens.cardCornerRadius,
        padding: CGFloat = DesignTokens.cardPadding,
        includePadding: Bool = true
    ) -> some View {
        modifier(CardStyle(
            cornerRadius: cornerRadius,
            padding: padding,
            includePadding: includePadding
        ))
    }
    
    /// Apply elevated card styling for nested elements
    func elevatedCardStyle(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 12
    ) -> some View {
        modifier(ElevatedCardStyle(
            cornerRadius: cornerRadius,
            padding: padding
        ))
    }
    
    /// Apply colored circular background to an icon
    func iconBackground(color: Color, size: CGFloat = DesignTokens.iconBackgroundSize) -> some View {
        modifier(IconBackgroundStyle(color: color, size: size))
    }
}

// MARK: - Preview

#Preview("Card Styles") {
    ScrollView {
        VStack(spacing: 20) {
            // Standard card
            VStack(alignment: .leading, spacing: 8) {
                Text("Standard Card")
                    .cardTitleStyle()
                Text("This is a card with adaptive styling")
                    .secondaryTextStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            
            // Card with icon
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .iconBackground(color: DesignTokens.orangeAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak")
                        .captionStyle()
                    Text("5 months")
                        .cardTitleStyle()
                }
                
                Spacer()
            }
            .cardStyle()
            
            // Elevated nested card
            VStack {
                Text("Outer Card")
                    .cardTitleStyle()
                
                Text("Inner elevated content")
                    .secondaryTextStyle()
                    .frame(maxWidth: .infinity)
                    .elevatedCardStyle()
            }
            .cardStyle()
        }
        .padding()
    }
    .background(DesignTokens.appBackground)
}
