import Foundation

// MARK: - Historical Convenience Initializer
// Used by DataController.getWeeklyCheckInData() and getPreviousWeeksData()
// which pass simple parameters from stored WeeklyCheckIn records.
// Maps old-style fields to the full WeeklyCheckInData struct.

extension WeeklyCheckInData {

    /// Creates a WeeklyCheckInData from legacy/simple parameters.
    /// Fields not available from historical records default to safe values.
    init(
        weekNumber: Int = 0,
        habitCompletionRate: Double = 0,
        avgSleep: Double = 0,
        avgHRV: Double = 0,
        avgRHR: Double = 0,
        energyRating: Int = 3,
        stressRating: Int = 3,
        recoveryRating: Int = 3,
        challenges: String = "",
        wins: String = "",
        date: Date = Date()
    ) {
        // Pace — not available from old records
        self.paceStart = 0
        self.paceEnd = 0
        self.paceTrend = "stable"
        self.strongestComponent = "Unknown"
        self.weakestComponent = "Unknown"
        self.weakestPercentile = 50

        // Health Metrics
        self.sleepAvgHours = avgSleep
        self.sleepPrevWeekAvg = 0
        self.hrvAvg = avgHRV
        self.hrvPrevWeekAvg = 0
        self.hrvTrend2Week = 0
        self.rhrAvg = avgRHR
        self.rhrPrevWeekAvg = 0
        self.rhrTrend2Week = 0
        self.stepsAvg = 0

        // Adherence
        self.habitAdherencePercent = Int(habitCompletionRate * 100)
        self.trainingAdherencePercent = 0
        self.sessionsCompleted = 0
        self.sessionsPrescribed = 0

        // Habit Detail
        self.habits = []
        self.consecutiveWeeksAbove80 = 0
        self.totalActiveHabits = 0

        // Strength
        self.liftProgressions = []

        // Cardio
        self.cardioSessions = 0
        self.cardioTotalMinutes = 0
        self.cardioPrevWeekMinutes = 0
        self.zone2Minutes = 0
        self.zone2PercentOfTotal = 0
        self.intervalsDetected = false
        self.avgIntervalRecoveryBPM = nil

        // Deload
        self.weeksSinceDeload = 0
        self.trainingAdherence2Week = 0

        // User Context
        self.userContext = challenges.isEmpty ? nil : challenges
        self.currentWeight = nil
        self.previousWeight = nil
        self.zone2HRRange = "124-145"
    }
}