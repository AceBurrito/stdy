import SwiftUI

// MARK: - Cardio Progression View (Check-In Step 3)
// Shows cardio session count, total minutes, longest session, avg HR — all WoW.
// Auto-skips (shows brief message) if no cardio sessions in either week.
// Used inside EnhancedWeeklyCheckInView as Step 3.

struct CardioProgressionView: View {
    let summary: WeeklyCardioAnalyzer.WeeklyCardioSummary
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                stepHeader
                
                if !summary.hasCardioThisWeek && !summary.hasCardioLastWeek {
                    noCardioCard
                } else {
                    // Stats grid
                    statsGrid
                    
                    // Session list (this week only)
                    if !summary.thisWeekSessionDetails.isEmpty {
                        sessionList
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Header
    
    private var stepHeader: some View {
        VStack(spacing: 4) {
            Text("CARDIO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.atlasPrimary)
                .tracking(1.5)
            
            Text("Aerobic Capacity")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text("Cardio sessions, this week vs last")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // MARK: - No Cardio
    
    private var noCardioCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 32))
                .foregroundColor(.atlasTextMuted.opacity(0.4))
            
            Text("No cardio sessions logged")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasTextMuted)
            
            Text("Log your cardio to track aerobic progress week over week")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        VStack(spacing: 8) {
            // Row 1: Sessions + Total Minutes
            HStack(spacing: 8) {
                statCard(
                    label: "Sessions",
                    value: "\(summary.thisWeekSessions)",
                    change: summary.sessionCountChange,
                    prevValue: summary.hasCardioLastWeek ? "\(summary.lastWeekSessions)" : nil,
                    icon: "number"
                )
                
                statCard(
                    label: "Total Minutes",
                    value: "\(summary.thisWeekTotalMinutes)",
                    change: summary.totalMinutesChange,
                    prevValue: summary.hasCardioLastWeek ? "\(summary.lastWeekTotalMinutes)" : nil,
                    icon: "clock.fill"
                )
            }
            
            // Row 2: Longest Session + Avg HR
            HStack(spacing: 8) {
                statCard(
                    label: "Longest Session",
                    value: "\(summary.thisWeekLongestSession) min",
                    change: summary.longestSessionChange,
                    prevValue: summary.hasCardioLastWeek ? "\(summary.lastWeekLongestSession) min" : nil,
                    icon: "timer"
                )
                
                if let avgHR = summary.thisWeekAvgHeartRate {
                    statCard(
                        label: "Avg Heart Rate",
                        value: "\(Int(avgHR)) bpm",
                        change: nil,
                        prevValue: summary.lastWeekAvgHeartRate != nil ? "\(Int(summary.lastWeekAvgHeartRate!)) bpm" : nil,
                        icon: "heart.fill"
                    )
                } else {
                    statCard(
                        label: "Avg Heart Rate",
                        value: "—",
                        change: nil,
                        prevValue: nil,
                        icon: "heart.fill"
                    )
                }
            }
            
            // Prescribed vs completed (if applicable)
            if let prescribed = summary.prescribedCardioSessions, prescribed > 0 {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasPrimary)
                    
                    Text("Prescribed: \(prescribed) sessions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    let met = summary.thisWeekSessions >= prescribed
                    Text(met ? "Met" : "Missed \(prescribed - summary.thisWeekSessions)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(met ? .atlasPrimary : .atlasAccent)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
        }
    }
    
    private func statCard(label: String, value: String, change: Int?, prevValue: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.atlasPrimary)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.atlasText)
            
            HStack(spacing: 4) {
                if let change = change {
                    let isPositive = change > 0
                    let arrow = change > 0 ? "↑" : (change < 0 ? "↓" : "→")
                    let color: Color = change > 0 ? .atlasPrimary : (change < 0 ? .atlasAccent : .atlasTextMuted)
                    
                    Text("\(arrow)\(isPositive ? "+" : "")\(change)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                }
                
                if let prev = prevValue {
                    Text("prev: \(prev)")
                        .font(.system(size: 10))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.atlasCardDark)
        .cornerRadius(12)
    }
    
    // MARK: - Session List
    
    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week's Sessions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
            
            ForEach(summary.thisWeekSessionDetails) { session in
                sessionRow(session)
            }
        }
        .padding(14)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
    }
    
    private func sessionRow(_ session: WeeklyCardioAnalyzer.CardioSessionSummary) -> some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: cardioIcon(session.sessionType))
                .font(.system(size: 14))
                .foregroundColor(.atlasPrimary)
                .frame(width: 22)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionType.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Text(formatSessionDate(session.date))
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted.opacity(0.6))
            }
            
            Spacer()
            
            // Duration
            Text("\(session.duration) min")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.atlasText)
            
            // HR Zone badge (if available)
            if let zone = session.hrZoneLabel {
                Text(zone)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.atlasPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func cardioIcon(_ type: String) -> String {
        let lowered = type.lowercased()
        if lowered.contains("run") { return "figure.run" }
        if lowered.contains("walk") { return "figure.walk" }
        if lowered.contains("cycle") || lowered.contains("bike") { return "figure.outdoor.cycle" }
        if lowered.contains("swim") { return "figure.pool.swim" }
        if lowered.contains("row") { return "figure.rower" }
        if lowered.contains("hike") { return "figure.hiking" }
        if lowered.contains("elliptical") { return "figure.elliptical" }
        return "figure.run"
    }
    
    private func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}