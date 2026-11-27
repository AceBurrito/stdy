import SwiftUI
import SwiftData

// MARK: - Custom Plan Builder View (Routine-Based)
// Revised flow:
// Step 1: Build Your Routines — create named workout routines with exercises
// Step 2: Build Your Week — assign routines, cardio, or rest to each day
// Step 3: Review and commit

struct CustomPlanBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutRoutine.createdDate) private var existingRoutines: [WorkoutRoutine]

    var onComplete: (() -> Void)?
    var onBack: (() -> Void)?

    @State private var currentStep = 1
    @State private var hasLoadedExisting = false
    @State private var routines: [RoutineConfig] = []
    // Maps local routineConfig index → existing WorkoutRoutine UUID string.
    // Routines imported from the library reuse their existing SwiftData object on commit.
    @State private var existingRoutineIDs: [Int: String] = [:]
    @State private var weekAssignments: [WeekDayAssignment] = (0..<7).map {
        WeekDayAssignment(dayOfWeek: $0, assignmentType: .rest, routineIndex: nil)
    }
    @State private var currentEditingRoutineIndex: Int? = nil
    @State private var showExercisePicker = false
    @State private var showRoutineBuilder = false

    private var userProfile: UserProfile? { profiles.first }

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    // At least 1 routine with exercises
    private var hasValidRoutine: Bool {
        routines.contains { !$0.exercises.isEmpty }
    }

    // At least 1 day assigned to a routine
    private var hasStrengthDay: Bool {
        weekAssignments.contains { $0.assignmentType == .routine }
    }

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch currentStep {
                        case 1: step1BuildRoutines
                        case 2: step2AssignDays
                        case 3: step3Review
                        default: EmptyView()
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }

                bottomButtons
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            PlanExercisePickerView(
                onSelect: { exercise in
                    addExerciseToRoutine(exercise)
                },
                equipmentFilter: userProfile?.availableEquipment
            )
        }
        .onAppear {
            guard !hasLoadedExisting else { return }
            hasLoadedExisting = true
            loadExistingRoutines()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= currentStep ? Color.atlasPrimary : Color.white.opacity(0.1))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Step 1: Build Routines

    private var step1BuildRoutines: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("STEP 1 OF 3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)

                Text("Build your routines")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.atlasText)

                Text("Create the workouts you'll rotate through your week.")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }

            // Existing routines
            ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                RoutineBuilderCard(
                    routineName: Binding(
                        get: { routines[index].name },
                        set: { routines[index].name = $0 }
                    ),
                    exercises: routine.exercises,
                    onAddExercise: {
                        currentEditingRoutineIndex = index
                        showExercisePicker = true
                    },
                    onRemoveExercise: { exIndex in
                        routines[index].exercises.remove(at: exIndex)
                    },
                    onUpdateSets: { exIndex, sets in
                        routines[index].exercises[exIndex].sets = sets
                    },
                    onUpdateReps: { exIndex, reps in
                        routines[index].exercises[exIndex].reps = reps
                    },
                    onMoveExercise: { from, to in
                        routines[index].exercises.move(fromOffsets: IndexSet(integer: from), toOffset: to)
                    },
                    onDelete: {
                        // Also clear any day assignments referencing this routine
                        for i in weekAssignments.indices {
                            if weekAssignments[i].routineIndex == index {
                                weekAssignments[i].assignmentType = .rest
                                weekAssignments[i].routineIndex = nil
                            } else if let ri = weekAssignments[i].routineIndex, ri > index {
                                weekAssignments[i].routineIndex = ri - 1
                            }
                        }
                        // Shift existingRoutineIDs to match new indices
                        var updated: [Int: String] = [:]
                        for (key, val) in existingRoutineIDs {
                            if key < index { updated[key] = val }
                            else if key > index { updated[key - 1] = val }
                            // key == index is the deleted one, skip it
                        }
                        existingRoutineIDs = updated
                        routines.remove(at: index)
                    }
                )
            }

            // Add Routine button
            Button(action: {
                let name = routines.isEmpty ? "Workout A" : "Workout \(Character(UnicodeScalar(65 + routines.count)!))"
                routines.append(RoutineConfig(name: name))
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text(routines.isEmpty ? "Create Your First Routine" : "Add Another Routine")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.atlasPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.atlasPrimary.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            if routines.isEmpty {
                VStack(spacing: 6) {
                    Text("What's a routine?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                    Text("A named workout you can assign to multiple days. For example, \"Full Body A\" on Monday and Friday, \"Full Body B\" on Wednesday.")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Step 2: Assign Days

    private var step2AssignDays: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("STEP 2 OF 3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)

                Text("Build your week")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.atlasText)

                Text("Assign your routines to days. Same routine can go on multiple days.")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }

            VStack(spacing: 10) {
                ForEach(0..<7) { dayIndex in
                    DayAssignmentRow(
                        dayName: fullDayNames[dayIndex],
                        shortName: dayNames[dayIndex],
                        assignment: $weekAssignments[dayIndex],
                        routineOptions: routines.map { $0.name },
                        onCreateNewRoutine: {
                            let name = "Workout \(Character(UnicodeScalar(65 + routines.count)!))"
                            routines.append(RoutineConfig(name: name))
                            weekAssignments[dayIndex].assignmentType = .routine
                            weekAssignments[dayIndex].routineIndex = routines.count - 1
                        }
                    )
                }
            }

            if !hasStrengthDay {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasAmber)
                    Text("Assign at least 1 routine to continue")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAmber)
                }
            }
        }
    }

    // MARK: - Step 3: Review

    private var step3Review: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("STEP 3 OF 3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)

                Text("Review your plan")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.atlasText)
            }

            ForEach(0..<7) { dayIndex in
                let assignment = weekAssignments[dayIndex]
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(fullDayNames[dayIndex])
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.atlasText)

                        Spacer()

                        switch assignment.assignmentType {
                        case .routine:
                            Text("Strength")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.atlasPrimary)
                        case .cardio:
                            Text("Cardio")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.atlasAmber)
                        case .rest:
                            Text("Rest")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.atlasTextMuted.opacity(0.5))
                        }
                    }

                    switch assignment.assignmentType {
                    case .routine:
                        if let ri = assignment.routineIndex, ri < routines.count {
                            let routine = routines[ri]
                            Text(routine.name)
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                            ForEach(Array(routine.exercises.prefix(4).enumerated()), id: \.offset) { _, ex in
                                HStack {
                                    Text("• \(ex.name)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.atlasTextMuted)
                                    Spacer()
                                    Text("\(ex.sets)×\(ex.reps)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                                }
                            }
                            if routine.exercises.count > 4 {
                                Text("+ \(routine.exercises.count - 4) more")
                                    .font(.system(size: 12))
                                    .foregroundColor(.atlasTextMuted.opacity(0.5))
                            }
                        }
                    case .cardio:
                        Text("\(assignment.cardioZone.rawValue) · \(assignment.cardioDurationMinutes) min")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    case .rest:
                        Text("Recovery")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: goBack) {
                Text(currentStep == 1 ? "Cancel" : "Back")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: goNext) {
                Text(currentStep == 3 ? "Start Plan" : "Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canAdvance ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.atlasBackground)
    }

    // MARK: - Navigation Logic

    private var canAdvance: Bool {
        switch currentStep {
        case 1: return hasValidRoutine
        case 2: return hasStrengthDay
        case 3: return true
        default: return false
        }
    }

    private func goNext() {
        switch currentStep {
        case 1:
            currentStep = 2
        case 2:
            currentStep = 3
        case 3:
            commitCustomPlan()
        default:
            break
        }
    }

    private func goBack() {
        if currentStep > 1 {
            currentStep -= 1
        } else {
            onBack?() ?? dismiss()
        }
    }

    // MARK: - Add Exercise to Routine

    private func addExerciseToRoutine(_ definition: ExerciseDefinition) {
        guard let index = currentEditingRoutineIndex else { return }
        let exercise = ExerciseConfig(
            name: definition.name,
            exerciseID: definition.id,
            sets: definition.defaultSets,
            reps: definition.isCompound ? "8" : "12",
            notes: nil,
            isBodyweight: definition.isBodyweight
        )
        routines[index].exercises.append(exercise)
    }

    // MARK: - Load Existing Routines from Library

    private func loadExistingRoutines() {
        guard !existingRoutines.isEmpty else { return }

        for routine in existingRoutines {
            let exercises = routine.sortedExercises.map { ex in
                ExerciseConfig(
                    name: ex.exerciseName,
                    exerciseID: ex.exerciseID,
                    sets: ex.sets,
                    reps: ex.reps,
                    notes: ex.notes,
                    isBodyweight: ex.isBodyweight
                )
            }

            let config = RoutineConfig(name: routine.name, exercises: exercises)
            let newIndex = routines.count
            routines.append(config)
            existingRoutineIDs[newIndex] = routine.id.uuidString
        }
    }

    // MARK: - Commit

    private func commitCustomPlan() {
        guard let profile = userProfile else { return }

        // First, create WorkoutRoutine SwiftData objects for each routine
        // (or reuse existing ones imported from the library)
        var routineIDs: [Int: String] = [:]  // routineIndex -> UUID string

        for (index, routineConfig) in routines.enumerated() {
            if let existingID = existingRoutineIDs[index] {
                // Reuse existing routine — update its exercises to reflect any edits
                if let existing = PlanCommitter.fetchRoutine(id: existingID, modelContext: modelContext) {
                    existing.name = routineConfig.name
                    existing.lastModifiedDate = Date()
                    // Clear old exercises and rebuild
                    for old in existing.exercises {
                        modelContext.delete(old)
                    }
                    for (exIndex, ex) in routineConfig.exercises.enumerated() {
                        let routineEx = RoutineExercise(
                            exerciseID: ex.exerciseID,
                            exerciseName: ex.name,
                            sets: ex.sets,
                            reps: ex.reps,
                            sortOrder: exIndex,
                            isBodyweight: ex.isBodyweight
                        )
                        routineEx.notes = ex.notes
                        routineEx.routine = existing
                        modelContext.insert(routineEx)
                    }
                    routineIDs[index] = existingID
                    continue
                }
            }

            // New routine — create it
            let routine = WorkoutRoutine(name: routineConfig.name)
            routine.userProfile = profile
            modelContext.insert(routine)

            for (exIndex, ex) in routineConfig.exercises.enumerated() {
                let routineEx = RoutineExercise(
                    exerciseID: ex.exerciseID,
                    exerciseName: ex.name,
                    sets: ex.sets,
                    reps: ex.reps,
                    sortOrder: exIndex,
                    isBodyweight: ex.isBodyweight
                )
                routineEx.notes = ex.notes
                routineEx.routine = routine
                modelContext.insert(routineEx)
            }

            routineIDs[index] = routine.id.uuidString
        }

        // Build custom day configs
        var customDays: [PlanCommitter.CustomDayConfig] = []

        for assignment in weekAssignments {
            switch assignment.assignmentType {
            case .routine:
                if let ri = assignment.routineIndex, ri < routines.count {
                    let routine = routines[ri]
                    let config = PlanCommitter.CustomDayConfig(
                        dayOfWeek: assignment.dayOfWeek,
                        name: routine.name,
                        type: .strength,
                        exercises: routine.exercises.map { ex in
                            PlanCommitter.CustomExercise(
                                name: ex.name,
                                sets: ex.sets,
                                reps: ex.reps,
                                notes: ex.notes
                            )
                        },
                        cardioType: nil,
                        cardioDurationMinutes: nil,
                        routineID: routineIDs[ri]
                    )
                    customDays.append(config)
                }
            case .cardio:
                let config = PlanCommitter.CustomDayConfig(
                    dayOfWeek: assignment.dayOfWeek,
                    name: assignment.cardioZone.rawValue,
                    type: .cardio,
                    exercises: [],
                    cardioType: assignment.cardioZone.rawValue,
                    cardioDurationMinutes: assignment.cardioDurationMinutes
                )
                customDays.append(config)
            case .rest:
                break
            }
        }

        PlanCommitter.commitCustomPlan(
            customDays: customDays,
            userProfile: profile,
            modelContext: modelContext
        )

        onComplete?()
    }
}

// MARK: - Internal Models

struct RoutineConfig: Identifiable {
    let id = UUID()
    var name: String
    var exercises: [ExerciseConfig] = []
}

struct ExerciseConfig: Identifiable {
    let id = UUID()
    var name: String
    var exerciseID: String
    var sets: Int
    var reps: String
    var notes: String?
    var isBodyweight: Bool = false
}

struct WeekDayAssignment {
    let dayOfWeek: Int
    var assignmentType: AssignmentType
    var routineIndex: Int?
    var cardioDurationMinutes: Int = 30
    var cardioZone: CardioZone = .zone2

    enum AssignmentType {
        case routine
        case cardio
        case rest
    }

    enum CardioZone: String, CaseIterable {
        case zone2 = "Zone 2"
        case intervals = "Intervals"
        case sprint = "Sprint"
        case mixed = "Mixed"

        var description: String {
            switch self {
            case .zone2: return "Easy / Aerobic (Zone 2)"
            case .intervals: return "Intervals (Zone 3-4)"
            case .sprint: return "Sprints (Zone 4-5)"
            case .mixed: return "Mixed Zones"
            }
        }
    }
}

// MARK: - Day Assignment Row

struct DayAssignmentRow: View {
    let dayName: String
    let shortName: String
    @Binding var assignment: WeekDayAssignment
    let routineOptions: [String]
    let onCreateNewRoutine: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(shortName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .frame(width: 36, alignment: .leading)

                // Type buttons
                HStack(spacing: 6) {
                    assignmentButton(type: .rest, label: "Rest", icon: "moon.fill", color: .atlasTextMuted)
                    assignmentButton(type: .cardio, label: "Cardio", icon: "heart.fill", color: .atlasAmber)
                }

                // Routine picker (shown as a menu)
                Menu {
                    ForEach(Array(routineOptions.enumerated()), id: \.offset) { index, name in
                        Button(action: {
                            assignment.assignmentType = .routine
                            assignment.routineIndex = index
                        }) {
                            if assignment.assignmentType == .routine && assignment.routineIndex == index {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }

                    Divider()

                    Button(action: onCreateNewRoutine) {
                        Label("New Routine...", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 11))
                        Text(routineLabel)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(assignment.assignmentType == .routine ? .atlasBackground : .atlasTextMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(assignment.assignmentType == .routine ? Color.atlasPrimary : Color.white.opacity(0.06))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding(.vertical, 6)

            // Cardio config (shown when cardio selected)
            if assignment.assignmentType == .cardio {
                CardioAssignmentConfig(assignment: $assignment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: assignment.assignmentType)
    }

    private var routineLabel: String {
        if assignment.assignmentType == .routine,
           let ri = assignment.routineIndex,
           ri < routineOptions.count {
            return routineOptions[ri]
        }
        return "Routine"
    }

    private func assignmentButton(type: WeekDayAssignment.AssignmentType, label: String, icon: String, color: Color) -> some View {
        Button(action: {
            assignment.assignmentType = type
            if type != .routine { assignment.routineIndex = nil }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(assignment.assignmentType == type ? .atlasBackground : .atlasTextMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(assignment.assignmentType == type ? color : Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Cardio Assignment Config

struct CardioAssignmentConfig: View {
    @Binding var assignment: WeekDayAssignment
    private let durationOptions = [15, 20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Duration
            HStack(spacing: 6) {
                ForEach(durationOptions, id: \.self) { mins in
                    Button(action: { assignment.cardioDurationMinutes = mins }) {
                        Text("\(mins)m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(assignment.cardioDurationMinutes == mins ? .atlasBackground : .atlasText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(assignment.cardioDurationMinutes == mins ? Color.atlasAmber : Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Zone
            HStack(spacing: 6) {
                ForEach(WeekDayAssignment.CardioZone.allCases, id: \.self) { zone in
                    Button(action: { assignment.cardioZone = zone }) {
                        Text(zone.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(assignment.cardioZone == zone ? .atlasBackground : .atlasText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(assignment.cardioZone == zone ? Color.atlasAmber : Color.white.opacity(0.04))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(12)
        .background(Color.atlasAmber.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.atlasAmber.opacity(0.2), lineWidth: 1)
        )
        .padding(.top, 4)
    }
}

// MARK: - Routine Builder Card (inline in step 1)

struct RoutineBuilderCard: View {
    @Binding var routineName: String
    let exercises: [ExerciseConfig]
    let onAddExercise: () -> Void
    let onRemoveExercise: (Int) -> Void
    let onUpdateSets: (Int, Int) -> Void
    let onUpdateReps: (Int, String) -> Void
    let onMoveExercise: (Int, Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with delete
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasPrimary)

                Spacer()

                Text("\(exercises.count) exercises")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAccent.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Name
            TextField("Routine name (e.g., Full Body A)", text: $routineName)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)

            // Exercises
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted.opacity(0.3))

                    Text(exercise.name)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 4) {
                        Button(action: { if exercise.sets > 1 { onUpdateSets(index, exercise.sets - 1) } }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.atlasTextMuted)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("\(exercise.sets)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.atlasText)
                            .frame(width: 20)

                        Button(action: { if exercise.sets < 10 { onUpdateSets(index, exercise.sets + 1) } }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.atlasTextMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("×")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)

                    Text(exercise.reps)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.atlasText)
                        .frame(width: 28)

                    Button(action: { onRemoveExercise(index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasAccent.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 4)
            }

            // Add exercise
            Button(action: onAddExercise) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add Exercise")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.atlasPrimary)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}