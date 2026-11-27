import SwiftUI
import SwiftData

// MARK: - Routine Builder View
// Creates a new WorkoutRoutine from scratch.
// Step 1: Name the routine
// Step 2: Add exercises from the exercise picker
// Returns the built routine via onSave callback.

struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    let onSave: (WorkoutRoutine) -> Void

    @State private var routineName: String = ""
    @State private var exercises: [BuilderExercise] = []
    @State private var showExercisePicker = false
    @State private var editingIndex: Int? = nil

    private var userProfile: UserProfile? { profiles.first }

    private var canSave: Bool {
        !routineName.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROUTINE NAME")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.atlasTextMuted)
                                .tracking(1.2)

                            TextField("e.g., Full Body A, Upper Body, Push Day", text: $routineName)
                                .font(.system(size: 18))
                                .foregroundColor(.atlasText)
                                .padding(14)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                        }

                        // Exercises
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("EXERCISES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.atlasTextMuted)
                                    .tracking(1.2)

                                Spacer()

                                if !exercises.isEmpty {
                                    Text("\(exercises.count) exercises")
                                        .font(.system(size: 12))
                                        .foregroundColor(.atlasTextMuted)
                                }
                            }

                            if exercises.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle.dashed")
                                        .font(.system(size: 28))
                                        .foregroundColor(.atlasTextMuted.opacity(0.4))
                                    Text("Add exercises to your routine")
                                        .font(.system(size: 14))
                                        .foregroundColor(.atlasTextMuted.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                    BuilderExerciseRow(
                                        exercise: exercise,
                                        onUpdateSets: { newSets in
                                            exercises[index].sets = newSets
                                        },
                                        onUpdateReps: { newReps in
                                            exercises[index].reps = newReps
                                        },
                                        onRemove: {
                                            exercises.remove(at: index)
                                        },
                                        onMoveUp: index > 0 ? {
                                            exercises.swapAt(index, index - 1)
                                        } : nil,
                                        onMoveDown: index < exercises.count - 1 ? {
                                            exercises.swapAt(index, index + 1)
                                        } : nil
                                    )
                                }
                            }

                            // Add exercise button
                            Button(action: { showExercisePicker = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Add Exercise")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.atlasPrimary)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }

                // Save button
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    Button(action: saveRoutine) {
                        Text("Save Routine")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(canSave ? .atlasBackground : .atlasTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSave ? Color.atlasPrimary : Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .background(Color.atlasBackground)
            }
        }
        .navigationTitle("New Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            PlanExercisePickerView(
                onSelect: { definition in
                    let ex = BuilderExercise(
                        exerciseID: definition.id,
                        name: definition.name,
                        sets: definition.defaultSets,
                        reps: "\(definition.defaultReps)",
                        isBodyweight: definition.isBodyweight
                    )
                    exercises.append(ex)
                },
                equipmentFilter: userProfile?.availableEquipment
            )
        }
    }

    // MARK: - Save

    private func saveRoutine() {
        guard canSave else { return }

        let routine = WorkoutRoutine(
            name: routineName.trimmingCharacters(in: .whitespaces)
        )
        routine.userProfile = userProfile

        // Exercises will be inserted by caller after inserting the routine
        // We build RoutineExercise objects here
        for (index, ex) in exercises.enumerated() {
            let routineEx = RoutineExercise(
                exerciseID: ex.exerciseID,
                exerciseName: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                sortOrder: index,
                isBodyweight: ex.isBodyweight
            )
            routineEx.routine = routine
            routine.exercises.append(routineEx)
        }

        onSave(routine)
    }
}

// MARK: - Builder Exercise (local state model)

struct BuilderExercise: Identifiable {
    let id = UUID()
    let exerciseID: String
    var name: String
    var sets: Int
    var reps: String
    var isBodyweight: Bool
}

// MARK: - Builder Exercise Row

struct BuilderExerciseRow: View {
    let exercise: BuilderExercise
    let onUpdateSets: (Int) -> Void
    let onUpdateReps: (String) -> Void
    let onRemove: () -> Void
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Reorder arrows
            VStack(spacing: 6) {
                if let moveUp = onMoveUp {
                    Button(action: moveUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted.opacity(0.3))
                if let moveDown = onMoveDown {
                    Button(action: moveDown) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 20)

            // Name
            Text(exercise.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
                .lineLimit(1)

            Spacer()

            // Sets stepper
            HStack(spacing: 4) {
                Button(action: { if exercise.sets > 1 { onUpdateSets(exercise.sets - 1) } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.atlasTextMuted)
                }
                .buttonStyle(PlainButtonStyle())

                Text("\(exercise.sets)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.atlasText)
                    .frame(width: 20)

                Button(action: { if exercise.sets < 10 { onUpdateSets(exercise.sets + 1) } }) {
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

            // Remove
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasAccent.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}