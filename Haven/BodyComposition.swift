// BodyComposition.swift
// Steady — body composition math behind the Body tab, the Today snapshot and
// the target body fat goal. Pure logic, no UI.
//
// Units: weight in lbs, body fat as a fraction (0.18 = 18%), height in inches.

import Foundation
import SwiftData

// MARK: - Metric

enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, bodyFat, leanMass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return "Weight"
        case .bodyFat: return "Body fat"
        case .leanMass: return "Lean mass"
        }
    }
}

// MARK: - Daily Series

struct BodyDayPoint: Identifiable {
    var id: Date { date }
    let date: Date        // start of day
    let value: Double     // raw reading for the day (latest entry that day)
    let trend: Double     // 7-day trailing average of available days
}

enum BodySeries {
    /// One point per day that has a reading, oldest first. Missing days are skipped,
    /// not counted as zero, and the trend only averages days that exist.
    static func points(for metric: BodyMetric, entries: [BodyCompEntry], calendar: Calendar = .current) -> [BodyDayPoint] {
        // Latest entry per day
        var byDay: [Date: BodyCompEntry] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if let existing = byDay[day], existing.date >= entry.date { continue }
            byDay[day] = entry
        }

        // Body fat may be logged on a different entry than that day's latest weight
        var bodyFatByDay: [Date: Double] = [:]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            if let bf = entry.bodyFat, bf > 0 {
                bodyFatByDay[calendar.startOfDay(for: entry.date)] = bf
            }
        }

        var raw: [(Date, Double)] = []
        for (day, entry) in byDay {
            switch metric {
            case .weight:
                if entry.weight > 0 { raw.append((day, entry.weight)) }
            case .bodyFat:
                if let bf = bodyFatByDay[day] { raw.append((day, bf)) }
            case .leanMass:
                if entry.weight > 0, let bf = bodyFatByDay[day] { raw.append((day, entry.weight * (1 - bf))) }
            }
        }
        raw.sort { $0.0 < $1.0 }

        return raw.enumerated().map { index, item in
            let windowStart = calendar.date(byAdding: .day, value: -6, to: item.0) ?? item.0
            var sum = 0.0
            var count = 0.0
            var i = index
            while i >= 0, raw[i].0 >= windowStart {
                sum += raw[i].1
                count += 1
                i -= 1
            }
            return BodyDayPoint(date: item.0, value: item.1, trend: sum / max(count, 1))
        }
    }

    /// Weekly rate of change from a least-squares fit over the last `days` days.
    /// Needs at least 4 readings spanning 10+ days; otherwise nil.
    static func weeklyRate(_ points: [BodyDayPoint], days: Int = 28, now: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return nil }
        let recent = points.filter { $0.date >= cutoff }
        guard recent.count >= 4, let first = recent.first, let last = recent.last,
              last.date.timeIntervalSince(first.date) >= 10 * 86_400 else { return nil }

        let xs = recent.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = recent.map { $0.value }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var num = 0.0
        var den = 0.0
        for (x, y) in zip(xs, ys) {
            num += (x - meanX) * (y - meanY)
            den += (x - meanX) * (x - meanX)
        }
        guard den > 0 else { return nil }
        return num / den * 7
    }
}

// MARK: - Current State

/// Everything the Body tab headline needs, derived from entries + profile.
struct BodyState {
    let latestWeight: Double?
    let trendWeight: Double?
    let latestBodyFat: Double?
    let latestBodyFatDate: Date?
    /// lbs per week, negative = losing
    let weeklyWeightRate: Double?
    let weightPoints: [BodyDayPoint]

    var leanMass: Double? {
        guard let weight = trendWeight ?? latestWeight, let bf = latestBodyFat else { return nil }
        return weight * (1 - bf)
    }

    var fatMass: Double? {
        guard let weight = trendWeight ?? latestWeight, let bf = latestBodyFat else { return nil }
        return weight * bf
    }

    static func from(entries: [BodyCompEntry], profile: UserProfile?) -> BodyState {
        let weightPoints = BodySeries.points(for: .weight, entries: entries)
        let latestBF = entries
            .filter { ($0.bodyFat ?? 0) > 0 }
            .max(by: { $0.date < $1.date })

        return BodyState(
            latestWeight: weightPoints.last?.value ?? profile?.weight,
            trendWeight: weightPoints.last?.trend ?? profile?.weight,
            latestBodyFat: latestBF?.bodyFat ?? profile?.bodyFatPercent,
            latestBodyFatDate: latestBF?.date,
            weeklyWeightRate: BodySeries.weeklyRate(weightPoints),
            weightPoints: weightPoints
        )
    }
}

// MARK: - Target Body Fat Goal

struct BodyGoal {
    let targetBodyFat: Double
    let goalWeight: Double
    /// Positive = weight to lose, negative = weight to gain (lbs)
    let toGo: Double
    let projectedDate: Date?
    let isReached: Bool

    /// Goal weight holding today's lean mass constant: lean / (1 − target).
    static func goalWeight(leanMass: Double, targetBodyFat: Double) -> Double {
        leanMass / (1 - targetBodyFat)
    }

    static func from(state: BodyState, targetBodyFat: Double?, now: Date = Date()) -> BodyGoal? {
        guard let target = targetBodyFat, target > 0, target < 0.6,
              let lean = state.leanMass, let current = state.trendWeight ?? state.latestWeight else { return nil }

        let goal = goalWeight(leanMass: lean, targetBodyFat: target)
        let toGo = current - goal
        let reached = abs(toGo) < 0.5 || (state.latestBodyFat.map { abs($0 - target) < 0.005 } ?? false)

        var projected: Date? = nil
        if !reached, let rate = state.weeklyWeightRate, abs(rate) >= 0.1, (rate < 0) == (toGo > 0) {
            let weeks = abs(toGo) / abs(rate)
            if weeks <= 104 {
                projected = Calendar.current.date(byAdding: .day, value: Int((weeks * 7).rounded()), to: now)
            }
        }
        return BodyGoal(targetBodyFat: target, goalWeight: goal, toGo: toGo, projectedDate: projected, isReached: reached)
    }
}

// MARK: - Metabolic Age (estimate)

/// Compares a lean-mass BMR (Katch-McArdle) with the population-average BMR for
/// the same age, height, weight and sex (Mifflin-St Jeor). Each 1% above average
/// counts as about a year younger, capped at ±15 years. It's an estimate, and the
/// UI says so.
struct MetabolicAge {
    let years: Int
    let actualAge: Int
    let bmr: Int            // kcal/day from lean mass
    let averageBMR: Int     // kcal/day for an average person of the same build

    static func estimate(profile: UserProfile?, state: BodyState) -> MetabolicAge? {
        guard let profile, let age = profile.age, age >= 18,
              let heightIn = profile.height, heightIn > 0,
              let weightLbs = state.trendWeight ?? state.latestWeight,
              let lean = state.leanMass else { return nil }

        let sexOffset: Double
        switch profile.gender?.lowercased() {
        case "male": sexOffset = 5
        case "female": sexOffset = -161
        default: return nil
        }

        let kg = weightLbs * 0.453592
        let cm = heightIn * 2.54
        let leanKg = lean * 0.453592

        let katch = 370 + 21.6 * leanKg
        let mifflin = 10 * kg + 6.25 * cm - 5 * Double(age) + sexOffset
        guard mifflin > 0 else { return nil }

        let percentAbove = (katch / mifflin - 1) * 100
        let offset = max(-15, min(15, percentAbove))
        let years = max(18, Int((Double(age) - offset).rounded()))

        return MetabolicAge(years: years, actualAge: age, bmr: Int(katch.rounded()), averageBMR: Int(mifflin.rounded()))
    }
}

// MARK: - Profile Sync

enum BodyProfileSync {
    /// Keeps profile.weight / bodyFatPercent / goalWeight in step with the latest
    /// entries. Call after any body comp entry is added, edited, deleted or imported.
    @MainActor
    static func apply(modelContext: ModelContext) {
        guard let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        let entries = (try? modelContext.fetch(FetchDescriptor<BodyCompEntry>())) ?? []
        let state = BodyState.from(entries: entries, profile: profile)

        if let latest = state.latestWeight { profile.weight = latest }
        if let bf = state.latestBodyFat { profile.bodyFatPercent = bf }
        if let goal = BodyGoal.from(state: state, targetBodyFat: profile.targetBodyFatPercent) {
            profile.goalWeight = goal.goalWeight
        }
        try? modelContext.save()
    }
}
