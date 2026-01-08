// Theme.swift
// Professional audio plugin color scheme and styling

#if canImport(SwiftUI)
import SwiftUI

/// Color palette for the audio plugin
public struct PluginColors {
    // Background colors
    public static let backgroundDark = Color(red: 0.08, green: 0.08, blue: 0.10)
    public static let backgroundMedium = Color(red: 0.12, green: 0.12, blue: 0.14)
    public static let backgroundLight = Color(red: 0.18, green: 0.18, blue: 0.20)
    public static let panelBackground = Color(red: 0.14, green: 0.14, blue: 0.16)
    
    // Accent colors
    public static let accentPrimary = Color(red: 0.0, green: 0.75, blue: 0.95)    // Cyan
    public static let accentSecondary = Color(red: 0.95, green: 0.6, blue: 0.0)   // Orange
    public static let accentGreen = Color(red: 0.2, green: 0.85, blue: 0.4)       // Green
    public static let accentRed = Color(red: 0.95, green: 0.25, blue: 0.3)        // Red
    public static let accentPurple = Color(red: 0.7, green: 0.4, blue: 0.95)      // Purple
    
    // Text colors
    public static let textPrimary = Color.white
    public static let textSecondary = Color(white: 0.7)
    public static let textDimmed = Color(white: 0.5)
    
    // Meter colors
    public static let meterGreen = Color(red: 0.2, green: 0.9, blue: 0.3)
    public static let meterYellow = Color(red: 0.95, green: 0.85, blue: 0.2)
    public static let meterRed = Color(red: 0.95, green: 0.2, blue: 0.25)
    
    // Gradient for meters
    public static let meterGradient = LinearGradient(
        colors: [meterGreen, meterYellow, meterRed],
        startPoint: .bottom,
        endPoint: .top
    )
    
    // Knob colors
    public static let knobBackground = Color(red: 0.2, green: 0.2, blue: 0.22)
    public static let knobIndicator = accentPrimary
    public static let knobRing = Color(white: 0.3)
}

/// Typography styles
public struct PluginFonts {
    public static let title = Font.system(size: 18, weight: .bold, design: .rounded)
    public static let sectionTitle = Font.system(size: 14, weight: .semibold, design: .rounded)
    public static let label = Font.system(size: 11, weight: .medium, design: .rounded)
    public static let value = Font.system(size: 12, weight: .bold, design: .monospaced)
    public static let small = Font.system(size: 9, weight: .regular, design: .rounded)
}

/// Common shadow styles
public struct PluginShadows {
    public static let small = Shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    public static let medium = Shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
    public static let large = Shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    public static let glow = Shadow(color: PluginColors.accentPrimary.opacity(0.5), radius: 8, x: 0, y: 0)
}

/// Shadow configuration struct
public struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// View modifiers for consistent styling
public struct PanelStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(PluginColors.panelBackground)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

public struct GlowingBorder: ViewModifier {
    var color: Color
    var isActive: Bool
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: isActive ? 2 : 0)
                    .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: 4)
            )
    }
}

public extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
    
    func glowingBorder(color: Color = PluginColors.accentPrimary, isActive: Bool = true) -> some View {
        modifier(GlowingBorder(color: color, isActive: isActive))
    }
}
#endif
