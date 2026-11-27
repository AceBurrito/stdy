import SwiftUI
import SwiftData

// MARK: - Routine Detail View
// View/edit a single WorkoutRoutine.
// - Tap exercise to edit sets/reps
// - Move up/down to reorder
// - Swipe to delete
// - Add exercises from picker
// - Rename, duplicate, delete from overflow menu

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: WorkoutRoutine

    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true && $0.isEventPlan == false })
    private var activePrograms: [TrainingProgram]

    @State private var showingAddExercise = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var showingDeleteConfirm = false
    @State private var showingDuplicateConfirm = false
    @State private var editingExercise: RoutineExercise? = nil

    private var activeProgram: TrainingProgram? { activePrograms.first }

    private var assignedDayNames: [String] {
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard let program = activeProgram else { return [] }
        return program.workoutDays
            .filter { $0.workoutRoutineID == routine.id.uuidString }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
            .compactMap { day in
                guard day.dayOfWeek >= 0, day.dayOfWeek < dayNames.count else { return nil }
                return dayNames[day.dayOfWeek]
            }
    }

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    exercisesSection
                    addExerciseButton

                    if !assignedDayNames.isEmpty {
                        scheduledSection
                    }

                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundColor(.atlasPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        renameText = routine.name
                        showingRename = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(action: { showingDuplicateConfirm = true }) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                        Label("Delete Routine", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            PlanExercisePickerView(
                onSelect: { definition in
                    addExercise(definition)
                },
                equipmentFilter: nil
            )
        }
        .sheet(item: $editingExercise) { exercise in
            RoutineExerciseEditSheet(exercise: exercise, onSave: {
                routine.lastModifiedDate = Date()
                try? modelContext.save()
            })
        }
        .alert("Rename Routine", isPresented: $showingRename) {
            TextField("Routine name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    routine.name = renameText.trimmingCharacters(in: .whitespaces)
                    routine.lastModifiedDate = Date()
                    try? modelContext.save()
                }
            }
        }
        .alert("Delete Routine?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteRoutine() }
        } message: {
            if assignedDayNames.isEmpty {
                Text("This will permanently delete \"\(routine.name)\" and its exercises.")
            } else {
                Text("This routine is scheduled on \(assignedDayNames.joined(separator: ", ")). Deleting it will remove those day assignments.")
            }
        }
        .alert("Duplicate Routine", isPresented: $showingDuplicateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Duplicate") { duplicateRoutine() }
        } message: {
            Text("Create a copy of \"\(routine.name)\"?")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKOUT ROUTINE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)

            Text("\(routine.exercises.count) exercises")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(spacing: 10) {
            let sorted = routine.sortedExercises
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, exercise in
                RoutineExerciseRow(
                    exercise: exercise,
                    isFirst: index == 0,
                    isLast: index == sorted.count - 1,
                    onTap: { editingExercise = exercise },
                    onMoveUp: { moveExercise(exercise, direction: .up) },
                    onMoveDown: { moveExercise(exercise, direction: .down) },
                    onDelete: { deleteExercise(exercise) }
                )
            }
        }
    }

    // MARK: - Add Exercise

    private var addExerciseButton: some View {
        Button(action: { showingAddExercise = true }) {
            HStack(spacing: 8) {
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

    // MARK: - Scheduled Section

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULED ON")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.2)

            Text(assignedDayNames.joined(separator: ", "))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.atlasPrimary.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Actions

    enum MoveDirection { case up, down }

    private func moveExercise(_ exercise: RoutineExercise, direction: MoveDirection) {
        var sorted = routine.sortedExercises
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

        let temp = sorted[currentIndex].sortOrder
        sorted[currentIndex].sortOrder = sorted[targetIndex].sortOrder
        sorted[targetIndex].sortOrder = temp

        routine.lastModifiedDate = Date()
        try? modelContext.save()
    }

    private func addExercise(_ definition: ExerciseDefinition) {
        let exercise = RoutineExercise(
            exerciseID: definition.id,
            exerciseName: definition.name,
            sets: definition.defaultSets,
            reps: "\(definition.defaultReps)",
            sortOrder: routine.exercises.count,
            isBodyweight: definition.isBodyweight
        )
        exercise.routine = routine
        routine.exercises.append(exercise)
        modelContext.insert(exercise)
        routine.lastModifiedDate = Date()
        try? modelContext.save()
    }

    private func deleteExercise(_ exercise: RoutineExercise) {
        modelContext.delete(exercise)
        // Reindex remaining
        for (i, ex) in routine.sortedExercises.enumerated() {
            ex.sortOrder = i
        }
        routine.lastModifiedDate = Date()
        try? modelContext.save()
    }

    private func deleteRoutine() {
        // Clear references from days
        if let program = activeProgram {
            for day in program.workoutDays {
                if day.workoutRoutineID == routine.id.uuidString {
                    day.workoutRoutineID = nil
                }
            }
        }
        modelContext.delete(routine)
        try? modelContext.save()
        dismiss()
    }

    private func duplicateRoutine() {
        let copy = WorkoutRoutine(name: "\(routine.name) (Copy)", isFromTemplate: false)
        copy.userProfile = routine.userProfile
        modelContext.insert(copy)

        for exercise in routine.sortedExercises {
            let copyEx = RoutineExercise(
                exerciseID: exercise.exerciseID,
                exerciseName: exercise.exerciseName,
                sets: exercise.sets,
                reps: exercise.reps,
                sortOrder: exercise.sortOrder,
                isBodyweight: exercise.isBodyweight
            )
            copyEx.notes = exercise.notes
            copyEx.routine = copy
            modelContext.insert(copyEx)
        }

        try? modelContext.save()
    }
}

// MARK: - Routine Exercise Row

struct RoutineExerciseRow: View {
    let exercise: RoutineExercise
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Drag handle area
                VStack(spacing: 4) {
                    if !isFirst {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.atlasTextMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted.opacity(0.4))
                    if !isLast {
                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.atlasTextMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(exercise.sets) sets × \(exercise.reps) reps")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasAccent)

                        if let notes = exercise.notes, !notes.isEmpty {
                            Text("· \(notes)")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted.opacity(0.4))
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if !isFirst {
                Button(action: onMoveUp) { Label("Move Up", systemImage: "arrow.up") }
            }
            if !isLast {
                Button(action: onMoveDown) { Label("Move Down", systemImage: "arrow.down") }
            }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Remove", systemImage: "trash") }
        }
    }
}

// MARK: - Routine Exercise Edit Sheet

struct RoutineExerciseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: RoutineExercise
    let onSave: () -> Void

    @State private var setsText: String = ""
    @State private var repsText: String = ""
    @State private var notesText: String = ""

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                    Spacer()
                    Text("Edit Exercise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                    Spacer()
                    Button("Save") { save() }
                        .foregroundColor(.atlasPrimary)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 20) {
                    Text(exercise.exerciseName)
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.atlasText)

                    // Sets
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SETS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.2)
                        TextField("3", text: $setsText)
                            .font(.system(size: 18))
                            .foregroundColor(.atlasText)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }

                    // Reps
                    VStack(alignment: .leading, spacing: 6) {
                        Text("REPS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.2)
                        TextField("8-10", text: $repsText)
                            .font(.system(size: 18))
                            .foregroundColor(.atlasText)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES (optional)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.2)
                        TextField("e.g., Pause at bottom", text: $notesText)
                            .font(.system(size: 16))
                            .foregroundColor(.atlasText)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            setsText = "\(exercise.sets)"
            repsText = exercise.reps
            notesText = exercise.notes ?? ""
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        if let sets = Int(setsText), sets > 0 {
            exercise.sets = sets
        }
        if !repsText.trimmingCharacters(in: .whitespaces).isEmpty {
            exercise.reps = repsText.trimmingCharacters(in: .whitespaces)
        }
        exercise.notes = notesText.isEmpty ? nil : notesText
        onSave()
        dismiss()
    }
}