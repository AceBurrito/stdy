import SwiftUI
import SwiftData

// MARK: - Weekly Data Summary View (Check-In Step 1)
// Automated review: Pace trend, health metrics WoW, adherence.
// No user input — pure data display.
// Used inside EnhancedWeeklyCheckInView as the first step.

struct WeeklyDataSummaryView: View {
    let paceStart: Double?
    let paceEnd: Double?
    let paceTrend: String?            // "improving", "stable", "declining"
    let strongestComponent: String?
    let weakestComponent: String?
    
    // Health metrics: this week avg, last week avg
    let sleepAvg: Double?
    let prevSleepAvg: Double?
    let hrvAvg: Double?
    let prevHrvAvg: Double?
    let rhrAvg: Double?
    let prevRhrAvg: Double?
    let stepsAvg: Double?
    let prevStepsAvg: Double?
    let vo2Max: Double?
    let prevVo2Max: Double?
    
    // Adherence
    let habitsCompleted: Int
    let habitsTotal: Int
    let sessionsCompleted: Int
    let sessionsPrescribed: Int
    let habitBreakdown: [(name: String, completed: Int, total: Int)]
    
    // Week number
    let weekNumber: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                stepHeader
                
                // Pace Hero Card
                paceHeroCard
                
                // Health Metrics WoW
                healthMetricsSection
                
                // Adherence
                adherenceSection
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step Header
    
    private var stepHeader: some View {
        VStack(spacing: 4) {
            Text("WEEK \(weekNumber) REVIEW")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.atlasPrimary)
                .tracking(1.5)
            
            Text("Your Week at a Glance")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.atlasText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // MARK: - Pace Hero Card
    
    private var paceHeroCard: some View {
        VStack(spacing: 12) {
            // Pace values
            HStack(alignment: .top) {
                // Start of week
                VStack(spacing: 2) {
                    Text("Week Start")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text(paceStart != nil ? String(format: "%.2f", paceStart!) : "—")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                // Arrow
                VStack(spacing: 4) {
                    Image(systemName: paceArrowIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(paceArrowColor)
                    
                    Text(paceTrendLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(paceArrowColor)
                }
                .padding(.top, 12)
                
                Spacer()
                
                // End of week
                VStack(spacing: 2) {
                    Text("Now")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text(paceEnd != nil ? String(format: "%.2f", paceEnd!) : "—")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.atlasText)
                }
            }
            
            // Component pills
            if strongestComponent != nil || weakestComponent != nil {
                HStack(spacing: 8) {
                    if let strongest = strongestComponent {
                        componentPill(label: "Strongest", value: strongest, color: .atlasPrimary)
                    }
                    if let weakest = weakestComponent {
                        componentPill(label: "Focus Area", value: weakest, color: .atlasAccent)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func componentPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color.opacity(0.8))
                .tracking(1)
            
            Text(value.capitalized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.atlasText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Health Metrics Section
    
    private var healthMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Signals")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.atlasText)
            
            VStack(spacing: 6) {
                if let sleep = sleepAvg {
                    metricRow(
                        icon: "bed.double.fill",
                        label: "Sleep",
                        thisWeek: String(format: "%.1fh", sleep),
                        lastWeek: prevSleepAvg != nil ? String(format: "%.1fh", prevSleepAvg!) : nil,
                        trend: trendDirection(current: sleep, previous: prevSleepAvg, higherIsBetter: true)
                    )
                }
                
                if let hrv = hrvAvg {
                    metricRow(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        thisWeek: String(format: "%.0f ms", hrv),
                        lastWeek: prevHrvAvg != nil ? String(format: "%.0f ms", prevHrvAvg!) : nil,
                        trend: trendDirection(current: hrv, previous: prevHrvAvg, higherIsBetter: true)
                    )
                }
                
                if let rhr = rhrAvg {
                    metricRow(
                        icon: "heart.fill",
                        label: "RHR",
                        thisWeek: String(format: "%.0f bpm", rhr),
                        lastWeek: prevRhrAvg != nil ? String(format: "%.0f bpm", prevRhrAvg!) : nil,
                        trend: trendDirection(current: rhr, previous: prevRhrAvg, higherIsBetter: false)
                    )
                }
                
                if let steps = stepsAvg {
                    metricRow(
                        icon: "figure.walk",
                        label: "Steps",
                        thisWeek: formatSteps(steps),
                        lastWeek: prevStepsAvg != nil ? formatSteps(prevStepsAvg!) : nil,
                        trend: trendDirection(current: steps, previous: prevStepsAvg, higherIsBetter: true)
                    )
                }
                
                if let vo2 = vo2Max {
                    metricRow(
                        icon: "lungs.fill",
                        label: "VO₂ Max",
                        thisWeek: String(format: "%.1f", vo2),
                        lastWeek: prevVo2Max != nil ? String(format: "%.1f", prevVo2Max!) : nil,
                        trend: trendDirection(current: vo2, previous: prevVo2Max, higherIsBetter: true)
                    )
                }
            }
        }
        .padding(16)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
    }
    
    private func metricRow(icon: String, label: String, thisWeek: String, lastWeek: String?, trend: TrendType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(trend.color)
                .frame(width: 22)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
            
            Spacer()
            
            // This week value
            Text(thisWeek)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.atlasText)
            
            // Trend arrow
            Text(trend.arrow)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(trend.color)
                .frame(width: 18)
            
            // Last week value (dimmed)
            if let lastWeek = lastWeek {
                Text(lastWeek)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.atlasTextMuted.opacity(0.6))
                    .frame(width: 55, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted.opacity(0.4))
                    .frame(width: 55, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Adherence Section
    
    private var adherenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adherence")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.atlasText)
            
            // Habits overall
            adherenceBar(
                label: "Habits",
                completed: habitsCompleted,
                total: habitsTotal,
                icon: "checkmark.circle.fill"
            )
            
            // Training sessions
            adherenceBar(
                label: "Training",
                completed: sessionsCompleted,
                total: sessionsPrescribed,
                icon: "figure.strengthtraining.traditional"
            )
            
            // Individual habit breakdown (compact)
            if !habitBreakdown.isEmpty {
                VStack(spacing: 4) {
                    ForEach(habitBreakdown.indices, id: \.self) { index in
                        let habit = habitBreakdown[index]
                        HStack(spacing: 8) {
                            Circle()
                                .fill(habit.completed == habit.total ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                                .frame(width: 6, height: 6)
                            
                            Text(habit.name)
                                .font(.system(size: 12))
                                .foregroundColor(.atlasTextMuted)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(habit.completed)/\(habit.total)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(habit.completed == habit.total ? .atlasPrimary : .atlasTextMuted)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
    }
    
    private func adherenceBar(label: String, completed: Int, total: Int, icon: String) -> some View {
        let progress = total > 0 ? Double(completed) / Double(total) : 0
        let percentage = Int(progress * 100)
        
        return VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasPrimary)
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Text("\(completed)/\(total)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.atlasText)
                
                Text("(\(percentage)%)")
                    .font(.system(size: 12))
                    .foregroundColor(adherenceColor(percentage))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.atlasTextMuted.opacity(0.15))
                        .frame(height: 5)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(adherenceColor(percentage))
                        .frame(width: geo.size.width * progress, height: 5)
                }
            }
            .frame(height: 5)
        }
    }
    
    // MARK: - Helpers
    
    private var paceArrowIcon: String {
        guard let start = paceStart, let end = paceEnd else { return "arrow.right" }
        let diff = end - start
        if diff < -0.01 { return "arrow.down.right" }      // Improving (pace going down)
        if diff > 0.01 { return "arrow.up.right" }          // Declining (pace going up)
        return "arrow.right"
    }
    
    private var paceArrowColor: Color {
        guard let start = paceStart, let end = paceEnd else { return .atlasTextMuted }
        let diff = end - start
        if diff < -0.01 { return .atlasPrimary }
        if diff > 0.01 { return .atlasAccent }
        return .atlasTextMuted
    }
    
    private var paceTrendLabel: String {
        guard let start = paceStart, let end = paceEnd else { return "No data" }
        let diff = end - start
        if diff < -0.01 { return "Slowing aging" }
        if diff > 0.01 { return "Monitor this" }
        return "Holding steady"
    }
    
    private enum TrendType {
        case up, down, stable, noData
        
        var arrow: String {
            switch self {
            case .up: return "↑"
            case .down: return "↓"
            case .stable: return "→"
            case .noData: return "—"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .atlasPrimary
            case .down: return .atlasAccent
            case .stable: return .atlasTextMuted
            case .noData: return .atlasTextMuted.opacity(0.5)
            }
        }
    }
    
    private func trendDirection(current: Double?, previous: Double?, higherIsBetter: Bool) -> TrendType {
        guard let curr = current, let prev = previous, prev > 0 else { return .noData }
        let pctChange = (curr - prev) / prev
        
        if abs(pctChange) < 0.03 { return .stable }
        
        if higherIsBetter {
            return pctChange > 0 ? .up : .down
        } else {
            return pctChange < 0 ? .up : .down  // Lower is better (e.g. RHR)
        }
    }
    
    private func adherenceColor(_ percentage: Int) -> Color {
        if percentage >= 80 { return .atlasPrimary }
        if percentage >= 60 { return .atlasAmber }
        return .atlasAccent
    }
    
    private func formatSteps(_ steps: Double) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", steps / 1000.0)
        }
        return String(format: "%.0f", steps)
    }
}