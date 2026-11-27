// DailyInsights.swift
// Steady — rule-based daily insights for Today. No AI: every insight comes from
// a plain rule over the user's own data, and says what to do about it.
// At most two are shown, highest priority first.

import Foundation
import SwiftUI

struct DailyInsight: Identifiable, Equatable {
    enum Tone { case good, neutral, caution }

    let id: String
    let title: String
    let detail: String
    let tone: Tone
    /// Higher shows first
    let priority: Int

    var color: Color {
        switch tone {
        case .good: return .atlasPrimary
        case .neutral: return .atlasTextMuted
        case .caution: return .atlasAmber
        }
    }
}

struct InsightInputs {
    var metrics: [HealthMetrics]            // any order
    var lifts: [LiftHistory]
    var volumeRows: [MuscleVolumeRow]       // this week
    var bodyState: BodyState
    var bodyGoal: BodyGoal?
    var plannedDaysLeftThisWeek: Int        // strength days still to come this week, today included
    var sessionsThisWeek: Int
    var plannedSessionsPerWeek: Int?
    var unitFormatter: UnitFormatter
    var now: Date = Date()
}

enum DailyInsightsEngine {
    static func insights(_ input: InsightInputs, limit: Int = 2) -> [DailyInsight] {
        var all: [DailyInsight] = []
        all += newBests(input)
        all += sleepDebt(input)
        all += volumeGap(input)
        all += droppingLift(input)
        all += bodyPace(input)
        all += hrvTrend(input)
        all += consistency(input)
        return Array(all.sorted { $0.priority > $1.priority }.prefix(limit))
    }

    // MARK: - Rules

    /// A lift hit a new best today or yesterday.
    static func newBests(_ input: InsightInputs) -> [DailyInsight] {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: input.now)) else { return [] }
        let recent = input.lifts.compactMap { lift -> (LiftHistory, LiftSessionPoint)? in
            guard let last = lift.points.last, last.isPR, last.date >= yesterday else { return nil }
            return (lift, last)
        }
        guard let first = recent.first else { return [] }
        let (lift, point) = first

        let previousBest = lift.points.dropLast().compactMap { $0.value(for: lift.primaryMetric) }.max()
        let value = point.value(for: lift.primaryMetric) ?? 0
        let detail: String
        if lift.isBodyweight {
            detail = "\(Int(value)) reps, up from \(Int(previousBest ?? 0)). Hold that rep count next time before adding more."
        } else {
            let gain = input.unitFormatter.fromLbs(value - (previousBest ?? value))
            detail = String(format: "Estimated 1RM %@, up %.0f %@. Repeat the weight next session and add a rep before adding load.",
                            input.unitFormatter.displayWeightInt(value), gain, input.unitFormatter.weightUnit)
        }
        let others = recent.count > 1 ? " (+\(recent.count - 1) more)" : ""
        return [DailyInsight(id: "pr", title: "New best on \(lift.name)\(others)", detail: detail, tone: .good, priority: 90)]
    }

    /// Short sleep for 3 nights running.
    static func sleepDebt(_ input: InsightInputs) -> [DailyInsight] {
        let nights = lastDays(input.metrics, days: 3, now: input.now).compactMap { $0.sleepDuration }.filter { $0 > 0 }
        guard nights.count == 3 else { return [] }
        let avg = nights.reduce(0, +) / 3
        guard avg < 6.5 else { return [] }
        return [DailyInsight(
            id: "sleep",
            title: String(format: "Sleep has averaged %.1f h for 3 nights", avg),
            detail: "Short sleep slows strength gains and recovery. An earlier night tonight does more than any extra set.",
            tone: .caution,
            priority: 80
        )]
    }

    /// A muscle group is well short of its minimum late in the week.
    static func volumeGap(_ input: InsightInputs) -> [DailyInsight] {
        let weekday = Calendar.current.component(.weekday, from: input.now) // 1 = Sunday
        let daysLeft = weekday == 1 ? 1 : 9 - weekday                        // today through Sunday
        guard daysLeft <= 4 else { return [] }                              // Thursday onward

        let gaps = input.volumeRows
            .map { ($0, Double($0.minimum) - $0.sets) }
            .filter { $0.1 >= 3 }
            .sorted { $0.1 > $1.1 }
        guard let top = gaps.first else { return [] }
        let (row, missing) = top

        let suggestion = ExerciseLibrary.exercises(for: row.group).first { $0.isCompound }?.name
            ?? ExerciseLibrary.exercises(for: row.group).first?.name ?? "a \(row.group.shortName.lowercased()) exercise"
        let setsNeeded = Int(missing.rounded(.up))
        let when = input.plannedDaysLeftThisWeek > 0 ? "in your next session" : "on a spare day"
        let others = gaps.count > 1 ? " \(gaps.count - 1) other group\(gaps.count == 2 ? " is" : "s are") short too." : ""
        return [DailyInsight(
            id: "volume-\(row.group.rawValue)",
            title: "\(row.group.rawValue) is at \(Int(row.sets)) of \(row.minimum) sets",
            detail: "\(daysLeft) day\(daysLeft == 1 ? "" : "s") left this week. Add \(setsNeeded) sets of \(suggestion) \(when).\(others)",
            tone: .caution,
            priority: 70
        )]
    }

    /// A main lift has slipped over its last few sessions.
    static func droppingLift(_ input: InsightInputs) -> [DailyInsight] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -21, to: input.now) else { return [] }
        guard let lift = input.lifts.first(where: { $0.trend == .dropping && ($0.lastDate ?? .distantPast) >= cutoff && !$0.isBodyweight }) else { return [] }
        return [DailyInsight(
            id: "dropping-\(lift.name)",
            title: "\(lift.name) has slipped",
            detail: "Your last 3 sessions are below the 3 before. Hold the weight, check sleep and recovery, and consider a lighter week if it keeps dropping.",
            tone: .caution,
            priority: 60
        )]
    }

    /// Weight change pace against the body fat goal.
    static func bodyPace(_ input: InsightInputs) -> [DailyInsight] {
        guard let rate = input.bodyState.weeklyWeightRate, let weight = input.bodyState.trendWeight, weight > 0 else { return [] }
        let percentPerWeek = rate / weight
        let fmt = input.unitFormatter
        let rateText = String(format: "%.1f %@/week", fmt.fromLbs(abs(rate)), fmt.weightUnit)

        if percentPerWeek < -0.01 {
            return [DailyInsight(
                id: "pace-fast",
                title: "Losing \(rateText)",
                detail: "That's faster than 1% of your body weight a week, which tends to cost muscle. Keep protein high and consider eating a little more.",
                tone: .caution,
                priority: 65
            )]
        }
        if let goal = input.bodyGoal, !goal.isReached, let date = goal.projectedDate {
            return [DailyInsight(
                id: "pace-goal",
                title: "On pace for your \(String(format: "%.0f%%", goal.targetBodyFat * 100)) goal",
                detail: "At \(rateText) \(rate < 0 ? "down" : "up"), you'd reach \(fmt.displayWeight(goal.goalWeight)) around \(date.formatted(.dateTime.month(.abbreviated).day())).",
                tone: .good,
                priority: 30
            )]
        }
        return []
    }

    /// HRV clearly above or below the user's 30-day norm for the last 3 days.
    static func hrvTrend(_ input: InsightInputs) -> [DailyInsight] {
        let recent = lastDays(input.metrics, days: 3, now: input.now).compactMap { $0.heartRateVariability }.filter { $0 > 0 }
        let baseline = lastDays(input.metrics, days: 30, now: input.now).dropLast(3).compactMap { $0.heartRateVariability }.filter { $0 > 0 }
        guard recent.count >= 3, baseline.count >= 10 else { return [] }
        let r = recent.reduce(0, +) / Double(recent.count)
        let b = baseline.reduce(0, +) / Double(baseline.count)
        let change = (r - b) / b
        if change >= 0.1 {
            return [DailyInsight(
                id: "hrv-up",
                title: String(format: "HRV is up %.0f%% on your norm", change * 100),
                detail: "Three days above your 30-day average. A good window to push a top set.",
                tone: .good,
                priority: 40
            )]
        }
        if change <= -0.15 {
            return [DailyInsight(
                id: "hrv-down",
                title: String(format: "HRV is down %.0f%% on your norm", abs(change) * 100),
                detail: "Three days below your 30-day average. Stress, alcohol, illness or hard training can all do this. Keep today's effort moderate.",
                tone: .caution,
                priority: 55
            )]
        }
        return []
    }

    /// Behind on planned sessions late in the week.
    static func consistency(_ input: InsightInputs) -> [DailyInsight] {
        guard let planned = input.plannedSessionsPerWeek, planned > 0 else { return [] }
        let weekday = Calendar.current.component(.weekday, from: input.now)
        guard weekday == 1 || weekday >= 6 else { return [] } // Friday–Sunday
        if input.sessionsThisWeek >= planned {
            return [DailyInsight(
                id: "consistency-done",
                title: "All \(planned) sessions done this week",
                detail: "Consistency is the whole game. Rest up for next week.",
                tone: .good,
                priority: 20
            )]
        }
        return []
    }

    // MARK: - Helpers

    /// HealthMetrics rows for the last `days` days including today, oldest first.
    private static func lastDays(_ metrics: [HealthMetrics], days: Int, now: Date) -> [HealthMetrics] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else { return [] }
        var byDay: [Date: HealthMetrics] = [:]
        for m in metrics where m.date >= start {
            byDay[calendar.startOfDay(for: m.date)] = m
        }
        return byDay.keys.sorted().compactMap { byDay[$0] }
    }
}

// MARK: - Card

struct InsightsCard: View {
    let insights: [DailyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights").steadyLabel()
            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                if index > 0 { Rectangle().fill(Color.steadyHairline).frame(height: 1) }
                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(insight.color)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(SteadyType.bodyEmphasis)
                            .foregroundColor(.atlasText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(insight.detail)
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .steadyPanel()
    }
}
