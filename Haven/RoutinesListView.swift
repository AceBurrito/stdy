import SwiftUI
import SwiftData

// MARK: - Routines List View
// "My Routines" library showing all WorkoutRoutine objects.
// Accessible via segmented control in the Training tab.
// Each card shows routine name, exercise count, and assigned days.

struct RoutinesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRoutine.createdDate, order: .reverse) private var routines: [WorkoutRoutine]
    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true && $0.isEventPlan == false })
    private var activePrograms: [TrainingProgram]

    @State private var selectedRoutine: WorkoutRoutine? = nil
    @State private var showingNewRoutine = false
    @State private var showingDeleteConfirm: WorkoutRoutine? = nil

    private var activeProgram: TrainingProgram? { activePrograms.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if routines.isEmpty {
                    emptyState
                } else {
                    ForEach(routines) { routine in
                        RoutineCard(
                            routine: routine,
                            assignedDays: assignedDays(for: routine),
                            onTap: { selectedRoutine = routine },
                            onDelete: { showingDeleteConfirm = routine }
                        )
                    }
                }

                // New Routine button
                Button(action: { showingNewRoutine = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text("New Routine")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.atlasPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer().frame(height: 40)
            }
            .padding(24)
        }
        .sheet(item: $selectedRoutine) { routine in
            NavigationStack {
                RoutineDetailView(routine: routine)
            }
        }
        .sheet(isPresented: $showingNewRoutine) {
            NavigationStack {
                RoutineBuilderView(onSave: { newRoutine in
                    modelContext.insert(newRoutine)
                    try? modelContext.save()
                    showingNewRoutine = false
                })
            }
        }
        .alert("Delete Routine?", isPresented: Binding(
            get: { showingDeleteConfirm != nil },
            set: { if !$0 { showingDeleteConfirm = nil } }
        )) {
            Button("Cancel", role: .cancel) { showingDeleteConfirm = nil }
            Button("Delete", role: .destructive) {
                if let routine = showingDeleteConfirm {
                    deleteRoutine(routine)
                }
            }
        } message: {
            if let routine = showingDeleteConfirm {
                let days = assignedDays(for: routine)
                if days.isEmpty {
                    Text("This will permanently delete \"\(routine.name)\" and its exercises.")
                } else {
                    Text("This routine is assigned to \(days.joined(separator: ", ")). Deleting it will remove those workout assignments.")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundColor(.atlasTextMuted.opacity(0.3))

            VStack(spacing: 6) {
                Text("No Routines Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)

                Text("Create reusable workout routines, then assign them to days in your schedule.")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    private func assignedDays(for routine: WorkoutRoutine) -> [String] {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard let program = activeProgram else { return [] }

        return program.workoutDays
            .filter { $0.workoutRoutineID == routine.id.uuidString }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
            .compactMap { day in
                guard day.dayOfWeek >= 0, day.dayOfWeek < dayNames.count else { return nil }
                return dayNames[day.dayOfWeek]
            }
    }

    private func deleteRoutine(_ routine: WorkoutRoutine) {
        // Clear routine references from any days that use it
        if let program = activeProgram {
            for day in program.workoutDays {
                if day.workoutRoutineID == routine.id.uuidString {
                    day.workoutRoutineID = nil
                }
            }
        }

        modelContext.delete(routine)
        try? modelContext.save()
        showingDeleteConfirm = nil
    }
}

// MARK: - Routine Card

struct RoutineCard: View {
    let routine: WorkoutRoutine
    let assignedDays: [String]
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(routine.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Spacer()

                    if routine.isFromTemplate {
                        Text("TEMPLATE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.atlasAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.atlasAccent.opacity(0.15))
                            .cornerRadius(4)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                }

                HStack(spacing: 12) {
                    Label("\(routine.exercises.count) exercises", systemImage: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)

                    if !assignedDays.isEmpty {
                        Text("·")
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                        Text(assignedDays.joined(separator: ", "))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.atlasPrimary)
                    } else {
                        Text("·")
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                        Text("Not scheduled")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                            .italic()
                    }
                }

                // Exercise preview (first 3)
                if !routine.sortedExercises.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(routine.sortedExercises.prefix(3)), id: \.id) { exercise in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.atlasPrimary.opacity(0.4))
                                    .frame(width: 4, height: 4)
                                Text(exercise.exerciseName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.atlasTextMuted)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(exercise.sets)×\(exercise.reps)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.atlasTextMuted.opacity(0.6))
                            }
                        }
                        if routine.exercises.count > 3 {
                            Text("+ \(routine.exercises.count - 3) more")
                                .font(.system(size: 12))
                                .foregroundColor(.atlasTextMuted.opacity(0.5))
                                .padding(.leading, 10)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}