import Foundation

// MARK: - Habit Trend
// Used by DataController.getHabitTrends() and ProtocolAdjustmentEngine

struct HabitTrend {
    let habitName: String
    let currentWeekRate: Double
    let previousWeekRate: Double?
    let trend: String           // "improving", "declining", "stable", "new"
    let analysis: String        // Human-readable summary
    
    /// Convenience accessor used by ProtocolAdjustmentEngine
    var recentAdherence: Double { currentWeekRate }
}

