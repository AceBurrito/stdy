import Foundation

// MARK: - Shared JSON Parsing Structures
// These structs are used by both EventPlanGenerator and TrainingPlanParser

// MARK: - Exercise JSON

struct ExerciseJSON: Codable {
    let name: String
    let targetSets: Int
    let targetReps: String?
    let isBodyweight: Bool
    let equipmentNeeded: String?
    let notes: String?
    
    // Custom decoding to handle both Int and String from API
    enum CodingKeys: String, CodingKey {
        case name, targetSets, targetReps, isBodyweight, equipmentNeeded, notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        targetSets = try container.decode(Int.self, forKey: .targetSets)
        isBodyweight = try container.decode(Bool.self, forKey: .isBodyweight)
        equipmentNeeded = try container.decodeIfPresent(String.self, forKey: .equipmentNeeded)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Handle targetReps as either Int or String
        if let repsInt = try? container.decode(Int.self, forKey: .targetReps) {
            targetReps = String(repsInt)
        } else if let repsString = try? container.decode(String.self, forKey: .targetReps) {
            targetReps = repsString
        } else {
            targetReps = nil
        }
    }
}

// MARK: - Week Details (for template-based event plans)

struct WeekDetailsJSON: Codable {
    let weekNumber: Int
    let phase: String?          // Half Marathon uses this
    let focus: String?          // Half Marathon uses this
    let focusArea: String?      // HYROX uses this instead of "focus"
    let totalVolume: String?
    let totalWeeklyMileage: String?  // Half Marathon uses this (string)
    let weeklyMileage: Double?       // HYROX uses this (number)
    let days: [WeekDayJSON]
}

struct WeekDayJSON: Codable {
    let dayType: String
    let dayName: String
    let dayOfWeek: Int
    let userActivityName: String?  // ⭐ NEW: User's original activity name
    let cardioType: String?
    let cardioDuration: Int?
    let cardioNotes: String?
    let targetHRMin: Int?
    let targetHRMax: Int?
    let targetDistance: Double?
    let distanceUnit: String?
    let targetPace: String?
    let workoutStructure: String?
    let isBrickWorkout: Bool?
    let exercises: [ExerciseJSON]
}