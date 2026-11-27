import SwiftUI
import SwiftData

struct PlannedWorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var workoutDay: PlannedWorkoutDay
    
    @State private var selectedExercise: PlannedExercise? = nil
    @State private var showingAddExercise = false
    @State private var showingDayPicker = false
    
    // Swap scope prompt state
    @State private var pendingSwapExercise: PlannedExercise? = nil
    @State private var pendingSwapAlternative: ExerciseAlternatives.Alternative? = nil
    @State private var showingSwapScopePrompt = false
    
    /// Resolved routine for this day (if any)
    private var routine: WorkoutRoutine? {
        PlanCommitter.fetchRoutine(id: workoutDay.workoutRoutineID, modelContext: modelContext)
    }
    
    /// Whether this day is backed by a shared routine
    private var hasRoutine: Bool { routine != nil }
    
    /// Count of other days sharing this routine (for swap scope prompt messaging)
    private var otherDaysSharingRoutine: Int {
        guard let routineID = workoutDay.workoutRoutineID else { return 0 }
        guard let program = workoutDay.trainingProgram else { return 0 }
        return program.workoutDays.filter {
            $0.workoutRoutineID == routineID && $0.id != workoutDay.id
        }.count
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    exercisesSection
                    addExerciseButton
                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle(workoutDay.dayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedExercise) { exercise in
            PlanExerciseSwapSheet(
                exercise: exercise,
                onSelect: { alternative in
                    if hasRoutine && otherDaysSharingRoutine > 0 {
                        // Show scope prompt
                        pendingSwapExercise = exercise
                        pendingSwapAlternative = alternative
                        selectedExercise = nil
                        // Delay to let the sheet dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showingSwapScopePrompt = true
                        }
                    } else {
                        // Only one day uses this routine (or no routine) — swap directly
                        swapExerciseAllDays(exercise, with: alternative)
                        selectedExercise = nil
                    }
                }
            )
        }
        .sheet(isPresented: $showingAddExercise) {
            ExercisePickerView(
                existingExerciseNames: Set(workoutDay.exercises.map { $0.name }),
                onSelect: { definition in
                    addExercise(definition)
                }
            )
        }
        .sheet(isPresented: $showingDayPicker) {
            DayReassignmentSheet(
                currentDayOfWeek: workoutDay.dayOfWeek,
                workoutName: workoutDay.dayName,
                onSelect: { newDay in
                    reassignDay(to: newDay)
                }
            )
        }
        .confirmationDialog(
            "Swap Exercise",
            isPresented: $showingSwapScopePrompt,
            titleVisibility: .visible
        ) {
            Button("This Day Only") {
                if let exercise = pendingSwapExercise, let alt = pendingSwapAlternative {
                    swapExerciseThisDayOnly(exercise, with: alt)
                }
                clearPendingSwap()
            }
            Button("All Days Using This Routine") {
                if let exercise = pendingSwapExercise, let alt = pendingSwapAlternative {
                    swapExerciseAllDays(exercise, with: alt)
                }
                clearPendingSwap()
            }
            Button("Cancel", role: .cancel) {
                clearPendingSwap()
            }
        } message: {
            let routineName = routine?.name ?? workoutDay.dayName
            Text("\"This Day Only\" changes just \(dayFullName)'s workout.\n\"All Days\" updates the \"\(routineName)\" routine everywhere it's scheduled.")
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tappable day pill
            Button(action: { showingDayPicker = true }) {
                HStack(spacing: 6) {
                    Text(dayFullName.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                        .tracking(2)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasAccent.opacity(0.7))
                    
                    Text("Change")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.atlasAccent.opacity(0.7))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(workoutDay.dayName)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)
            
            HStack(spacing: 8) {
                Text("\(workoutDay.exercises.count) exercises")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                
                if hasRoutine {
                    Text("· Routine")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasPrimary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                EditablePlannedExerciseCard(
                    exercise: exercise,
                    isFirst: index == 0,
                    isLast: index == sortedExercises.count - 1,
                    onSwapExercise: {
                        selectedExercise = exercise
                    },
                    onDelete: {
                        deleteExercise(exercise)
                    },
                    onMoveUp: {
                        moveExercise(exercise, direction: .up)
                    },
                    onMoveDown: {
                        moveExercise(exercise, direction: .down)
                    },
                    onSetsRepsChanged: {
                        markEdited()
                        try? modelContext.save()
                    }
                )
            }
        }
    }
    
    // MARK: - Add Exercise Button
    private var addExerciseButton: some View {
        Button(action: { showingAddExercise = true }) {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.atlasPrimary)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.atlasPrimary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helpers
    
    private var dayFullName: String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard workoutDay.dayOfWeek >= 0 && workoutDay.dayOfWeek < days.count else { return "" }
        return days[workoutDay.dayOfWeek]
    }
    
    private var sortedExercises: [PlannedExercise] {
        workoutDay.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    // MARK: - Actions
    
    enum MoveDirection { case up, down }
    
    private func moveExercise(_ exercise: PlannedExercise, direction: MoveDirection) {
        var sorted = sortedExercises
        guard let currentIndex = sorted.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        let targetIndex: Int
        switch direction {
        case .up:
            guard currentIndex > 0 else { return }
            targetIndex = currentIndex - 1
        case .down:
            guard currentIndex < sorted.count - 1 else { return }
            targetIndex = currentIndex + 1
        }
        
        // Swap order indices
        let tempOrder = sorted[currentIndex].orderIndex
        sorted[currentIndex].orderIndex = sorted[targetIndex].orderIndex
        sorted[targetIndex].orderIndex = tempOrder
        
        markEdited()
        try? modelContext.save()
    }
    
    private func reassignDay(to newDayOfWeek: Int) {
        workoutDay.dayOfWeek = newDayOfWeek
        markEdited()
        try? modelContext.save()
    }
    
    private func markEdited() {
        // Walk up to the TrainingProgram and mark it as having user edits
        if let program = workoutDay.trainingProgram {
            if !program.hasUserEdits {
                // Save original plan snapshot before first edit
                saveOriginalPlanSnapshot(program)
            }
            program.hasUserEdits = true
        }
    }
    
    private func saveOriginalPlanSnapshot(_ program: TrainingProgram) {
        // Only snapshot if we haven't already
        guard program.originalPlanJSON == nil else { return }
        
        var snapshot: [[String: Any]] = []
        let days = program.workoutDays.sorted { $0.orderIndex < $1.orderIndex }
        
        for day in days {
            var dayDict: [String: Any] = [
                "dayOfWeek": day.dayOfWeek,
                "dayType": day.dayType,
                "dayName": day.dayName,
                "orderIndex": day.orderIndex
            ]
            
            var exerciseList: [[String: Any]] = []
            for ex in day.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                var exDict: [String: Any] = [
                    "name": ex.name,
                    "targetSets": ex.targetSets,
                    "targetReps": ex.targetReps ?? "",
                    "orderIndex": ex.orderIndex,
                    "isBodyweight": ex.isBodyweight
                ]
                if let notes = ex.notes { exDict["notes"] = notes }
                if let equip = ex.equipmentNeeded { exDict["equipmentNeeded"] = equip }
                exerciseList.append(exDict)
            }
            dayDict["exercises"] = exerciseList
            snapshot.append(dayDict)
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: snapshot),
           let jsonString = String(data: data, encoding: .utf8) {
            program.originalPlanJSON = jsonString
            print("📸 Saved original plan snapshot (\(jsonString.count) chars)")
        }
    }
    
    // MARK: - Swap: This Day Only (day-level override)
    
    private func swapExerciseThisDayOnly(_ old: PlannedExercise, with alternative: ExerciseAlternatives.Alternative) {
        // Create a day-level override so the routine stays clean
        let override = ExerciseOverride(
            originalExerciseID: ExerciseLibrary.find(name: old.name)?.id ?? old.name,
            replacementExerciseID: ExerciseLibrary.find(name: alternative.name)?.id ?? alternative.name,
            replacementName: alternative.name,
            sets: alternative.defaultSets,
            reps: "\(alternative.defaultReps)",
            isBodyweight: alternative.isBodyweight
        )
        workoutDay.addOverride(override)
        
        // Also update the PlannedExercise on this day (for backward compatibility / immediate display)
        old.name = alternative.name
        old.targetSets = alternative.defaultSets
        old.targetReps = "\(alternative.defaultReps)"
        old.parseTargetReps()
        old.isBodyweight = alternative.isBodyweight
        old.notes = "Swapped (this day only)"
        
        if let def = ExerciseLibrary.find(name: alternative.name) {
            old.equipmentNeeded = def.equipment.rawValue
        }
        
        markEdited()
        try? modelContext.save()
        print("🔄 Swapped exercise on \(dayFullName) only (day override)")
    }
    
    // MARK: - Swap: All Days (modify the routine)
    
    private func swapExerciseAllDays(_ old: PlannedExercise, with alternative: ExerciseAlternatives.Alternative) {
        // Update the routine exercise if we have a routine
        if let routine = routine {
            let oldExerciseID = ExerciseLibrary.find(name: old.name)?.id ?? old.name
            if let routineExercise = routine.exercises.first(where: { $0.exerciseID == oldExerciseID || $0.exerciseName == old.name }) {
                routineExercise.exerciseID = ExerciseLibrary.find(name: alternative.name)?.id ?? alternative.name
                routineExercise.exerciseName = alternative.name
                routineExercise.sets = alternative.defaultSets
                routineExercise.reps = "\(alternative.defaultReps)"
                routineExercise.isBodyweight = alternative.isBodyweight
                routineExercise.notes = nil
                routine.lastModifiedDate = Date()
            }
            
            // Also update PlannedExercise objects on ALL days that share this routine
            if let program = workoutDay.trainingProgram {
                let routineIDStr = routine.id.uuidString
                let sharingDays = program.workoutDays.filter { $0.workoutRoutineID == routineIDStr }
                for day in sharingDays {
                    if let pe = day.exercises.first(where: { $0.name == old.name }) {
                        pe.name = alternative.name
                        pe.targetSets = alternative.defaultSets
                        pe.targetReps = "\(alternative.defaultReps)"
                        pe.parseTargetReps()
                        pe.isBodyweight = alternative.isBodyweight
                        pe.notes = "Swapped from previous exercise"
                        if let def = ExerciseLibrary.find(name: alternative.name) {
                            pe.equipmentNeeded = def.equipment.rawValue
                        }
                    }
                }
            }
        } else {
            // No routine — just update this day's exercise (legacy behavior)
            old.name = alternative.name
            old.targetSets = alternative.defaultSets
            old.targetReps = "\(alternative.defaultReps)"
            old.parseTargetReps()
            old.isBodyweight = alternative.isBodyweight
            old.notes = "Swapped from previous exercise"
            
            if let def = ExerciseLibrary.find(name: alternative.name) {
                old.equipmentNeeded = def.equipment.rawValue
            }
        }
        
        markEdited()
        try? modelContext.save()
        print("🔄 Swapped exercise across all days using routine")
    }
    
    private func clearPendingSwap() {
        pendingSwapExercise = nil
        pendingSwapAlternative = nil
    }
    
    private func addExercise(_ definition: ExerciseDefinition) {
        let newExercise = PlannedExercise(
            name: definition.name,
            targetSets: definition.defaultSets,
            targetReps: "\(definition.defaultReps)",
            orderIndex: workoutDay.exercises.count,
            isBodyweight: definition.isBodyweight
        )
        newExercise.workoutDay = workoutDay
        workoutDay.exercises.append(newExercise)
        
        // Also add to routine if one exists
        if let routine = routine {
            let routineEx = RoutineExercise(
                exerciseID: definition.id,
                exerciseName: definition.name,
                sets: definition.defaultSets,
                reps: "\(definition.defaultReps)",
                sortOrder: routine.exercises.count,
                isBodyweight: definition.isBodyweight
            )
            routineEx.routine = routine
            modelContext.insert(routineEx)
            routine.lastModifiedDate = Date()
        }
        
        modelContext.insert(newExercise)
        markEdited()
        try? modelContext.save()
    }
    
    private func deleteExercise(_ exercise: PlannedExercise) {
        // Also remove from routine if one exists
        if let routine = routine {
            let exerciseID = ExerciseLibrary.find(name: exercise.name)?.id ?? exercise.name
            if let routineEx = routine.exercises.first(where: { $0.exerciseID == exerciseID || $0.exerciseName == exercise.name }) {
                modelContext.delete(routineEx)
                routine.lastModifiedDate = Date()
            }
        }
        
        modelContext.delete(exercise)
        markEdited()
        try? modelContext.save()
    }
}

// MARK: - Editable Planned Exercise Card

struct EditablePlannedExerciseCard: View {
    @Bindable var exercise: PlannedExercise
    let isFirst: Bool
    let isLast: Bool
    let onSwapExercise: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSetsRepsChanged: () -> Void
    
    @State private var showingDeleteConfirm = false
    @State private var isEditingSets = false
    @State private var isEditingReps = false
    @State private var editSetsText = ""
    @State private var editRepsText = ""
    
    private var hasAlternatives: Bool {
        ExerciseAlternatives.hasAlternatives(for: exercise.name)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name + actions
            HStack {
                Text(exercise.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                // Swap button (inline, visible)
                if hasAlternatives {
                    Button(action: onSwapExercise) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.atlasPrimary.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Overflow menu for move/delete
                Menu {
                    if !isFirst {
                        Button(action: onMoveUp) {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                    }
                    
                    if !isLast {
                        Button(action: onMoveDown) {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                        .frame(width: 32, height: 32)
                }
            }
            
            // Sets × Reps (tappable to edit)
            HStack(spacing: 16) {
                // Sets
                if isEditingSets {
                    HStack(spacing: 4) {
                        TextField("", text: $editSetsText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.atlasText)
                            .keyboardType(.numberPad)
                            .frame(width: 32)
                            .multilineTextAlignment(.center)
                            .onSubmit { commitSetsEdit() }
                        
                        Text("sets")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                        
                        Button(action: { commitSetsEdit() }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.atlasPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Button(action: {
                        editSetsText = "\(exercise.targetSets)"
                        isEditingSets = true
                    }) {
                        HStack(spacing: 4) {
                            Text("\(exercise.targetSets)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.atlasText)
                            Text("sets")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text("×")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                
                // Reps
                if isEditingReps {
                    HStack(spacing: 4) {
                        TextField("", text: $editRepsText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.atlasText)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .onSubmit { commitRepsEdit() }
                        
                        Text("reps")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                        
                        Button(action: { commitRepsEdit() }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.atlasPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Button(action: {
                        editRepsText = exercise.targetReps ?? ""
                        isEditingReps = true
                    }) {
                        HStack(spacing: 4) {
                            Text(exercise.targetReps ?? "10")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.atlasText)
                            Text("reps")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            
            // Notes
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .italic()
            }
            
            // Equipment badge
            if let equipment = exercise.equipmentNeeded, !equipment.isEmpty {
                Text(equipment)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .alert("Remove Exercise?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { onDelete() }
        } message: {
            Text("Remove \(exercise.name) from this workout?")
        }
    }
    
    private func commitSetsEdit() {
        if let newSets = Int(editSetsText), newSets > 0, newSets <= 20 {
            exercise.targetSets = newSets
            onSetsRepsChanged()
        }
        isEditingSets = false
    }
    
    private func commitRepsEdit() {
        let trimmed = editRepsText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            exercise.targetReps = trimmed
            exercise.parseTargetReps()
            onSetsRepsChanged()
        }
        isEditingReps = false
    }
}

// MARK: - Plan Exercise Swap Sheet (unchanged)

struct PlanExerciseSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let exercise: PlannedExercise
    let onSelect: (ExerciseAlternatives.Alternative) -> Void
    
    private var alternatives: [ExerciseAlternatives.Alternative] {
        ExerciseAlternatives.alternatives(for: exercise.name)
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Text("Swap Exercise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Button("Cancel") { }
                        .opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                if alternatives.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.atlasTextMuted)
                        Text("No alternatives found")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasTextMuted)
                        Text("This exercise isn't in the library. Ask your coach in chat for suggestions.")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Current exercise context
                            VStack(spacing: 4) {
                                Text("Replace \(exercise.name) with:")
                                    .font(.system(size: 15))
                                    .foregroundColor(.atlasTextMuted)
                                
                                if let def = ExerciseLibrary.find(name: exercise.name) {
                                    Text("\(def.muscleGroup.rawValue) • \(def.category.rawValue)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 16)
                            
                            // Alternatives list
                            VStack(spacing: 12) {
                                ForEach(alternatives) { alt in
                                    Button(action: {
                                        onSelect(alt)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(alt.name)
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .foregroundColor(.atlasText)
                                                
                                                Text("\(alt.defaultSets) sets × \(alt.defaultReps) reps")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.atlasAccent)
                                                
                                                Text(alt.reason)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.atlasTextMuted)
                                                    .multilineTextAlignment(.leading)
                                                
                                                Text(alt.equipment)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.atlasTextMuted.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.right.circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(.atlasPrimary)
                                        }
                                        .padding(16)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Day Reassignment Sheet

struct DayReassignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentDayOfWeek: Int
    let workoutName: String
    let onSelect: (Int) -> Void
    
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Text("Move Workout")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Spacer()
                    
                    Button("Cancel") { }
                        .opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollView {
                    VStack(spacing: 8) {
                        Text("Move \(workoutName) to:")
                            .font(.system(size: 15))
                            .foregroundColor(.atlasTextMuted)
                            .padding(.top, 20)
                            .padding(.bottom, 8)
                        
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let isCurrent = dayIndex == currentDayOfWeek
                            
                            Button(action: {
                                if !isCurrent {
                                    onSelect(dayIndex)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Text(dayNames[dayIndex])
                                        .font(.system(size: 17, weight: isCurrent ? .semibold : .regular))
                                        .foregroundColor(isCurrent ? .atlasPrimary : .atlasText)
                                    
                                    Spacer()
                                    
                                    if isCurrent {
                                        Text("Current")
                                            .font(.system(size: 13))
                                            .foregroundColor(.atlasPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.atlasPrimary.opacity(0.15))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isCurrent)
                            
                            if dayIndex < 6 {
                                Divider()
                                    .background(Color.white.opacity(0.05))
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        TrainingProgramView()
    }
}