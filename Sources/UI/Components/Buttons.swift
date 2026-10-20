// Buttons.swift
// Professional toggle buttons and action buttons

#if canImport(SwiftUI)
import SwiftUI

/// Toggle button for enabling/bypassing effects
public struct ToggleButton: View {
    @Binding var isOn: Bool
    var label: String
    var onColor: Color
    var offColor: Color
    
    public init(
        isOn: Binding<Bool>,
        label: String,
        onColor: Color = PluginColors.accentGreen,
        offColor: Color = PluginColors.backgroundLight
    ) {
        self._isOn = isOn
        self.label = label
        self.onColor = onColor
        self.offColor = offColor
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 6) {
                // LED indicator
                Circle()
                    .fill(isOn ? onColor : offColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: isOn ? onColor.opacity(0.6) : .clear, radius: 4)
                
                Text(label)
                    .font(PluginFonts.label)
                    .foregroundColor(isOn ? PluginColors.textPrimary : PluginColors.textDimmed)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOn ? onColor.opacity(0.2) : PluginColors.backgroundDark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isOn ? onColor.opacity(0.5) : PluginColors.knobRing, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Bypass button with special styling
public struct BypassButton: View {
    @Binding var isBypassed: Bool
    
    public init(isBypassed: Binding<Bool>) {
        self._isBypassed = isBypassed
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                isBypassed.toggle()
            }
        }) {
            Text("BYPASS")
                .font(PluginFonts.label)
                .foregroundColor(isBypassed ? PluginColors.accentRed : PluginColors.textDimmed)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isBypassed ? PluginColors.accentRed.opacity(0.2) : PluginColors.backgroundDark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isBypassed ? PluginColors.accentRed : PluginColors.knobRing, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Segmented control for selecting options
public struct SegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    var options: [(T, String)]
    var accentColor: Color
    
    public init(
        selection: Binding<T>,
        options: [(T, String)],
        accentColor: Color = PluginColors.accentPrimary
    ) {
        self._selection = selection
        self.options = options
        self.accentColor = accentColor
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                let (value, label) = options[index]
                let isSelected = selection == value
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = value
                    }
                }) {
                    Text(label)
                        .font(PluginFonts.label)
                        .foregroundColor(isSelected ? PluginColors.textPrimary : PluginColors.textDimmed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? accentColor.opacity(0.3) : Color.clear
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                if index < options.count - 1 {
                    Rectangle()
                        .fill(PluginColors.knobRing)
                        .frame(width: 1)
                }
            }
        }
        .background(PluginColors.backgroundDark)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(PluginColors.knobRing, lineWidth: 1)
        )
    }
}

/// Preset selector dropdown
public struct PresetSelector: View {
    @Binding var selectedPreset: String
    var presets: [String]
    var onPrevious: () -> Void
    var onNext: () -> Void
    
    public init(
        selectedPreset: Binding<String>,
        presets: [String],
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {}
    ) {
        self._selectedPreset = selectedPreset
        self.presets = presets
        self.onPrevious = onPrevious
        self.onNext = onNext
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Previous button
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(PluginColors.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Preset name
            Menu {
                ForEach(presets, id: \.self) { preset in
                    Button(preset) {
                        selectedPreset = preset
                    }
                }
            } label: {
                Text(selectedPreset)
                    .font(PluginFonts.label)
                    .foregroundColor(PluginColors.textPrimary)
                    .frame(minWidth: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            
            // Next button
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(PluginColors.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(PluginColors.backgroundDark)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(PluginColors.knobRing, lineWidth: 1)
        )
    }
}

/// Action button (save, load, etc.)
public struct ActionButton: View {
    var label: String
    var icon: String?
    var action: () -> Void
    var style: ActionButtonStyle
    
    public enum ActionButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    public init(
        label: String,
        icon: String? = nil,
        style: ActionButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    private var buttonColor: Color {
        switch style {
        case .primary: return PluginColors.accentPrimary
        case .secondary: return PluginColors.backgroundLight
        case .destructive: return PluginColors.accentRed
        }
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(PluginFonts.label)
            }
            .foregroundColor(style == .primary ? .white : PluginColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(style == .primary ? buttonColor : buttonColor.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(buttonColor.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ButtonsPreviews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack {
                ToggleButton(isOn: .constant(true), label: "EQ")
                ToggleButton(isOn: .constant(false), label: "COMP")
                BypassButton(isBypassed: .constant(false))
            }
        
            PresetSelector(
                selectedPreset: .constant("Warm Vocal"),
                presets: ["Init", "Warm Vocal", "Punchy Drums"]
            )
        
            HStack {
                ActionButton(label: "Save", icon: "square.and.arrow.down", style: .primary) {}
                ActionButton(label: "A/B", style: .secondary) {}
            }
        }
        .padding()
        .background(PluginColors.backgroundMedium)
    }
}
#endif
