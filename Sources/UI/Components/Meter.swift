// Meter.swift
// Professional level meters and gain reduction meters

#if canImport(SwiftUI)
import SwiftUI

/// Vertical level meter with peak hold
public struct LevelMeter: View {
    var level: Float      // dB (-60 to 0)
    var peakHold: Bool
    var showScale: Bool
    var width: CGFloat
    var height: CGFloat
    
    @State private var peakLevel: Float = -60
    @State private var peakHoldTimer: Timer?
    
    public init(
        level: Float,
        peakHold: Bool = true,
        showScale: Bool = false,
        width: CGFloat = 12,
        height: CGFloat = 150
    ) {
        self.level = level
        self.peakHold = peakHold
        self.showScale = showScale
        self.width = width
        self.height = height
    }
    
    private var normalizedLevel: CGFloat {
        let clamped = max(-60, min(0, level))
        return CGFloat((clamped + 60) / 60)
    }
    
    private var normalizedPeak: CGFloat {
        let clamped = max(-60, min(0, peakLevel))
        return CGFloat((clamped + 60) / 60)
    }
    
    private var meterColor: Color {
        if level > -3 { return PluginColors.meterRed }
        if level > -12 { return PluginColors.meterYellow }
        return PluginColors.meterGreen
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            if showScale {
                // Scale labels
                VStack {
                    Text("0").font(PluginFonts.small)
                    Spacer()
                    Text("-12").font(PluginFonts.small)
                    Spacer()
                    Text("-24").font(PluginFonts.small)
                    Spacer()
                    Text("-48").font(PluginFonts.small)
                    Spacer()
                    Text("-∞").font(PluginFonts.small)
                }
                .foregroundColor(PluginColors.textDimmed)
                .frame(height: height)
            }
            
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(PluginColors.backgroundDark)
                    .frame(width: width, height: height)
                
                // Segmented meter background
                VStack(spacing: 1) {
                    ForEach(0..<30, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.3))
                            .frame(height: (height - 29) / 30)
                    }
                }
                .frame(width: width - 2, height: height - 2)
                
                // Active level
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                PluginColors.meterGreen,
                                PluginColors.meterGreen,
                                PluginColors.meterYellow,
                                PluginColors.meterRed
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width - 2, height: max(0, height * normalizedLevel))
                    .animation(.easeOut(duration: 0.05), value: normalizedLevel)
                
                // Peak hold indicator
                if peakHold && peakLevel > -60 {
                    Rectangle()
                        .fill(level > -3 ? PluginColors.meterRed : PluginColors.textPrimary)
                        .frame(width: width - 2, height: 2)
                        .offset(y: -height * normalizedPeak + 1)
                }
                
                // Clip indicator
                if level > -0.1 {
                    Rectangle()
                        .fill(PluginColors.meterRed)
                        .frame(width: width, height: 4)
                        .offset(y: -height + 2)
                }
            }
        }
        .onChange(of: level) { newLevel in
            if newLevel > peakLevel {
                peakLevel = newLevel
                peakHoldTimer?.invalidate()
                peakHoldTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        peakLevel = -60
                    }
                }
            }
        }
    }
}

/// Stereo level meter pair
public struct StereoMeter: View {
    var leftLevel: Float
    var rightLevel: Float
    var label: String
    var height: CGFloat
    
    public init(leftLevel: Float, rightLevel: Float, label: String = "", height: CGFloat = 120) {
        self.leftLevel = leftLevel
        self.rightLevel = rightLevel
        self.label = label
        self.height = height
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                LevelMeter(level: leftLevel, width: 8, height: height)
                LevelMeter(level: rightLevel, width: 8, height: height)
            }
            
            HStack(spacing: 2) {
                Text("L")
                    .font(PluginFonts.small)
                    .foregroundColor(PluginColors.textDimmed)
                    .frame(width: 8)
                Text("R")
                    .font(PluginFonts.small)
                    .foregroundColor(PluginColors.textDimmed)
                    .frame(width: 8)
            }
            
            if !label.isEmpty {
                Text(label)
                    .font(PluginFonts.small)
                    .foregroundColor(PluginColors.textSecondary)
            }
        }
    }
}

/// Gain reduction meter (shows compression amount)
public struct GainReductionMeter: View {
    var reduction: Float  // Positive value in dB
    var height: CGFloat
    
    public init(reduction: Float, height: CGFloat = 120) {
        self.reduction = reduction
        self.height = height
    }
    
    private var normalizedReduction: CGFloat {
        CGFloat(min(reduction, 20) / 20)
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .top) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(PluginColors.backgroundDark)
                    .frame(width: 12, height: height)
                
                // Reduction bar (grows from top)
                RoundedRectangle(cornerRadius: 2)
                    .fill(PluginColors.accentSecondary)
                    .frame(width: 10, height: max(0, height * normalizedReduction))
                    .animation(.easeOut(duration: 0.05), value: normalizedReduction)
            }
            
            Text("GR")
                .font(PluginFonts.small)
                .foregroundColor(PluginColors.textDimmed)
            
            Text(String(format: "-%.1f", reduction))
                .font(PluginFonts.small)
                .foregroundColor(PluginColors.accentSecondary)
        }
    }
}

/// Horizontal spectrum-style meter
public struct SpectrumMeter: View {
    var levels: [Float]  // Array of band levels
    var barCount: Int
    var height: CGFloat
    
    public init(levels: [Float] = [], barCount: Int = 16, height: CGFloat = 60) {
        self.levels = levels
        self.barCount = barCount
        self.height = height
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let level = i < levels.count ? levels[i] : Float.random(in: -40...(-10))
                let normalized = CGFloat(max(0, (level + 60) / 60))
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [PluginColors.meterGreen, PluginColors.meterYellow, PluginColors.meterRed],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: height * normalized)
                    .animation(.easeOut(duration: 0.1), value: normalized)
            }
        }
        .frame(height: height, alignment: .bottom)
        .background(PluginColors.backgroundDark)
        .cornerRadius(4)
    }
}

private struct MeterPreviews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 30) {
            StereoMeter(leftLevel: -12, rightLevel: -18, label: "INPUT")
            GainReductionMeter(reduction: 6)
            StereoMeter(leftLevel: -6, rightLevel: -9, label: "OUTPUT")
        }
        .padding()
        .background(PluginColors.backgroundMedium)
    }
}
#endif
