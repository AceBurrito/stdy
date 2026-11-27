import Foundation

// MARK: - Exercise Library
// Single source of truth for all exercises in atlas.
// Users select from this list. Custom exercises stored in CustomExercise SwiftData model.
//
// To add exercises: append to the relevant section below.
// Everything else (picker, history, progression) reads from here.

// MARK: - Enums

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case quads = "Quads"
    case hamstringsGlutes = "Hamstrings & Glutes"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case core = "Core"
    
    var id: String { rawValue }
    
    var shortName: String {
        switch self {
        case .hamstringsGlutes: return "Hams/Glutes"
        default: return rawValue
        }
    }
    
    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rowing"
        case .quads: return "figure.walk"
        case .hamstringsGlutes: return "figure.run"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.curling"
        case .triceps: return "figure.strengthtraining.functional"
        case .core: return "figure.core.training"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .chest: return 0
        case .back: return 1
        case .quads: return 2
        case .hamstringsGlutes: return 3
        case .shoulders: return 4
        case .biceps: return 5
        case .triceps: return 6
        case .core: return 7
        }
    }
}

enum ExerciseCategory: String {
    case compound = "Compound"
    case isolation = "Isolation"
}

enum Equipment: String, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case kettlebell = "Kettlebell"
    case band = "Band"
    case trapBar = "Trap Bar"
    case other = "Other"
}

// MARK: - Exercise Definition

struct ExerciseDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
    let category: ExerciseCategory
    let equipment: Equipment
    let isBodyweight: Bool
    let isUnilateral: Bool
    let isTimed: Bool
    let defaultSets: Int
    let defaultReps: Int
    let weightIncrement: Double
    let formCues: [String]
    
    var isCompound: Bool { category == .compound }
    
    var suggestedRestTime: Int {
        switch category {
        case .compound: return 120
        case .isolation: return 75
        }
    }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ExerciseDefinition, rhs: ExerciseDefinition) -> Bool { lhs.id == rhs.id }
}

// MARK: - Library

struct ExerciseLibrary {
    
    static let all: [ExerciseDefinition] = {
        var e: [ExerciseDefinition] = []
        e.append(contentsOf: chest)
        e.append(contentsOf: back)
        e.append(contentsOf: quads)
        e.append(contentsOf: hamstringsGlutes)
        e.append(contentsOf: shoulders)
        e.append(contentsOf: biceps)
        e.append(contentsOf: triceps)
        e.append(contentsOf: core)
        return e
    }()
    
    static let grouped: [(group: MuscleGroup, exercises: [ExerciseDefinition])] = {
        MuscleGroup.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { group in (group: group, exercises: all.filter { $0.muscleGroup == group }) }
    }()
    
    static func find(id: String) -> ExerciseDefinition? { all.first { $0.id == id } }
    static func find(name: String) -> ExerciseDefinition? {
        let lower = name.lowercased()
        return all.first { $0.name.lowercased() == lower }
    }
    static func search(_ query: String) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return all }
        let lower = query.lowercased()
        return all.filter { $0.name.lowercased().contains(lower) }
    }
    static func exercises(for group: MuscleGroup) -> [ExerciseDefinition] { all.filter { $0.muscleGroup == group } }
    static func exercises(with equipment: Equipment) -> [ExerciseDefinition] { all.filter { $0.equipment == equipment } }
    static var compounds: [ExerciseDefinition] { all.filter { $0.isCompound } }
    static var bodyweight: [ExerciseDefinition] { all.filter { $0.isBodyweight } }
    static func exists(_ name: String) -> Bool { find(name: name) != nil }
    static var count: Int { all.count }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // CHEST (14 exercises)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let chest: [ExerciseDefinition] = [
        .init(id: "bench-press-barbell", name: "Bench Press (Barbell)", muscleGroup: .chest, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Shoulder blades retracted and pinched together", "Bar path: slight diagonal from mid-chest to lockout", "Feet planted, drive through heels", "Full range — bar touches chest, full lockout at top"]),
        
        .init(id: "bench-press-dumbbell", name: "Bench Press (Dumbbell)", muscleGroup: .chest, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Shoulder blades retracted on bench", "Dumbbells at chest level, elbows at ~45°", "Press up and slightly together", "Control the descent — don't drop"]),
        
        .init(id: "incline-bench-barbell", name: "Incline Bench Press (Barbell)", muscleGroup: .chest, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Bench at 30-45° — steeper hits more shoulder", "Bar to upper chest, not neck", "Same retracted shoulder blade position as flat bench"]),
        
        .init(id: "incline-press-dumbbell", name: "Incline Press (Dumbbell)", muscleGroup: .chest, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Bench at 30-45°", "Press up and slightly together", "Full stretch at the bottom"]),
        
        .init(id: "decline-bench-barbell", name: "Decline Bench Press (Barbell)", muscleGroup: .chest, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Bench at slight decline (~15-30°)", "Bar to lower chest", "Same retracted shoulder blades as flat bench", "Most people are strongest in this position"]),
        
        .init(id: "decline-press-dumbbell", name: "Decline Press (Dumbbell)", muscleGroup: .chest, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Slight decline bench", "Targets lower chest fibers", "Full range of motion"]),
        
        .init(id: "smith-machine-bench", name: "Smith Machine Bench Press", muscleGroup: .chest, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Position bench so bar path hits mid-chest", "Shoulder blades retracted", "Good for going to failure without a spotter", "Fixed bar path — focus on squeezing chest"]),
        
        .init(id: "landmine-press", name: "Landmine Press", muscleGroup: .chest, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["One end of barbell in corner or landmine attachment", "Press up and forward in an arc", "Great for shoulder-friendly pressing", "Core stays braced throughout"]),
        
        .init(id: "cable-flyes", name: "Cable Flyes", muscleGroup: .chest, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Slight bend in elbows throughout", "Squeeze chest at peak contraction", "Control the eccentric — don't let cables pull you back"]),
        
        .init(id: "dumbbell-flyes", name: "Dumbbell Flyes", muscleGroup: .chest, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Slight elbow bend — imagine hugging a tree", "Deep stretch at bottom, squeeze at top", "Lighter weight, focus on the stretch"]),
        
        .init(id: "push-ups", name: "Push-Ups", muscleGroup: .chest, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 0, formCues: ["Body straight from head to heels", "Hands slightly wider than shoulders", "Chest to floor, full lockout at top"]),
        
        .init(id: "chest-dips", name: "Chest Dips", muscleGroup: .chest, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["Lean forward slightly to target chest over triceps", "Lower until upper arms parallel to floor", "Don't go too deep if shoulders are tight"]),
        
        .init(id: "machine-chest-press", name: "Machine Chest Press", muscleGroup: .chest, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Adjust seat so handles are at mid-chest", "Full range of motion", "Don't lock elbows aggressively at top"]),
        
        .init(id: "pec-deck", name: "Pec Deck", muscleGroup: .chest, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Slight elbow bend, squeeze at center", "Control the return — don't let it snap back"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // BACK (16 exercises)
    // Includes lats, rhomboids, traps, rear delts, erectors.
    // Rear delts here because they're trained with pulling.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let back: [ExerciseDefinition] = [
        .init(id: "pull-ups", name: "Pull-Ups", muscleGroup: .back, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 0, formCues: ["Full dead hang at bottom, chin over bar at top", "Initiate with lats — think elbows to hips", "Control the descent — no dropping"]),
        
        .init(id: "chin-ups", name: "Chin-Ups", muscleGroup: .back, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 0, formCues: ["Supinated grip (palms facing you)", "Full range — dead hang to chin over bar", "More bicep involvement than pull-ups"]),
        
        .init(id: "barbell-row", name: "Barbell Row", muscleGroup: .back, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Torso ~45° angle, core braced", "Pull to lower sternum, not neck", "Squeeze shoulder blades together at top", "Control the descent — don't just drop it"]),
        
        .init(id: "dumbbell-row", name: "Dumbbell Row", muscleGroup: .back, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["One hand and knee on bench for support", "Pull dumbbell to hip, not shoulder", "Full stretch at bottom, squeeze at top"]),
        
        .init(id: "lat-pulldown", name: "Lat Pulldown", muscleGroup: .back, category: .compound, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Pull to upper chest, not behind neck", "Lean back slightly, chest up", "Squeeze lats at bottom of movement"]),
        
        .init(id: "single-arm-lat-pulldown", name: "Single-Arm Lat Pulldown", muscleGroup: .back, category: .compound, equipment: .cable, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Use D-handle, pull to same-side chest", "Slight lean away from working arm", "Great for fixing left-right imbalances", "Full stretch at top, squeeze at bottom"]),
        
        .init(id: "seated-cable-row", name: "Seated Cable Row", muscleGroup: .back, category: .compound, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Sit tall, slight lean back at contraction", "Pull to lower sternum", "Shoulder blades together at peak"]),
        
        .init(id: "t-bar-row", name: "T-Bar Row", muscleGroup: .back, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Neutral spine, core tight", "Pull into lower chest/upper abs", "Full stretch at bottom"]),
        
        .init(id: "meadows-row", name: "Meadows Row", muscleGroup: .back, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Stand perpendicular to landmine end of barbell", "Overhand grip, pull to hip", "Allows extra range of motion vs standard row", "Named after John Meadows — great for lat width"]),
        
        .init(id: "chest-supported-row", name: "Chest-Supported Row", muscleGroup: .back, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Lie face down on incline bench (~30°)", "Row both dumbbells to hip level", "Eliminates lower back fatigue and momentum", "Pure back work — can't cheat"]),
        
        .init(id: "seal-row", name: "Seal Row", muscleGroup: .back, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Lie flat on elevated bench, arms hang straight down", "Row dumbbells up, squeeze shoulder blades", "Zero momentum — gravity does all the work", "If no elevated bench, use chest-supported row instead"]),
        
        .init(id: "face-pulls", name: "Face Pulls", muscleGroup: .back, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Pull rope to face level, elbows high", "Externally rotate at end — hands finish beside ears", "Squeeze rear delts, don't use momentum"]),
        
        .init(id: "reverse-flyes", name: "Reverse Flyes", muscleGroup: .back, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Bent over or chest-supported on incline bench", "Lead with elbows, squeeze rear delts", "Light weight, focus on contraction"]),
        
        .init(id: "reverse-pec-deck", name: "Reverse Pec Deck", muscleGroup: .back, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 5.0, formCues: ["Chest against pad, arms extended", "Pull handles back, squeeze shoulder blades", "Control the return"]),
        
        .init(id: "straight-arm-pulldown", name: "Straight-Arm Pulldown", muscleGroup: .back, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Slight forward lean, arms straight with soft elbows", "Pull the bar down to thighs in an arc", "Feel the lats stretch at top and squeeze at bottom"]),
        
        .init(id: "inverted-row", name: "Inverted Row", muscleGroup: .back, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 0, formCues: ["Body straight — like an upside-down push-up", "Pull chest to bar, squeeze shoulder blades", "Lower feet to make it harder, raise to make easier"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // QUADS (13 exercises)
    // Knee-dominant lower body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let quads: [ExerciseDefinition] = [
        .init(id: "squat-barbell", name: "Back Squat (Barbell)", muscleGroup: .quads, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Full depth — hip crease below knee", "Chest up, core braced throughout", "Knees track over toes, don't cave in", "Drive up through mid-foot"]),
        
        .init(id: "front-squat", name: "Front Squat", muscleGroup: .quads, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Elbows high, bar rests on front delts", "More upright torso than back squat", "Full depth, knees forward is OK"]),
        
        .init(id: "goblet-squat", name: "Goblet Squat", muscleGroup: .quads, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Hold dumbbell at chest, elbows inside knees", "Full depth, upright torso", "Great for learning squat mechanics"]),
        
        .init(id: "smith-machine-squat", name: "Smith Machine Squat", muscleGroup: .quads, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Feet slightly forward of bar for quad focus", "Full depth, controlled descent", "Good for training to failure safely", "Fixed path allows focus on muscle, not balance"]),
        
        .init(id: "leg-press", name: "Leg Press", muscleGroup: .quads, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 10.0, formCues: ["Feet shoulder-width on platform", "Lower until ~90° knee bend", "Don't lock knees at top", "Keep lower back pressed into pad"]),
        
        .init(id: "hack-squat", name: "Hack Squat", muscleGroup: .quads, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 10.0, formCues: ["Back flat against pad, shoulders under pads", "Full depth — don't half rep", "Drive through the whole foot"]),
        
        .init(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", muscleGroup: .quads, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Rear foot elevated on bench", "Front shin stays roughly vertical", "Lower until front thigh is parallel", "Drive up through front heel"]),
        
        .init(id: "lunges-dumbbell", name: "Walking Lunges (Dumbbell)", muscleGroup: .quads, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Big step forward, both knees to ~90°", "Front knee tracks over toes", "Upright torso, core engaged"]),
        
        .init(id: "step-ups", name: "Step-Ups", muscleGroup: .quads, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Box height: thigh parallel at top", "Drive through the lead foot only", "Don't push off the back foot"]),
        
        .init(id: "sissy-squat", name: "Sissy Squat", muscleGroup: .quads, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 0, formCues: ["Hold onto something for balance", "Lean back as knees travel forward", "Intense quad isolation — don't need much weight", "Control the descent, feel the stretch"]),
        
        .init(id: "leg-extension", name: "Leg Extension", muscleGroup: .quads, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Pad on lower shins, not ankles", "Full extension at top, squeeze quad", "Control the descent — don't drop"]),
        
        .init(id: "bodyweight-squat", name: "Bodyweight Squat", muscleGroup: .quads, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 0, formCues: ["Arms forward for balance", "Full depth, chest up", "Good for warmups and beginners"]),
        
        .init(id: "wall-sit", name: "Wall Sit", muscleGroup: .quads, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 45, weightIncrement: 0, formCues: ["Back flat against wall, thighs parallel to floor", "Knees at 90°, shins vertical", "Breathe normally — don't hold breath", "Great isometric endurance builder"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // HAMSTRINGS & GLUTES (19 exercises)
    // Hip-dominant, posterior chain
    // Critical for longevity: injury prevention, hip health,
    // lower back protection, fall prevention
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let hamstringsGlutes: [ExerciseDefinition] = [
        .init(id: "deadlift-barbell", name: "Deadlift (Barbell)", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 5, weightIncrement: 10.0, formCues: ["Neutral spine — no rounding under load", "Bar stays in contact with shins and thighs", "Hips and shoulders rise together", "Lockout with glutes, don't hyperextend"]),
        
        .init(id: "trap-bar-deadlift", name: "Trap Bar Deadlift", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .trapBar, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 6, weightIncrement: 10.0, formCues: ["Stand centered in the bar, grip both handles", "More upright than conventional — easier on low back", "Drive through feet, stand tall at top", "Great for longevity — high reward, lower injury risk"]),
        
        .init(id: "romanian-deadlift-barbell", name: "Romanian Deadlift (Barbell)", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Slight knee bend — this is a hip hinge, not a squat", "Bar slides down thighs, feel the hamstring stretch", "Stop when you feel max hamstring stretch", "Drive hips forward to return"]),
        
        .init(id: "romanian-deadlift-dumbbell", name: "Romanian Deadlift (Dumbbell)", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Dumbbells slide down front of thighs", "Same hip hinge pattern as barbell version", "Good option when barbells are taken"]),
        
        .init(id: "single-leg-rdl", name: "Single-Leg Romanian Deadlift", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Hinge at hip, free leg extends behind you", "Keep hips square — don't rotate open", "Dumbbell in opposite hand to working leg", "Critical for balance and asymmetry correction"]),
        
        .init(id: "hip-thrust-barbell", name: "Hip Thrust (Barbell)", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 10.0, formCues: ["Upper back on bench, feet flat on floor", "Drive hips to full extension", "Squeeze glutes hard at top — hold 1 second", "Chin tucked, don't hyperextend neck"]),
        
        .init(id: "hip-thrust-dumbbell", name: "Hip Thrust (Dumbbell)", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Dumbbell placed on hip crease", "Same movement as barbell hip thrust", "Good alternative when barbell setup isn't available"]),
        
        .init(id: "glute-bridge", name: "Glute Bridge", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 0, formCues: ["Feet flat, knees at ~90°", "Drive hips up, squeeze glutes at top", "Lower back stays neutral"]),
        
        .init(id: "single-leg-glute-bridge", name: "Single-Leg Glute Bridge", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 0, formCues: ["One foot flat, other leg extended", "Drive through planted heel", "Keep hips level — don't rotate"]),
        
        .init(id: "nordic-curl", name: "Nordic Curl", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 6, weightIncrement: 0, formCues: ["Kneel on pad, anchor feet under something solid", "Lower yourself as slowly as possible — fight gravity", "Use hands to catch yourself at the bottom if needed", "One of the best hamstring exercises for injury prevention"]),
        
        .init(id: "glute-ham-raise", name: "Glute-Ham Raise", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .machine, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 0, formCues: ["Pad at mid-thigh on GHD machine", "Lower with control, curl back up with hamstrings", "Keep hips extended throughout", "Easier progression: use hands on pad for push assist"]),
        
        .init(id: "leg-curl-lying", name: "Leg Curl (Lying)", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Hips stay pressed into pad", "Full contraction — heel toward glute", "Slow eccentric, feel the hamstring stretch"]),
        
        .init(id: "leg-curl-seated", name: "Leg Curl (Seated)", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Adjust pad to sit just above ankle", "Full range — extend and curl completely", "Don't use momentum"]),
        
        .init(id: "cable-pull-through", name: "Cable Pull-Through", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Face away from cable, rope between legs", "Hip hinge — push hips back, soft knees", "Drive hips forward to stand, squeeze glutes"]),
        
        .init(id: "banded-walk", name: "Banded Lateral Walk", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .band, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 0, formCues: ["Band around ankles or just above knees", "Quarter-squat position, stay low throughout", "Step laterally with control — don't let feet come together", "Great glute med activation and warm-up"]),
        
        .init(id: "kettlebell-swing", name: "Kettlebell Swing", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .kettlebell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 5.0, formCues: ["Hip hinge, not a squat — hips drive the movement", "Arms are just along for the ride", "Snap hips forward, squeeze glutes at top", "Bell to chest height, no higher"]),
        
        .init(id: "good-mornings", name: "Good Mornings", muscleGroup: .hamstringsGlutes, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Bar on upper back like a squat", "Hinge forward with slight knee bend", "Feel hamstring stretch, return by driving hips", "Start light — this loads the low back"]),
        
        .init(id: "calf-raises-standing", name: "Calf Raises (Standing)", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 5.0, formCues: ["Full stretch at bottom — heels below platform", "Full contraction at top — up on toes", "Pause at top for 1 second"]),
        
        .init(id: "calf-raises-seated", name: "Calf Raises (Seated)", muscleGroup: .hamstringsGlutes, category: .isolation, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 5.0, formCues: ["Targets soleus (deep calf muscle)", "Full stretch and contraction", "Slow and controlled"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SHOULDERS (12 exercises)
    // Pressing + lateral/front raises.
    // Rear delts in Back (trained with pulling).
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let shoulders: [ExerciseDefinition] = [
        .init(id: "overhead-press-barbell", name: "Overhead Press (Barbell)", muscleGroup: .shoulders, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Core tight, ribs down — don't hyperextend", "Bar starts at front delts, press slightly back", "Bar finishes directly over mid-foot", "Full lockout at top"]),
        
        .init(id: "overhead-press-dumbbell", name: "Overhead Press (Dumbbell)", muscleGroup: .shoulders, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Start at shoulder height, palms forward", "Press up and slightly together", "Don't arch the back"]),
        
        .init(id: "arnold-press", name: "Arnold Press", muscleGroup: .shoulders, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Start palms facing you at chin height", "Rotate palms forward as you press up", "Smooth rotation through the full range"]),
        
        .init(id: "lateral-raises-dumbbell", name: "Lateral Raises (Dumbbell)", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Slight forward lean, slight elbow bend", "Lead with elbows, not hands", "Raise to shoulder height, no higher", "Control the descent — don't swing"]),
        
        .init(id: "cable-lateral-raises", name: "Cable Lateral Raises", muscleGroup: .shoulders, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Cable from opposite side, behind body", "Slight lean away from cable", "Constant tension throughout range"]),
        
        .init(id: "front-raises", name: "Front Raises", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Raise to shoulder height", "Palms down or neutral grip", "Don't swing — control the weight"]),
        
        .init(id: "lu-raise", name: "Lu Raise", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Front raise to shoulder height, then lateral raise out", "Reverse the motion back down the same path", "Named after Lu Xiaojun — excellent shoulder builder", "Light weight — the movement pattern is the challenge"]),
        
        .init(id: "prone-y-raise", name: "Prone Y-Raise", muscleGroup: .shoulders, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Lie face down on incline bench", "Raise arms in Y-shape, thumbs up", "Targets lower traps and rear delts", "Very light weight — prehab exercise"]),
        
        .init(id: "machine-shoulder-press", name: "Machine Shoulder Press", muscleGroup: .shoulders, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Adjust seat so handles start at shoulder height", "Press to full lockout", "Good for going to failure safely"]),
        
        .init(id: "band-pull-apart", name: "Band Pull-Apart", muscleGroup: .shoulders, category: .isolation, equipment: .band, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 20, weightIncrement: 0, formCues: ["Arms straight in front, shoulder height", "Pull band apart by squeezing shoulder blades", "Pause at full stretch, control return", "Great for shoulder health and posture"]),
        
        .init(id: "cable-external-rotation", name: "Cable External Rotation", muscleGroup: .shoulders, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Elbow at 90°, pinned to side", "Rotate forearm outward against cable", "Slow and controlled — this is prehab, not ego lifting", "Critical for rotator cuff health"]),
        
        .init(id: "pike-push-up", name: "Pike Push-Up", muscleGroup: .shoulders, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["Hips high in inverted V position", "Lower head toward the floor between hands", "Push back up to full lockout", "Progression toward handstand push-ups"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // BICEPS (10 exercises)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let biceps: [ExerciseDefinition] = [
        .init(id: "barbell-curl", name: "Barbell Curl", muscleGroup: .biceps, category: .isolation, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Elbows pinned to sides", "Full extension at bottom, full contraction at top", "Don't swing the weight — control it"]),
        
        .init(id: "ez-bar-curl", name: "EZ Bar Curl", muscleGroup: .biceps, category: .isolation, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Angled grip is easier on wrists than straight bar", "Same strict form as barbell curl", "Full range of motion, elbows pinned"]),
        
        .init(id: "dumbbell-curl", name: "Dumbbell Curl", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Supinate as you curl (rotate pinky up)", "Full stretch at bottom", "No momentum — strict form"]),
        
        .init(id: "hammer-curl", name: "Hammer Curl", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Neutral grip (palms facing each other)", "Targets brachialis and forearms", "Don't swing — keep elbows still"]),
        
        .init(id: "cable-hammer-curl", name: "Cable Hammer Curl", muscleGroup: .biceps, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Use rope attachment, neutral grip", "Constant tension from the cable", "Elbows pinned, full range"]),
        
        .init(id: "incline-dumbbell-curl", name: "Incline Dumbbell Curl", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Bench at ~45°, arms hanging straight down", "Excellent stretch on the long head", "Curl up, control down — don't swing"]),
        
        .init(id: "spider-curl", name: "Spider Curl", muscleGroup: .biceps, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Lie face down on incline bench, arms hanging", "Curl up — gravity resists throughout entire range", "Peak contraction at the top", "No momentum possible — pure bicep"]),
        
        .init(id: "drag-curl", name: "Drag Curl", muscleGroup: .biceps, category: .isolation, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Pull elbows back as you curl — bar drags up torso", "Bar stays in contact with body throughout", "Targets the long head of biceps", "Lighter weight than standard curl"]),
        
        .init(id: "preacher-curl", name: "Preacher Curl", muscleGroup: .biceps, category: .isolation, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Upper arms flat on pad", "Full stretch at bottom — don't half rep", "Squeeze at top"]),
        
        .init(id: "cable-curl", name: "Cable Curl", muscleGroup: .biceps, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Constant tension from the cable", "Elbows pinned, full range of motion"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TRICEPS (11 exercises)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let triceps: [ExerciseDefinition] = [
        .init(id: "tricep-pushdown", name: "Tricep Pushdown", muscleGroup: .triceps, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Elbows pinned to sides, don't flare", "Full lockout at bottom", "Control the return — don't let cable snap back"]),
        
        .init(id: "overhead-tricep-extension-cable", name: "Overhead Tricep Extension (Cable)", muscleGroup: .triceps, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Elbows pointing forward, close to head", "Full stretch at bottom behind head", "Extend fully at top"]),
        
        .init(id: "overhead-tricep-extension-dumbbell", name: "Overhead Tricep Extension (Dumbbell)", muscleGroup: .triceps, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 5.0, formCues: ["Both hands on one dumbbell, lower behind head", "Elbows stay close to ears", "Full stretch, full extension"]),
        
        .init(id: "skull-crushers", name: "Skull Crushers", muscleGroup: .triceps, category: .isolation, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Lower bar to forehead or just behind", "Elbows stationary, pointing at ceiling", "Extend fully at top"]),
        
        .init(id: "jm-press", name: "JM Press", muscleGroup: .triceps, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Hybrid of close-grip bench and skull crusher", "Lower bar to chin/upper chest with elbows tucked", "Press up and back to lockout", "Excellent tricep mass builder"]),
        
        .init(id: "french-press", name: "French Press (Cable)", muscleGroup: .triceps, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Seated or standing, rope behind head", "Similar to overhead extension with constant cable tension", "Full stretch at bottom, full lockout at top", "Keep elbows close to head"]),
        
        .init(id: "close-grip-bench-press", name: "Close-Grip Bench Press", muscleGroup: .triceps, category: .compound, equipment: .barbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 5.0, formCues: ["Hands shoulder-width or slightly narrower", "Elbows stay close to body", "Same bar path as regular bench, just narrower grip"]),
        
        .init(id: "tricep-dips", name: "Dips (Tricep)", muscleGroup: .triceps, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["Upright torso (unlike chest dips which lean forward)", "Elbows track backward, not out", "Lower until ~90° elbow bend"]),
        
        .init(id: "diamond-push-ups", name: "Diamond Push-Ups", muscleGroup: .triceps, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 0, formCues: ["Hands together forming a diamond under chest", "Elbows stay close to body", "Full range — chest to hands, full lockout", "Harder than regular push-ups — great tricep builder"]),
        
        .init(id: "dip-machine", name: "Dip Machine (Assisted)", muscleGroup: .triceps, category: .compound, equipment: .machine, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 5.0, formCues: ["Adjust counterweight — more weight = easier", "Upright torso for tricep focus", "Full range of motion", "Good progression toward bodyweight dips"]),
        
        .init(id: "tricep-kickback", name: "Tricep Kickback", muscleGroup: .triceps, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Upper arm parallel to floor, pinned to body", "Extend fully, squeeze at lockout", "Light weight — this is about contraction"]),
    ]
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // CORE (22 exercises)
    // Anti-extension, anti-rotation, anti-lateral flexion,
    // loaded carries, and grip work.
    //
    // Longevity rationale: spine health, functional strength,
    // fall prevention, grip strength (top longevity biomarker)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static let core: [ExerciseDefinition] = [
        // Anti-extension
        .init(id: "plank", name: "Plank", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 60, weightIncrement: 0, formCues: ["Straight line from head to heels", "Core tight — don't let hips sag or pike", "Breathe normally, don't hold breath"]),
        
        .init(id: "ab-rollout", name: "Ab Rollout", muscleGroup: .core, category: .isolation, equipment: .other, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["Roll out as far as you can control", "Core tight — don't let lower back sag", "Pull back with abs, not hip flexors"]),
        
        .init(id: "hanging-leg-raise", name: "Hanging Leg Raise", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["Minimize swinging — control the movement", "Raise legs to at least parallel", "Slow descent — don't just drop"]),
        
        .init(id: "hanging-knee-raise", name: "Hanging Knee Raise", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 0, formCues: ["Easier progression than straight-leg version", "Bring knees to chest, control the return", "Minimize swinging"]),
        
        .init(id: "toes-to-bar", name: "Toes-to-Bar", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 8, weightIncrement: 0, formCues: ["Hang from bar, raise toes to touch the bar", "Requires significant hip flexor and core strength", "Control the descent — don't swing", "Progression from hanging leg raises"]),
        
        // Anti-rotation
        .init(id: "pallof-press", name: "Pallof Press", muscleGroup: .core, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 2.5, formCues: ["Stand perpendicular to cable", "Press hands straight out — resist rotation", "Core fights the pull, don't twist"]),
        
        .init(id: "cable-woodchop", name: "Cable Woodchop", muscleGroup: .core, category: .isolation, equipment: .cable, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 12, weightIncrement: 2.5, formCues: ["Rotate through the torso, not the arms", "Feet planted, core doing the work", "Control both directions"]),
        
        // Anti-lateral flexion / stability
        .init(id: "dead-bug", name: "Dead Bug", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["Lower back pressed into floor throughout", "Opposite arm and leg extend simultaneously", "Slow and controlled — this is about stability"]),
        
        .init(id: "bird-dog", name: "Bird Dog", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 10, weightIncrement: 0, formCues: ["On hands and knees, extend opposite arm and leg", "Keep hips level — don't rotate", "Hold at full extension for 2 seconds"]),
        
        .init(id: "side-plank", name: "Side Plank", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: true, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 0, formCues: ["Stack feet or stagger for balance", "Straight line from head to feet", "Don't let hips drop"]),
        
        .init(id: "copenhagen-plank", name: "Copenhagen Plank", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: true, isTimed: true, defaultSets: 3, defaultReps: 20, weightIncrement: 0, formCues: ["Side plank with top leg on bench, bottom leg hanging", "Targets adductors and obliques simultaneously", "Adductor injury prevention — used in soccer prehab", "Start with bent knee on bench, progress to straight leg"]),
        
        .init(id: "hollow-body-hold", name: "Hollow Body Hold", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 0, formCues: ["Lie flat, press lower back into floor", "Arms overhead, legs extended, lift both off floor", "Maintain banana shape — no arch in lower back", "Foundation of gymnastics core strength"]),
        
        .init(id: "l-sit", name: "L-Sit", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 15, weightIncrement: 0, formCues: ["Support yourself on parallettes or dip bars", "Legs extended straight forward, parallel to floor", "Requires strong hip flexors and core", "Start with tucked knees, progress to straight legs"]),
        
        // Loaded carries — Attia's top longevity exercises
        .init(id: "farmers-carry", name: "Farmer's Carry", muscleGroup: .core, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 40, weightIncrement: 5.0, formCues: ["Tall posture, shoulders back and down", "Tight grip, core braced", "Short quick steps, don't lean", "Top longevity exercise — grip, core, posture"]),
        
        .init(id: "suitcase-carry", name: "Suitcase Carry", muscleGroup: .core, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 5.0, formCues: ["One weight in one hand, walk tall", "Don't lean to the weighted side", "Core fights lateral flexion — that's the exercise", "Switch sides each set"]),
        
        .init(id: "overhead-carry", name: "Overhead Carry", muscleGroup: .core, category: .compound, equipment: .dumbbell, isBodyweight: false, isUnilateral: true, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 5.0, formCues: ["One dumbbell or kettlebell pressed overhead", "Lock elbow, rib cage down, core tight", "Walk with control — this is harder than it looks", "Builds shoulder stability and core simultaneously"]),
        
        // Turkish Get-Up — the ultimate longevity exercise
        .init(id: "turkish-getup", name: "Turkish Get-Up", muscleGroup: .core, category: .compound, equipment: .kettlebell, isBodyweight: false, isUnilateral: true, isTimed: false, defaultSets: 3, defaultReps: 3, weightIncrement: 5.0, formCues: ["Eyes on the weight throughout the entire movement", "Each position is a pause point — don't rush", "Combines mobility, stability, and strength in one move", "Start light and master the pattern before adding weight"]),
        
        // Grip — one of the strongest longevity biomarkers
        .init(id: "dead-hang", name: "Dead Hang", muscleGroup: .core, category: .isolation, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 0, formCues: ["Full dead hang, shoulders engaged (not shrugged to ears)", "Overhand grip, shoulder width", "Grip strength is one of the strongest longevity predictors", "Build toward 60+ seconds"]),
        
        .init(id: "plate-pinch", name: "Plate Pinch Hold", muscleGroup: .core, category: .isolation, equipment: .other, isBodyweight: false, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 0, formCues: ["Pinch two plates together smooth-side out", "Hold at side, don't lean", "Builds pinch grip — different from bar grip"]),
        
        .init(id: "wrist-curl", name: "Wrist Curl", muscleGroup: .core, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Forearms on thighs, wrists over knees", "Full range — stretch at bottom, curl at top", "Builds forearm and grip endurance"]),
        
        .init(id: "reverse-wrist-curl", name: "Reverse Wrist Curl", muscleGroup: .core, category: .isolation, equipment: .dumbbell, isBodyweight: false, isUnilateral: false, isTimed: false, defaultSets: 3, defaultReps: 15, weightIncrement: 2.5, formCues: ["Overhand grip, forearms on thighs", "Extend wrists upward, control down", "Targets wrist extensors — balances forearm development"]),
        
        .init(id: "bear-crawl", name: "Bear Crawl", muscleGroup: .core, category: .compound, equipment: .bodyweight, isBodyweight: true, isUnilateral: false, isTimed: true, defaultSets: 3, defaultReps: 30, weightIncrement: 0, formCues: ["Hands and feet on ground, knees hovering 1 inch off floor", "Opposite hand and foot move together", "Keep hips low and level — don't pike up", "Full-body stability and coordination challenge"]),
    ]
}