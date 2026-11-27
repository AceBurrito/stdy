import Foundation
import SwiftData

// MARK: - User Profile
//
// Steady pivot (Nov 2026): Habit, Pace, longevity tier, nutrition, event and
// weekly check-in fields were removed. SwiftData drops removed attributes in a
// lightweight migration; no beta users exist, so no data carry-over is needed.
// CloudKit rules: every property has a default or is optional, no unique
// constraints, relationships optional.
@Model
class UserProfile {
    var id: UUID = UUID()
    var onboardingComplete: Bool = false
    var onboardingCompletedDate: Date?
    var hasSeenTrainingIntro: Bool = false  // UX-001: Training program intro card
    var currentDay: Int = 1
    var currentWeek: Int = 0
    
    // Basics (used for metabolic age and HR zones)
    var age: Int?
    var height: Double?          // inches
    var weight: Double?          // lbs
    var name: String?
    var gender: String?
    
    // Body composition starting point
    /// Body fat % as a fraction (0.18 = 18%). Nil when unknown.
    var bodyFatPercent: Double?
    /// Target body fat % as a fraction. Drives the smart goal weight (Sprint 2).
    var targetBodyFatPercent: Double?
    
    // Plan tracking
    var planActivationDate: Date?
    var currentWeekStartDate: Date?
    
    // Training context
    /// "lose_fat", "build_muscle", "recomp", "maintain" (see SteadyGoal)
    var primaryGoal: String?
    /// Legacy Atlas field. No longer set by Steady.
    var secondaryGoal: String?
    /// Display string from SteadyEquipment ("Bodyweight", "Dumbbells", "Full Gym")
    var availableEquipment: String?
    var trainingConstraints: String?
    var trainingDaysPerWeek: Int?
    var trainingMinutesPerSession: Int?
    /// "beginner", "intermediate", "advanced"
    var experienceLevel: String?
    var planAdjustmentCount: Int = 0
    var planAdjustmentWeekStart: Date?
    var goalWeight: Double?

    // Unit System Preference (stored as raw string for CloudKit compatibility)
    // "imperial", "metric", or "" for auto-detect from device locale
    var unitPreference: String = ""

    /// Resolves the effective UnitSystem from the stored preference string.
    /// Returns device locale default when preference is "" (auto).
    var effectiveUnitSystem: UnitSystem {
        switch unitPreference {
        case "imperial": return .imperial
        case "metric":   return .metric
        default:         return UnitSystem.deviceDefault
        }
    }

    init() {
        self.id = UUID()
        self.onboardingComplete = false
        self.currentDay = 1
        self.currentWeek = 0
    }
    
    // MARK: - Inverse Relationships (required for CloudKit — must be optional)
    @Relationship(deleteRule: .cascade, inverse: \HealthMetrics.userProfile)
    var healthMetrics: [HealthMetrics]?
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.userProfile)
    var workoutSessions: [WorkoutSession]?
    
    @Relationship(deleteRule: .cascade, inverse: \BodyCompEntry.userProfile)
    var bodyCompEntries: [BodyCompEntry]?
    
    @Relationship(deleteRule: .cascade, inverse: \CardioSession.userProfile)
    var cardioSessions: [CardioSession]?
    
    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.userProfile)
    var progressPhotos: [ProgressPhoto]?
    
    @Relationship(deleteRule: .cascade, inverse: \TrainingProgram.userProfile)
    var trainingPrograms: [TrainingProgram]?
    
    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.userProfile)
    var personalRecords: [PersonalRecord]?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRoutine.userProfile)
    var workoutRoutines: [WorkoutRoutine]?
}

// MARK: - Health Metrics
@Model
class HealthMetrics {
    var id: UUID = UUID()
    var date: Date = Date()
    var userProfile: UserProfile?
    
    var sleepDuration: Double?
    var bedtime: Date?
    var wakeTime: Date?
    var sleepQuality: String?
    
    var heartRateVariability: Double?
    var restingHeartRate: Double?
    
    var vo2Max: Double?
    var activeEnergyBurned: Double?
    var exerciseMinutes: Double?
    
    var weight: Double?
    var stepCount: Double?
    var bodyFatPercentage: Double?
    
    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
    }
}

// MARK: - Training Program
@Model
class TrainingProgram {
    var id: UUID = UUID()
    var userProfile: UserProfile?
    var generatedDate: Date = Date()
    var programText: String = ""
    var programSummary: String?
    var splitType: String?
    var daysPerWeek: Int = 4
    var minutesPerSession: Int = 45
    var currentPhase: Int = 1
    var currentWeek: Int = 0
    var totalWeeks: Int = 0
    var startDate: Date?
    var isActive: Bool = false
    
    var isEventPlan: Bool = false
    var eventType: String?
    var eventName: String?
    var eventDate: Date?
    var phasesJSON: String?
    var hasUserEdits: Bool = false
    var originalPlanJSON: String? 

    var planSource: String?         // "template", "custom", "event"
    var planTemplateID: String?     // References TrainingPlanCatalog template ID
    var planCategory: String?   

    @Relationship(deleteRule: .cascade, inverse: \PlannedWorkoutWeek.trainingProgram)
    var _workoutWeeks: [PlannedWorkoutWeek]?
    
    @Relationship(deleteRule: .cascade, inverse: \PlannedWorkoutDay.trainingProgram)
    var _workoutDays: [PlannedWorkoutDay]?
    
    /// Non-optional accessor — CloudKit requires the stored property to be optional,
    /// but the rest of the codebase expects a plain array.
    var workoutWeeks: [PlannedWorkoutWeek] {
        get { _workoutWeeks ?? [] }
        set { _workoutWeeks = newValue }
    }
    
    var workoutDays: [PlannedWorkoutDay] {
        get { _workoutDays ?? [] }
        set { _workoutDays = newValue }
    }
    
    init(programText: String = "", daysPerWeek: Int = 4, minutesPerSession: Int = 45) {
        self.id = UUID()
        self.generatedDate = Date()
        self.programText = programText
        self.daysPerWeek = daysPerWeek
        self.minutesPerSession = minutesPerSession
        self.currentPhase = 1
        self.currentWeek = 1
        self.totalWeeks = 1
        self.isActive = true
        self.isEventPlan = false
        self._workoutWeeks = []
        self._workoutDays = []
        self.hasUserEdits = false
        self.originalPlanJSON = nil 
        self.planSource = nil
        self.planTemplateID = nil
        self.planCategory = nil
    }
    
    var currentWeekWorkouts: PlannedWorkoutWeek? {
        workoutWeeks.first { $0.weekNumber == currentWeek }
    }
    
    func phaseName(for week: Int) -> String {
        guard let json = phasesJSON,
              let data = json.data(using: .utf8),
              let phases = try? JSONDecoder().decode([String: [Int]].self, from: data) else {
            return "Training"
        }
        
        for (phase, range) in phases {
            if range.count == 2 && week >= range[0] && week <= range[1] {
                return phase.capitalized
            }
        }
        return "Training"
    }
}

// MARK: - Planned Workout Week
@Model
class PlannedWorkoutWeek {
    var id: UUID = UUID()
    var weekNumber: Int = 0
    var phaseName: String = "Training"
    var weekFocus: String?
    var totalVolume: String?
    
    @Relationship(deleteRule: .cascade, inverse: \PlannedWorkoutDay.workoutWeek)
    var _days: [PlannedWorkoutDay]?
    
    var days: [PlannedWorkoutDay] {
        get { _days ?? [] }
        set { _days = newValue }
    }
    
    var trainingProgram: TrainingProgram?
    
    init(weekNumber: Int, phaseName: String = "Training") {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.phaseName = phaseName
        self._days = []
    }
}

// MARK: - Planned Workout Day
@Model
class PlannedWorkoutDay {
    var id: UUID = UUID()
    var dayType: String = "rest"
    var dayName: String = ""
    var dayOfWeek: Int = 0
    var orderIndex: Int = 0

    var userActivityName: String?
    
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.workoutDay)
    var _exercises: [PlannedExercise]?
    
    var exercises: [PlannedExercise] {
        get { _exercises ?? [] }
        set { _exercises = newValue }
    }
    
    var cardioType: String?
    var cardioIntensityLevel: String?
    var cardioProtocol: String?
    var cardioDuration: Int?
    var cardioNotes: String?
    var targetHRMin: Int?
    var targetHRMax: Int?
    
    var targetDistance: Double?
    var distanceUnit: String?
    var targetPace: String?
    var workoutStructure: String?
    
    var isBrickWorkout: Bool = false
    var brickComponents: String?
    
    // FEAT-003: Multi-activity day support
    // When a strength day also has cardio, these fields track the secondary cardio activity.
    // The primary activity is determined by dayType ("strength" or "cardio").
    // hasSecondaryCardio = true means this strength day also includes a cardio session.
    var hasSecondaryCardio: Bool = false
    var secondaryCardioDuration: Int?       // minutes
    var secondaryCardioZone: String?        // "Zone 2", "Intervals", "Sprint", "Mixed"
    var secondaryCardioNotes: String?
    
    // Independent completion tracking for multi-activity days
    var isPrimaryCompleted: Bool = false
    var isPrimaryCompletedDate: Date?
    var isSecondaryCompleted: Bool = false
    var isSecondaryCompletedDate: Date?
    
    // ============================================
    // ROUTINE SYSTEM
    // ============================================
    // References a WorkoutRoutine by UUID string (CloudKit-safe — no direct relationship
    // needed; avoids complex multi-parent inverse chains in SwiftData).
    var workoutRoutineID: String?
    
    // Day-level exercise overrides (JSON). When a user swaps an exercise "This Day Only",
    // the override is stored here. The routine itself stays unchanged.
    // Format: [{"originalExerciseID":"...","replacementExerciseID":"...","replacementName":"...","sets":3,"reps":"8-10"}]
    var exerciseOverridesJSON: String?
    
    var trainingProgram: TrainingProgram?
    var workoutWeek: PlannedWorkoutWeek?
    
    init(dayType: String, dayName: String, dayOfWeek: Int = 0, orderIndex: Int = 0) {
        self.id = UUID()
        self.dayType = dayType
        self.dayName = dayName
        self.dayOfWeek = dayOfWeek
        self.orderIndex = orderIndex
        self._exercises = []
        self.isBrickWorkout = false
        // FEAT-003 defaults
        self.hasSecondaryCardio = false
        self.isPrimaryCompleted = false
        self.isSecondaryCompleted = false
    }
    
    // MARK: - Exercise Override Support
    
    /// Decoded exercise overrides for this day.
    var exerciseOverrides: [ExerciseOverride] {
        get {
            guard let json = exerciseOverridesJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([ExerciseOverride].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                exerciseOverridesJSON = nil
            } else if let data = try? JSONEncoder().encode(newValue),
                      let json = String(data: data, encoding: .utf8) {
                exerciseOverridesJSON = json
            }
        }
    }
    
    /// Add a day-level override (swap exercise for this day only).
    func addOverride(_ override: ExerciseOverride) {
        var overrides = exerciseOverrides
        // Remove existing override for same original exercise
        overrides.removeAll { $0.originalExerciseID == override.originalExerciseID }
        overrides.append(override)
        exerciseOverrides = overrides
    }
}

// MARK: - Exercise Override (Codable, stored as JSON on PlannedWorkoutDay)

struct ExerciseOverride: Codable, Identifiable {
    var id: String { originalExerciseID }
    let originalExerciseID: String   // RoutineExercise.exerciseID being replaced
    let replacementExerciseID: String // New exercise ID
    let replacementName: String       // Display name of replacement
    let sets: Int
    let reps: String
    let isBodyweight: Bool
}

@Model
class PlannedExercise {
    var id: UUID = UUID()
    var name: String = ""
    var targetSets: Int = 3
    var targetReps: String?  // "8-10", "12-15", "AMRAP", etc.
    var targetRepsMin: Int?  // Parsed min for logging (e.g., 8 from "8-10")
    var targetRepsMax: Int?  // Parsed max for logging (e.g., 10 from "8-10")
    var orderIndex: Int = 0
    var notes: String?
    var isBodyweight: Bool = false
    var equipmentNeeded: String?
    
    var workoutDay: PlannedWorkoutDay?
    
    init(name: String, targetSets: Int, targetReps: String?, orderIndex: Int = 0, isBodyweight: Bool = false) {
        self.id = UUID()
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.orderIndex = orderIndex
        self.isBodyweight = isBodyweight
        
        // Parse targetReps to get min/max
        self.parseTargetReps()
    }
    
    /// Parse targetReps string into min/max integers
    func parseTargetReps() {
        guard let repsString = targetReps else {
            self.targetRepsMin = nil
            self.targetRepsMax = nil
            return
        }
        
        // Handle ranges like "8-10"
        if repsString.contains("-") {
            let parts = repsString.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2,
               let min = Int(parts[0]),
               let max = Int(parts[1]) {
                self.targetRepsMin = min
                self.targetRepsMax = max
                return
            }
        }
        
        // Handle single numbers like "12"
        if let reps = Int(repsString) {
            self.targetRepsMin = reps
            self.targetRepsMax = reps
            return
        }
        
        // Handle special cases like "AMRAP", "Max", "Hold 45 sec"
        // Default to a reasonable range for logging purposes
        self.targetRepsMin = 10
        self.targetRepsMax = 15
    }
    
    /// Get the target reps for logging (uses min value from range)
    var targetRepsForLogging: Int {
        return targetRepsMin ?? 10
    }
}

// MARK: - Workout Session
@Model
class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var workoutName: String?
    var programPhase: Int?
    var notes: String?
    var duration: Int?

    var totalVolume: Double?        // Total weight × reps across all exercises
    var totalSets: Int?             // Completed sets count
    var durationMinutes: Int?       // Wall clock time from first to last set
    var exerciseCount: Int?         // Number of distinct exercises
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workoutSession)
    var _exercises: [Exercise]?
    
    var exercises: [Exercise] {
        get { _exercises ?? [] }
        set { _exercises = newValue }
    }
    
    var userProfile: UserProfile?
    
    init(date: Date = Date(), workoutName: String? = nil) {
        self.id = UUID()
        self.date = date
        self.workoutName = workoutName
        self._exercises = []
    }
}

// MARK: - Exercise
@Model
class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    var notes: String?
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var _sets: [WorkoutSet]?
    
    var sets: [WorkoutSet] {
        get { _sets ?? [] }
        set { _sets = newValue }
    }
    
    var workoutSession: WorkoutSession?
    
    init(name: String, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self._sets = []
    }
}

// MARK: - Workout Set
@Model
class WorkoutSet {
    var id: UUID = UUID()
    var setNumber: Int = 1
    var weight: Double?
    var reps: Int = 0
    var rpe: Int?
    var isBodyweight: Bool = false
    
    var exercise: Exercise?
    
    init(setNumber: Int, weight: Double?, reps: Int, isBodyweight: Bool = false) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.isBodyweight = isBodyweight
    }
}

// MARK: - Body Composition Entry
@Model
class BodyCompEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0          // lbs
    var bodyFat: Double?            // fraction, 0.18 = 18%
    var waistCircumference: Double?
    var notes: String?
    /// "health" when imported from Apple Health; nil or "manual" when logged in the app.
    var source: String?
    
    var userProfile: UserProfile?
    
    var isFromHealth: Bool { source == "health" }
    
    init(date: Date, weight: Double) {
        self.id = UUID()
        self.date = date
        self.weight = weight
    }
}

// MARK: - Progress Photo
@Model
class ProgressPhoto {
    var id: UUID = UUID()
    var date: Date = Date()
    var photoData: Data = Data()
    var notes: String?
    var weight: Double?
    
    var userProfile: UserProfile?
    
    init(date: Date, photoData: Data) {
        self.id = UUID()
        self.date = date
        self.photoData = photoData
    }
}


// MARK: - Cardio Session
@Model
class CardioSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var duration: Int = 0                          // Total minutes
    var sessionType: String = "zone2"                    // CardioActivityType raw value
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var calories: Double?
    var distance: Double?                      // Miles
    var notes: String?
    var wasAboveZone2: Bool?
    var importedFromHealthKit: Bool = false
    var healthKitWorkoutID: String?            // Prevent duplicate imports

    // Zone breakdown (seconds in each zone)
    var zone1Seconds: Double?
    var zone2Seconds: Double?
    var zone3Seconds: Double?
    var zone4Seconds: Double?
    var zone5Seconds: Double?

    // Interval data (stored as JSON)
    var intervalDataJSON: String?
    var intervalCount: Int?
    var avgIntervalPeakHR: Double?
    var avgRecoveryDrop60s: Double?

    // Post-workout recovery
    var postWorkoutHR60s: Double?
    var postWorkoutRecoveryDrop: Double?       // Max HR - HR at 60s

    // Deterministic coaching feedback
    var coachingFeedback: String?

    var userProfile: UserProfile?

    init(date: Date, duration: Int, sessionType: String) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.sessionType = sessionType
    }

    // MARK: - Computed: Zone Breakdown

    var hasZoneData: Bool {
        zone1Seconds != nil || zone2Seconds != nil
    }

    var zoneBreakdown: ZoneBreakdown {
        let z1 = zone1Seconds ?? 0
        let z2 = zone2Seconds ?? 0
        let z3 = zone3Seconds ?? 0
        let z4 = zone4Seconds ?? 0
        let z5 = zone5Seconds ?? 0
        let total = z1 + z2 + z3 + z4 + z5
        return ZoneBreakdown(
            zone1Seconds: z1, zone2Seconds: z2, zone3Seconds: z3,
            zone4Seconds: z4, zone5Seconds: z5,
            totalSeconds: total > 0 ? total : Double(duration * 60)
        )
    }

    // MARK: - Computed: Decoded Intervals

    var decodedIntervals: [DetectedInterval] {
        guard let json = intervalDataJSON,
              let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([DetectedInterval].self, from: data)) ?? []
    }

    // MARK: - Populate from Analysis

    func populate(from result: WorkoutAnalysisResult) {
        self.sessionType = result.activityType.rawValue

        // Zone breakdown
        self.zone1Seconds = result.zoneBreakdown.zone1Seconds
        self.zone2Seconds = result.zoneBreakdown.zone2Seconds
        self.zone3Seconds = result.zoneBreakdown.zone3Seconds
        self.zone4Seconds = result.zoneBreakdown.zone4Seconds
        self.zone5Seconds = result.zoneBreakdown.zone5Seconds

        // Intervals
        if !result.intervals.isEmpty {
            if let data = try? JSONEncoder().encode(result.intervals),
               let json = String(data: data, encoding: .utf8) {
                self.intervalDataJSON = json
            }
            self.intervalCount = result.intervals.count
            self.avgIntervalPeakHR = result.intervals.map(\.peakHR).reduce(0, +) / Double(result.intervals.count)

            let recoveries = result.intervals.compactMap { $0.recoveryAfter?.dropIn60Sec }
            if !recoveries.isEmpty {
                self.avgRecoveryDrop60s = recoveries.reduce(0, +) / Double(recoveries.count)
            }
        }

        // Post-workout recovery
        self.postWorkoutHR60s = result.postWorkoutRecoveryHR
        self.postWorkoutRecoveryDrop = result.postWorkoutRecoveryDrop

        // Deterministic feedback
        self.coachingFeedback = result.feedback
    }
}

// MARK: - Personal Record
@Model
class PersonalRecord {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var recordType: String = ""
    var value: Double = 0
    var date: Date = Date()
    var workoutSessionId: UUID?
    var previousRecord: Double?
    
    var userProfile: UserProfile?
    
    init(exerciseName: String, recordType: String, value: Double, date: Date = Date()) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.recordType = recordType
        self.value = value
        self.date = date
    }
}
