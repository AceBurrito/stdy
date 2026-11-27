import Foundation

// MARK: - Strength Exercise Libraries
// These libraries provide exercise replacements for event training plans
// based on user goals (injury prevention vs build strength) and equipment access

struct ExerciseTemplate {
    let name: String
    let sets: Int
    let reps: String
    let isBodyweight: Bool
    let equipment: String
    let notes: String
}

class StrengthExerciseLibraries {
    
    // MARK: - LOWER BODY LIBRARIES
    
    // Already in templates - this is the baseline
    static let lowerBodyInjuryPrevention: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Goblet Squat",
            sets: 3,
            reps: "12",
            isBodyweight: false,
            equipment: "dumbbell",
            notes: "Focus on depth and control, keep chest up"
        ),
        ExerciseTemplate(
            name: "Romanian Deadlift",
            sets: 3,
            reps: "10",
            isBodyweight: false,
            equipment: "dumbbells",
            notes: "Hamstring and glute focus, feel the stretch"
        ),
        ExerciseTemplate(
            name: "Walking Lunges",
            sets: 3,
            reps: "20",
            isBodyweight: true,
            equipment: "none",
            notes: "10 each leg, control the descent"
        ),
        ExerciseTemplate(
            name: "Single Leg Glute Bridge",
            sets: 3,
            reps: "12",
            isBodyweight: true,
            equipment: "none",
            notes: "12 per leg, hip strength and stability"
        ),
        ExerciseTemplate(
            name: "Plank",
            sets: 3,
            reps: "45 sec",
            isBodyweight: true,
            equipment: "none",
            notes: "Maintain neutral spine, breathe steadily"
        )
    ]
    
    static let lowerBodyBuildStrengthFullGym: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Back Squat",
            sets: 4,
            reps: "6-8",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Heavy load, focus on depth and bracing. Progressive overload each week."
        ),
        ExerciseTemplate(
            name: "Romanian Deadlift",
            sets: 4,
            reps: "8-10",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Hip hinge pattern, build posterior chain strength"
        ),
        ExerciseTemplate(
            name: "Bulgarian Split Squat",
            sets: 3,
            reps: "10",
            isBodyweight: false,
            equipment: "dumbbells",
            notes: "Each leg, unilateral strength and stability"
        ),
        ExerciseTemplate(
            name: "Leg Curl",
            sets: 3,
            reps: "12",
            isBodyweight: false,
            equipment: "machine",
            notes: "Hamstring isolation, injury prevention"
        ),
        ExerciseTemplate(
            name: "Weighted Plank",
            sets: 3,
            reps: "45 sec",
            isBodyweight: false,
            equipment: "plate",
            notes: "Plate on back, maintain form under load"
        )
    ]
    
    static let lowerBodyBuildStrengthHomeGym: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Back Squat",
            sets: 4,
            reps: "6-8",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Heavy barbell squats, progressive overload"
        ),
        ExerciseTemplate(
            name: "Romanian Deadlift",
            sets: 4,
            reps: "8-10",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Hip hinge, build posterior chain"
        ),
        ExerciseTemplate(
            name: "Goblet Squat",
            sets: 3,
            reps: "12",
            isBodyweight: false,
            equipment: "dumbbell",
            notes: "Heavy dumbbell, additional volume"
        ),
        ExerciseTemplate(
            name: "Single Leg Deadlift",
            sets: 3,
            reps: "10",
            isBodyweight: false,
            equipment: "dumbbell",
            notes: "Each leg, balance and unilateral strength"
        ),
        ExerciseTemplate(
            name: "Nordic Hamstring Curl",
            sets: 3,
            reps: "6-8",
            isBodyweight: true,
            equipment: "none",
            notes: "Eccentric hamstring strength, very challenging"
        )
    ]
    
    // MARK: - UPPER BODY LIBRARIES
    
    static let upperBodyInjuryPrevention: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Pushups",
            sets: 3,
            reps: "12",
            isBodyweight: true,
            equipment: "none",
            notes: "Modify to knees if needed, full range of motion"
        ),
        ExerciseTemplate(
            name: "Dumbbell Rows",
            sets: 3,
            reps: "10",
            isBodyweight: false,
            equipment: "dumbbells",
            notes: "Each arm, maintain neutral spine"
        ),
        ExerciseTemplate(
            name: "Overhead Press",
            sets: 3,
            reps: "10",
            isBodyweight: false,
            equipment: "dumbbells",
            notes: "Shoulder stability and strength"
        ),
        ExerciseTemplate(
            name: "Dead Bug",
            sets: 3,
            reps: "20",
            isBodyweight: true,
            equipment: "none",
            notes: "10 per side, core control and anti-extension"
        ),
        ExerciseTemplate(
            name: "Side Plank",
            sets: 3,
            reps: "30 sec",
            isBodyweight: true,
            equipment: "none",
            notes: "30 seconds each side, oblique strength"
        )
    ]
    
    static let upperBodyBuildStrengthFullGym: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Bench Press",
            sets: 4,
            reps: "6-8",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Heavy pressing, progressive overload"
        ),
        ExerciseTemplate(
            name: "Barbell Rows",
            sets: 4,
            reps: "8-10",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Pull strength, back development"
        ),
        ExerciseTemplate(
            name: "Overhead Press",
            sets: 3,
            reps: "8-10",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Shoulder strength and stability"
        ),
        ExerciseTemplate(
            name: "Pull-ups",
            sets: 3,
            reps: "8-10",
            isBodyweight: true,
            equipment: "pull-up bar",
            notes: "Vertical pull, use assistance if needed"
        ),
        ExerciseTemplate(
            name: "Pallof Press",
            sets: 3,
            reps: "12",
            isBodyweight: false,
            equipment: "cable",
            notes: "Each side, anti-rotation core strength"
        )
    ]
    
    static let upperBodyBuildStrengthHomeGym: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Bench Press",
            sets: 4,
            reps: "6-8",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Heavy barbell pressing"
        ),
        ExerciseTemplate(
            name: "Barbell Rows",
            sets: 4,
            reps: "8-10",
            isBodyweight: false,
            equipment: "barbell",
            notes: "Pull strength, horizontal row"
        ),
        ExerciseTemplate(
            name: "Overhead Press",
            sets: 3,
            reps: "8-10",
            isBodyweight: false,
            equipment: "barbell or dumbbells",
            notes: "Shoulder strength"
        ),
        ExerciseTemplate(
            name: "Pull-ups or Inverted Rows",
            sets: 3,
            reps: "10",
            isBodyweight: true,
            equipment: "bar or rings",
            notes: "Vertical or horizontal pull"
        ),
        ExerciseTemplate(
            name: "Weighted Plank",
            sets: 3,
            reps: "45 sec",
            isBodyweight: false,
            equipment: "plate or dumbbell",
            notes: "Core strength under load"
        )
    ]
    
    // MARK: - FULL BODY / LIGHT WEEK LIBRARIES
    
    static let fullBodyLight: [ExerciseTemplate] = [
        ExerciseTemplate(
            name: "Bodyweight Squat",
            sets: 2,
            reps: "15",
            isBodyweight: true,
            equipment: "none",
            notes: "Recovery week - light movement quality"
        ),
        ExerciseTemplate(
            name: "Pushups",
            sets: 2,
            reps: "10",
            isBodyweight: true,
            equipment: "none",
            notes: "Light work, maintain movement patterns"
        ),
        ExerciseTemplate(
            name: "Walking Lunges",
            sets: 2,
            reps: "20",
            isBodyweight: true,
            equipment: "none",
            notes: "Total steps, stay loose"
        ),
        ExerciseTemplate(
            name: "Plank",
            sets: 2,
            reps: "30 sec",
            isBodyweight: true,
            equipment: "none",
            notes: "Maintain core activation"
        )
    ]
    
    // MARK: - Helper Functions
    
    static func getExerciseLibrary(
        dayName: String,
        strengthGoal: String,
        equipmentAccess: String,
        weekPhase: String? = nil
    ) -> [ExerciseTemplate] {
        
        let isLowerBody = dayName.lowercased().contains("lower")
        let isUpperBody = dayName.lowercased().contains("upper")
        let isFullBody = dayName.lowercased().contains("full body")
        let isLight = dayName.lowercased().contains("light") || weekPhase == "recovery"
        
        // Light/recovery week override
        if isLight || isFullBody {
            return fullBodyLight
        }
        
        // Lower body exercises
        if isLowerBody {
            if strengthGoal == "build_strength" {
                if equipmentAccess == "full_gym" {
                    return lowerBodyBuildStrengthFullGym
                } else if equipmentAccess == "home_gym" {
                    return lowerBodyBuildStrengthHomeGym
                }
            }
            return lowerBodyInjuryPrevention // Default
        }
        
        // Upper body exercises
        if isUpperBody {
            if strengthGoal == "build_strength" {
                if equipmentAccess == "full_gym" {
                    return upperBodyBuildStrengthFullGym
                } else if equipmentAccess == "home_gym" {
                    return upperBodyBuildStrengthHomeGym
                }
            }
            return upperBodyInjuryPrevention // Default
        }
        
        // Fallback for other types
        return []
    }
}