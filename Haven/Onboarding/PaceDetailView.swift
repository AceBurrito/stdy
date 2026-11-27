import SwiftUI
import SwiftData

struct PaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BiologicalPaceScore.date, order: .reverse) private var paceHistory: [BiologicalPaceScore]
    @Query private var profiles: [UserProfile]
    
    private var userProfile: UserProfile? { profiles.first }
    
    private var latestScore: BiologicalPaceScore? { paceHistory.first }
    
    private var paceValue: Double {
        latestScore?.paceValue ?? userProfile?.latestPaceValue ?? 1.0
    }
    
    private var paceColor: Color {
        if paceValue <= 0.95 { return Color(hex: "#4a9e8e") }
        if paceValue <= 1.03 { return .white.opacity(0.7) }
        if paceValue <= 1.10 { return Color(hex: "#d4a054") }
        return Color(hex: "#c46a5a")
    }
    
    // Build component list from latest score — SLEEP FIRST
    private var components: [PaceComponent] {
        guard let score = latestScore else { return [] }
        
        var list: [PaceComponent] = []
        
        // Sleep FIRST — foundational pillar (always show, even without data)
        let sleepPct = score.sleepPercentile ?? -1
            list.append(PaceComponent(
                name: "Sleep", icon: "bed.double.fill", percentile: sleepPct,
                isWeakest: isWeakest("sleep", score: score),
                isStrongest: isStrongest("sleep", score: score)
            ))
        
        
        if let pct = score.hrvPercentile {
            list.append(PaceComponent(
                name: "HRV", icon: "heart.text.square.fill", percentile: pct,
                isWeakest: isWeakest("hrv", score: score),
                isStrongest: isStrongest("hrv", score: score)
            ))
        }
        
        if let pct = score.rhrPercentile {
            list.append(PaceComponent(
                name: "Resting HR", icon: "heart.fill", percentile: pct,
                isWeakest: isWeakest("rhr", score: score),
                isStrongest: isStrongest("rhr", score: score)
            ))
        }
        
        if let pct = score.vo2MaxPercentile {
            list.append(PaceComponent(
                name: "VO₂ Max", icon: "lungs.fill", percentile: pct,
                isWeakest: isWeakest("vo2max", score: score),
                isStrongest: isStrongest("vo2max", score: score)
            ))
        }
        
        if let pct = score.stepsPercentile {
            list.append(PaceComponent(
                name: "Daily Movement", icon: "figure.walk", percentile: pct,
                isWeakest: isWeakest("steps", score: score),
                isStrongest: isStrongest("steps", score: score)
            ))
        }
        
        if let pct = score.strengthPercentile {
            list.append(PaceComponent(
                name: "Strength", icon: "dumbbell.fill", percentile: pct,
                isWeakest: isWeakest("strength", score: score),
                isStrongest: isStrongest("strength", score: score)
            ))
        }
        
        return list
    }
    
    // Flexible matching for weakest/strongest (handles different string formats)
    private func isWeakest(_ key: String, score: BiologicalPaceScore) -> Bool {
        guard let weakest = score.weakestComponent?.lowercased() else { return false }
        return weakest.contains(key.lowercased())
    }
    
    private func isStrongest(_ key: String, score: BiologicalPaceScore) -> Bool {
        guard let strongest = score.strongestComponent?.lowercased() else { return false }
        return strongest.contains(key.lowercased())
    }
    
    // If no weakest flagged by the calculator, find it ourselves
    private var weakestComponent: PaceComponent? {
        // First try the flagged one
        if let flagged = components.first(where: { $0.isWeakest }) {
            return flagged
        }
        // Fallback: lowest percentile
        return components.min(by: { $0.percentile < $1.percentile })
    }
    
    // Days gained calculation
    private var daysGained: Double {
        DaysGainedCalculator.totalDaysGained(
            paceHistory: paceHistory.reversed().map { ($0.date, $0.paceValue) }
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if !components.isEmpty {
                            componentSection
                        }
                        
                        if let weakest = weakestComponent {
                            opportunityCard(weakest)
                        }
                        
                        if daysGained > 0 {
                            daysGainedCard
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
                ToolbarItem(placement: .principal) {
                    Text("PACE BREAKDOWN")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1.5)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            let pct = abs(Int(round((1.0 - paceValue) * 100)))
            let suffix = paceValue < 1.0 ? "slower" : paceValue > 1.0 ? "faster" : "on pace"
            
            Text("\(pct)% \(suffix)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(paceColor)
            
            Text("Pace \(String(format: "%.2f", paceValue))")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.atlasTextMuted.opacity(0.5))
            
            if let confidence = latestScore?.confidenceLevel, confidence != "full" {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text(confidence == "limited" ? "Limited data" : "Partial data")
                        .font(.system(size: 11))
                }
                .foregroundColor(.atlasTextMuted)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Components
    
    private var componentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COMPONENTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)
            
            ForEach(components) { component in
                ComponentRow(component: component)
            }
        }
    }
    
    // MARK: - Opportunity Card
    
    private func opportunityCard(_ component: PaceComponent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasAmber)
                
                Text("BIGGEST OPPORTUNITY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAmber)
                    .tracking(1.5)
            }
            
            Text("\(component.name) is your weakest component at the \(ordinal(Int(component.percentile))) percentile.")
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .lineSpacing(4)
            
            Text(opportunityAdvice(for: component.name))
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.atlasAmber.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasAmber.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Days Gained
    
    private var daysGainedCard: some View {
        VStack(spacing: 8) {
            Text("DAYS GAINED")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasPrimary)
                .tracking(1.5)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", daysGained))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.atlasPrimary)
                
                Text("days")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasPrimary.opacity(0.7))
            }
            
            Text("of life expectancy gained since starting atlas")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.atlasPrimary.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasPrimary.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func ordinal(_ n: Int) -> String {
        let ones = n % 10
        let tens = (n / 10) % 10
        let suffix: String
        if tens == 1 { suffix = "th" }
        else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
    
    private func opportunityAdvice(for component: String) -> String {
        switch component {
        case "Sleep": return "Focus on sleep consistency and duration. This is often the highest-leverage change."
        case "HRV": return "Your recovery score responds to sleep quality, stress management, and breathwork."
        case "Resting HR": return "Improved by consistent Zone 2 cardio and recovery practices."
        case "VO₂ Max": return "Build cardiorespiratory fitness through structured Zone 2 and interval training."
        case "Daily Movement": return "Increase daily steps and reduce prolonged sitting periods."
        case "Strength": return "Consistent resistance training preserves muscle mass — the strongest longevity predictor."
        default: return "This component has the most room for improvement in your Pace score."
        }
    }
}

// MARK: - Component Model

struct PaceComponent: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let percentile: Double
    let isWeakest: Bool
    let isStrongest: Bool
    
    var color: Color {
        if percentile < 0 { return Color.atlasTextMuted }
        if percentile >= 65 { return Color.atlasPrimary }
        if percentile >= 35 { return Color.atlasAmber }
        return Color.atlasAccent
    }
}

// MARK: - Component Row

struct ComponentRow: View {
    let component: PaceComponent
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: component.icon)
                    .font(.system(size: 16))
                    .foregroundColor(component.color)
                    .frame(width: 24)
                
                Text(component.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                if component.percentile >= 0 {
                    Text("\(ordinal(Int(component.percentile))) %ile")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(component.color)
                } else {
                    Text("No data")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                }
                if component.isWeakest {
                    Text("WEAKEST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.atlasAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.atlasAccent.opacity(0.15))
                        .cornerRadius(4)
                }
                if component.isStrongest {
                    Text("STRONGEST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.atlasPrimary.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            
            // Percentile bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(component.percentile >= 0 ? component.color : Color.atlasTextMuted.opacity(0.3))
                        .frame(width: component.percentile >= 0 ? max(geo.size.width * (component.percentile / 100), 4) : geo.size.width * 0.05, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    
    private func ordinal(_ n: Int) -> String {
        let ones = n % 10
        let tens = (n / 10) % 10
        let suffix: String
        if tens == 1 { suffix = "th" }
        else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
