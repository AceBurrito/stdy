// RecoveryScore.swift
// Steady — daily readiness-to-train assessment (replaces Pace).
//
// Inputs come from HealthMetrics rows that HealthKitManager syncs:
//   Sleep (40%) — last night's duration, absolute bands
//   HRV   (35%) — this morning vs the personal 30-day average
//   RHR   (25%) — this morning vs the personal 30-day average
//
// Rules:
// - Baselines are personal, never population norms.
// - Days with no data are excluded from averages (never counted as zero).
// - A missing input is dropped and the remaining weights are renormalized.
// - Pure and deterministic: no stored state, recomputed from HealthMetrics.

import SwiftUI

// MARK: - State

enum RecoveryState: String, CaseIterable, Identifiable {
    // Raw values are shared with the widget through App Group UserDefaults.
    case readyToCrush = "ready"
    case goodToGo = "good"
    case manageIt = "manage"
    case recover = "recover"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readyToCrush: return "Ready to Crush"
        case .goodToGo: return "Good to Go"
        case .manageIt: return "Manage It"
        case .recover: return "Recover"
        }
    }

    var color: Color {
        switch self {
        case .readyToCrush: return .steadyGreen
        case .goodToGo: return .atlasPrimary
        case .manageIt: return .atlasAmber
        case .recover: return .atlasAccent
        }
    }

    /// One-line call for the day. Direct, no cheerleading.
    var guidance: String {
        switch self {
        case .readyToCrush: return "Every signal is up. Go heavy today."
        case .goodToGo: return "Recovery is solid. Train as planned."
        case .manageIt: return "Some signals are down. Train, but keep 2–3 reps in reserve."
        case .recover: return "Your body is behind. Walk, stretch, or take the day."
        }
    }

    /// Very short call for the home screen widget.
    var widgetHint: String {
        switch self {
        case .readyToCrush: return "Go heavy today"
        case .goodToGo: return "Train as planned"
        case .manageIt: return "Keep 2–3 reps in reserve"
        case .recover: return "Walk, stretch or rest"
        }
    }

    /// Short note shown on the training card when the day isn't green or teal.
    var trainingAdjustment: String? {
        switch self {
        case .readyToCrush, .goodToGo: return nil
        case .manageIt: return "Recovery is down. Hold your weights, don't chase PRs."
        case .recover: return "Recovery is low. Swap for light cardio or mobility, or cut volume in half."
        }
    }

    /// 85-100 Ready to Crush, 65-84 Good to Go, 40-64 Manage It, 0-39 Recover
    static func from(score: Int) -> RecoveryState {
        switch score {
        case 85...: return .readyToCrush
        case 65..<85: return .goodToGo
        case 40..<65: return .manageIt
        default: return .recover
        }
    }
}

// MARK: - Components

struct RecoveryComponent: Identifiable {
    enum Kind: String {
        case sleep, hrv, rhr

        var label: String {
            switch self {
            case .sleep: return "Sleep"
            case .hrv: return "HRV"
            case .rhr: return "Resting HR"
            }
        }

        var shortLabel: String {
            switch self {
            case .sleep: return "Sleep"
            case .hrv: return "HRV"
            case .rhr: return "RHR"
            }
        }

        var weight: Double {
            switch self {
            case .sleep: return 0.40
            case .hrv: return 0.35
            case .rhr: return 0.25
            }
        }
    }

    let kind: Kind
    /// 0-100 sub-score
    let score: Int
    /// Today's raw value (hours, ms, or bpm)
    let value: Double
    /// Personal 30-day average, nil for sleep (absolute bands) or too little history
    let baseline: Double?
    /// Number of days that made up the baseline
    let baselineDays: Int

    var id: String { kind.rawValue }

    /// Formatted today value, e.g. "7.4h", "52 ms", "54 bpm"
    var valueText: String {
        switch kind {
        case .sleep: return String(format: "%.1fh", value)
        case .hrv: return String(format: "%.0f ms", value)
        case .rhr: return String(format: "%.0f bpm", value)
        }
    }

    /// Comparison to baseline, e.g. "+8% vs avg", "−2 vs avg"
    var deltaText: String? {
        guard let baseline, baseline > 0 else { return nil }
        switch kind {
        case .sleep:
            return nil
        case .hrv:
            let pct = (value - baseline) / baseline * 100
            if abs(pct) < 1 { return "at avg" }
            return String(format: "%@%.0f%% vs avg", pct > 0 ? "+" : "−", abs(pct))
        case .rhr:
            let diff = value - baseline
            if abs(diff) < 1 { return "at avg" }
            return String(format: "%@%.0f vs avg", diff > 0 ? "+" : "−", abs(diff))
        }
    }

    /// Sleep has no baseline: show the band instead.
    var bandText: String? {
        guard kind == .sleep else { return nil }
        switch value {
        case ..<5: return "under 5h"
        case 5..<6: return "5–6h"
        case 6..<7: return "6–7h"
        case 7..<8: return "7–8h"
        default: return "8h+"
        }
    }
}

// MARK: - Assessment

struct RecoveryAssessment {
    let date: Date
    /// 0-100, weighted. Kept internal to the UI: the state is what users see.
    let score: Int
    let state: RecoveryState
    let components: [RecoveryComponent]
    /// True while HRV/RHR baselines rest on fewer than `RecoveryScoreCalculator.calibrationDays` days.
    let isCalibrating: Bool

    func component(_ kind: RecoveryComponent.Kind) -> RecoveryComponent? {
        components.first { $0.kind == kind }
    }

    /// Inputs that were missing today, for an honest footnote.
    var missingKinds: [RecoveryComponent.Kind] {
        [.sleep, .hrv, .rhr].filter { component($0) == nil }
    }
}

// MARK: - Calculator

enum RecoveryScoreCalculator {
    /// Rolling window for personal baselines.
    static let baselineWindowDays = 30
    /// Fewer baseline days than this and the HRV/RHR input is skipped.
    static let minimumBaselineDays = 5
    /// Below this many baseline days the UI marks the score as calibrating.
    static let calibrationDays = 14

    /// Assess recovery for `date` (normally today) from synced HealthMetrics.
    /// Returns nil when no input is available at all.
    static func assess(
        metrics: [HealthMetrics],
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> RecoveryAssessment? {
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }

        let todayRow = metrics.first { calendar.isDate($0.date, inSameDayAs: today) }
        let yesterdayRow = metrics.first { calendar.isDate($0.date, inSameDayAs: yesterday) }

        var components: [RecoveryComponent] = []
        var calibrating = false

        // Sleep: last night only. Yesterday's row is the night before, so never fall back to it.
        if let hours = todayRow?.sleepDuration, hours > 0 {
            components.append(RecoveryComponent(
                kind: .sleep, score: sleepScore(hours: hours),
                value: hours, baseline: nil, baselineDays: 0
            ))
        }

        // HRV: this morning, else yesterday if the watch hasn't synced yet today.
        let hrvToday: (value: Double, day: Date)? = {
            if let v = todayRow?.heartRateVariability, v > 0 { return (v, today) }
            if let v = yesterdayRow?.heartRateVariability, v > 0 { return (v, yesterday) }
            return nil
        }()
        if let hrvToday {
            let base = baseline(metrics: metrics, before: hrvToday.day, calendar: calendar) { $0.heartRateVariability }
            if let avg = base.average, base.days >= minimumBaselineDays {
                components.append(RecoveryComponent(
                    kind: .hrv, score: hrvScore(today: hrvToday.value, baseline: avg),
                    value: hrvToday.value, baseline: avg, baselineDays: base.days
                ))
                if base.days < calibrationDays { calibrating = true }
            } else {
                calibrating = true
            }
        }

        // RHR: same selection as HRV.
        let rhrToday: (value: Double, day: Date)? = {
            if let v = todayRow?.restingHeartRate, v > 0 { return (v, today) }
            if let v = yesterdayRow?.restingHeartRate, v > 0 { return (v, yesterday) }
            return nil
        }()
        if let rhrToday {
            let base = baseline(metrics: metrics, before: rhrToday.day, calendar: calendar) { $0.restingHeartRate }
            if let avg = base.average, base.days >= minimumBaselineDays {
                components.append(RecoveryComponent(
                    kind: .rhr, score: rhrScore(today: rhrToday.value, baseline: avg),
                    value: rhrToday.value, baseline: avg, baselineDays: base.days
                ))
                if base.days < calibrationDays { calibrating = true }
            } else {
                calibrating = true
            }
        }

        guard !components.isEmpty else { return nil }

        let totalWeight = components.reduce(0) { $0 + $1.kind.weight }
        let weighted = components.reduce(0) { $0 + Double($1.score) * $1.kind.weight } / totalWeight
        let score = Int(weighted.rounded())

        return RecoveryAssessment(
            date: today,
            score: score,
            state: RecoveryState.from(score: score),
            components: components,
            isCalibrating: calibrating
        )
    }

    // MARK: Sub-scores

    /// <5h=20, 5-6h=40, 6-7h=60, 7-8h=80, 8+h=100
    static func sleepScore(hours: Double) -> Int {
        switch hours {
        case ..<5: return 20
        case 5..<6: return 40
        case 6..<7: return 60
        case 7..<8: return 80
        default: return 100
        }
    }

    /// >10% above avg=100, within 10%=75, 10-20% below=50, >20% below=25
    static func hrvScore(today: Double, baseline: Double) -> Int {
        guard baseline > 0 else { return 75 }
        let change = (today - baseline) / baseline
        if change > 0.10 { return 100 }
        if change >= -0.10 { return 75 }
        if change >= -0.20 { return 50 }
        return 25
    }

    /// >5 below avg=100, 3 above to 5 below=75, 3-8 above=50, >8 above=25.
    /// The spec leaves 3-5 bpm below average open; it scores 75 here (normal range).
    static func rhrScore(today: Double, baseline: Double) -> Int {
        let diff = today - baseline
        if diff < -5 { return 100 }
        if diff <= 3 { return 75 }
        if diff <= 8 { return 50 }
        return 25
    }

    // MARK: Baseline

    /// Average of `value` over the 30 days before `day` (exclusive), skipping days without data.
    static func baseline(
        metrics: [HealthMetrics],
        before day: Date,
        calendar: Calendar = .current,
        value: (HealthMetrics) -> Double?
    ) -> (average: Double?, days: Int) {
        let end = calendar.startOfDay(for: day)
        guard let start = calendar.date(byAdding: .day, value: -baselineWindowDays, to: end) else {
            return (nil, 0)
        }
        // One value per calendar day (HealthMetrics should already be one row per day,
        // but CloudKit merges can briefly produce duplicates).
        var byDay: [Date: Double] = [:]
        for row in metrics {
            let d = calendar.startOfDay(for: row.date)
            guard d >= start, d < end, let v = value(row), v > 0 else { continue }
            byDay[d] = v
        }
        guard !byDay.isEmpty else { return (nil, 0) }
        let avg = byDay.values.reduce(0, +) / Double(byDay.count)
        return (avg, byDay.count)
    }
}
