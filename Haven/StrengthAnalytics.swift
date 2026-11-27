// StrengthAnalytics.swift
// Steady — the numbers behind the Strength tab: weekly working sets per muscle
// group against a minimum, and per-exercise progression (e1RM, top set, volume).
// Pure logic, no UI. Weights in lbs.

import Foundation
import SwiftData

// MARK: - Exercise → Muscle Group

/// Resolves a logged exercise name to its primary muscle group through
/// ExerciseLibrary first, then the user's custom exercises.
struct MuscleGroupResolver {
    private let custom: [String: MuscleGroup]

    init(customExercises: [CustomExercise]) {
        var map: [String: MuscleGroup] = [:]
        for exercise in customExercises { map[exercise.name.lowercased()] = exercise.muscleGroup }
        custom = map
    }

    func group(for exerciseName: String) -> MuscleGroup? {
        if let def = ExerciseLibrary.find(name: exerciseName) { return def.muscleGroup }
        return custom[exerciseName.lowercased()]
    }

    func isBodyweight(_ exerciseName: String) -> Bool {
        ExerciseLibrary.find(name: exerciseName)?.isBodyweight ?? false
    }
}

// MARK: - Weekly Volume Targets

/// Working-set minimums per muscle group per week. Big groups start at 10 sets,
/// the evidence-backed floor for steady hypertrophy; arms and core at 6 because
/// compound lifts already train them. Scaled by experience.
enum VolumeTargets {
    static func minimum(for group: MuscleGroup, experience: String?) -> Int {
        let base: Double
        switch group {
        case .chest, .back, .quads, .hamstringsGlutes, .shoulders: base = 10
        case .biceps, .triceps, .core: base = 6
        }
        let scale: Double
        switch SteadyExperience(rawValue: experience ?? "") {
        case .beginner: scale = 0.7
        case .advanced: scale = 1.2
        default: scale = 1
        }
        return Int((base * scale).rounded())
    }

    /// Above this, extra sets mostly add fatigue.
    static func ceiling(for group: MuscleGroup, experience: String?) -> Int {
        minimum(for: group, experience: experience) * 2 + 2
    }
}

// MARK: - Plan Volume

/// Working sets per muscle group per week that the active plan prescribes,
/// summed over its strength days. Nil when there's no plan with strength exercises,
/// so callers fall back to the experience-based minimums.
enum PlanVolume {
    static func weeklySets(program: TrainingProgram?, resolver: MuscleGroupResolver) -> [MuscleGroup: Int]? {
        guard let program = program else { return nil }
        var totals: [MuscleGroup: Int] = [:]
        var hasExercises = false
        for day in program.workoutDays where day.dayType == "strength" {
            for exercise in day.exercises {
                hasExercises = true
                guard let group = resolver.group(for: exercise.name) else { continue }
                totals[group, default: 0] += max(exercise.targetSets, 0)
            }
        }
        return hasExercises ? totals : nil
    }
}

// MARK: - Weekly Muscle Volume

enum VolumeStatus {
    case none, under, met, high
}

struct MuscleVolumeRow: Identifiable {
    var id: MuscleGroup { group }
    let group: MuscleGroup
    let sets: Double
    /// Evidence-based weekly floor for this group, scaled by experience.
    let minimum: Int
    let ceiling: Int
    /// Working sets per week the active plan prescribes; nil when there's no plan.
    var planned: Int? = nil

    /// What progress is measured against: the plan when there is one, else the minimum.
    var target: Int { planned ?? minimum }

    /// The plan itself prescribes fewer sets than the minimum for this group.
    var planIsShort: Bool {
        guard let planned = planned else { return false }
        return planned < minimum
    }

    var status: VolumeStatus {
        if sets <= 0 { return .none }
        if sets < Double(target) { return .under }
        if sets > Double(ceiling) { return .high }
        return .met
    }
}

enum VolumeWindow: String, CaseIterable, Identifiable {
    case thisWeek, lastWeek, fourWeekAverage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisWeek: return "This week"
        case .lastWeek: return "Last week"
        case .fourWeekAverage: return "4-wk avg"
        }
    }
}

enum MuscleVolume {
    /// Monday 00:00 of the week containing `date`.
    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    /// Working sets (reps > 0) per muscle group in [start, end).
    static func sets(in sessions: [WorkoutSession], from start: Date, to end: Date, resolver: MuscleGroupResolver) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        for session in sessions where session.date >= start && session.date < end {
            for exercise in session.exercises {
                guard let group = resolver.group(for: exercise.name) else { continue }
                let working = exercise.sets.filter { $0.reps > 0 }.count
                totals[group, default: 0] += Double(working)
            }
        }
        return totals
    }

    static func rows(
        sessions: [WorkoutSession],
        window: VolumeWindow,
        experience: String?,
        resolver: MuscleGroupResolver,
        plan: [MuscleGroup: Int]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MuscleVolumeRow] {
        let thisWeek = weekStart(for: now, calendar: calendar)
        let totals: [MuscleGroup: Double]
        switch window {
        case .thisWeek:
            let end = calendar.date(byAdding: .day, value: 7, to: thisWeek) ?? now
            totals = sets(in: sessions, from: thisWeek, to: end, resolver: resolver)
        case .lastWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: thisWeek) ?? thisWeek
            totals = sets(in: sessions, from: start, to: thisWeek, resolver: resolver)
        case .fourWeekAverage:
            // The four full weeks before this one
            let start = calendar.date(byAdding: .day, value: -28, to: thisWeek) ?? thisWeek
            totals = sets(in: sessions, from: start, to: thisWeek, resolver: resolver).mapValues { $0 / 4 }
        }

        return MuscleGroup.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { group -> MuscleVolumeRow in
                let planned = plan.map { $0[group] ?? 0 }
                return MuscleVolumeRow(
                    group: group,
                    sets: totals[group] ?? 0,
                    minimum: VolumeTargets.minimum(for: group, experience: experience),
                    ceiling: max(VolumeTargets.ceiling(for: group, experience: experience), planned ?? 0),
                    planned: planned
                )
            }
    }

    /// Total working sets per week for the last `weeks` weeks, oldest first (this week last).
    static func weeklyTotals(sessions: [WorkoutSession], weeks: Int = 8, now: Date = Date(), calendar: Calendar = .current) -> [(weekStart: Date, sets: Int)] {
        let thisWeek = weekStart(for: now, calendar: calendar)
        return (0..<weeks).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -7 * offset, to: thisWeek),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            let count = sessions
                .filter { $0.date >= start && $0.date < end }
                .reduce(0) { total, session in
                    total + session.exercises.reduce(0) { $0 + $1.sets.filter { $0.reps > 0 }.count }
                }
            return (weekStart: start, sets: count)
        }
    }
}

// MARK: - Per-Exercise Progression

enum LiftMetric: String, CaseIterable, Identifiable {
    case e1rm, topSet, volume, reps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .e1rm: return "e1RM"
        case .topSet: return "Top set"
        case .volume: return "Volume"
        case .reps: return "Best reps"
        }
    }
}

struct LiftSessionPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let e1rm: Double?        // best set, Epley
    let topWeight: Double?   // heaviest working set
    let topReps: Int         // reps on that set (or best reps for bodyweight)
    let volume: Double       // Σ weight × reps
    let bestReps: Int
    let sets: [WorkoutSet]
    /// Set a new best e1RM (or best reps for bodyweight) compared with everything before it
    var isPR: Bool = false

    func value(for metric: LiftMetric) -> Double? {
        switch metric {
        case .e1rm: return e1rm
        case .topSet: return topWeight
        case .volume: return volume > 0 ? volume : nil
        case .reps: return bestReps > 0 ? Double(bestReps) : nil
        }
    }
}

enum LiftTrend {
    case progressing, holding, dropping, building

    var title: String {
        switch self {
        case .progressing: return "Progressing"
        case .holding: return "Holding"
        case .dropping: return "Dropping"
        case .building: return "Building data"
        }
    }
}

struct LiftHistory {
    let name: String
    let group: MuscleGroup?
    let isBodyweight: Bool
    /// Oldest first, one point per session
    let points: [LiftSessionPoint]

    var lastDate: Date? { points.last?.date }

    /// Main metric for this lift: e1RM, or best reps for bodyweight work
    var primaryMetric: LiftMetric { isBodyweight ? .reps : .e1rm }

    var latest: Double? { points.last?.value(for: primaryMetric) }
    var best: Double? { points.compactMap { $0.value(for: primaryMetric) }.max() }

    /// Compares the best of the last 3 sessions with the best of the 3 before.
    var trend: LiftTrend {
        let values = points.compactMap { $0.value(for: primaryMetric) }
        guard values.count >= 4 else { return .building }
        let recent = values.suffix(3).max() ?? 0
        let earlier = values.dropLast(3).suffix(3).max() ?? 0
        guard earlier > 0 else { return .building }
        let change = (recent - earlier) / earlier
        if change >= 0.01 { return .progressing }
        if change <= -0.03 { return .dropping }
        return .holding
    }

    /// Percent change of the primary metric over roughly the last `days` days.
    func change(overDays days: Int = 56, now: Date = Date()) -> Double? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return nil }
        let window = points.filter { $0.date >= cutoff }.compactMap { $0.value(for: primaryMetric) }
        guard window.count >= 2, let first = window.first, first > 0, let last = window.last else { return nil }
        return (last - first) / first
    }
}

enum LiftAnalytics {
    static func point(for exercise: Exercise, date: Date, bodyweightLift: Bool) -> LiftSessionPoint {
        let working = exercise.sets.filter { $0.reps > 0 }
        let weighted = working.filter { !$0.isBodyweight && ($0.weight ?? 0) > 0 }
        let top = weighted.max { ($0.weight ?? 0, $0.reps) < ($1.weight ?? 0, $1.reps) }
        let e1rm = bodyweightLift ? nil : EstimatedMaxCalculator.bestE1RM(from: exercise)
        let volume = weighted.reduce(0.0) { $0 + ($1.weight ?? 0) * Double($1.reps) }

        return LiftSessionPoint(
            date: date,
            e1rm: e1rm,
            topWeight: top?.weight,
            topReps: top?.reps ?? (working.map(\.reps).max() ?? 0),
            volume: volume,
            bestReps: working.map(\.reps).max() ?? 0,
            sets: exercise.sets.sorted { $0.setNumber < $1.setNumber }
        )
    }

    /// Every lift the user has logged, newest activity first.
    static func histories(sessions: [WorkoutSession], resolver: MuscleGroupResolver) -> [LiftHistory] {
        var byName: [String: (name: String, points: [LiftSessionPoint])] = [:]
        for session in sessions {
            for exercise in session.exercises where !exercise.sets.isEmpty {
                let key = exercise.name.lowercased()
                let isBW = resolver.isBodyweight(exercise.name) || exercise.sets.allSatisfy { $0.isBodyweight || ($0.weight ?? 0) == 0 }
                let p = point(for: exercise, date: session.date, bodyweightLift: isBW)
                byName[key, default: (name: exercise.name, points: [])].points.append(p)
            }
        }

        return byName.values.map { entry in
            let isBW = resolver.isBodyweight(entry.name)
                || entry.points.allSatisfy { $0.e1rm == nil }
            let sorted = mergeSameDay(entry.points.sorted { $0.date < $1.date })
            return LiftHistory(name: entry.name, group: resolver.group(for: entry.name), isBodyweight: isBW, points: markPRs(sorted, bodyweight: isBW))
        }
        .sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
    }

    static func history(named name: String, sessions: [WorkoutSession], resolver: MuscleGroupResolver) -> LiftHistory? {
        let key = name.lowercased()
        let matching = sessions.filter { session in session.exercises.contains { $0.name.lowercased() == key } }
        return histories(sessions: matching, resolver: resolver).first { $0.name.lowercased() == key }
    }

    /// Two entries of the same lift in one session or day keep the better one.
    private static func mergeSameDay(_ points: [LiftSessionPoint]) -> [LiftSessionPoint] {
        var result: [LiftSessionPoint] = []
        for p in points {
            if let last = result.last, Calendar.current.isDate(last.date, inSameDayAs: p.date) {
                let better = (p.e1rm ?? Double(p.bestReps)) > (last.e1rm ?? Double(last.bestReps)) ? p : last
                result[result.count - 1] = better
            } else {
                result.append(p)
            }
        }
        return result
    }

    private static func markPRs(_ points: [LiftSessionPoint], bodyweight: Bool) -> [LiftSessionPoint] {
        var best = 0.0
        return points.enumerated().map { index, p in
            var copy = p
            let value = bodyweight ? Double(p.bestReps) : (p.e1rm ?? 0)
            // The first session is a baseline, not a PR
            copy.isPR = index > 0 && value > best
            best = max(best, value)
            return copy
        }
    }
}
