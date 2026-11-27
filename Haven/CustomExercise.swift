import Foundation
import SwiftData

// MARK: - Custom Exercise (User-Created)
// Stored in SwiftData and synced via CloudKit.
// Merged into exercise picker results alongside ExerciseLibrary entries.
// Participates in PR tracking, volume tracking, and workout history.
//
// All properties have defaults for CloudKit compatibility.

@Model
class CustomExercise {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroupRaw: String = "Core"         // MuscleGroup.rawValue
    var categoryRaw: String = "Compound"        // ExerciseCategory.rawValue
    var equipmentRaw: String = "Other"          // Equipment.rawValue
    var isBodyweight: Bool = false
    var isUnilateral: Bool = false
    var isTimed: Bool = false
    var defaultSets: Int = 3
    var defaultReps: Int = 10
    var createdDate: Date = Date()
    
    // CloudKit compatible: all properties have defaults
    
    init(
        name: String,
        muscleGroup: MuscleGroup,
        category: ExerciseCategory,
        equipment: Equipment,
        isBodyweight: Bool = false,
        isUnilateral: Bool = false,
        isTimed: Bool = false,
        defaultSets: Int = 3,
        defaultReps: Int = 10
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.categoryRaw = category.rawValue
        self.equipmentRaw = equipment.rawValue
        self.isBodyweight = isBodyweight
        self.isUnilateral = isUnilateral
        self.isTimed = isTimed
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.createdDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var muscleGroup: MuscleGroup {
        MuscleGroup(rawValue: muscleGroupRaw) ?? .core
    }
    
    var category: ExerciseCategory {
        ExerciseCategory(rawValue: categoryRaw) ?? .compound
    }
    
    var equipment: Equipment {
        Equipment(rawValue: equipmentRaw) ?? .other
    }
    
    /// Convert to ExerciseDefinition for use in pickers, workout logging, and PR tracking.
    /// The ID is prefixed with "custom-" so the system can distinguish custom from library exercises.
    func toDefinition() -> ExerciseDefinition {
        ExerciseDefinition(
            id: "custom-\(id.uuidString)",
            name: name,
            muscleGroup: muscleGroup,
            category: category,
            equipment: equipment,
            isBodyweight: isBodyweight,
            isUnilateral: isUnilateral,
            isTimed: isTimed,
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            weightIncrement: isBodyweight ? 0 : 5.0,
            formCues: ["Custom exercise — focus on control and full range of motion"]
        )
    }
}

// MARK: - ExerciseLibrary Extension (Custom Exercise Support)

extension ExerciseLibrary {
    
    /// Fetch all custom exercises from SwiftData and convert to ExerciseDefinitions.
    static func fetchCustomExercises(modelContext: ModelContext) -> [ExerciseDefinition] {
        let descriptor = FetchDescriptor<CustomExercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        let customs = (try? modelContext.fetch(descriptor)) ?? []
        return customs.map { $0.toDefinition() }
    }
    
    /// All exercises (library + custom) for use in pickers.
    static func allIncludingCustom(modelContext: ModelContext) -> [ExerciseDefinition] {
        var combined = all
        combined.append(contentsOf: fetchCustomExercises(modelContext: modelContext))
        return combined
    }
    
    /// Grouped exercises including custom, for picker display.
    static func groupedIncludingCustom(modelContext: ModelContext) -> [(group: MuscleGroup, exercises: [ExerciseDefinition])] {
        let allExercises = allIncludingCustom(modelContext: modelContext)
        return MuscleGroup.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { group in (group: group, exercises: allExercises.filter { $0.muscleGroup == group }) }
    }
    
    /// Search including custom exercises.
    static func searchIncludingCustom(_ query: String, modelContext: ModelContext) -> [ExerciseDefinition] {
        let allExercises = allIncludingCustom(modelContext: modelContext)
        guard !query.isEmpty else { return allExercises }
        let lower = query.lowercased()
        return allExercises.filter { $0.name.lowercased().contains(lower) }
    }
    
    /// Find by ID, including custom exercise IDs (prefixed with "custom-").
    static func findIncludingCustom(id: String, modelContext: ModelContext) -> ExerciseDefinition? {
        // Check library first
        if let found = find(id: id) { return found }
        // Check custom exercises
        return fetchCustomExercises(modelContext: modelContext).first { $0.id == id }
    }
    
    /// Find by name, including custom exercises.
    static func findIncludingCustom(name: String, modelContext: ModelContext) -> ExerciseDefinition? {
        if let found = find(name: name) { return found }
        let lower = name.lowercased()
        return fetchCustomExercises(modelContext: modelContext).first { $0.name.lowercased() == lower }
    }
    
    /// Check if an exercise ID belongs to a custom exercise.
    static func isCustomExercise(id: String) -> Bool {
        id.hasPrefix("custom-")
    }
}