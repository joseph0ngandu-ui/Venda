import SwiftUI

/// Centralized design system for consistent spacing, typography, and component sizing
struct DesignSystem {
    // MARK: - Spacing Scale
    /// Standardized spacing values for consistent rhythm throughout the app
    struct Spacing {
        static let xs: CGFloat = 4      // minimal spacing
        static let sm: CGFloat = 8      // small spacing
        static let md: CGFloat = 12     // default spacing between elements
        static let lg: CGFloat = 16     // standard screen padding
        static let xl: CGFloat = 24     // section spacing
        static let xxl: CGFloat = 32    // major section spacing
        static let xxxl: CGFloat = 40   // screen-level spacing
    }
    
    // MARK: - Corner Radius
    struct Radius {
        static let sm: CGFloat = 8      // small buttons, badges
        static let md: CGFloat = 12     // cards, input fields
        static let lg: CGFloat = 16     // modals, rounded containers
        static let xl: CGFloat = 22     // tab bar, large surfaces
        static let full: CGFloat = 999  // pill shapes, fully rounded
    }
    
    // MARK: - Typography Scale
    /// Standardized font sizes and weights for consistency
    struct Typography {
        // Display / Headings
        static let h1 = Font.system(size: 28, weight: .bold, design: .default)
        static let h2 = Font.system(size: 24, weight: .semibold, design: .default)
        static let h3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let h4 = Font.system(size: 18, weight: .semibold, design: .default)
        
        // Body text
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodySemibold = Font.system(size: 16, weight: .semibold, design: .default)
        static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
        
        // Supplementary text
        static let label = Font.system(size: 12, weight: .semibold, design: .default)
        static let caption = Font.system(size: 11, weight: .medium, design: .default)
        static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
        
        // Interactive elements
        static let button = Font.system(size: 15, weight: .semibold, design: .default)
        static let buttonSmall = Font.system(size: 13, weight: .semibold, design: .default)
    }
    
    // MARK: - Component Sizes
    struct ComponentSize {
        // Button heights
        static let buttonHeightLarge: CGFloat = 52
        static let buttonHeightSmall: CGFloat = 40
        static let buttonHeightMini: CGFloat = 32
        
        // Icon sizes
        static let iconLarge: CGFloat = 24
        static let iconMedium: CGFloat = 18
        static let iconSmall: CGFloat = 16
        
        // Avatar sizes
        static let avatarLarge: CGFloat = 64
        static let avatarMedium: CGFloat = 52
        static let avatarSmall: CGFloat = 40
        
        // Card heights
        static let minTouchTarget: CGFloat = 44
        static let businessTypeCardHeight: CGFloat = 88
        
        // Indicator sizes
        static let progressDotSize: CGFloat = 8
    }
    
    // MARK: - Shadow System
    struct Shadow {
        static let subtle = (color: Color.black, opacity: 0.05, radius: 4.0, x: 0.0, y: 2.0)
        static let default_ = (color: Color.black, opacity: 0.08, radius: 8.0, x: 0.0, y: 4.0)
        static let elevated = (color: Color.black, opacity: 0.12, radius: 12.0, x: 0.0, y: 6.0)
    }
    
    // MARK: - Opacity Values
    struct Opacity {
        static let disabled: Double = 0.5
        static let hover: Double = 0.8
        static let subtle: Double = 0.6
        static let muted: Double = 0.7
        static let minimal: Double = 0.2
    }
    
    // MARK: - Animation Durations
    struct Animation {
        static let fast: Double = 0.15
        static let normal: Double = 0.3
        static let slow: Double = 0.5
    }
}

// MARK: - Spacing Extensions
extension View {
    /// Standard inset padding (16 horizontal, 12 vertical)
    func vendaPadding(_ edges: Edge.Set = .all, standard: Bool = true) -> some View {
        if standard {
            return AnyView(self.padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md))
        } else {
            return AnyView(self.padding(edges, DesignSystem.Spacing.lg))
        }
    }
}
