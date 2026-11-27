// MARK: - HeroCard
// V3 Layout: Pace Strip (hero) → Daily Insight Brief → Metric Pills
// Pace + sparkline are the visual anchor — large and prominent.
// Brief sits below as a compact insight card.
// Metric pills scroll horizontally at the bottom.

import SwiftUI
import SwiftData

// MARK: - Hero Card (Main Container)

struct HeroCard: View {
    let briefHistory: [MorningBriefEntry]
    let paceValue: Double?
    let paceConfidence: String?
    let paceHistory: [Double]
    let signals: [MetricPillData]
    let currentStreak: Int
    let onPaceTap: () -> Void
    let onMetricTap: (MetricDetailSheet.MetricType, Double, Double?) -> Void
    
    @State private var showInsightDetail = false
    
    private var briefs: [MorningBriefEntry] { Array(briefHistory.prefix(7)) }
    
    private var percentage: Double {
        guard let pace = paceValue else { return 0 }
        return (1.0 - pace) * 100
    }
    
    private var heroText: String {
        let pct = abs(Int(round(percentage)))
        return "\(pct)%"
    }
    
    private var heroSuffix: String {
        if abs(percentage) < 0.5 { return "on pace" }
        return paceValue ?? 1.0 < 1.0 ? "slower" : "faster"
    }
    
    private var sparklineColor: Color {
        guard let pace = paceValue else { return Color(hex: "#4a9e8e") }
        if pace <= 1.00 { return Color(hex: "#4a9e8e") }
        if pace <= 1.05 { return Color(hex: "#d4a054") }
        return Color(hex: "#c46a5a")
    }
    
    private var paceColor: Color {
        guard let pace = paceValue else { return .white }
        if pace < 1.00 { return .white }
        if pace <= 1.05 { return Color(hex: "#f0d0a0") }
        return Color(hex: "#f0b0a0")
    }
    
    private var trendLabel: (text: String, color: Color) {
        guard paceHistory.count >= 7 else {
            return ("Building trend...", Color(hex: "#3e3e48"))
        }
        let recentAvg = paceHistory.suffix(7).reduce(0, +) / Double(paceHistory.suffix(7).count)
        let earlierAvg = paceHistory.prefix(7).reduce(0, +) / Double(paceHistory.prefix(7).count)
        let change = recentAvg - earlierAvg
        if change < -0.005 { return ("▼ Improving", Color(hex: "#4a9e8e")) }
        if change > 0.005 { return ("▲ Needs focus", Color(hex: "#c46a5a")) }
        return ("→ Stable", Color(hex: "#8a8a96"))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Zone 1: YOUR PACE — hero element ──
            paceZone
                .onTapGesture { onPaceTap() }

            // ── Zone 2: Metric pills + Insight button ──
            metricPillsZone
                .padding(.top, 8)
        }
        .sheet(isPresented: $showInsightDetail) {
            if let entry = briefs.first {
                let accent: Color = {
                    switch entry.accentColor {
                    case "amber": return .atlasAmber
                    case "coral": return .atlasAccent
                    default: return .atlasPrimary
                    }
                }()
                InsightDetailSheet(entry: entry, accent: accent)
            }
        }
    }
    
    // MARK: - Zone 1: Pace Strip (HERO)
    
    private var paceZone: some View {
        Group {
            if let pace = paceValue {
                HStack(alignment: .top) {
                    // Left: Pace number + trend
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR PACE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.5)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(heroText)
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundColor(paceColor)
                                .monospacedDigit()
                            Text(heroSuffix)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(paceColor.opacity(0.6))
                        }
                        
                        HStack(spacing: 8) {
                            Text(trendLabel.text)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(trendLabel.color)
                            Text(String(format: "%.2f", pace))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.atlasTextMuted.opacity(0.3))
                        }
                    }
                    
                    Spacer()
                    
                    // Right: Sparkline + Insight button stacked
                    VStack(alignment: .trailing, spacing: 6) {
                        if paceHistory.count >= 3 {
                            PaceSparkline(dataPoints: paceHistory, lineColor: sparklineColor)
                                .frame(width: 140, height: 52)
                        }
                        
                        // Daily Insight button — coral, compact
                        if briefs.first != nil {
                            Button(action: {
                                showInsightDetail = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: briefs.first?.icon ?? "sparkle")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("Daily Insight")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.atlasAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.atlasAccent.opacity(0.1))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.atlasAccent.opacity(0.2), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR PACE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.5)
                        Text("Calculating...")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.atlasText.opacity(0.5))
                        Text("Needs 7 days of data")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted.opacity(0.35))
                    }
                    Spacer()
                    
                    // Insight button even without pace data
                    if briefs.first != nil {
                        Button(action: {
                            showInsightDetail = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: briefs.first?.icon ?? "sparkle")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Daily Insight")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.atlasAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.atlasAccent.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.atlasAccent.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Zone 2: Metric Pills
    
    private var metricPillsZone: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                MetricPill(
                    label: currentStreak > 0 ? "🔥 \(currentStreak)d" : "0d",
                    sublabel: currentStreak >= 7 ? "On fire" : (currentStreak > 0 ? "Streak" : "Start today"),
                    color: currentStreak >= 7 ? .atlasPrimary : (currentStreak > 0 ? .atlasAmber : .atlasAccent),
                    onTap: nil
                )
                ForEach(signals) { signal in
                    MetricPill(
                        label: "\(signal.shortName) \(signal.displayValue)",
                        sublabel: signal.sublabel, color: signal.color,
                        onTap: signal.metricType != nil ? {
                            if let type = signal.metricType, let val = signal.numericValue { onMetricTap(type, val, signal.numericValue) }
                        } : nil
                    )
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
    let label: String; let sublabel: String; let color: Color; let onTap: (() -> Void)?
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.atlasText).lineLimit(1)
                Text(sublabel).font(.system(size: 9, weight: .semibold)).foregroundColor(color).lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.04)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(PlainButtonStyle()).disabled(onTap == nil)
    }
}

// MARK: - Metric Pill Data

struct MetricPillData: Identifiable {
    let id = UUID()
    let shortName: String; let displayValue: String; let sublabel: String
    let color: Color; let metricType: MetricDetailSheet.MetricType?; let numericValue: Double?
}

// MARK: - Insight Detail Sheet

struct InsightDetailSheet: View {
    let entry: MorningBriefEntry
    let accent: Color
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Category + date
                        HStack(spacing: 6) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(accent)
                            Text(formattedDate)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                        }
                        
                        // Headline
                        Text(entry.headline)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.atlasText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Full body
                        Text(entry.body)
                            .font(.system(size: 16))
                            .foregroundColor(.atlasText.opacity(0.7))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Today preview if available
                        if let preview = entry.todayPreview, !preview.isEmpty {
                            Text(preview)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(accent)
                                .padding(.top, 4)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(entry.date) { return "Today" }
        if calendar.isDateInYesterday(entry.date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: entry.date)
    }
}