import Foundation

// MARK: - Plan Template Enums

enum PlanCategory: String, Codable, CaseIterable {
    case basicMovement = "Basic Movement"
    case foundation = "Foundation"
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"
    case athletic = "Athletic Performance"
    case bodyRecomp = "Body Recomposition"
}

enum EquipmentTier: Int, Codable, Comparable {
    case bodyweight = 0
    case dumbbells = 1
    case fullGym = 2

    static func < (lhs: EquipmentTier, rhs: EquipmentTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight"
        case .dumbbells: return "Dumbbells"
        case .fullGym: return "Full Gym"
        }
    }
}

enum ExperienceLevel: String, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

// MARK: - Plan Template Structs

struct TrainingPlanTemplate: Identifiable {
    let id: String
    let name: String
    let category: PlanCategory
    let tagline: String
    let description: String
    let strengthDays: Int
    let splitType: String
    let equipmentTier: EquipmentTier
    let experienceLevel: ExperienceLevel
    let goalAlignment: [String]
    let workouts: [TemplateWorkout]
}

struct TemplateWorkout: Identifiable {
    let id: String
    let name: String
    let exercises: [TemplateExercise]
}

struct TemplateExercise {
    let exerciseID: String
    let sets: Int
    let reps: Int
    let notes: String?
}

// MARK: - Training Plan Catalog

struct TrainingPlanCatalog {

    static let allPlans: [TrainingPlanTemplate] = [
        startHereBW,
        firstStepsDB,
        longevityFoundationDB,
        longevityFoundationGym,
        leanStrongDB,
        leanStrongGym,
        strengthFirst3Day,
        strengthFirst4Day,
        functionalAthleteGym,
        recompDB,
        recompGym
    ]

    // =========================================================================
    // MARK: - Plan 1: Start Here (Bodyweight)
    // =========================================================================

    static let startHereBW = TrainingPlanTemplate(
        id: "start-here-bw",
        name: "Start Here",                          // ✅ Unique — only BW beginner plan
        category: .basicMovement,
        tagline: "Master the basics. Bodyweight only.",
        description: "No equipment needed. Learn fundamental movement patterns — squat, push, pull, hinge, carry. Build the base that everything else is built on.",
        strengthDays: 3,
        splitType: "Full Body",
        equipmentTier: .bodyweight,
        experienceLevel: .beginner,
        goalAlignment: ["liveLonger", "feelBetter"],
        workouts: [
            TemplateWorkout(
                id: "start-here-bw-a",
                name: "Full Body A",
                exercises: [
                    TemplateExercise(exerciseID: "bodyweight-squat", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "push-ups", sets: 3, reps: 10, notes: "From knees if needed"),
                    TemplateExercise(exerciseID: "inverted-row", sets: 3, reps: 10, notes: "Use a sturdy table edge if no bar"),
                    TemplateExercise(exerciseID: "glute-bridge", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 30, notes: nil),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 20, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "start-here-bw-b",
                name: "Full Body B",
                exercises: [
                    TemplateExercise(exerciseID: "bodyweight-squat", sets: 3, reps: 12, notes: "Slow tempo: 3 seconds down"),
                    TemplateExercise(exerciseID: "chest-dips", sets: 3, reps: 8, notes: "Use a chair or bench for assisted dips"),
                    TemplateExercise(exerciseID: "pull-ups", sets: 3, reps: 5, notes: "Use a band or do negatives if needed"),
                    TemplateExercise(exerciseID: "single-leg-glute-bridge", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: "Use a light resistance band"),
                    TemplateExercise(exerciseID: "dead-bug", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 40, notes: "Use heavy objects if no dumbbells")
                ]
            ),
            TemplateWorkout(
                id: "start-here-bw-c",
                name: "Full Body C",
                exercises: [
                    TemplateExercise(exerciseID: "bodyweight-squat", sets: 3, reps: 20, notes: "Pause at the bottom for 1 second"),
                    TemplateExercise(exerciseID: "push-ups", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "inverted-row", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "single-leg-glute-bridge", sets: 3, reps: 12, notes: "12 per side"),
                    TemplateExercise(exerciseID: "side-plank", sets: 3, reps: 20, notes: "20 seconds per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 2: First Steps (Dumbbells)
    // =========================================================================

    static let firstStepsDB = TrainingPlanTemplate(
        id: "first-steps-db",
        name: "First Steps",                         // ✅ Unique — only DB beginner plan
        category: .basicMovement,
        tagline: "Dumbbells and the fundamentals.",
        description: "Build strength with basic dumbbell movements. Learn the patterns before adding barbells. Simple, effective, and scalable.",
        strengthDays: 3,
        splitType: "Full Body",
        equipmentTier: .dumbbells,
        experienceLevel: .beginner,
        goalAlignment: ["liveLonger", "feelBetter"],
        workouts: [
            TemplateWorkout(
                id: "first-steps-db-a",
                name: "Full Body A",
                exercises: [
                    TemplateExercise(exerciseID: "goblet-squat", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "bench-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "romanian-deadlift-dumbbell", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 30, notes: nil),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 20, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "first-steps-db-b",
                name: "Full Body B",
                exercises: [
                    TemplateExercise(exerciseID: "lunges-dumbbell", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 3, reps: 12, notes: "12 per side"),
                    TemplateExercise(exerciseID: "glute-bridge", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 40, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "first-steps-db-c",
                name: "Full Body C",
                exercises: [
                    TemplateExercise(exerciseID: "goblet-squat", sets: 3, reps: 10, notes: "Slow tempo"),
                    TemplateExercise(exerciseID: "incline-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "reverse-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "dead-bug", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 3: Foundation — Dumbbells
    // =========================================================================

    static let longevityFoundationDB = TrainingPlanTemplate(
        id: "longevity-foundation-db",
        name: "Foundation — Dumbbells",               // ✅ RENAMED from "Longevity Foundation"
        category: .foundation,
        tagline: "The movements that matter most. Dumbbells only.",
        description: "Three full-body sessions per week. Compound lifts, carries, grip work, and mobility. A balanced base for any goal. No barbell required.",
        strengthDays: 3,
        splitType: "Full Body",
        equipmentTier: .dumbbells,
        experienceLevel: .intermediate,
        goalAlignment: ["liveLonger", "feelBetter", "getStronger"],
        workouts: [
            TemplateWorkout(
                id: "longevity-foundation-db-a",
                name: "Full Body A",
                exercises: [
                    TemplateExercise(exerciseID: "goblet-squat", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "bench-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "romanian-deadlift-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 45, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "longevity-foundation-db-b",
                name: "Full Body B",
                exercises: [
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "chin-ups", sets: 3, reps: 8, notes: "Use a band if needed"),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "reverse-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dead-bug", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "longevity-foundation-db-c",
                name: "Full Body C",
                exercises: [
                    TemplateExercise(exerciseID: "step-ups", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "incline-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 4, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "kettlebell-swing", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "side-plank", sets: 3, reps: 30, notes: "30 seconds per side"),
                    TemplateExercise(exerciseID: "suitcase-carry", sets: 3, reps: 40, notes: "40 seconds per side")
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 4: Foundation — Full Gym
    // =========================================================================

    static let longevityFoundationGym = TrainingPlanTemplate(
        id: "longevity-foundation-gym",
        name: "Foundation — Full Gym",                // ✅ RENAMED from "Longevity Foundation"
        category: .foundation,
        tagline: "Build strength in the movements that matter most.",
        description: "Three full-body sessions built around barbell compounds, carries, and grip work — a balanced base for any goal, built to progress for months.",
        strengthDays: 3,
        splitType: "Full Body",
        equipmentTier: .fullGym,
        experienceLevel: .intermediate,
        goalAlignment: ["liveLonger", "feelBetter", "getStronger"],
        workouts: [
            TemplateWorkout(
                id: "longevity-foundation-gym-a",
                name: "Full Body A",
                exercises: [
                    TemplateExercise(exerciseID: "squat-barbell", sets: 4, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "bench-press-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "barbell-row", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 8, notes: "8 per side, dumbbells"),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 45, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "longevity-foundation-gym-b",
                name: "Full Body B",
                exercises: [
                    TemplateExercise(exerciseID: "trap-bar-deadlift", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "lat-pulldown", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "pallof-press", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "longevity-foundation-gym-c",
                name: "Full Body C",
                exercises: [
                    TemplateExercise(exerciseID: "front-squat", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "incline-bench-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "seated-cable-row", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "hanging-knee-raise", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "suitcase-carry", sets: 3, reps: 40, notes: "40 seconds per side")
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 5: Lean & Strong — Dumbbells
    // =========================================================================

    static let leanStrongDB = TrainingPlanTemplate(
        id: "lean-strong-db",
        name: "Lean & Strong — Dumbbells",            // ✅ RENAMED from "Lean & Strong"
        category: .hypertrophy,
        tagline: "Body composition focused. Dumbbells only.",
        description: "Four days per week, upper/lower split. Higher volume for muscle growth with compound lifts as the foundation. No gym required.",
        strengthDays: 4,
        splitType: "Upper/Lower",
        equipmentTier: .dumbbells,
        experienceLevel: .intermediate,
        goalAlignment: ["lookBetter", "getStronger"],
        workouts: [
            TemplateWorkout(
                id: "lean-strong-db-upper-a",
                name: "Upper A",
                exercises: [
                    TemplateExercise(exerciseID: "bench-press-dumbbell", sets: 4, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 4, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "reverse-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "lateral-raises-dumbbell", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-curl", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "overhead-tricep-extension-dumbbell", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "lean-strong-db-lower-a",
                name: "Lower A",
                exercises: [
                    TemplateExercise(exerciseID: "goblet-squat", sets: 4, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-dumbbell", sets: 4, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "single-leg-glute-bridge", sets: 3, reps: 12, notes: "12 per side"),
                    TemplateExercise(exerciseID: "kettlebell-swing", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 45, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "lean-strong-db-upper-b",
                name: "Upper B",
                exercises: [
                    TemplateExercise(exerciseID: "incline-press-dumbbell", sets: 4, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "chin-ups", sets: 4, reps: 8, notes: "Use a band if needed"),
                    TemplateExercise(exerciseID: "arnold-press", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "hammer-curl", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "tricep-kickback", sets: 3, reps: 12, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "lean-strong-db-lower-b",
                name: "Lower B",
                exercises: [
                    TemplateExercise(exerciseID: "lunges-dumbbell", sets: 4, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "step-ups", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "glute-bridge", sets: 3, reps: 15, notes: "Elevated feet for difficulty"),
                    TemplateExercise(exerciseID: "reverse-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dead-bug", sets: 3, reps: 12, notes: "12 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 6: Lean & Strong — Full Gym
    // =========================================================================

    static let leanStrongGym = TrainingPlanTemplate(
        id: "lean-strong-gym",
        name: "Lean & Strong — Full Gym",             // ✅ RENAMED from "Lean & Strong"
        category: .hypertrophy,
        tagline: "Body composition focused with progressive overload.",
        description: "Four days per week, upper/lower split. Higher volume for muscle growth with barbell compounds as the foundation. Includes targeted isolation work.",
        strengthDays: 4,
        splitType: "Upper/Lower",
        equipmentTier: .fullGym,
        experienceLevel: .intermediate,
        goalAlignment: ["lookBetter", "getStronger"],
        workouts: [
            TemplateWorkout(
                id: "lean-strong-gym-upper-a",
                name: "Upper A",
                exercises: [
                    TemplateExercise(exerciseID: "bench-press-barbell", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "barbell-row", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "cable-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "lateral-raises-dumbbell", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "barbell-curl", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "tricep-pushdown", sets: 3, reps: 12, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "lean-strong-gym-lower-a",
                name: "Lower A",
                exercises: [
                    TemplateExercise(exerciseID: "squat-barbell", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-barbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "leg-press", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "leg-curl-lying", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "calf-raises-standing", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "hanging-leg-raise", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "lean-strong-gym-upper-b",
                name: "Upper B",
                exercises: [
                    TemplateExercise(exerciseID: "incline-bench-barbell", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "lat-pulldown", sets: 4, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "seated-cable-row", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "pec-deck", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "incline-dumbbell-curl", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "overhead-tricep-extension-cable", sets: 3, reps: 12, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "lean-strong-gym-lower-b",
                name: "Lower B",
                exercises: [
                    TemplateExercise(exerciseID: "deadlift-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "front-squat", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "leg-extension", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "leg-curl-seated", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "hip-thrust-barbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "calf-raises-seated", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "cable-woodchop", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 7: Strength First — 3 Day
    // =========================================================================

    static let strengthFirst3Day = TrainingPlanTemplate(
        id: "strength-first-3day",
        name: "Strength First — 3 Day",               // ✅ RENAMED from "Strength First"
        category: .strength,
        tagline: "Heavy compounds. Get strong, everything else follows.",
        description: "Built around squat, bench, deadlift, and overhead press. Lower volume, higher intensity. Three days per week with full recovery between sessions.",
        strengthDays: 3,
        splitType: "Full Body",
        equipmentTier: .fullGym,
        experienceLevel: .advanced,
        goalAlignment: ["getStronger", "liveLonger"],
        workouts: [
            TemplateWorkout(
                id: "strength-first-3day-a",
                name: "Full Body A — Squat Focus",
                exercises: [
                    TemplateExercise(exerciseID: "squat-barbell", sets: 5, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "bench-press-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "barbell-row", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 45, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: "Go heavy")
                ]
            ),
            TemplateWorkout(
                id: "strength-first-3day-b",
                name: "Full Body B — Deadlift Focus",
                exercises: [
                    TemplateExercise(exerciseID: "deadlift-barbell", sets: 5, reps: 3, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "lat-pulldown", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "strength-first-3day-c",
                name: "Full Body C — Variation",
                exercises: [
                    TemplateExercise(exerciseID: "front-squat", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "incline-bench-barbell", sets: 4, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "seated-cable-row", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "suitcase-carry", sets: 3, reps: 40, notes: "40 seconds per side")
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 8: Strength First — 4 Day
    // =========================================================================

    static let strengthFirst4Day = TrainingPlanTemplate(
        id: "strength-first-4day",
        name: "Strength First — 4 Day",               // ✅ RENAMED from "Strength First"
        category: .strength,
        tagline: "Four days. Barbell-focused. Get strong.",
        description: "Upper/lower split built for strength. Heavy barbell compounds with supporting accessory work. More frequency on the big lifts than the 3-day plan.",
        strengthDays: 4,
        splitType: "Upper/Lower",
        equipmentTier: .fullGym,
        experienceLevel: .advanced,
        goalAlignment: ["getStronger", "liveLonger"],
        workouts: [
            TemplateWorkout(
                id: "strength-first-4day-upper-a",
                name: "Upper A — Bench Focus",
                exercises: [
                    TemplateExercise(exerciseID: "bench-press-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "barbell-row", sets: 4, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "lat-pulldown", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-curl", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "tricep-pushdown", sets: 3, reps: 10, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "strength-first-4day-lower-a",
                name: "Lower A — Squat Focus",
                exercises: [
                    TemplateExercise(exerciseID: "squat-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "leg-curl-lying", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "hanging-knee-raise", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: "Go heavy")
                ]
            ),
            TemplateWorkout(
                id: "strength-first-4day-upper-b",
                name: "Upper B — OHP Focus",
                exercises: [
                    TemplateExercise(exerciseID: "overhead-press-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "pull-ups", sets: 4, reps: 6, notes: "Add weight if possible"),
                    TemplateExercise(exerciseID: "incline-bench-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "seated-cable-row", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "hammer-curl", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "close-grip-bench-press", sets: 3, reps: 8, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "strength-first-4day-lower-b",
                name: "Lower B — Deadlift Focus",
                exercises: [
                    TemplateExercise(exerciseID: "deadlift-barbell", sets: 3, reps: 3, notes: nil),
                    TemplateExercise(exerciseID: "front-squat", sets: 3, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "leg-curl-seated", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "calf-raises-standing", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 9: Functional Athlete (Full Gym)
    // =========================================================================

    static let functionalAthleteGym = TrainingPlanTemplate(
        id: "functional-athlete-gym",
        name: "Functional Athlete",                    // ✅ Unique — only athletic plan
        category: .athletic,
        tagline: "Strength meets conditioning.",
        description: "For people who want to be strong AND athletic. Compound lifts, carries, kettlebell work, and power movements. Built to pair with cardio days.",
        strengthDays: 4,
        splitType: "Full Body / Mixed",
        equipmentTier: .fullGym,
        experienceLevel: .advanced,
        goalAlignment: ["feelBetter", "getStronger"],
        workouts: [
            TemplateWorkout(
                id: "functional-athlete-gym-a",
                name: "Strength A — Lower Emphasis",
                exercises: [
                    TemplateExercise(exerciseID: "trap-bar-deadlift", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "goblet-squat", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "kettlebell-swing", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "pallof-press", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "functional-athlete-gym-b",
                name: "Strength B — Upper Emphasis",
                exercises: [
                    TemplateExercise(exerciseID: "bench-press-barbell", sets: 4, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "pull-ups", sets: 4, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "turkish-getup", sets: 3, reps: 3, notes: "3 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "functional-athlete-gym-c",
                name: "Strength C — Lower Emphasis",
                exercises: [
                    TemplateExercise(exerciseID: "front-squat", sets: 4, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "seated-cable-row", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "kettlebell-swing", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "bird-dog", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "overhead-carry", sets: 3, reps: 40, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "functional-athlete-gym-d",
                name: "Strength D — Upper Emphasis",
                exercises: [
                    TemplateExercise(exerciseID: "overhead-press-barbell", sets: 4, reps: 5, notes: nil),
                    TemplateExercise(exerciseID: "chin-ups", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "incline-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "barbell-row", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "lateral-raises-dumbbell", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "turkish-getup", sets: 3, reps: 3, notes: "3 per side"),
                    TemplateExercise(exerciseID: "suitcase-carry", sets: 3, reps: 40, notes: "40 seconds per side")
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 10: Recomp — Dumbbells
    // =========================================================================

    static let recompDB = TrainingPlanTemplate(
        id: "recomp-db",
        name: "Recomp — Dumbbells",                   // ✅ RENAMED from "Recomp"
        category: .bodyRecomp,
        tagline: "Lose fat. Build muscle. Dumbbells only.",
        description: "Moderate volume and intensity designed to support body recomposition. Compound lifts preserve muscle in a deficit. Pairs well with Zone 2 cardio days.",
        strengthDays: 4,
        splitType: "Upper/Lower",
        equipmentTier: .dumbbells,
        experienceLevel: .intermediate,
        goalAlignment: ["lookBetter", "liveLonger"],
        workouts: [
            TemplateWorkout(
                id: "recomp-db-upper-a",
                name: "Upper A",
                exercises: [
                    TemplateExercise(exerciseID: "bench-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-row", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "reverse-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "lateral-raises-dumbbell", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "hammer-curl", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dead-bug", sets: 3, reps: 10, notes: "10 per side")
                ]
            ),
            TemplateWorkout(
                id: "recomp-db-lower-a",
                name: "Lower A",
                exercises: [
                    TemplateExercise(exerciseID: "goblet-squat", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "kettlebell-swing", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "plank", sets: 3, reps: 45, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "recomp-db-upper-b",
                name: "Upper B",
                exercises: [
                    TemplateExercise(exerciseID: "incline-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "chin-ups", sets: 3, reps: 8, notes: "Use a band if needed"),
                    TemplateExercise(exerciseID: "arnold-press", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "band-pull-apart", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "dumbbell-curl", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "side-plank", sets: 3, reps: 30, notes: "30 seconds per side")
                ]
            ),
            TemplateWorkout(
                id: "recomp-db-lower-b",
                name: "Lower B",
                exercises: [
                    TemplateExercise(exerciseID: "lunges-dumbbell", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "step-ups", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "single-leg-glute-bridge", sets: 3, reps: 12, notes: "12 per side"),
                    TemplateExercise(exerciseID: "reverse-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "hanging-knee-raise", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )

    // =========================================================================
    // MARK: - Plan 11: Recomp — Full Gym
    // =========================================================================

    static let recompGym = TrainingPlanTemplate(
        id: "recomp-gym",
        name: "Recomp — Full Gym",                    // ✅ RENAMED from "Recomp"
        category: .bodyRecomp,
        tagline: "Lose fat. Build muscle. Keep both.",
        description: "Moderate volume and intensity for body recomposition. Barbell compounds preserve muscle while you cut. Pairs well with Zone 2 cardio days.",
        strengthDays: 4,
        splitType: "Upper/Lower",
        equipmentTier: .fullGym,
        experienceLevel: .intermediate,
        goalAlignment: ["lookBetter", "liveLonger"],
        workouts: [
            TemplateWorkout(
                id: "recomp-gym-upper-a",
                name: "Upper A",
                exercises: [
                    TemplateExercise(exerciseID: "bench-press-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "barbell-row", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-dumbbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "lat-pulldown", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "cable-curl", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "pallof-press", sets: 3, reps: 10, notes: "10 per side")
                ]
            ),
            TemplateWorkout(
                id: "recomp-gym-lower-a",
                name: "Lower A",
                exercises: [
                    TemplateExercise(exerciseID: "squat-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "romanian-deadlift-barbell", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "leg-press", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "leg-curl-lying", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "bulgarian-split-squat", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "hanging-knee-raise", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "farmers-carry", sets: 3, reps: 45, notes: nil)
                ]
            ),
            TemplateWorkout(
                id: "recomp-gym-upper-b",
                name: "Upper B",
                exercises: [
                    TemplateExercise(exerciseID: "incline-bench-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "seated-cable-row", sets: 3, reps: 10, notes: nil),
                    TemplateExercise(exerciseID: "overhead-press-barbell", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "cable-flyes", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "face-pulls", sets: 3, reps: 15, notes: nil),
                    TemplateExercise(exerciseID: "tricep-pushdown", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "dead-bug", sets: 3, reps: 10, notes: "10 per side")
                ]
            ),
            TemplateWorkout(
                id: "recomp-gym-lower-b",
                name: "Lower B",
                exercises: [
                    TemplateExercise(exerciseID: "trap-bar-deadlift", sets: 3, reps: 6, notes: nil),
                    TemplateExercise(exerciseID: "front-squat", sets: 3, reps: 8, notes: nil),
                    TemplateExercise(exerciseID: "leg-extension", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "leg-curl-seated", sets: 3, reps: 12, notes: nil),
                    TemplateExercise(exerciseID: "single-leg-rdl", sets: 3, reps: 8, notes: "8 per side"),
                    TemplateExercise(exerciseID: "cable-woodchop", sets: 3, reps: 10, notes: "10 per side"),
                    TemplateExercise(exerciseID: "dead-hang", sets: 3, reps: 30, notes: nil)
                ]
            )
        ]
    )
}