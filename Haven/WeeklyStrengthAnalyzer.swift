import Foundation
import SwiftData

// MARK: - Weekly Strength Analyzer
// Compares the best set per exercise this week vs last week.
// Returns e1RM changes and progression status for each tracked lift.
// Used by: EnhancedWeeklyCheckInView (Step 2), CoachingContextBuilder (AI prompt)

struct WeeklyStrengthAnalyzer {
    
    // MARK: - Result Types
    
    struct LiftProgression: Identifiable {
        let id = UUID()
        let exerciseName: String
        let lastWeekBest: BestSet?
        let thisWeekBest: BestSet?
        let lastWeekE1RM: Double?
        let thisWeekE1RM: Double?
        let changeType: ChangeType
        let changeDescription: String   // "+10 lbs" or "+2 reps" or "Stable"
        let e1RMChangePercent: Double?   // e.g., +3.2%
        
        struct BestSet {
            let weight: Double
            let reps: Int
            let isBodyweight: Bool
        }
        
        enum ChangeType: String {
            case improved    // Higher e1RM or more reps at same weight
            case stable      // Same e1RM within 2%
            case regressed   // Lower e1RM
            case noDataThisWeek  // Logged last week but not this week
            case newLift     // First time logging this lift (no last week data)
        }
    }
    
    struct WeeklyStrengthSummary {
        let progressions: [LiftProgression]
        let hasAnyWorkouts: Bool
        let thisWeekSessionCount: Int
        let lastWeekSessionCount: Int
        
        /// For AI prompt: formatted string of all lift progressions
        var promptDescription: String {
            guard !progressions.isEmpty else {
                return "No strength data available for comparison."
            }
            
            var lines: [String] = []
            for lift in progressions {
                var line = "- \(lift.exerciseName): "
                
                if let lastBest = lift.lastWeekBest {
                    line += "\(Int(lastBest.weight))×\(lastBest.reps)"
                } else {
                    line += "No data"
                }
                
                line += " → "
                
                if let thisBest = lift.thisWeekBest {
                    line += "\(Int(thisBest.weight))×\(thisBest.reps)"
                } else {
                    line += "No data"
                }
                
                line += " (\(lift.changeDescription))"
                
                if let lastE1RM = lift.lastWeekE1RM, let thisE1RM = lift.thisWeekE1RM {
                    let pctChange = ((thisE1RM - lastE1RM) / lastE1RM) * 100
                    line += " | e1RM: \(Int(lastE1RM))→\(Int(thisE1RM)) (\(String(format: "%+.1f", pctChange))%)"
                }
                
                lines.append(line)
            }
            
            return lines.joined(separator: "\n")
        }
    }
    
    // MARK: - Main Analysis Method
    
    /// Analyze strength progression for the current week vs previous week.
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - referenceDate: The date to consider as "now" (defaults to today)
    /// - Returns: WeeklyStrengthSummary with all lift progressions
    static func analyze(
        modelContext: ModelContext,
        referenceDate: Date = Date()
    ) -> WeeklyStrengthSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        
        // Calculate week boundaries
        // "This week" = last 7 days from today
        // "Last week" = 8-14 days ago
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: today),
              let lastWeekStart = calendar.date(byAdding: .day, value: -14, to: today) else {
            return WeeklyStrengthSummary(
                progressions: [],
                hasAnyWorkouts: false,
                thisWeekSessionCount: 0,
                lastWeekSessionCount: 0
            )
        }
        
        // Fetch all workout sessions from the last 14 days
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.date >= lastWeekStart
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else {
            return WeeklyStrengthSummary(
                progressions: [],
                hasAnyWorkouts: false,
                thisWeekSessionCount: 0,
                lastWeekSessionCount: 0
            )
        }
        
        // Split into this week and last week
        let thisWeekSessions = sessions.filter { $0.date >= thisWeekStart }
        let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
        
        // Build exercise maps: exerciseName -> best set data
        let thisWeekLifts = buildLiftMap(from: thisWeekSessions)
        let lastWeekLifts = buildLiftMap(from: lastWeekSessions)
        
        // Merge all exercise names from both weeks
        let allExerciseNames = Set(thisWeekLifts.keys).union(Set(lastWeekLifts.keys))
        
        // Build progressions for each exercise
        var progressions: [LiftProgression] = []
        
        for exerciseName in allExerciseNames.sorted() {
            let thisWeek = thisWeekLifts[exerciseName]
            let lastWeek = lastWeekLifts[exerciseName]
            
            let progression = buildProgression(
                exerciseName: exerciseName,
                thisWeek: thisWeek,
                lastWeek: lastWeek
            )
            
            progressions.append(progression)
        }
        
        // Sort: improved first, then stable, then noData, then regressed
        progressions.sort { lhs, rhs in
            lhs.changeType.sortOrder < rhs.changeType.sortOrder
        }
        
        return WeeklyStrengthSummary(
            progressions: progressions,
            hasAnyWorkouts: !thisWeekSessions.isEmpty || !lastWeekSessions.isEmpty,
            thisWeekSessionCount: thisWeekSessions.count,
            lastWeekSessionCount: lastWeekSessions.count
        )
    }
    
    // MARK: - Build Lift Map
    
    /// Extract the best set (by e1RM) per exercise from a set of workout sessions
    private static func buildLiftMap(from sessions: [WorkoutSession]) -> [String: LiftData] {
        var map: [String: LiftData] = [:]
        
        for session in sessions {
            for exercise in session.exercises {
                let name = exercise.name
                
                // Find best set by e1RM for this exercise in this session
                for set in exercise.sets {
                    guard set.reps > 0 else { continue }
                    
                    let isBodyweight = set.isBodyweight
                    let weight = set.weight ?? 0
                    
                    // Skip bodyweight exercises for e1RM comparison
                    // (still include them but without e1RM)
                    let e1rm: Double?
                    if !isBodyweight && weight > 0 {
                        e1rm = EstimatedMaxCalculator.calculate1RM(weight: weight, reps: set.reps)
                    } else {
                        e1rm = nil
                    }
                    
                    let setData = LiftData(
                        weight: weight,
                        reps: set.reps,
                        isBodyweight: isBodyweight,
                        e1RM: e1rm
                    )
                    
                    // Keep the set with highest e1RM (or most reps for bodyweight)
                    if let existing = map[name] {
                        if let newE1RM = e1rm, let existingE1RM = existing.e1RM {
                            if newE1RM > existingE1RM {
                                map[name] = setData
                            }
                        } else if isBodyweight {
                            // For bodyweight: compare total reps
                            if set.reps > existing.reps {
                                map[name] = setData
                            }
                        }
                    } else {
                        map[name] = setData
                    }
                }
            }
        }
        
        return map
    }
    
    // MARK: - Build Progression
    
    private static func buildProgression(
        exerciseName: String,
        thisWeek: LiftData?,
        lastWeek: LiftData?
    ) -> LiftProgression {
        
        let thisWeekBest: LiftProgression.BestSet? = thisWeek.map {
            .init(weight: $0.weight, reps: $0.reps, isBodyweight: $0.isBodyweight)
        }
        
        let lastWeekBest: LiftProgression.BestSet? = lastWeek.map {
            .init(weight: $0.weight, reps: $0.reps, isBodyweight: $0.isBodyweight)
        }
        
        let thisE1RM = thisWeek?.e1RM
        let lastE1RM = lastWeek?.e1RM
        
        // Determine change type and description
        let changeType: LiftProgression.ChangeType
        let changeDescription: String
        var e1RMChangePercent: Double? = nil
        
        if thisWeek == nil && lastWeek != nil {
            // Logged last week but not this week
            changeType = .noDataThisWeek
            changeDescription = "Not logged this week"
            
        } else if thisWeek != nil && lastWeek == nil {
            // New lift — first time
            changeType = .newLift
            changeDescription = "New this week"
            
        } else if let thisE1RM = thisE1RM, let lastE1RM = lastE1RM, lastE1RM > 0 {
            // Both weeks have e1RM data — compare
            let percentChange = ((thisE1RM - lastE1RM) / lastE1RM) * 100
            e1RMChangePercent = percentChange
            
            if percentChange > 2.0 {
                changeType = .improved
                
                // Describe the improvement in user-friendly terms
                if let thisW = thisWeek, let lastW = lastWeek {
                    if thisW.weight > lastW.weight {
                        let weightDiff = thisW.weight - lastW.weight
                        changeDescription = "+\(Int(weightDiff)) lbs"
                    } else if thisW.reps > lastW.reps {
                        let repsDiff = thisW.reps - lastW.reps
                        changeDescription = "+\(repsDiff) rep\(repsDiff == 1 ? "" : "s")"
                    } else {
                        changeDescription = String(format: "+%.0f%% e1RM", percentChange)
                    }
                } else {
                    changeDescription = String(format: "+%.0f%% e1RM", percentChange)
                }
                
            } else if percentChange < -2.0 {
                changeType = .regressed
                changeDescription = String(format: "%.0f%% e1RM", percentChange)
                
            } else {
                changeType = .stable
                changeDescription = "Stable"
            }
            
        } else if let thisW = thisWeek, let lastW = lastWeek, thisW.isBodyweight && lastW.isBodyweight {
            // Bodyweight exercise — compare reps
            let repsDiff = thisW.reps - lastW.reps
            if repsDiff > 0 {
                changeType = .improved
                changeDescription = "+\(repsDiff) rep\(repsDiff == 1 ? "" : "s")"
            } else if repsDiff < 0 {
                changeType = .regressed
                changeDescription = "\(repsDiff) rep\(abs(repsDiff) == 1 ? "" : "s")"
            } else {
                changeType = .stable
                changeDescription = "Stable"
            }
            
        } else {
            changeType = .stable
            changeDescription = "Stable"
        }
        
        return LiftProgression(
            exerciseName: exerciseName,
            lastWeekBest: lastWeekBest,
            thisWeekBest: thisWeekBest,
            lastWeekE1RM: lastE1RM,
            thisWeekE1RM: thisE1RM,
            changeType: changeType,
            changeDescription: changeDescription,
            e1RMChangePercent: e1RMChangePercent
        )
    }
}

// MARK: - Internal Types

private struct LiftData {
    let weight: Double
    let reps: Int
    let isBodyweight: Bool
    let e1RM: Double?
}

// MARK: - ChangeType Sort Order

extension WeeklyStrengthAnalyzer.LiftProgression.ChangeType {
    var sortOrder: Int {
        switch self {
        case .improved: return 0
        case .newLift: return 1
        case .stable: return 2
        case .regressed: return 3
        case .noDataThisWeek: return 4
        }
    }
    
    var displayLabel: String {
        switch self {
        case .improved: return "Improved"
        case .stable: return "Stable"
        case .regressed: return "Regressed"
        case .noDataThisWeek: return "Not logged"
        case .newLift: return "New"
        }
    }
    
    var badgeColor: String {
        switch self {
        case .improved: return "atlasPrimary"
        case .stable: return "atlasTextMuted"
        case .regressed: return "atlasAccent"
        case .noDataThisWeek: return "atlasAccent"
        case .newLift: return "atlasPrimary"
        }
    }
}