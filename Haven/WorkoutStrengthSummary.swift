import Foundation
import SwiftData

// MARK: - Weekly Strength Summary
// Aggregates volume, sets, and sessions for the current and previous week
// Used by the "THIS WEEK" summary cards at the top of the Strength tab

struct WeeklyStrengthSummary {
    let totalVolume: Double           // Sum of weight × reps for all sets
    let prevWeekVolume: Double
    let setsCompleted: Int            // Total sets across all workouts
    let prevWeekSets: Int
    let sessionsCompleted: Int        // Number of workout sessions
    let prevWeekSessions: Int
    
    var volumeTrend: Double { totalVolume - prevWeekVolume }
    var setsTrend: Int { setsCompleted - prevWeekSets }
    var sessionsTrend: Int { sessionsCompleted - prevWeekSessions }
    
    // MARK: - Formatted Values
    
    var formattedVolume: String {
        if totalVolume > 99_999 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return Int(totalVolume).formatted()
    }
    
    var formattedVolumeTrend: String {
        let delta = volumeTrend
        if abs(delta) < 1 { return "— same" }
        let sign = delta > 0 ? "+" : ""
        if abs(delta) > 99_999 {
            return "\(sign)\(String(format: "%.1fk", delta / 1000))"
        }
        return "\(sign)\(Int(delta).formatted())"
    }
    
    var formattedSetsTrend: String {
        let delta = setsTrend
        if delta == 0 { return "— same" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }
    
    var formattedSessionsTrend: String {
        let delta = sessionsTrend
        if delta == 0 { return "— same" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }
    
    // MARK: - Empty State
    
    static let empty = WeeklyStrengthSummary(
        totalVolume: 0, prevWeekVolume: 0,
        setsCompleted: 0, prevWeekSets: 0,
        sessionsCompleted: 0, prevWeekSessions: 0
    )
    
    // MARK: - Build from Sessions
    
    static func calculate(from sessions: [WorkoutSession]) -> WeeklyStrengthSummary {
        let calendar = Calendar.current
        let now = Date()
        
        // Current week: Monday 00:00 → Sunday 23:59 (ISO week)
        let currentWeekStart = startOfWeek(for: now, calendar: calendar)
        let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        
        // Previous week
        let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        let prevWeekEnd = currentWeekStart
        
        let currentWeekSessions = sessions.filter { $0.date >= currentWeekStart && $0.date < currentWeekEnd }
        let prevWeekSessions = sessions.filter { $0.date >= prevWeekStart && $0.date < prevWeekEnd }
        
        return WeeklyStrengthSummary(
            totalVolume: totalVolume(for: currentWeekSessions),
            prevWeekVolume: totalVolume(for: prevWeekSessions),
            setsCompleted: totalSets(for: currentWeekSessions),
            prevWeekSets: totalSets(for: prevWeekSessions),
            sessionsCompleted: currentWeekSessions.count,
            prevWeekSessions: prevWeekSessions.count
        )
    }
    
    // MARK: - Helpers
    
    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }
    
    private static func totalVolume(for sessions: [WorkoutSession]) -> Double {
        // Prefer stored totalVolume if available, otherwise compute
        sessions.reduce(0) { total, session in
            if let stored = session.totalVolume, stored > 0 {
                return total + stored
            }
            // Fallback: compute from exercises
            return total + session.exercises.reduce(0) { exTotal, exercise in
                exTotal + exercise.sets.reduce(0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
            }
        }
    }
    
    private static func totalSets(for sessions: [WorkoutSession]) -> Int {
        sessions.reduce(0) { total, session in
            if let stored = session.totalSets, stored > 0 {
                return total + stored
            }
            return total + session.exercises.reduce(0) { $0 + $1.sets.count }
        }
    }
}