import Foundation

// MARK: - Backward-Compatible Property Aliases
// Maps old field names (used by ProtocolAdjustmentEngine, ProtocolAdjustmentRules,
// and legacy code) to the new WeeklyCheckInData field names.
//
// ONLY aliases for names that do NOT already exist on the struct.
// Do NOT redeclare: habitAdherencePercent, trainingAdherencePercent,
// sleepAvgHours, hrvAvg, rhrAvg, etc. — those are real stored properties.

extension WeeklyCheckInData {

    // Old name → New name (these old names don't exist on the struct)
    var overallAdherence: Double { Double(habitAdherencePercent) / 100.0 }
    var habitCompletionRate: Double { Double(habitAdherencePercent) / 100.0 }
    var avgSleep: Double { sleepAvgHours }
    var avgHRV: Double { hrvAvg }
    var avgRHR: Double { rhrAvg }

    // Subjective ratings — removed from new struct, provide safe defaults
    var energyRating: Int { 3 }
    var stressRating: Int { 3 }

    // Free-text fields — map from userContext
    var wins: String { "" }
    var challenges: String { userContext ?? "" }
}