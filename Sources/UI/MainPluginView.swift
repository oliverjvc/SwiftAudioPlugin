// MainPluginView.swift
// Main plugin view combining all panels

#if canImport(SwiftUI)
import SwiftUI
import DSP

/// Main plugin interface
public struct MainPluginView: View {
    @StateObject private var engine = PluginEngine()
    @State private var selectedTab: PluginTab = .all
    @State private var showPresetBrowser = false
    
    public enum PluginTab: String, CaseIterable {
        case all = "ALL"
        case eq = "EQ"
        case compressor = "COMP"
        case delay = "DELAY"
        case reverb = "REVERB"
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .all:
                        EQPanel(eq: engine.eq)
                        CompressorPanel(compressor: engine.compressor)
                        DelayPanel(delay: engine.delay)
                        ReverbPanel(reverb: engine.reverb)
                    case .eq:
                        EQPanel(eq: engine.eq)
                    case .compressor:
                        CompressorPanel(compressor: engine.compressor)
                    case .delay:
                        DelayPanel(delay: engine.delay)
                    case .reverb:
                        ReverbPanel(reverb: engine.reverb)
                    }
                }
                .padding()
            }
            
            // Footer with I/O
            footerBar
        }
        .frame(minWidth: 650, minHeight: 600)
        .background(PluginColors.backgroundMedium)
    }
    
    private var headerBar: some View {
        HStack(spacing: 16) {
            // Logo/Title
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(PluginColors.accentPrimary)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("SWIFT AUDIO")
                        .font(PluginFonts.title)
                        .foregroundColor(PluginColors.textPrimary)
                    Text("CHANNEL STRIP")
                        .font(PluginFonts.small)
                        .foregroundColor(PluginColors.textDimmed)
                }
            }
            
            Spacer()
            
            // Tab selector
            HStack(spacing: 0) {
                ForEach(PluginTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(PluginFonts.label)
                            .foregroundColor(selectedTab == tab ? PluginColors.textPrimary : PluginColors.textDimmed)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedTab == tab ? PluginColors.accentPrimary.opacity(0.3) : Color.clear
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(PluginColors.backgroundDark)
            .cornerRadius(4)
            
            Spacer()
            
            // Preset selector
            PresetSelector(
                selectedPreset: .init(
                    get: { engine.currentPreset?.name ?? "Init" },
                    set: { name in
                        if let preset = engine.presets.first(where: { $0.name == name }) {
                            engine.loadPreset(preset)
                        }
                    }
                ),
                presets: ["Init"] + engine.presets.map { $0.name },
                onPrevious: {
                    // Navigate to previous preset
                },
                onNext: {
                    // Navigate to next preset
                }
            )
            
            // Action buttons
            HStack(spacing: 8) {
                ActionButton(label: "Save", icon: "square.and.arrow.down", style: .secondary) {
                    // Save preset
                }
                
                BypassButton(isBypassed: $engine.isBypassed)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PluginColors.backgroundDark)
    }
    
    private var footerBar: some View {
        HStack(spacing: 20) {
            // Input section
            HStack(spacing: 12) {
                Knob(
                    value: $engine.inputGain,
                    range: -24...24,
                    label: "INPUT",
                    unit: " dB",
                    defaultValue: 0,
                    displayFormat: "%+.1f"
                )
                
                StereoMeter(
                    leftLevel: engine.inputLevelL,
                    rightLevel: engine.inputLevelR,
                    label: "",
                    height: 60
                )
            }
            
            Spacer()
            
            // Center info
            VStack(spacing: 4) {
                Text("SAMPLE RATE")
                    .font(PluginFonts.small)
                    .foregroundColor(PluginColors.textDimmed)
                Text("\(Int(engine.sampleRate)) Hz")
                    .font(PluginFonts.value)
                    .foregroundColor(PluginColors.textSecondary)
            }
            
            Spacer()
            
            // Output section
            HStack(spacing: 12) {
                StereoMeter(
                    leftLevel: engine.outputLevelL,
                    rightLevel: engine.outputLevelR,
                    label: "",
                    height: 60
                )
                
                Knob(
                    value: $engine.outputGain,
                    range: -24...24,
                    label: "OUTPUT",
                    unit: " dB",
                    defaultValue: 0,
                    displayFormat: "%+.1f"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PluginColors.backgroundDark)
    }
}

#Preview {
    MainPluginView()
}
#endif
