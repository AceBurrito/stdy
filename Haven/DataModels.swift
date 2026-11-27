import Foundation
import SwiftData

// MARK: - User Profile
@Model
class UserProfile {
    var id: UUID = UUID()
    var onboardingComplete: Bool = false
    var onboardingCompletedDate: Date?  // BUG-003: For 7-day milestone grace period
    var hasSeenTrainingIntro: Bool = false  // UX-001: Training program intro card
    var currentDay: Int = 1
    var currentWeek: Int = 0
    var currentTier: String = "Seeker"
    
    
    // Health data
    var age: Int?
    var height: Double?
    var weight: Double?
    var name: String?
    var gender: String?
    var currentProteinIntake: Double?
    var proteinIsEstimated: Bool = true
    var targetWakeTime: Date?
    var selfReportedSleepHours: Double?

    // Intervention Selection
    var selectedInterventionIds: [String]?
    var selectedInterventionsJSON: String?
    var lastInterventionUnlockDate: Date?
    
    // Week tracking
    var planActivationDate: Date?
    var currentWeekStartDate: Date?
    
    // Training context
    var currentActivities: String?
    var lovedExercises: String?
    var availableEquipment: String?
    var trainingConstraints: String?  
    var primaryGoal: String?
    var secondaryGoal: String?
    var trainingDaysPerWeek: Int?
    var trainingMinutesPerSession: Int?
    var activityLevel: String?
    var trackProtein: Bool = false
    var activitySchedule: String?
    var experienceLevel: String?
    var trainingScheduleJSON: String?
    var planAdjustmentCount: Int = 0
    var planAdjustmentWeekStart: Date?
    var proteinGoal: Int?
    var proteinGoalSource: String?
    var goalWeight: Double?
    var lastZone2CoachingDate: Date?
    var lastZone2CoachingResponse: String?
    var lastCelebratedMilestone: Int?
    var lastCheckInDate: Date?

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

    // Optimization Habits
    var optimizationHabitsUnlocked: Bool = false
    var optimizationHabitsDeclinedDate: Date?

    // Event Training
    var isTrainingForEvent: Bool = false
    var eventType: String?
    var eventName: String?
    var eventDate: Date?
    var hasExistingPlan: Bool = false
    var existingPlanDetails: String?
    var existingPlanWeek: Int?
    var trainingMode: String = "longevity"
    var eventCompletedDate: Date?
    @Relationship(deleteRule: .nullify, inverse: \UserCapabilityAssessment.userProfile)
    var currentAssessment: UserCapabilityAssessment?


    
    // Event week tracking (SINGLE SET)
    var currentEventWeek: Int = 1
    var eventPlanStartDate: Date?
    var lastEventWeekAdvanceDate: Date?
    var missedWorkoutsInPeriod: Int = 0
    var lastMissedWorkoutCheck: Date?
    var bailoutPromptShownDate: Date?
    var weeklyCommitDate: Date?  
    var lastDeloadWeekDate: Date?

    // ============================================
    // TRAINING TIER SYSTEM (0-4)
    // 0 = Recovery, 1 = Beginner, 2 = Active, 3 = Advanced, 4 = Beast Mode
    // ============================================
    var trainingTier: Int?
    var trainingTierName: String?
    var trainingTierAssessedAt: Date?
    var lastTrainingTierReassessmentDate: Date?

    // ============================================
    // LONGEVITY TIER SYSTEM
    // "at_risk", "rising", "phoenix", "optimal", "elite"
    // ============================================
    var longevityTier: String?
    var longevityTierPercentile: Int?
    var longevityTierRevealedAt: Date?
    var lastLongevityTierCalculationDate: Date?

    // Longevity Tier Assessment
    var longevityTierAssessmentAvailableDate: Date?
    var lastLongevityTierAssessmentDate: Date?
    var nextLongevityTierAssessmentDate: Date?
    var lastTierRecalculation: Date?


    // ============================================
    // TIER PROGRESSION TRACKING
    // ============================================
    var consistentWeeksAtCurrentTier: Int = 0
    var tierProgressionHistoryJSON: String?  // [{"date": "...", "fromTier": 1, "toTier": 2, "reason": "..."}]

    // ============================================
    // CRISIS MODE
    // ============================================
    var isCrisisMode: Bool = false
    var crisisModeStartDate: Date?
    var crisisModeReason: String?

    // ============================================
    // RECOVERY TIER (TIER 0) SPECIFIC
    // ============================================
    var hasMedicalClearance: Bool?
    var medicalClearanceDate: Date?
    var approvedExercisesJSON: String?  // From PT/doctor
    var nextMedicalCheckInDate: Date?
    var recoveryCondition: String?  // "post_surgery", "chronic_condition", "severe_limitation"

    var movementPlanStartDate: Date?

    // Strength Assessment Data
    var benchPressMax: Double?
    var squatMax: Double?
    var deadliftMax: Double?
    var pushupRange: String?  // "0-5", "6-15", "16-30", "31-50", "50+"
    var canStandFromSitting: Bool?
    var deadHangRange: String?  // "cant", "under_15", "15-30", "30-60", "60+"
    var strengthDataSource: String?  // "selfReported", "bodyweightOnly", "dontKnow", "workoutDerived"


    var lastAIHabitChangeDate: Date?

    // ============================================
    // PACE SCORING SYSTEM
    // ============================================
    var latestPaceValue: Double?
    var latestPaceDate: Date?
    var latestPaceConfidence: String?
    var paceBaselineValue: Double?        // First calculated Pace (from onboarding)
    var paceBaselineDate: Date?
    var bestPaceEver: Double?             // Lowest Pace achieved (lower = better)
    var bestPaceDate: Date?
    var lastStrengthAssessmentDate: Date?
    var userExercisesRegularly: Bool = false

    // ============================================
    // MORNING BRIEF TRACKING (Sprint 1 — Engagement Overhaul)
    // ============================================
    var lastBriefVarietyKey: String?      // Prevents same template category 2 days in a row
    var lastBriefDate: Date?              // When last brief was generated
    var announcedPRExerciseIDs: [String] = []  // BUG-012: Track which PR exercise announcements have been shown

    // ============================================
    // STREAK PERSISTENCE (Sprint 1 — Engagement Overhaul)
    // ============================================
    var longestStreakEver: Int = 0                // Personal best streak (updated on each app launch)
    var lastCelebratedStreakMilestone: Int = 0    // Highest streak milestone already celebrated (3/7/14/21/30/50/100)
    var morningBriefNotificationEnabled: Bool = false

    init() {
        self.id = UUID()
        self.onboardingComplete = false
        self.onboardingCompletedDate = nil
        self.currentDay = 1
        self.currentWeek = 0
        self.currentTier = "Seeker"
        self.planActivationDate = nil
        self.currentWeekStartDate = nil
        self.name = nil
        self.gender = nil
        
        // Training defaults
        self.experienceLevel = nil
        self.currentActivities = nil
        self.lovedExercises = nil
        self.availableEquipment = nil
        self.trainingConstraints = nil
        self.trainingDaysPerWeek = nil
        self.trainingMinutesPerSession = nil
        
        // Event defaults
        self.isTrainingForEvent = false
        self.trainingMode = "longevity"
        self.hasExistingPlan = false
        self.currentEventWeek = 1
        self.missedWorkoutsInPeriod = 0
        self.weeklyCommitDate = nil
        self.lastDeloadWeekDate = nil

        self.selectedInterventionIds = nil
        self.selectedInterventionsJSON = nil
        self.lastInterventionUnlockDate = nil

        // AI Master Prompt Additions
        self.trainingTier = nil
        self.trainingTierName = nil
        self.trainingTierAssessedAt = nil
        self.lastTrainingTierReassessmentDate = nil

        self.longevityTier = nil
        self.longevityTierPercentile = nil
        self.longevityTierRevealedAt = nil
        self.lastLongevityTierCalculationDate = nil

        self.consistentWeeksAtCurrentTier = 0
        self.tierProgressionHistoryJSON = nil

        self.isCrisisMode = false
        self.crisisModeStartDate = nil
        self.crisisModeReason = nil

        self.hasMedicalClearance = nil
        self.medicalClearanceDate = nil
        self.approvedExercisesJSON = nil
        self.nextMedicalCheckInDate = nil
        self.recoveryCondition = nil

        // Pace defaults
        self.latestPaceValue = nil
        self.latestPaceDate = nil
        self.latestPaceConfidence = nil
        self.paceBaselineValue = nil
        self.paceBaselineDate = nil
        self.bestPaceEver = nil
        self.bestPaceDate = nil
        self.lastStrengthAssessmentDate = nil
        self.userExercisesRegularly = false
        self.strengthDataSource = nil

        // Morning Brief defaults (Sprint 1)
        self.lastBriefVarietyKey = nil
        self.lastBriefDate = nil

        // Streak persistence defaults (Sprint 1)
        self.longestStreakEver = 0
        self.lastCelebratedStreakMilestone = 0

        // Notification preferences (Sprint 5 — Notification Overhaul)
        self.morningBriefNotificationEnabled = false
    }
    
    // MARK: - Inverse Relationships (required for CloudKit — must be optional)
    @Relationship(deleteRule: .cascade, inverse: \Habit.userProfile)
    var habits: [Habit]?
    
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
    
    @Relationship(deleteRule: .cascade, inverse: \WeeklyCheckIn.userProfile)
    var weeklyCheckIns: [WeeklyCheckIn]?
    
    @Relationship(deleteRule: .cascade, inverse: \TrainingProgram.userProfile)
    var trainingPrograms: [TrainingProgram]?
    
    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.userProfile)
    var personalRecords: [PersonalRecord]?
    
    @Relationship(deleteRule: .cascade, inverse: \ProteinEntry.userProfile)
    var proteinEntries: [ProteinEntry]?
    
    @Relationship(deleteRule: .cascade, inverse: \CoachingEntry.userProfile)
    var coachingEntries: [CoachingEntry]?
    
    @Relationship(deleteRule: .cascade, inverse: \LongevityPlan.userProfile)
    var longevityPlans: [LongevityPlan]?
    
    @Relationship(deleteRule: .cascade, inverse: \LongevityTierHistory.userProfile)
    var longevityTierHistories: [LongevityTierHistory]?
    
    @Relationship(deleteRule: .cascade, inverse: \BiologicalPaceScore.userProfile)
    var biologicalPaceScores: [BiologicalPaceScore]?
    
    @Relationship(deleteRule: .cascade, inverse: \ComponentMilestone.userProfile)
    var componentMilestones: [ComponentMilestone]?
    
    @Relationship(deleteRule: .cascade, inverse: \EventMasterPlan.userProfile)
    var eventMasterPlans: [EventMasterPlan]?
    
    @Relationship(deleteRule: .cascade, inverse: \EventWeeklyCheckIn.userProfile)
    var eventWeeklyCheckIns: [EventWeeklyCheckIn]?

    // Sprint 1 — Morning Brief inverse relationship
    @Relationship(deleteRule: .cascade, inverse: \MorningBriefEntry.userProfile)
    var morningBriefEntries: [MorningBriefEntry]?

    // Workout Routines
    @Relationship(deleteRule: .cascade, inverse: \WorkoutRoutine.userProfile)
    var workoutRoutines: [WorkoutRoutine]?
}

// MARK: - User Capability Assessment
@Model
class UserCapabilityAssessment {
    var id: UUID = UUID()
    
    // Event type this assessment is for
    var eventType: String = ""
    
    // Universal assessment fields
    var runningCapability: String = ""
    var recentRaces: [String] = []
    var strengthTrainingFrequency: String = ""
    var weeklyTimeAvailable: String = ""
    var strengthDaysPerWeek: Int? // 0, 1, 2, or 3
    var strengthGoal: String? // "injury_prevention" or "build_strength"
    var equipmentAccess: String? // "full_gym" or "home_gym"
    
    // Optional fields for different event types
    var swimmingCapability: String?
    var cyclingCapability: String?
    var triathlonExperience: String?
    var functionalFitnessBackground: [String]?
    var availableEquipment: [String]?
    
    // HYROX-specific
    var trainsAtHyroxGym: Bool?
    
    // Timeline calculations (set by CapabilityAssessor)
    var minimumWeeksRequired: Int?
    var recommendedWeeks: Int?
    
    // Timestamp
    var createdDate: Date = Date()
    
    // Inverse handled by UserProfile.currentAssessment
    var userProfile: UserProfile?
    
    // Simple initializer for EventCreationFlow
    init(eventType: String) {
        self.id = UUID()
        self.eventType = eventType
        
        // Initialize with empty/default values
        self.runningCapability = ""
        self.recentRaces = []
        self.strengthTrainingFrequency = ""
        self.weeklyTimeAvailable = ""
        
        self.swimmingCapability = nil
        self.cyclingCapability = nil
        self.triathlonExperience = nil
        self.functionalFitnessBackground = nil
        self.availableEquipment = nil
        self.trainsAtHyroxGym = nil
        
        self.minimumWeeksRequired = nil
        self.recommendedWeeks = nil
        
        self.createdDate = Date()
        self.userProfile = nil
    }
    
    // Inverse for EventMasterPlan.assessment (required for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \EventMasterPlan.assessment)
    var eventMasterPlans: [EventMasterPlan]?
}

// MARK: - Event Template
@Model
final class EventTemplate {
    var id: UUID = UUID()
    var eventType: String = ""
    var experienceLevel: String = ""
    var weekDuration: Int = 0
    
    // Matching criteria
    var minRunningCapability: String = ""
    var maxRunningCapability: String = ""
    var requiresRecentRace: Bool = false
    var requiresStrengthBase: Bool = false
    var templateDescription: String = ""  // RENAMED from 'description'
    
    // Full plan storage
    var fullPlanJSON: String = "[]"
    var phasesJSON: String = "{}"
    
    var createdDate: Date = Date()
    var lastUpdated: Date = Date()
    
    init(eventType: String, experienceLevel: String, weekDuration: Int) {
        self.id = UUID()
        self.eventType = eventType
        self.experienceLevel = experienceLevel
        self.weekDuration = weekDuration
        self.minRunningCapability = ""
        self.maxRunningCapability = ""
        self.requiresRecentRace = false
        self.requiresStrengthBase = false
        self.templateDescription = ""  // UPDATED
        self.fullPlanJSON = "[]"
        self.phasesJSON = "{}"
        self.createdDate = Date()
        self.lastUpdated = Date()
    }
}

// MARK: - Event Master Plan (High-level periodization)
@Model
class EventMasterPlan {
    var id: UUID = UUID()
    var eventType: String = ""
    var eventName: String?
    var eventDate: Date?
    var totalWeeks: Int = 0
    var createdAt: Date = Date()
    var isActive: Bool = true
    
    // Periodization data
    var phasesJSON: String?
    var weeklyTargetsJSON: String?
    var weeklyStructureJSON: String?
    
    // Status tracking
    var status: String = "scheduled" // "scheduled", "active", "completed", "cancelled"
    var scheduledStartDate: Date? // When training should start (for future-dated events)
    var actualStartDate: Date? // When user actually started
    var eventCompletionDate: Date? // When event happened
    
    // Assessment reference
    var assessmentId: UUID? // Link to UserCapabilityAssessment
    var timelineWarningsJSON: String? // JSON array of warnings shown to user
    
    // Template tracking
    var usesTemplates: Bool = true // Whether this plan uses templates for weeks 1-3
    var templateId: UUID? // Reference to template used
    var personalizationTriggered: Bool = false
    var personalizationDate: Date?
    
    // Reminder tracking
    var fourWeekReminderSent: Bool = false
    var fourWeekReminderDate: Date?
    var twoWeekReminderSent: Bool = false
    var twoWeekReminderDate: Date?
    var activationReminderSent: Bool = false
    
    // User confirmation (for future-dated events)
    var userConfirmed: Bool? // nil = pending, true = confirmed, false = cancelled
    var confirmationDate: Date?
    
    // Equipment (for HYROX)
    var equipmentJSON: String? // Stores equipment availability + substitutions
    
    // Relationships
    @Relationship(deleteRule: .nullify) var userProfile: UserProfile?
    @Relationship(deleteRule: .nullify) var assessment: UserCapabilityAssessment?
    
    init(eventType: String, totalWeeks: Int) {
        self.id = UUID()
        self.eventType = eventType
        self.totalWeeks = totalWeeks
        self.createdAt = Date()
        self.isActive = true
    }
    
    func getWeeklyTarget(for week: Int) -> WeeklyTarget? {
        guard let json = weeklyTargetsJSON,
              let data = json.data(using: .utf8),
              let targets = try? JSONDecoder().decode([WeeklyTarget].self, from: data) else {
            return nil
        }
        return targets.first { $0.week == week }
    }
    
    func getPhase(for week: Int) -> String {
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

// MARK: - Event Weekly Check-In
@Model
class EventWeeklyCheckIn {
    var id: UUID = UUID()
    var eventPlanId: UUID = UUID()
    var weekNumber: Int = 0
    var checkInDate: Date = Date()
    
    // Training Adherence
    var workoutsCompleted: Int = 0
    var workoutsPlanned: Int = 0
    var adherenceRate: Double = 0.0
    
    // Biomarkers (from Apple Health)
    var hrvAverage: Double?
    var hrvBaseline: Double?
    var sleepAverage: Double?
    var rhrAverage: Double?
    var rhrBaseline: Double?
    
    // Subjective Feedback
    var energyLevel: Int? // 1-5
    var recoveryFeeling: Int? // 1-5
    var soreness: String? // "none", "minor", "concerning"
    var sorenessAreas: [String] = []
    var motivationLevel: Int? // 1-5
    var stressLevel: Int? // 1-5
    var userNotes: String?
    
    // Performance Data (JSON - event specific)
    var performanceDataJSON: String?
    // Example for running: {"easyPace": "10:15/mile", "tempoPace": "9:25/mile", "longRunPace": "10:30/mile"}
    
    // AI Coaching Response
    var aiAnalysis: String?
    var aiAdjustmentsJSON: String? // JSON array of adjustments
    var aiCoachingMessage: String?
    var apiCost: Double?
    
    // Relationship
    @Relationship(deleteRule: .nullify) var userProfile: UserProfile?
    
    init(eventPlanId: UUID, weekNumber: Int) {
        self.id = UUID()
        self.eventPlanId = eventPlanId
        self.weekNumber = weekNumber
        self.checkInDate = Date()
    }
}

// MARK: - Weekly Target (for JSON decoding)
struct WeeklyTarget: Codable {
    let week: Int
    let phase: String
    let totalVolume: String
    let focus: String
    let keyWorkouts: [String]
    let swimSessions: Int?
    let bikeSessions: Int?
    let runSessions: Int?
    let strengthSessions: Int?
    let brickSession: Bool?
}

// MARK: - Daily Check-In
@Model
class DailyCheckIn {
    var id: UUID = UUID()
    var dayNumber: Int = 0
    var date: Date = Date()
    var type: String = ""
    
    var feelingNow: Int?
    var stressLevel: Int?
    var notes: String?
    
    var bedtime: Date?
    var wakeTime: Date?
    var morningFeeling: Int?
    var timeInBed: Double?
    
    init(dayNumber: Int, date: Date, type: String) {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.date = date
        self.type = type
    }
}

// MARK: - Morning Brief Entry (Sprint 1 — Engagement Overhaul)
@Model
class MorningBriefEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var dayNumber: Int = 0
    var headline: String = ""
    var body: String = ""
    var todayPreview: String?
    var accentColor: String = "teal"   // "teal", "amber", "coral"
    var icon: String = "sun.max.fill"
    var varietyKey: String = ""
    var userProfile: UserProfile?

    init(dayNumber: Int, headline: String, body: String, todayPreview: String? = nil, accentColor: String = "teal", icon: String = "sun.max.fill", varietyKey: String) {
        self.id = UUID()
        self.date = Date()
        self.dayNumber = dayNumber
        self.headline = headline
        self.body = body
        self.todayPreview = todayPreview
        self.accentColor = accentColor
        self.icon = icon
        self.varietyKey = varietyKey
    }
}

// MARK: - Habit Model
@Model
class Habit {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var pillar: String = ""
    var startDate: Date = Date()
    var isActive: Bool = true

    var habitType: String = "non_negotiable"
    var isTrainingHabit: Bool = false
    var trainingDayType: String?
    var isUnlocked: Bool = true
    var dayOfWeek: Int?

    var howToGuide: String?
    var researchCitation: String?
    var interventionId: String?
    var sortOrder: Int = 0
    
    @Relationship(deleteRule: .cascade) var completions: [HabitCompletion]?
    var userProfile: UserProfile?
    
    init(
        title: String,
        details: String,
        pillar: String,
        startDate: Date = Date(),
        habitType: String = "non_negotiable",
        isTrainingHabit: Bool = false,
        trainingDayType: String? = nil,
        isUnlocked: Bool = true,
        dayOfWeek: Int? = nil,
        howToGuide: String? = nil,
        researchCitation: String? = nil,
        interventionId: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.pillar = pillar
        self.startDate = startDate
        self.isActive = true
        self.habitType = habitType
        self.isTrainingHabit = isTrainingHabit
        self.trainingDayType = trainingDayType
        self.isUnlocked = isUnlocked
        self.dayOfWeek = dayOfWeek
        self.howToGuide = howToGuide
        self.researchCitation = researchCitation
        self.interventionId = interventionId
    }
    
    func appliesTo(date: Date) -> Bool {
        guard isTrainingHabit, let habitDay = dayOfWeek else { return true }
        let calendar = Calendar.current
        let dateWeekday = calendar.component(.weekday, from: date) - 1
        return habitDay == dateWeekday
    }
}

// MARK: - Lesson Model
@Model
class Lesson {
    var id: UUID = UUID()
    var dayNumber: Int = 0
    var title: String = ""
    var pillar: String = ""
    var content: String = ""
    
    init(dayNumber: Int, title: String = "", pillar: String = "", content: String = "") {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.title = title
        self.pillar = pillar
        self.content = content
    }
}

// MARK: - Lesson Progress Model
@Model
class LessonProgress {
    var id: UUID = UUID()
    var dayNumber: Int = 0
    var completed: Bool = false
    var completedAt: Date?
    
    init(dayNumber: Int, completed: Bool = false) {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.completed = completed
        self.completedAt = completed ? Date() : nil
    }
}

// MARK: - Habit Completion Model
@Model
class HabitCompletion {
    var id: UUID = UUID()
    var date: Date = Date()
    var completed: Bool = false
    var habit: Habit?
    
    init(date: Date, completed: Bool = false) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.completed = completed
    }
}

// MARK: - Weekly Check-In
@Model
class WeeklyCheckIn {
    var id: UUID = UUID()
    var weekNumber: Int = 0
    var date: Date = Date()
    
    var energyLevel: Int?
    var biggestChallenge: String?
    var biggestWin: String?
    var overallRating: Int?
    
    var habitCompletionRate: Double?
    var sleepAverage: Double?
    var hrvAverage: Double?
    var rhrAverage: Double?
    
    var aiCoachingFeedback: String?
    
    var protocolRecommendation: String?
    var recommendationAccepted: Bool?
    var recommendationReasoning: String?
    var recommendationChanges: [String]?

    var lastCheckInDate: Date?


    // ⭐ NEW: Tier-related fields
    var isFirstCheckIn: Bool = false  // Flag for Longevity Tier reveal
    var longevityTierRevealed: Bool = false  // Track if tier was shown
    var longevityTierAtCheckIn: String?  // Snapshot of tier at this check-in
    var longevityTierPercentileAtCheckIn: Int?  // Snapshot of percentile
    var tierProgressionDetected: Bool = false  // Did user progress a training tier?
    var newTrainingTier: Int?  // If progressed, what's the new tier?
    
    var userProfile: UserProfile?
    
    init(weekNumber: Int, date: Date) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.date = date
        self.protocolRecommendation = nil
        self.recommendationAccepted = nil
        self.recommendationReasoning = nil
        self.recommendationChanges = nil
    }
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
    var weight: Double = 0
    var bodyFat: Double?
    var waistCircumference: Double?
    var notes: String?
    
    var userProfile: UserProfile?
    
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

// MARK: - Protein Entry
@Model
final class ProteinEntry {
    var date: Date = Date()
    var grams: Int = 0
    var isEstimated: Bool = false
    var userProfile: UserProfile?
    
    init(date: Date, grams: Int, isEstimated: Bool = false) {
        self.date = date
        self.grams = grams
        self.isEstimated = isEstimated
    }
}

// MARK: - Coaching Entry
@Model
class CoachingEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""
    var title: String = ""
    var content: String = ""
    var weekNumber: Int?
    
    var userProfile: UserProfile?
    
    init(type: String, title: String, content: String, weekNumber: Int? = nil) {
        self.id = UUID()
        self.date = Date()
        self.type = type
        self.title = title
        self.content = content
        self.weekNumber = weekNumber
    }
}