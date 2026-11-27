import Foundation

// MARK: - Coaching Engine Input

struct WeeklyCheckInData {
    // Pace
    let paceStart: Double
    let paceEnd: Double
    let paceTrend: String              // "improving", "stable", "worsening"
    let strongestComponent: String     // e.g., "Sleep"
    let weakestComponent: String       // e.g., "VO2 Max"
    let weakestPercentile: Int         // e.g., 23

    // Health Metrics (7-day averages)
    let sleepAvgHours: Double
    let sleepPrevWeekAvg: Double
    let hrvAvg: Double
    let hrvPrevWeekAvg: Double
    let hrvTrend2Week: Double          // % change over 2 weeks (negative = declining)
    let rhrAvg: Double
    let rhrPrevWeekAvg: Double
    let rhrTrend2Week: Double          // bpm change over 2 weeks (positive = increasing)
    let stepsAvg: Int

    // Adherence
    let habitAdherencePercent: Int     // 0-100
    let trainingAdherencePercent: Int  // 0-100
    let sessionsCompleted: Int
    let sessionsPrescribed: Int

    // Habit Detail
    let habits: [HabitWeekData]
    let consecutiveWeeksAbove80: Int   // How many weeks in a row habit adherence > 80%
    let totalActiveHabits: Int         // How many habits user currently has

    // Strength (per-lift)
    let liftProgressions: [LiftProgression]

    // Cardio
    let cardioSessions: Int
    let cardioTotalMinutes: Int
    let cardioPrevWeekMinutes: Int
    let zone2Minutes: Int
    let zone2PercentOfTotal: Double    // 0.0-1.0
    let intervalsDetected: Bool
    let avgIntervalRecoveryBPM: Double? // bpm drop in 60s

    // Deload
    let weeksSinceDeload: Int
    let trainingAdherence2Week: Double // 0.0-1.0

    // User Context (from free-text input in check-in step 4)
    let userContext: String?           // nil or "Traveled", "Was sick", etc.

    // Weight (optional)
    let currentWeight: Double?
    let previousWeight: Double?

    // Zone 2 HR range for coaching text
    let zone2HRRange: String           // e.g., "124-145"
}

struct LiftProgression {
    let exerciseName: String
    let prevE1RM: Double?
    let currentE1RM: Double?
    let changePercent: Double          // Positive = improved
    let weeksStalled: Int              // 0 if progressing
    let hadDataLastWeek: Bool
    let hasDataThisWeek: Bool
}

struct HabitWeekData {
    let habitName: String
    let completedDays: Int             // Out of 7
    let adherencePercent: Int          // 0-100 for this specific habit
    let streakDays: Int                // Current streak
}

// MARK: - Coaching Engine Output

struct WeeklyAnalysis {
    let sections: [CoachingSection]
}

enum SectionType: String, Codable {
    case paceTrend = "paceTrend"
    case biggestWin = "biggestWin"
    case concern = "concern"
    case strength = "strength"
    case cardio = "cardio"
    case habitProgression = "habitProgression"
    case deload = "deload"
    case weeklyFocus = "weeklyFocus"
}

struct CoachingSection: Identifiable {
    let id = UUID()
    let type: SectionType
    let title: String
    let body: String
    let icon: String          // SF Symbol name
    let accentColor: String   // "teal", "amber", "coral"
}

// MARK: - Coaching Engine

struct WeeklyCoachingEngine {

    /// Generates a complete weekly coaching analysis from check-in data.
    /// Sections are returned in display order.
    static func generateAnalysis(data: WeeklyCheckInData) -> WeeklyAnalysis {
        var sections: [CoachingSection] = []

        // 1. Pace trend (ALWAYS present)
        sections.append(analyzePaceTrend(data))

        // 2. Biggest win (ALWAYS present — has a fallback)
        sections.append(identifyBiggestWin(data))

        // 3. Biggest concern (SKIPPED if no concerns)
        if let concern = identifyBiggestConcern(data) {
            sections.append(concern)
        }

        // 4. Strength progression (SKIPPED if no lift data)
        if !data.liftProgressions.isEmpty {
            sections.append(analyzeStrengthProgression(data))
        }

        // 5. Cardio progression (SKIPPED if no sessions)
        if data.cardioSessions > 0 {
            sections.append(analyzeCardioProgression(data))
        }

        // 6. Habit progression (SKIPPED if no actionable insight)
        if let habitRec = analyzeHabitProgression(data) {
            sections.append(habitRec)
        }

        // 7. Deload recommendation (SKIPPED unless all conditions met)
        if let deload = checkDeload(data) {
            sections.append(deload)
        }

        // 8. This week's focus (ALWAYS present — ALWAYS last)
        sections.append(generateWeeklyFocus(data))

        return WeeklyAnalysis(sections: sections)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 1: PACE TREND
    // Always first. Sets the tone for the whole analysis.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func analyzePaceTrend(_ data: WeeklyCheckInData) -> CoachingSection {
        let change = data.paceEnd - data.paceStart
        var body: String

        if change < -0.02 {
            // Improved (lower Pace = aging slower)
            body = "Your Pace dropped from \(f2(data.paceStart)) to \(f2(data.paceEnd)) this week — that's meaningful progress."
            body += " Your \(data.strongestComponent.lowercased()) is driving the improvement."
        } else if change > 0.02 {
            // Worsened
            body = "Your Pace moved from \(f2(data.paceStart)) to \(f2(data.paceEnd)) this week."
            body += " Your \(data.weakestComponent.lowercased()) is the primary factor."
            if let context = data.userContext, !context.isEmpty {
                body += " The \(context.lowercased()) likely played a role."
            } else {
                body += " Check your sleep and recovery — they're usually the first to slip."
            }
        } else {
            // Stable
            body = "Your Pace held steady at \(f2(data.paceEnd)) this week."
            if data.habitAdherencePercent >= 70 {
                body += " You're building a foundation. Consistency compounds."
            } else {
                body += " Adherence slipped to \(data.habitAdherencePercent)% — the data needs more input to move."
            }
        }

        return CoachingSection(
            type: .paceTrend,
            title: "Pace Trend",
            body: body,
            icon: "gauge.with.needle",
            accentColor: change <= 0 ? "teal" : "coral"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 2: BIGGEST WIN
    // Always present. Priority cascade — first match wins.
    // Has a fallback so it never returns empty.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func identifyBiggestWin(_ data: WeeklyCheckInData) -> CoachingSection {
        let body: String
        let paceChange = data.paceStart - data.paceEnd  // Positive = improved

        if paceChange > 0.03 {
            let pct = String(format: "%.1f", paceChange / data.paceStart * 100)
            body = "Pace improved \(pct)% — your biggest move yet."
        }
        // TODO: Check for component tier crossing (Below Average → Above Average, etc.)
        // This requires comparing tier labels from PaceComponent — implement based on
        // your existing tier calculation logic. For now, falls through to next check.
        else if let bestLift = data.liftProgressions.max(by: { $0.changePercent < $1.changePercent }),
                bestLift.changePercent > 5.0 {
            body = "Your \(bestLift.exerciseName) estimated max jumped \(String(format: "%.0f", bestLift.changePercent))%."
        }
        else if data.sleepAvgHours - data.sleepPrevWeekAvg > 0.5 {
            body = "Sleep averaged \(f1(data.sleepAvgHours))h, up from \(f1(data.sleepPrevWeekAvg))h."
        }
        else if data.rhrPrevWeekAvg - data.rhrAvg > 2 {
            body = "Resting heart rate dropped to \(Int(data.rhrAvg)), down from \(Int(data.rhrPrevWeekAvg))."
        }
        else if data.hrvAvg - data.hrvPrevWeekAvg > 5 {
            body = "HRV averaged \(Int(data.hrvAvg))ms, up from \(Int(data.hrvPrevWeekAvg))ms."
        }
        else if data.habitAdherencePercent >= 80 {
            body = "You hit \(data.habitAdherencePercent)% habit adherence this week."
        }
        else if data.trainingAdherencePercent == 100 {
            body = "You didn't miss a single session."
        }
        else {
            body = "Consistency is the win this week. Keep showing up."
        }

        return CoachingSection(
            type: .biggestWin,
            title: "This Week's Win",
            body: body,
            icon: "trophy.fill",
            accentColor: "teal"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 3: BIGGEST CONCERN
    // Skipped if nothing is concerning. Returns nil.
    // Priority cascade — first match wins.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func identifyBiggestConcern(_ data: WeeklyCheckInData) -> CoachingSection? {
        let body: String

        if data.sleepAvgHours < 6.5 {
            body = "Sleep averaged \(f1(data.sleepAvgHours))h — below the 7h minimum. This is limiting everything else."
        }
        else if data.habitAdherencePercent < 40 {
            body = "Habit adherence dropped to \(data.habitAdherencePercent)%. Simplify — which one habit can you commit to?"
        }
        else if data.trainingAdherencePercent < 50 {
            body = "You completed \(data.sessionsCompleted) of \(data.sessionsPrescribed) sessions. What's blocking you?"
        }
        else if data.hrvTrend2Week < -10 {
            body = "HRV is trending down over the past two weeks. Your nervous system needs recovery."
        }
        else if data.rhrTrend2Week > 3 {
            body = "Resting heart rate is creeping up — watch for overtraining or poor sleep."
        }
        else if let worstLift = data.liftProgressions.min(by: { $0.changePercent < $1.changePercent }),
                worstLift.changePercent < -5.0 {
            body = "Your \(worstLift.exerciseName) regressed \(String(format: "%.0f", abs(worstLift.changePercent)))%. Check recovery and sleep."
        }
        else if data.cardioSessions == 0 {
            body = "No cardio sessions this week. Even 20 minutes of Zone 2 moves the needle."
        }
        else if data.stepsAvg < 5000 {
            body = "Daily movement averaged \(data.stepsAvg) steps. Try to get above 7,000."
        }
        else {
            return nil  // No concerns — skip section entirely
        }

        return CoachingSection(
            type: .concern,
            title: "Needs Attention",
            body: body,
            icon: "exclamationmark.triangle.fill",
            accentColor: "coral"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 4: STRENGTH PROGRESSION
    // Skipped if no lift data exists.
    // Per-lift breakdown + summary.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func analyzeStrengthProgression(_ data: WeeklyCheckInData) -> CoachingSection {
        var lines: [String] = []
        var improvedCount = 0
        var stableCount = 0
        var regressedCount = 0

        for lift in data.liftProgressions {
            if !lift.hasDataThisWeek && lift.hadDataLastWeek {
                lines.append("⚠ \(lift.exerciseName): No data this week.")
            } else if lift.hasDataThisWeek {
                if lift.changePercent > 3.0 {
                    if let prev = lift.prevE1RM, let curr = lift.currentE1RM {
                        lines.append("↑ \(lift.exerciseName): \(Int(prev)) → \(Int(curr)) (+\(String(format: "%.0f", lift.changePercent))%)")
                    }
                    improvedCount += 1
                } else if lift.changePercent < -3.0 {
                    if let prev = lift.prevE1RM, let curr = lift.currentE1RM {
                        lines.append("↓ \(lift.exerciseName): Down from \(Int(prev)) to \(Int(curr))")
                    }
                    regressedCount += 1
                } else {
                    if let curr = lift.currentE1RM {
                        lines.append("→ \(lift.exerciseName): Holding at \(Int(curr)). Add a rep next session.")
                    }
                    stableCount += 1
                }
            }
        }

        // Summary
        let summary: String
        if improvedCount == data.liftProgressions.count && improvedCount > 0 {
            summary = "Every lift progressed. You're in a growth phase."
        } else if regressedCount == data.liftProgressions.count && regressedCount > 0 {
            summary = "Across-the-board regression usually means recovery debt. Consider a deload."
        } else {
            var parts: [String] = []
            if improvedCount > 0 { parts.append("\(improvedCount) improved") }
            if stableCount > 0 { parts.append("\(stableCount) stable") }
            if regressedCount > 0 { parts.append("\(regressedCount) regressed") }
            summary = parts.isEmpty ? "Limited data this week." : parts.joined(separator: ", ") + "."
        }

        let body = lines.isEmpty ? summary : lines.joined(separator: "\n") + "\n\n" + summary

        return CoachingSection(
            type: .strength,
            title: "Strength",
            body: body,
            icon: "dumbbell.fill",
            accentColor: regressedCount > improvedCount ? "amber" : "teal"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 5: CARDIO PROGRESSION
    // Skipped if no cardio sessions this week.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func analyzeCardioProgression(_ data: WeeklyCheckInData) -> CoachingSection {
        var lines: [String] = []

        // Volume change
        let volumeChange = data.cardioTotalMinutes - data.cardioPrevWeekMinutes
        if volumeChange > 10 {
            lines.append("Cardio volume increased to \(data.cardioTotalMinutes) minutes from \(data.cardioPrevWeekMinutes).")
        } else if volumeChange < -10 {
            lines.append("Cardio volume dropped to \(data.cardioTotalMinutes) minutes from \(data.cardioPrevWeekMinutes).")
        } else {
            lines.append("\(data.cardioSessions) sessions, \(data.cardioTotalMinutes) minutes total.")
        }

        // Zone 2 discipline
        if data.zone2PercentOfTotal > 0.70 {
            lines.append("Good Zone 2 discipline — \(data.zone2Minutes) of \(data.cardioTotalMinutes) minutes in the aerobic range.")
        } else if data.zone2PercentOfTotal < 0.40 && data.cardioSessions > 1 {
            lines.append("Most of your cardio was above Zone 2. Slow down — longevity cardio should feel conversational.")
        }

        // Interval recovery
        if data.intervalsDetected, let recovery = data.avgIntervalRecoveryBPM {
            if recovery > 25 {
                lines.append("Interval recovery is strong at \(Int(recovery)) bpm drop. Your cardiac fitness is solid.")
            } else if recovery < 15 {
                lines.append("Interval recovery is sluggish at \(Int(recovery)) bpm drop. You may need more rest between efforts.")
            }
        }

        return CoachingSection(
            type: .cardio,
            title: "Cardio",
            body: lines.joined(separator: "\n"),
            icon: "heart.fill",
            accentColor: "teal"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 6: HABIT PROGRESSION
    // Skipped if no actionable insight. Returns nil.
    // Covers: add habits, swap weak habits, simplify.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func analyzeHabitProgression(_ data: WeeklyCheckInData) -> CoachingSection? {
        let habits = data.habits
        guard !habits.isEmpty else { return nil }

        let strongHabits = habits.filter { $0.adherencePercent >= 80 }
        let weakHabits = habits.filter { $0.adherencePercent < 40 }
        let totalHabits = data.totalActiveHabits

        // Priority 1: Crushing all habits for 3+ weeks with room to add more
        if data.consecutiveWeeksAbove80 >= 3 && totalHabits < 5 {
            let topHabit = strongHabits.max(by: { $0.streakDays < $1.streakDays })
            let streakNote = topHabit != nil ? " \(topHabit!.habitName) is on a \(topHabit!.streakDays)-day streak." : ""
            return CoachingSection(
                type: .habitProgression,
                title: "Ready for More",
                body: "You've been above 80% adherence for \(data.consecutiveWeeksAbove80) weeks straight.\(streakNote) Your foundation is solid — consider adding one more habit.",
                icon: "plus.circle.fill",
                accentColor: "teal"
            )
        }

        // Priority 2: One weak habit dragging down an otherwise strong set
        if strongHabits.count >= totalHabits - 1 && weakHabits.count == 1 {
            let weak = weakHabits[0]
            return CoachingSection(
                type: .habitProgression,
                title: "Habit Check",
                body: "You're consistent with \(strongHabits.count) of \(totalHabits) habits, but \(weak.habitName) is at \(weak.adherencePercent)%. Either swap it for something you'll actually do, or drop it and lock in the \(strongHabits.count) that are working.",
                icon: "arrow.triangle.swap",
                accentColor: "amber"
            )
        }

        // Priority 3: Only 1-2 habits and crushing them → nudge to add
        if totalHabits <= 2 && data.habitAdherencePercent >= 80 && data.consecutiveWeeksAbove80 >= 2 {
            return CoachingSection(
                type: .habitProgression,
                title: "Layer Up",
                body: "You've locked in \(totalHabits == 1 ? "your habit" : "both habits") for \(data.consecutiveWeeksAbove80) weeks. That's the foundation. Adding one more won't overwhelm you now.",
                icon: "arrow.up.circle.fill",
                accentColor: "teal"
            )
        }

        // Priority 4: Multiple weak habits → suggest simplifying
        if weakHabits.count >= 2 {
            return CoachingSection(
                type: .habitProgression,
                title: "Simplify",
                body: "\(weakHabits.count) of your \(totalHabits) habits are below 40%. That's a signal you have too many. Drop the ones that aren't sticking and focus on the \(strongHabits.count > 0 ? "\(strongHabits.count)" : "1-2") you can actually commit to.",
                icon: "minus.circle.fill",
                accentColor: "coral"
            )
        }

        // No actionable insight
        return nil
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 7: DELOAD RECOMMENDATION
    // Only appears when ALL three conditions are met.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func checkDeload(_ data: WeeklyCheckInData) -> CoachingSection? {
        guard data.weeksSinceDeload >= 5,
              data.trainingAdherence2Week > 0.75,
              data.hrvTrend2Week < -10 else {
            return nil
        }

        return CoachingSection(
            type: .deload,
            title: "Deload Recommended",
            body: "You've trained hard for \(data.weeksSinceDeload) weeks with strong adherence, but your HRV is declining. Take a deload week: same exercises, cut volume by 50%. If you normally do 3 sets, do 2. If you run 45 minutes, run 25. This isn't stepping backward — it's letting your nervous system catch up with your muscles.",
            icon: "battery.25percent",
            accentColor: "amber"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SECTION 8: THIS WEEK'S FOCUS
    // Always last. ONE action. Priority cascade.
    // Styled distinctly from other cards (amber border).
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func generateWeeklyFocus(_ data: WeeklyCheckInData) -> CoachingSection {
        let body: String

        if data.sleepAvgHours < 7.0 {
            body = "Get your sleep above 7 hours. Everything else improves when sleep does."
        }
        else if data.habitAdherencePercent < 50 {
            body = "Focus on hitting your habits. Aim for 70%+ this week."
        }
        else if data.trainingAdherencePercent < 60 {
            body = "Make your sessions. \(data.sessionsPrescribed) sessions this week — put them in the calendar."
        }
        else if data.weakestPercentile < 30 {
            body = generateComponentAdvice(component: data.weakestComponent, percentile: data.weakestPercentile, data: data)
        }
        else if data.liftProgressions.filter({ $0.weeksStalled >= 3 }).count >= 2 {
            body = "Progressive overload has stalled. Add one rep per set across your main lifts this week."
        }
        else if data.cardioSessions == 0 {
            body = "Add one Zone 2 session this week. 20-30 minutes, keep your heart rate in the \(data.zone2HRRange) range."
        }
        else {
            body = "Stay the course. Consistency is compounding — your Pace reflects it."
        }

        return CoachingSection(
            type: .weeklyFocus,
            title: "This Week's Focus",
            body: body,
            icon: "target",
            accentColor: "amber"
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // HELPERS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static func generateComponentAdvice(component: String, percentile: Int, data: WeeklyCheckInData) -> String {
        switch component.lowercased() {
        case "sleep":
            return "Your weakest component is sleep at the \(percentile)th percentile. Prioritize getting to bed 30 minutes earlier this week."
        case "hrv":
            return "Your weakest component is HRV at the \(percentile)th percentile. Focus on recovery — cut alcohol, manage stress, prioritize sleep."
        case "resting heart rate", "rhr":
            return "Your weakest component is resting heart rate at the \(percentile)th percentile. Add Zone 2 cardio — it's the fastest way to bring RHR down."
        case "vo2 max", "vo2max":
            return "Your weakest component is VO2 Max at the \(percentile)th percentile. Add one high-intensity interval session this week."
        case "strength":
            return "Your weakest component is strength at the \(percentile)th percentile. Focus on progressive overload — add weight or reps to your compounds."
        case "daily movement", "movement", "steps":
            return "Your weakest component is daily movement at the \(percentile)th percentile. Aim for 8,000+ steps daily — walk after meals."
        default:
            return "Your weakest component is \(component) at the \(percentile)th percentile. Focus your energy there this week."
        }
    }

    private static func f2(_ val: Double) -> String { String(format: "%.2f", val) }
    private static func f1(_ val: Double) -> String { String(format: "%.1f", val) }
}