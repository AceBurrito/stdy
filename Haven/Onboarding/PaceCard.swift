import SwiftUI
import SwiftData

// MARK: - Redesigned Pace Card (Sparkline)

struct PaceCard: View {
    let paceValue: Double
    let confidenceLevel: String
    let trendDirection: String?
    let paceHistory: [Double]      // Last 30 days of pace values, oldest first
    let onTap: () -> Void
    
    // MARK: - Computed Properties
    
    // Percentage: (1.0 - pace) × 100
    private var percentage: Double {
        (1.0 - paceValue) * 100
    }
    
    private var isSlower: Bool {
        paceValue < 1.0
    }
    
    // Hero text: "6%"
    private var heroText: String {
        let pct = abs(Int(round(percentage)))
        return "\(pct)%"
    }
    
    private var heroSuffix: String {
        if abs(percentage) < 0.5 { return "on pace" }
        return isSlower ? "slower" : "faster"
    }
    
    // MARK: - Subtitle
    
    private var subtitleText: String {
        if paceValue <= 0.92 { return "Aging exceptionally slow" }
        if paceValue <= 0.96 { return "Aging slower than expected" }
        if paceValue <= 1.00 { return "Aging at a normal rate" }
        if paceValue <= 1.05 { return "Aging faster than expected" }
        if paceValue <= 1.10 { return "Aging significantly faster" }
        return "Needs attention"
    }
    
    private var subtitleColor: Color {
        if paceValue <= 0.92 { return Color(hex: "#4a9e8e") }
        if paceValue <= 0.96 { return Color(hex: "#4a9e8e") }
        if paceValue <= 1.00 { return Color(hex: "#8a9e8e") }
        if paceValue <= 1.05 { return Color(hex: "#d4a054") }
        if paceValue <= 1.10 { return Color(hex: "#c46a5a") }
        return Color(hex: "#b8524a")
    }
    
    // MARK: - Color System
    
    private var percentageColor: Color {
        if paceValue < 1.00 { return .white }
        if paceValue <= 1.05 { return Color(hex: "#f0d0a0") }
        return Color(hex: "#f0b0a0")
    }
    
    private var sparklineColor: Color {
        if paceValue <= 1.00 { return Color(hex: "#4a9e8e") }
        if paceValue <= 1.05 { return Color(hex: "#d4a054") }
        return Color(hex: "#c46a5a")
    }
    
    private var cardBackground: LinearGradient {
        if paceValue <= 1.00 {
            return LinearGradient(
                colors: [Color(hex: "#14211e"), Color(hex: "#111116")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#211914"), Color(hex: "#111116")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Trend
    
    private var trendLabel: (text: String, color: Color) {
        guard paceHistory.count >= 7 else {
            return ("Building trend...", Color(hex: "#3e3e48"))
        }
        
        let recentSlice = paceHistory.suffix(7)
        let recentAvg = recentSlice.reduce(0, +) / Double(recentSlice.count)
        
        let earlierSlice = paceHistory.prefix(7)
        let earlierAvg = earlierSlice.reduce(0, +) / Double(earlierSlice.count)
        
        let change = recentAvg - earlierAvg
        
        if change < -0.005 { return ("▼ Improving", Color(hex: "#4a9e8e")) }
        if change > 0.005 { return ("▲ Needs focus", Color(hex: "#c46a5a")) }
        return ("→ Stable", Color(hex: "#8a8a96"))
    }
    
    private var monthlyChangeText: String? {
        guard let oldest = paceHistory.first, let newest = paceHistory.last else { return nil }
        guard paceHistory.count >= 3 else { return nil }
        let change = abs(newest - oldest) * 100
        let direction = newest < oldest ? "↓" : "↑"
        return "\(direction) \(Int(round(change)))% this month"
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row: label + raw value
                HStack {
                    Text("YOUR PACE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.atlasTextMuted)
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f", paceValue))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.atlasTextMuted.opacity(0.6))
                    
                    // Confidence indicator
                    if confidenceLevel != "full" {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(Color.atlasTextMuted.opacity(0.4))
                    }
                }
                .padding(.bottom, 6)
                
                // Hero number: "6% slower" — left aligned
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(heroText)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(percentageColor)
                        .monospacedDigit()
                    
                    Text(heroSuffix)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(percentageColor.opacity(0.65))
                }
                .padding(.bottom, 2)
                
                // Subtitle
                Text(subtitleText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(subtitleColor)
                    .padding(.bottom, 10)
                
                // Sparkline section
                if paceHistory.count >= 3 {
                    Text("LAST 30 DAYS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "#3e3e48"))
                        .tracking(1.5)
                        .padding(.bottom, 6)
                    
                    PaceSparkline(
                        dataPoints: paceHistory,
                        lineColor: sparklineColor
                    )
                    .frame(height: 48)
                    .padding(.bottom, 6)
                } else {
                    // Empty state for new users
                    VStack(spacing: 4) {
                        Text("Your trend builds over the first week")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#3e3e48"))
                    }
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
                }
                
                // Footer: trend + monthly change
                HStack {
                    Text(trendLabel.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(trendLabel.color)
                    
                    Spacer()
                    
                    if let monthText = monthlyChangeText {
                        Text(monthText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.atlasTextMuted.opacity(0.5))
                    }
                }
                .padding(.top, 6)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(sparklineColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State

struct PaceCardEmpty: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR PACE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.atlasTextMuted)
                    .tracking(1.5)
                Spacer()
            }
            
            Text("Calculating...")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color.atlasText.opacity(0.6))
            
            Text("Check back tomorrow")
                .font(.system(size: 14))
                .foregroundColor(Color.atlasTextMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.atlasCardDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.atlasTextMuted.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Component Indicator (kept for compatibility)

struct PaceComponentIndicator: Identifiable {
    let id = UUID()
    let name: String
    let percentile: Double
    let status: ComponentStatus
    
    enum ComponentStatus {
        case good
        case moderate
        case needsAttention
    }
    
    var statusColor: Color {
        switch status {
        case .good: return Color.atlasPrimary
        case .moderate: return Color.atlasAmber
        case .needsAttention: return Color.atlasAccent
        }
    }
    
    static func from(score: BiologicalPaceScore) -> [PaceComponentIndicator] {
        var components: [(name: String, percentile: Double)] = []
        
        if let pct = score.sleepPercentile { components.append(("Sleep", pct)) }
        if let pct = score.hrvPercentile { components.append(("HRV", pct)) }
        if let pct = score.rhrPercentile { components.append(("Resting HR", pct)) }
        if let pct = score.vo2MaxPercentile { components.append(("Cardio", pct)) }
        if let pct = score.stepsPercentile { components.append(("Activity", pct)) }
        if let pct = score.strengthPercentile { components.append(("Strength", pct)) }
        
        components.sort { abs($0.percentile - 50) > abs($1.percentile - 50) }
        
        return components.prefix(3).map { component in
            let status: ComponentStatus
            if component.percentile >= 65 {
                status = .good
            } else if component.percentile >= 35 {
                status = .moderate
            } else {
                status = .needsAttention
            }
            
            return PaceComponentIndicator(
                name: component.name,
                percentile: component.percentile,
                status: status
            )
        }
    }
}
