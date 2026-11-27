import Foundation
import SwiftData

// MARK: - Weekly Cardio Analyzer
// Compares cardio sessions this week vs last week.
// Pulls from CardioSession model (logged via ManualCardioLogView).
// Not wired into the UI after the Steady pivot; kept for Sprint 2 progress views.

struct WeeklyCardioAnalyzer {
    
    // MARK: - Result Types
    
    struct CardioSessionSummary: Identifiable {
        let id = UUID()
        let date: Date
        let sessionType: String
        let duration: Int           // minutes
        let avgHeartRate: Double?
        let distance: Double?       // miles
        let hrZoneLabel: String?    // "Zone 2", "Zone 3", etc.
    }
    
    struct WeeklyCardioSummary {
        let hasCardioThisWeek: Bool
        let hasCardioLastWeek: Bool
        
        // This week
        let thisWeekSessions: Int
        let thisWeekTotalMinutes: Int
        let thisWeekLongestSession: Int       // minutes
        let thisWeekAvgHeartRate: Double?
        let thisWeekSessionDetails: [CardioSessionSummary]
        
        // Last week (for comparison)
        let lastWeekSessions: Int
        let lastWeekTotalMinutes: Int
        let lastWeekLongestSession: Int
        let lastWeekAvgHeartRate: Double?
        
        // Changes
        var sessionCountChange: Int { thisWeekSessions - lastWeekSessions }
        var totalMinutesChange: Int { thisWeekTotalMinutes - lastWeekTotalMinutes }
        var longestSessionChange: Int { thisWeekLongestSession - lastWeekLongestSession }
        
        // Event training context (optional)
        let prescribedCardioSessions: Int?
        let currentEventWeek: Int?
        
        /// For AI prompt: formatted string
        var promptDescription: String {
            guard hasCardioThisWeek || hasCardioLastWeek else {
                return "No cardio sessions logged in the past two weeks."
            }
            
            var lines: [String] = []
            lines.append("- Sessions: \(thisWeekSessions)\(lastWeekSessions > 0 ? " (prev: \(lastWeekSessions))" : "")")
            lines.append("- Total time: \(thisWeekTotalMinutes) min\(lastWeekTotalMinutes > 0 ? " (prev: \(lastWeekTotalMinutes) min)" : "")")
            lines.append("- Longest session: \(thisWeekLongestSession) min\(lastWeekLongestSession > 0 ? " (prev: \(lastWeekLongestSession) min)" : "")")
            
            if let avgHR = thisWeekAvgHeartRate {
                var hrLine = "- Avg heart rate: \(Int(avgHR)) bpm"
                if let lastHR = lastWeekAvgHeartRate {
                    hrLine += " (prev: \(Int(lastHR)) bpm)"
                }
                lines.append(hrLine)
            }
            
            if let prescribed = prescribedCardioSessions {
                lines.append("- Prescribed sessions: \(prescribed), completed: \(thisWeekSessions)")
            }
            
            // Session type breakdown
            let typeGroups = Dictionary(grouping: thisWeekSessionDetails, by: { $0.sessionType })
            if !typeGroups.isEmpty {
                let breakdown = typeGroups.map { "\($0.key): \($0.value.count)" }.sorted().joined(separator: ", ")
                lines.append("- Types: \(breakdown)")
            }
            
            return lines.joined(separator: "\n")
        }
    }
    
    // MARK: - Main Analysis Method
    
    /// Analyze cardio sessions for the current week vs previous week.
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - userAge: User's age (for HR zone calculation)
    ///   - restingHR: User's resting heart rate (for personalized zones)
    ///   - prescribedCardioSessions: Number of prescribed cardio sessions from training plan
    ///   - currentEventWeek: Current week in event training plan
    ///   - referenceDate: The date to consider as "now" (defaults to today)
    /// - Returns: WeeklyCardioSummary with all comparisons
    static func analyze(
        modelContext: ModelContext,
        userAge: Int? = nil,
        restingHR: Double? = nil,
        prescribedCardioSessions: Int? = nil,
        currentEventWeek: Int? = nil,
        referenceDate: Date = Date()
    ) -> WeeklyCardioSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        
        // Calculate week boundaries
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: today),
              let lastWeekStart = calendar.date(byAdding: .day, value: -14, to: today) else {
            return emptyResult()
        }
        
        // Fetch cardio sessions from the last 14 days
        let descriptor = FetchDescriptor<CardioSession>(
            predicate: #Predicate<CardioSession> { session in
                session.date >= lastWeekStart
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else {
            return emptyResult()
        }
        
        // Split into this week and last week
        let thisWeekSessions = sessions.filter { $0.date >= thisWeekStart }
        let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
        
        // This week stats
        let thisWeekTotalMinutes = thisWeekSessions.reduce(0) { $0 + $1.duration }
        let thisWeekLongestSession = thisWeekSessions.map { $0.duration }.max() ?? 0
        let thisWeekAvgHR = calculateAvgHeartRate(sessions: thisWeekSessions)
        
        // Last week stats
        let lastWeekTotalMinutes = lastWeekSessions.reduce(0) { $0 + $1.duration }
        let lastWeekLongestSession = lastWeekSessions.map { $0.duration }.max() ?? 0
        let lastWeekAvgHR = calculateAvgHeartRate(sessions: lastWeekSessions)
        
        // Build session details for this week
        let sessionDetails = thisWeekSessions.map { session in
            CardioSessionSummary(
                date: session.date,
                sessionType: session.sessionType,
                duration: session.duration,
                avgHeartRate: session.avgHeartRate,
                distance: session.distance,
                hrZoneLabel: determineHRZone(
                    avgHR: session.avgHeartRate,
                    userAge: userAge,
                    restingHR: restingHR
                )
            )
        }
        
        return WeeklyCardioSummary(
            hasCardioThisWeek: !thisWeekSessions.isEmpty,
            hasCardioLastWeek: !lastWeekSessions.isEmpty,
            thisWeekSessions: thisWeekSessions.count,
            thisWeekTotalMinutes: thisWeekTotalMinutes,
            thisWeekLongestSession: thisWeekLongestSession,
            thisWeekAvgHeartRate: thisWeekAvgHR,
            thisWeekSessionDetails: sessionDetails,
            lastWeekSessions: lastWeekSessions.count,
            lastWeekTotalMinutes: lastWeekTotalMinutes,
            lastWeekLongestSession: lastWeekLongestSession,
            lastWeekAvgHeartRate: lastWeekAvgHR,
            prescribedCardioSessions: prescribedCardioSessions,
            currentEventWeek: currentEventWeek
        )
    }
    
    // MARK: - Helpers
    
    /// Calculate average heart rate across sessions (only those with HR data)
    private static func calculateAvgHeartRate(sessions: [CardioSession]) -> Double? {
        let hrValues = sessions.compactMap { $0.avgHeartRate }
        guard !hrValues.isEmpty else { return nil }
        return hrValues.reduce(0, +) / Double(hrValues.count)
    }
    
    /// Determine the HR zone label based on average HR during session
    private static func determineHRZone(
        avgHR: Double?,
        userAge: Int?,
        restingHR: Double?
    ) -> String? {
        guard let avgHR = avgHR, let age = userAge else { return nil }
        
        let maxHR = 220.0 - Double(age)
        
        // Use Karvonen formula if resting HR available, otherwise simple percentage
        if let rhr = restingHR {
            let hrReserve = maxHR - rhr
            let intensityPercent = (avgHR - rhr) / hrReserve
            
            if intensityPercent < 0.50 {
                return "Zone 1"
            } else if intensityPercent < 0.60 {
                return "Zone 1-2"
            } else if intensityPercent < 0.70 {
                return "Zone 2"
            } else if intensityPercent < 0.80 {
                return "Zone 3"
            } else if intensityPercent < 0.90 {
                return "Zone 4"
            } else {
                return "Zone 5"
            }
        } else {
            // Simple percentage of max HR
            let percentMax = avgHR / maxHR
            
            if percentMax < 0.60 {
                return "Zone 1"
            } else if percentMax < 0.70 {
                return "Zone 2"
            } else if percentMax < 0.80 {
                return "Zone 3"
            } else if percentMax < 0.90 {
                return "Zone 4"
            } else {
                return "Zone 5"
            }
        }
    }
    
    /// Empty result for error cases
    private static func emptyResult() -> WeeklyCardioSummary {
        WeeklyCardioSummary(
            hasCardioThisWeek: false,
            hasCardioLastWeek: false,
            thisWeekSessions: 0,
            thisWeekTotalMinutes: 0,
            thisWeekLongestSession: 0,
            thisWeekAvgHeartRate: nil,
            thisWeekSessionDetails: [],
            lastWeekSessions: 0,
            lastWeekTotalMinutes: 0,
            lastWeekLongestSession: 0,
            lastWeekAvgHeartRate: nil,
            prescribedCardioSessions: nil,
            currentEventWeek: nil
        )
    }
}