import Foundation
import SwiftData

// MARK: - Morning Brief Output

/// The generated brief to display in the Morning Brief Card.
struct MorningBrief {
    let dayNumber: Int
    let headline: String
    let body: String
    let todayPreview: String?
    let accentColor: String    // "teal", "amber", "coral"
    let icon: String           // SF Symbol name
    let varietyKey: String     // Category for variety enforcement
}

// MARK: - Morning Brief Engine

/// Deterministic priority cascade that generates a personalized daily brief.
///
/// Priority order (first match wins):
///   P1: Milestones — Day milestones, first PR, Pace < 1.0, longest streak broken
///   P2: Recovery Alerts — Bad sleep, HRV crash, RHR spike
///   P3+: Component Wins — Any component percentile gained ≥5 points
///   P3: Positive Patterns — Sleep streaks, HRV trending up, high adherence
///   P4: Honest Coaching — Low adherence, sleep declining, no workouts
///   P5: Training Preview — Today's training day context
///   P6: Days Gained — Monday + Pace < 1.0 → annual projection
///   P7: Default Fallback — Always fires, needs only dayNumber + streak
struct MorningBriefEngine {

    // MARK: - Public Entry Point

    static func generateBrief(
        profile: UserProfile,
        dayNumber: Int,
        currentStreak: Int,
        lastNightSleep: Double?,              // hours
        sleepAvg7Day: Double?,                // hours
        consecutiveNightsAbove7: Int,
        hrvYesterday: Double?,
        hrvAvg7Day: Double?,
        hrvAvg14Day: Double?,
        rhrYesterday: Double?,
        rhrAvg7Day: Double?,
        latestPace: BiologicalPaceScore?,
        paceBaseline: Double?,
        componentWin: (component: String, delta: Double, currentPercentile: Double)?,
        adherence7Day: Double,                // 0.0–1.0
        recentPRs: [PersonalRecord],          // last 7 days
        todaysTrainingDayName: String?,       // "Upper Push", "Lower Body", "Zone 2 Cardio", nil
        todaysTrainingDayType: String?,       // "strength", "cardio", "rest", nil
        workoutsLast7Days: Int,
        totalWorkoutsLogged: Int,
        habitCount: Int,
        userName: String
    ) -> MorningBrief {

        // Build candidate list top-to-bottom through priority cascade.
        // First non-nil result that passes variety check wins.
        let candidates: [() -> MorningBrief?] = [
            // P1 — Milestones
            { p1_dayMilestone(dayNumber: dayNumber, currentStreak: currentStreak, latestPace: latestPace, adherence7Day: adherence7Day, userName: userName) },
            { p1_firstPR(recentPRs: recentPRs, totalWorkoutsLogged: totalWorkoutsLogged, dayNumber: dayNumber) },
            { p1_paceCrossesOne(latestPace: latestPace, paceBaseline: paceBaseline, dayNumber: dayNumber) },
            { p1_longestStreakBroken(currentStreak: currentStreak, profile: profile, dayNumber: dayNumber) },

            // P2 — Recovery Alerts
            { p2_recoveryAlert(lastNightSleep: lastNightSleep, hrvYesterday: hrvYesterday, hrvAvg7Day: hrvAvg7Day, rhrYesterday: rhrYesterday, rhrAvg7Day: rhrAvg7Day, dayNumber: dayNumber, todaysTrainingDayName: todaysTrainingDayName, todaysTrainingDayType: todaysTrainingDayType) },

            // P3+ — Component Wins
            { p3plus_componentWin(componentWin: componentWin, dayNumber: dayNumber) },

            // P3 — Positive Patterns
            { p3_sleepStreak(consecutiveNightsAbove7: consecutiveNightsAbove7, dayNumber: dayNumber) },
            { p3_hrvTrendingUp(hrvAvg7Day: hrvAvg7Day, hrvAvg14Day: hrvAvg14Day, dayNumber: dayNumber) },
            { p3_highAdherence(adherence7Day: adherence7Day, dayNumber: dayNumber, currentStreak: currentStreak) },
            { p3_trainingPositive(workoutsLast7Days: workoutsLast7Days, totalWorkoutsLogged: totalWorkoutsLogged, dayNumber: dayNumber) },
            { p3_multiplePositive(adherence7Day: adherence7Day, consecutiveNightsAbove7: consecutiveNightsAbove7, hrvAvg7Day: hrvAvg7Day, hrvAvg14Day: hrvAvg14Day, workoutsLast7Days: workoutsLast7Days, dayNumber: dayNumber) },
            { p3_recentPR(recentPRs: recentPRs, totalWorkoutsLogged: totalWorkoutsLogged, dayNumber: dayNumber) },
            { p3_streakApproaching(currentStreak: currentStreak, dayNumber: dayNumber) },

            // P4 — Honest Coaching
            { p4_slidingAdherence(adherence7Day: adherence7Day, dayNumber: dayNumber) },
            { p4_lowTrainingVolume(workoutsLast7Days: workoutsLast7Days, dayNumber: dayNumber, todaysTrainingDayType: todaysTrainingDayType) },
            { p4_honestCoaching(adherence7Day: adherence7Day, lastNightSleep: lastNightSleep, sleepAvg7Day: sleepAvg7Day, consecutiveNightsAbove7: consecutiveNightsAbove7, workoutsLast7Days: workoutsLast7Days, dayNumber: dayNumber) },

            // P5 — Training Preview
            { p5_trainingPreview(todaysTrainingDayName: todaysTrainingDayName, todaysTrainingDayType: todaysTrainingDayType, hrvYesterday: hrvYesterday, hrvAvg7Day: hrvAvg7Day, totalWorkoutsLogged: totalWorkoutsLogged, dayNumber: dayNumber) },

            // P6 — Days Gained
            { p6_daysGained(latestPace: latestPace, paceBaseline: paceBaseline, dayNumber: dayNumber) },

            // P7 — Default Fallback (always returns non-nil)
            { p7_defaultFallback(dayNumber: dayNumber, currentStreak: currentStreak, habitCount: habitCount, lastNightSleep: lastNightSleep, latestPace: latestPace, userName: userName, todaysTrainingDayName: todaysTrainingDayName, todaysTrainingDayType: todaysTrainingDayType) },
        ]

        // Walk cascade with variety enforcement
        let lastVarietyKey = profile.lastBriefVarietyKey
        let wasYesterday: Bool = {
            guard let lastDate = profile.lastBriefDate else { return false }
            return Calendar.current.isDateInYesterday(lastDate)
        }()

        for candidateFn in candidates {
            guard let brief = candidateFn() else { continue }

            // Variety check: skip if same varietyKey as yesterday (unless it's the only option left)
            if wasYesterday, brief.varietyKey == lastVarietyKey {
                // Allow P7 fallback to always pass — it's the last resort
                if brief.varietyKey == "daily_summary" || brief.varietyKey.hasPrefix("daily_welcome") {
                    return brief
                }
                continue
            }

            return brief
        }

        // Absolute fallback (should never reach here — P7 always returns)
        return MorningBrief(
            dayNumber: dayNumber,
            headline: "Day \(dayNumber).",
            body: "Your habits are waiting. Show up today.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "calendar",
            varietyKey: "daily_summary"
        )
    }

    // =========================================================================
    // MARK: - P1: MILESTONES
    // =========================================================================

    /// Day milestone briefs: 7, 14, 21, 30, 60, 90, 180, 365
    private static func p1_dayMilestone(
        dayNumber: Int,
        currentStreak: Int,
        latestPace: BiologicalPaceScore?,
        adherence7Day: Double,
        userName: String
    ) -> MorningBrief? {
        let milestones: [Int: (headline: String, body: String)] = [
            7: (
                "One week in.",
                "Seven days ago you made a decision. You're still here. That's not motivation — that's identity. Most people never make it past day 3."
            ),
            14: (
                "Two weeks. The hard part is over.",
                "You've built a foundation that most people never build. The data is starting to accumulate. Patterns are forming. Keep stacking days."
            ),
            21: (
                "Three weeks. This is who you are now.",
                "Research says 21 days starts to rewire behavior. You're not trying anymore — you're becoming. The habits are less effort now. That's the point."
            ),
            30: (
                "30 days. Unbreakable.",
                "A full month of showing up. Your body has adapted, your metrics have data, and your habits have roots. This is no longer an experiment — it's your operating system."
            ),
            60: (
                "60 days. Two months of proof.",
                "Most fitness apps see 90% drop-off by day 30. You doubled that. The compound effect is real — your body is changing in ways the data captures and ways it doesn't."
            ),
            90: (
                "90 days. Quarter of a year.",
                "Three months of consistent execution. If you started with sleep debt, it's likely repaid. If your HRV was low, it's climbing. You've earned every data point."
            ),
            180: (
                "Six months. Half a year.",
                "180 days of building a longer, stronger life. The person who started this journey wouldn't recognize the data you're producing now. This is mastery."
            ),
            365: (
                "One year. 365 days.",
                "You did what almost nobody does: you showed up every single day for a year. This isn't a habit anymore. This is who you are. The data tells a story of transformation."
            ),
        ]

        guard let milestone = milestones[dayNumber] else { return nil }

        // Add context stats where available
        var bodyText = milestone.body
        if let pace = latestPace {
            bodyText += " Your Pace is \(String(format: "%.2f", pace.paceValue))."
        }
        if currentStreak > 0 {
            bodyText += " Current streak: \(currentStreak) days."
        }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: milestone.headline,
            body: bodyText,
            todayPreview: nil,
            accentColor: "teal",
            icon: "star.fill",
            varietyKey: "milestone"
        )
    }

    /// First-ever PR celebration
    private static func p1_firstPR(
        recentPRs: [PersonalRecord],
        totalWorkoutsLogged: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        guard !recentPRs.isEmpty else { return nil }
        // Only fire if these are among the user's very first PRs (total workouts < 5)
        guard totalWorkoutsLogged <= 5 else { return nil }

        let prName = recentPRs.first?.exerciseName.replacingOccurrences(of: "-", with: " ").capitalized ?? "an exercise"

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "First PR in the books.",
            body: "You set a personal record on \(prName). This is your baseline — everything from here is improvement. The tracking starts now.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "trophy.fill",
            varietyKey: "first_pr"
        )
    }

    /// Pace crosses below 1.0 for the first time
    private static func p1_paceCrossesOne(
        latestPace: BiologicalPaceScore?,
        paceBaseline: Double?,
        dayNumber: Int
    ) -> MorningBrief? {
        guard let pace = latestPace,
              pace.paceValue < 1.0,
              let baseline = paceBaseline,
              baseline >= 1.0 else { return nil }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "You're aging slower than time.",
            body: "Your Pace dropped below 1.0 — that means your biological systems are outperforming your chronological age. That's not motivation. That's math. Your baseline was \(String(format: "%.2f", baseline)). You're now at \(String(format: "%.2f", pace.paceValue)).",
            todayPreview: nil,
            accentColor: "teal",
            icon: "bolt.fill",
            varietyKey: "pace_milestone"
        )
    }

    /// Longest streak ever broken
    private static func p1_longestStreakBroken(
        currentStreak: Int,
        profile: UserProfile,
        dayNumber: Int
    ) -> MorningBrief? {
        guard currentStreak >= 7,
              currentStreak == profile.longestStreakEver else { return nil }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "New personal best: \(currentStreak) days.",
            body: "You just broke your longest streak ever. \(currentStreak) consecutive days of showing up. Not perfect days — completed days. That's the difference between people who transform and people who try.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "flame.fill",
            varietyKey: "streak_record"
        )
    }

    // =========================================================================
    // MARK: - P2: RECOVERY ALERTS
    // =========================================================================

    private static func p2_recoveryAlert(
        lastNightSleep: Double?,
        hrvYesterday: Double?,
        hrvAvg7Day: Double?,
        rhrYesterday: Double?,
        rhrAvg7Day: Double?,
        dayNumber: Int,
        todaysTrainingDayName: String?,
        todaysTrainingDayType: String?
    ) -> MorningBrief? {

        let badSleep = lastNightSleep != nil && lastNightSleep! < 5.5
        let hrvCrash: Bool = {
            guard let hrv = hrvYesterday, let avg = hrvAvg7Day, avg > 0 else { return false }
            return (avg - hrv) / avg > 0.20
        }()
        let rhrSpike: Bool = {
            guard let rhr = rhrYesterday, let avg = rhrAvg7Day, avg > 0 else { return false }
            return (rhr - avg) / avg > 0.10
        }()

        // Count how many signals fired
        let alertCount = [badSleep, hrvCrash, rhrSpike].filter { $0 }.count
        guard alertCount > 0 else { return nil }

        let trainingNote: String = {
            if let dayType = todaysTrainingDayType {
                if dayType == "strength" || dayType == "cardio" {
                    return " If today's session feels off, cut the volume. A 60% effort day beats a skipped day."
                }
            }
            return ""
        }()

        if alertCount >= 2 {
            // Combined recovery alert
            var details: [String] = []
            if badSleep { details.append("sleep was under 5.5 hours") }
            if hrvCrash { details.append("HRV dropped significantly") }
            if rhrSpike { details.append("resting heart rate is elevated") }
            let detailStr = details.joined(separator: ", ")

            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Your body is asking for recovery.",
                body: "Multiple signals are flagged: \(detailStr). This isn't a failure — it's data. Prioritize sleep tonight, hydrate, and keep stress low.\(trainingNote)",
                todayPreview: nil,
                accentColor: "coral",
                icon: "heart.fill",
                varietyKey: "recovery_alert"
            )
        }

        if badSleep {
            let sleepStr = String(format: "%.1f", lastNightSleep!)
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Rough night, honest day.",
                body: "You got \(sleepStr) hours last night. Everything downstream — energy, focus, recovery — takes a hit. Today's priority is simple: protect tonight's sleep. Get to bed early.\(trainingNote)",
                todayPreview: nil,
                accentColor: "coral",
                icon: "moon.fill",
                varietyKey: "recovery_alert"
            )
        }

        if hrvCrash {
            let hrvStr = String(format: "%.0f", hrvYesterday!)
            let avgStr = String(format: "%.0f", hrvAvg7Day!)
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "HRV dropped — listen to it.",
                body: "Your HRV hit \(hrvStr) versus your 7-day average of \(avgStr). That's a meaningful dip. Common causes: poor sleep, stress, alcohol, or overtraining. Today, ease off if you can.\(trainingNote)",
                todayPreview: nil,
                accentColor: "coral",
                icon: "heart.fill",
                varietyKey: "recovery_alert"
            )
        }

        // RHR spike
        let rhrStr = String(format: "%.0f", rhrYesterday!)
        let rhrAvgStr = String(format: "%.0f", rhrAvg7Day!)
        return MorningBrief(
            dayNumber: dayNumber,
            headline: "Resting heart rate is up.",
            body: "Your RHR is \(rhrStr) bpm versus your average of \(rhrAvgStr). An elevated RHR often signals stress, dehydration, or incomplete recovery. Focus on the basics today: water, food, sleep.\(trainingNote)",
            todayPreview: nil,
            accentColor: "coral",
            icon: "heart.fill",
            varietyKey: "recovery_alert"
        )
    }

    // =========================================================================
    // MARK: - P3+: COMPONENT WINS
    // =========================================================================

    private static func p3plus_componentWin(
        componentWin: (component: String, delta: Double, currentPercentile: Double)?,
        dayNumber: Int
    ) -> MorningBrief? {
        guard let win = componentWin else { return nil }

        let deltaStr = String(format: "%.0f", win.delta)
        let percentileStr = String(format: "%.0f", win.currentPercentile)

        let componentInsight: String
        switch win.component {
        case "Sleep":
            componentInsight = "Better sleep cascades into everything — HRV, recovery, cognitive function. This is foundational."
        case "HRV":
            componentInsight = "Higher HRV means better autonomic flexibility. Your nervous system is adapting to the work."
        case "Resting HR":
            componentInsight = "A lower resting heart rate reflects improved cardiac efficiency. Your heart is getting stronger."
        case "VO₂ Max":
            componentInsight = "VO₂ Max is the single strongest predictor of all-cause mortality. Moving this number matters."
        case "Daily Movement":
            componentInsight = "Consistent daily movement reduces all-cause mortality risk independent of structured exercise."
        case "Strength":
            componentInsight = "Grip strength and muscle mass are among the strongest predictors of longevity. Keep loading."
        default:
            componentInsight = "Consistency is driving this improvement."
        }

        let iconName: String
        switch win.component {
        case "Sleep": iconName = "moon.fill"
        case "HRV": iconName = "waveform.path.ecg"
        case "Resting HR": iconName = "heart.fill"
        case "VO₂ Max": iconName = "lungs.fill"
        case "Daily Movement": iconName = "figure.walk"
        case "Strength": iconName = "figure.strengthtraining.traditional"
        default: iconName = "arrow.up.right"
        }

        let varietyKeySuffix = win.component.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "₂", with: "2")

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "\(win.component) is climbing.",
            body: "Your \(win.component) percentile jumped \(deltaStr) points this week — you're now at the \(percentileStr)th percentile. \(componentInsight)",
            todayPreview: nil,
            accentColor: "teal",
            icon: iconName,
            varietyKey: "component_win_\(varietyKeySuffix)"
        )
    }

    // =========================================================================
    // MARK: - P3: POSITIVE PATTERNS
    // =========================================================================

    private static func p3_sleepStreak(
        consecutiveNightsAbove7: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        if consecutiveNightsAbove7 >= 7 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "A full week of quality sleep.",
                body: "Seven consecutive nights above 7 hours. Sleep is the single most impactful lever for longevity, and you're nailing it. Your HRV, recovery, and cognitive function all benefit from this consistency.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "moon.stars.fill",
                varietyKey: "sleep_positive"
            )
        }
        if consecutiveNightsAbove7 >= 3 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Sleep is clicking.",
                body: "\(consecutiveNightsAbove7) nights in a row above 7 hours. That's when the compound effect kicks in — your body isn't just recovering, it's rebuilding. Protect this streak.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "moon.fill",
                varietyKey: "sleep_positive"
            )
        }
        return nil
    }

    private static func p3_hrvTrendingUp(
        hrvAvg7Day: Double?,
        hrvAvg14Day: Double?,
        dayNumber: Int
    ) -> MorningBrief? {
        guard let recent = hrvAvg7Day, let prior = hrvAvg14Day, prior > 0 else { return nil }
        let improvement = recent - prior
        guard improvement >= 3.0 else { return nil }  // Meaningful HRV improvement

        let improvStr = String(format: "%.0f", improvement)

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "Your HRV is climbing.",
            body: "Your 7-day HRV average is up \(improvStr) points compared to the prior week. That's your autonomic nervous system telling you the work is paying off. Sleep, recovery, and training load are dialing in.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "waveform.path.ecg",
            varietyKey: "hrv_positive"
        )
    }

    private static func p3_highAdherence(
        adherence7Day: Double,
        dayNumber: Int,
        currentStreak: Int
    ) -> MorningBrief? {
        if adherence7Day >= 0.90 && dayNumber >= 14 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "You haven't missed a beat.",
                body: "Over 90% adherence this week. That's not willpower — that's systems. The habits are automatic now. \(currentStreak > 7 ? "Your \(currentStreak)-day streak proves it." : "Keep stacking.")",
                todayPreview: nil,
                accentColor: "teal",
                icon: "checkmark.seal.fill",
                varietyKey: "adherence_positive"
            )
        }
        if adherence7Day >= 0.80 && dayNumber >= 21 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Consistency is your superpower.",
                body: "80%+ adherence sustained over multiple weeks. Research shows this is the threshold where real physiological adaptation happens. You're not just checking boxes — you're changing your biology.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "checkmark.seal.fill",
                varietyKey: "adherence_positive"
            )
        }
        return nil
    }

    private static func p3_streakApproaching(
        currentStreak: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        let nextMilestones = [7, 14, 21, 30, 50, 100]
        for milestone in nextMilestones {
            if currentStreak == milestone - 1 {
                return MorningBrief(
                    dayNumber: dayNumber,
                    headline: "Tomorrow is day \(milestone).",
                    body: "You're one day away from a \(milestone)-day streak. Don't think about tomorrow — just finish today. The milestone takes care of itself.",
                    todayPreview: nil,
                    accentColor: "teal",
                    icon: "flame.fill",
                    varietyKey: "streak_approaching"
                )
            }
        }
        return nil
    }

    /// Training volume positive — workouts logged consistently
    private static func p3_trainingPositive(
        workoutsLast7Days: Int,
        totalWorkoutsLogged: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        guard dayNumber > 14 else { return nil }

        if workoutsLast7Days >= 4 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "You're putting in the work.",
                body: "\(workoutsLast7Days) sessions logged this week. Training volume is where strength gains and VO₂ improvements live. You've logged \(totalWorkoutsLogged) total sessions — that's a real body of work.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "figure.strengthtraining.traditional",
                varietyKey: "training_positive"
            )
        }
        if workoutsLast7Days >= 3 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Solid training week.",
                body: "\(workoutsLast7Days) workouts in the last 7 days. Consistency beats perfection — you don't need to train every day, you need to train most weeks. You're doing that.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "figure.strengthtraining.traditional",
                varietyKey: "training_positive"
            )
        }
        return nil
    }

    /// Multiple positive signals firing at once
    private static func p3_multiplePositive(
        adherence7Day: Double,
        consecutiveNightsAbove7: Int,
        hrvAvg7Day: Double?,
        hrvAvg14Day: Double?,
        workoutsLast7Days: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        guard dayNumber > 14 else { return nil }

        var positiveCount = 0
        if adherence7Day >= 0.80 { positiveCount += 1 }
        if consecutiveNightsAbove7 >= 3 { positiveCount += 1 }
        if let recent = hrvAvg7Day, let prior = hrvAvg14Day, prior > 0, recent > prior { positiveCount += 1 }
        if workoutsLast7Days >= 3 { positiveCount += 1 }

        guard positiveCount >= 3 else { return nil }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "Everything is trending up.",
            body: "Sleep, adherence, training, recovery — multiple signals are green. This is what it looks like when the system is working. Don't change anything. Just keep executing.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "arrow.up.right",
            varietyKey: "multiple_positive"
        )
    }

    /// Recent PR celebration (not first-ever, but recent)
    private static func p3_recentPR(
        recentPRs: [PersonalRecord],
        totalWorkoutsLogged: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        // Skip if these are first-ever PRs (handled by P1)
        guard totalWorkoutsLogged > 5, !recentPRs.isEmpty else { return nil }

        let prName = recentPRs.first?.exerciseName.replacingOccurrences(of: "-", with: " ").capitalized ?? "an exercise"
        let prCount = recentPRs.count

        if prCount >= 3 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "\(prCount) PRs this week.",
                body: "You hit personal records on \(prCount) exercises. Progressive overload is working — your body is adapting to the stimulus and getting stronger. Keep pushing the edge.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "trophy.fill",
                varietyKey: "pr_celebration"
            )
        }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "New PR on \(prName).",
            body: "You beat your previous best. That's not luck — that's the compound effect of consistent training. Every session builds on the last.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "trophy.fill",
            varietyKey: "pr_celebration"
        )
    }

    // =========================================================================
    // MARK: - P4: HONEST COACHING
    // =========================================================================

    /// Sliding adherence — was high, now dropping
    private static func p4_slidingAdherence(
        adherence7Day: Double,
        dayNumber: Int
    ) -> MorningBrief? {
        // Detect the "was good, now slipping" pattern
        // If adherence is between 60-75% and we're past the honeymoon phase
        guard dayNumber > 21, adherence7Day >= 0.60, adherence7Day < 0.75 else { return nil }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "Something shifted.",
            body: "Your adherence is at \(Int(adherence7Day * 100))% — not terrible, but down from your usual. This is the point where most people slowly drift. What changed this week? Identify the friction and remove it. One adjustment can reset the trend.",
            todayPreview: nil,
            accentColor: "amber",
            icon: "exclamationmark.triangle.fill",
            varietyKey: "adherence_sliding"
        )
    }

    /// Low workout count but not zero
    private static func p4_lowTrainingVolume(
        workoutsLast7Days: Int,
        dayNumber: Int,
        todaysTrainingDayType: String?
    ) -> MorningBrief? {
        guard dayNumber > 14, workoutsLast7Days == 1 else { return nil }
        // Only fire if today is a training day — gives them the nudge when it matters
        guard let dayType = todaysTrainingDayType, dayType == "strength" || dayType == "cardio" else { return nil }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "One session this week.",
            body: "You got one workout in — better than zero. But your plan calls for more. If time is the constraint, even a 20-minute session counts. Today's a chance to add to the tally.",
            todayPreview: nil,
            accentColor: "amber",
            icon: "figure.strengthtraining.traditional",
            varietyKey: "training_nudge"
        )
    }

    private static func p4_honestCoaching(
        adherence7Day: Double,
        lastNightSleep: Double?,
        sleepAvg7Day: Double?,
        consecutiveNightsAbove7: Int,
        workoutsLast7Days: Int,
        dayNumber: Int
    ) -> MorningBrief? {

        // No workout in 5+ days
        if workoutsLast7Days == 0 && dayNumber > 7 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "It's been a while.",
                body: "No workouts logged in the last 7 days. Life happens — no judgment. But momentum is real, and the longer the gap, the harder the restart. Today doesn't need to be perfect. It just needs to happen.",
                todayPreview: nil,
                accentColor: "amber",
                icon: "arrow.uturn.left",
                varietyKey: "training_nudge"
            )
        }

        // Low adherence
        if adherence7Day < 0.60 && dayNumber > 7 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Let's simplify.",
                body: "Your adherence dropped below 60% this week. That usually means the protocol has too much friction. What's the one habit that feels hardest right now? Consider cutting back to just 2 core habits until the rhythm returns.",
                todayPreview: nil,
                accentColor: "amber",
                icon: "hand.raised.fill",
                varietyKey: "adherence_nudge"
            )
        }

        // Sleep trending down
        if let avg = sleepAvg7Day, let lastNight = lastNightSleep,
           lastNight < 6.5 && avg < 6.5 && consecutiveNightsAbove7 == 0 && dayNumber > 5 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Your sleep needs attention.",
                body: "Your recent sleep average is under 6.5 hours. Sleep is the foundation everything else is built on — training adaptations, HRV recovery, cognitive function. Tonight: no screens 30 minutes before bed. That's the intervention.",
                todayPreview: nil,
                accentColor: "amber",
                icon: "moon.fill",
                varietyKey: "sleep_nudge"
            )
        }

        return nil
    }

    // =========================================================================
    // MARK: - P5: TRAINING PREVIEW
    // =========================================================================

    private static func p5_trainingPreview(
        todaysTrainingDayName: String?,
        todaysTrainingDayType: String?,
        hrvYesterday: Double?,
        hrvAvg7Day: Double?,
        totalWorkoutsLogged: Int,
        dayNumber: Int
    ) -> MorningBrief? {
        guard let dayType = todaysTrainingDayType else { return nil }
        let dayName = todaysTrainingDayName ?? dayType.capitalized

        if dayType == "rest" {
            // Rest day variants based on HRV
            if let hrv = hrvYesterday, let avg = hrvAvg7Day, avg > 0 {
                let ratio = hrv / avg
                if ratio >= 1.05 {
                    return MorningBrief(
                        dayNumber: dayNumber,
                        headline: "Rest day. You've earned it.",
                        body: "Your HRV is above average — your body is recovering well. Use today for mobility, a walk, or just doing nothing. Recovery is where adaptation happens.",
                        todayPreview: "Today: Rest day.",
                        accentColor: "teal",
                        icon: "leaf.fill",
                        varietyKey: "rest_day"
                    )
                } else if ratio < 0.85 {
                    return MorningBrief(
                        dayNumber: dayNumber,
                        headline: "Rest day. Your HRV says you need this.",
                        body: "Your HRV is below your average — your body is still processing recent stress or training. Today is about recovery. Hydrate, eat well, and get to bed on time tonight.",
                        todayPreview: "Today: Rest day.",
                        accentColor: "amber",
                        icon: "leaf.fill",
                        varietyKey: "rest_day"
                    )
                }
            }
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "No training today.",
                body: "Rest days aren't wasted days — they're where your body rebuilds. Nail your habits, get outside if you can, and protect tonight's sleep.",
                todayPreview: "Today: Rest day.",
                accentColor: "teal",
                icon: "leaf.fill",
                varietyKey: "rest_day"
            )
        }

        if dayType == "strength" {
            if totalWorkoutsLogged == 0 {
                return MorningBrief(
                    dayNumber: dayNumber,
                    headline: "\(dayName) day.",
                    body: "First one in the books — just show up and move through the exercises. Don't worry about the weight. Learn the movements, get a feel for the session. The PRs come later.",
                    todayPreview: "Today: \(dayName).",
                    accentColor: "teal",
                    icon: "figure.strengthtraining.traditional",
                    varietyKey: "training_day"
                )
            }
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "\(dayName) day.",
                body: "Focus on form and progressive overload. If last session felt smooth, nudge the weight or add a rep. Small increments compound into big numbers over months.",
                todayPreview: "Today: \(dayName).",
                accentColor: "teal",
                icon: "figure.strengthtraining.traditional",
                varietyKey: "training_day"
            )
        }

        if dayType == "cardio" {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "\(dayName) day.",
                body: "Keep the effort conversational. Zone 2 is about building your aerobic base — the engine that powers everything else. You should be able to hold a conversation the entire time. If you can't, slow down.",
                todayPreview: "Today: \(dayName).",
                accentColor: "teal",
                icon: "figure.run",
                varietyKey: "cardio_day"
            )
        }

        // Generic training day
        return MorningBrief(
            dayNumber: dayNumber,
            headline: "\(dayName) today.",
            body: "Show up, execute the plan, and log it. Consistency beats intensity over the long run.",
            todayPreview: "Today: \(dayName).",
            accentColor: "teal",
            icon: "figure.mixed.cardio",
            varietyKey: "training_day"
        )
    }

    // =========================================================================
    // MARK: - P6: DAYS GAINED
    // =========================================================================

    private static func p6_daysGained(
        latestPace: BiologicalPaceScore?,
        paceBaseline: Double?,
        dayNumber: Int
    ) -> MorningBrief? {
        // Only show on Mondays
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard weekday == 2 else { return nil } // Monday = 2

        guard let pace = latestPace, pace.paceValue < 1.0 else { return nil }

        let daysGainedPerYear = (1.0 - pace.paceValue) * 365.0
        let daysStr = String(format: "%.0f", daysGainedPerYear)

        if let baseline = paceBaseline, baseline > pace.paceValue {
            let improvementDays = (baseline - pace.paceValue) * 365.0
            let improvStr = String(format: "%.0f", improvementDays)
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "You're gaining \(daysStr) days this year.",
                body: "At your current Pace of \(String(format: "%.2f", pace.paceValue)), you're aging slower than the calendar. Since your baseline of \(String(format: "%.2f", baseline)), that's \(improvStr) additional days per year. New week. Same process.",
                todayPreview: nil,
                accentColor: "teal",
                icon: "clock.arrow.circlepath",
                varietyKey: "days_gained"
            )
        }

        return MorningBrief(
            dayNumber: dayNumber,
            headline: "You're gaining \(daysStr) days this year.",
            body: "At your current Pace of \(String(format: "%.2f", pace.paceValue)), every year gives you more than a year of biological time. That's the compound interest of longevity. New week — keep investing.",
            todayPreview: nil,
            accentColor: "teal",
            icon: "clock.arrow.circlepath",
            varietyKey: "days_gained"
        )
    }

    // =========================================================================
    // MARK: - P7: DEFAULT FALLBACK
    // =========================================================================

    private static func p7_defaultFallback(
        dayNumber: Int,
        currentStreak: Int,
        habitCount: Int,
        lastNightSleep: Double?,
        latestPace: BiologicalPaceScore?,
        userName: String,
        todaysTrainingDayName: String?,
        todaysTrainingDayType: String?
    ) -> MorningBrief? {

        // Day 1: Welcome
        if dayNumber == 1 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Day 1. Let's go, \(userName).",
                body: "Today is about one thing: showing up. Don't try to optimize everything at once. Complete your \(habitCount) habits, let the health data sync, and trust the process. The framework works — you just have to start.",
                todayPreview: "\(habitCount) habits today. That's it.",
                accentColor: "teal",
                icon: "flag.fill",
                varietyKey: "daily_welcome"
            )
        }

        // Day 2
        if dayNumber == 2 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Day 2. You came back.",
                body: "That matters more than you think. Day 1 is excitement. Day 2 is choice. Your health data is starting to flow in — give it a few more days and the Pace score will have real signal.",
                todayPreview: "\(habitCount) habits today.",
                accentColor: "teal",
                icon: "arrow.right",
                varietyKey: "daily_welcome"
            )
        }

        // Day 3
        if dayNumber == 3 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Day 3. Building momentum.",
                body: "Three days in a row. Your body is starting to notice. Keep the focus narrow — the habits you have right now are enough. More gets layered in when these feel automatic.",
                todayPreview: "\(habitCount) habits today.",
                accentColor: "teal",
                icon: "arrow.right",
                varietyKey: "daily_welcome"
            )
        }

        // Build today preview
        var preview: String? = nil
        if let dayName = todaysTrainingDayName, let dayType = todaysTrainingDayType, dayType != "rest" {
            preview = "\(dayName) + \(habitCount) habits."
        } else {
            preview = "\(habitCount) habits today."
        }

        // Monday variant
        let weekday = Calendar.current.component(.weekday, from: Date())
        if weekday == 2 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "New week. Same process.",
                body: "Day \(dayNumber). \(currentStreak > 0 ? "\(currentStreak)-day streak." : "Fresh start.") Don't overthink it — just execute today's habits and let the week build from there.",
                todayPreview: preview,
                accentColor: "teal",
                icon: "calendar",
                varietyKey: "daily_summary"
            )
        }

        // Weekend variant
        if weekday == 1 || weekday == 7 {
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Day \(dayNumber). Weekend mode.",
                body: "Weekends are where streaks live or die. The routine changes but the habits don't. \(currentStreak > 0 ? "You're on a \(currentStreak)-day streak — keep it alive." : "Good day to start a streak.")",
                todayPreview: preview,
                accentColor: "teal",
                icon: "calendar",
                varietyKey: "daily_summary"
            )
        }

        // With one metric highlight (best available)
        if let sleep = lastNightSleep {
            let sleepNote = sleep >= 7.0 ? "Solid sleep last night." : "Sleep was light — protect tonight."
            return MorningBrief(
                dayNumber: dayNumber,
                headline: "Day \(dayNumber).",
                body: "\(currentStreak > 0 ? "\(currentStreak)-day streak. " : "")\(sleepNote) \(habitCount) habits on deck. Show up and check the boxes.",
                todayPreview: preview,
                accentColor: "teal",
                icon: "calendar",
                varietyKey: "daily_summary"
            )
        }

        // Minimal fallback — no health data at all
        return MorningBrief(
            dayNumber: dayNumber,
            headline: "Day \(dayNumber).",
            body: "\(currentStreak > 0 ? "\(currentStreak)-day streak. " : "")\(habitCount) habits today. Your health data is still syncing — give it a day or two. Focus on the habits for now.",
            todayPreview: preview,
            accentColor: "teal",
            icon: "calendar",
            varietyKey: "daily_summary"
        )
    }
}