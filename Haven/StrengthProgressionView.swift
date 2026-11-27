import SwiftUI

// MARK: - Strength Progression View (Check-In Step 2)
// Shows best set per lift: last week vs this week, e1RM change, color-coded badges.
// Auto-skips (shows brief message) if no workouts in either week.
// Used inside EnhancedWeeklyCheckInView as Step 2.

struct StrengthProgressionView: View {
    let summary: WeeklyStrengthAnalyzer.WeeklyStrengthSummary
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                stepHeader
                
                if !summary.hasAnyWorkouts {
                    noWorkoutsCard
                } else if summary.progressions.isEmpty {
                    noWorkoutsCard
                } else {
                    // Session count comparison
                    sessionCountRow
                    
                    // Lift progression cards
                    ForEach(summary.progressions) { lift in
                        liftCard(lift)
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
            Text("STRENGTH")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.atlasPrimary)
                .tracking(1.5)
            
            Text("Progressive Overload")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text("Best set per exercise, this week vs last")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // MARK: - No Workouts
    
    private var noWorkoutsCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 32))
                .foregroundColor(.atlasTextMuted.opacity(0.4))
            
            Text("No strength workouts logged")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasTextMuted)
            
            Text("Log your workouts to track progressive overload week over week")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
    }
    
    // MARK: - Session Count
    
    private var sessionCountRow: some View {
        HStack {
            Label {
                Text("Sessions this week")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasPrimary)
            }
            
            Spacer()
            
            Text("\(summary.thisWeekSessionCount)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.atlasText)
            
            if summary.lastWeekSessionCount > 0 {
                Text("(prev: \(summary.lastWeekSessionCount))")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted.opacity(0.6))
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Lift Card
    
    private func liftCard(_ lift: WeeklyStrengthAnalyzer.LiftProgression) -> some View {
        VStack(spacing: 10) {
            // Exercise name + badge
            HStack {
                Text(lift.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .lineLimit(1)
                
                Spacer()
                
                changeBadge(lift.changeType, description: lift.changeDescription)
            }
            
            // Best set comparison
            HStack(spacing: 0) {
                // Last week
                VStack(spacing: 3) {
                    Text("Last Week")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                        .tracking(0.5)
                    
                    if let best = lift.lastWeekBest {
                        if best.isBodyweight {
                            Text("\(best.reps) reps")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.atlasTextMuted)
                        } else {
                            Text("\(Int(best.weight)) × \(best.reps)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.atlasTextMuted)
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasTextMuted.opacity(0.4))
                    }
                    
                    if let e1rm = lift.lastWeekE1RM {
                        Text("e1RM: \(Int(e1rm))")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasTextMuted.opacity(0.3))
                    .frame(width: 30)
                
                // This week
                VStack(spacing: 3) {
                    Text("This Week")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                        .tracking(0.5)
                    
                    if let best = lift.thisWeekBest {
                        if best.isBodyweight {
                            Text("\(best.reps) reps")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.atlasText)
                        } else {
                            Text("\(Int(best.weight)) × \(best.reps)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.atlasText)
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasTextMuted.opacity(0.4))
                    }
                    
                    if let e1rm = lift.thisWeekE1RM {
                        Text("e1RM: \(Int(e1rm))")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // e1RM % change (if available)
            if let pctChange = lift.e1RMChangePercent, abs(pctChange) > 0.5 {
                HStack {
                    Spacer()
                    Text(String(format: "%+.1f%% e1RM", pctChange))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(pctChange > 0 ? .atlasPrimary : .atlasAccent)
                }
            }
        }
        .padding(14)
        .background(Color.atlasCardDark)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(badgeBorderColor(lift.changeType), lineWidth: 1)
        )
    }
    
    // MARK: - Badge
    
    private func changeBadge(_ type: WeeklyStrengthAnalyzer.LiftProgression.ChangeType, description: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon(type))
                .font(.system(size: 10, weight: .bold))
            
            Text(description)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(badgeTextColor(type))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground(type))
        .cornerRadius(6)
    }
    
    private func badgeIcon(_ type: WeeklyStrengthAnalyzer.LiftProgression.ChangeType) -> String {
        switch type {
        case .improved: return "arrow.up"
        case .stable: return "equal"
        case .regressed: return "arrow.down"
        case .noDataThisWeek: return "minus"
        case .newLift: return "sparkle"
        }
    }
    
    private func badgeTextColor(_ type: WeeklyStrengthAnalyzer.LiftProgression.ChangeType) -> Color {
        switch type {
        case .improved: return .atlasPrimary
        case .stable: return .atlasTextMuted
        case .regressed: return .atlasAccent
        case .noDataThisWeek: return .atlasTextMuted.opacity(0.6)
        case .newLift: return .atlasPrimary
        }
    }
    
    private func badgeBackground(_ type: WeeklyStrengthAnalyzer.LiftProgression.ChangeType) -> Color {
        switch type {
        case .improved: return .atlasPrimary.opacity(0.12)
        case .stable: return .atlasTextMuted.opacity(0.1)
        case .regressed: return .atlasAccent.opacity(0.12)
        case .noDataThisWeek: return .atlasTextMuted.opacity(0.08)
        case .newLift: return .atlasPrimary.opacity(0.12)
        }
    }
    
    private func badgeBorderColor(_ type: WeeklyStrengthAnalyzer.LiftProgression.ChangeType) -> Color {
        switch type {
        case .improved: return .atlasPrimary.opacity(0.2)
        case .stable: return .clear
        case .regressed: return .atlasAccent.opacity(0.15)
        case .noDataThisWeek: return .clear
        case .newLift: return .atlasPrimary.opacity(0.15)
        }
    }
}