import SwiftUI
import SwiftData

// MARK: - Workout History Card (Rich)

struct WorkoutHistoryCard: View {
    let session: WorkoutSession
    let coachingNote: String?
    let exerciseSnapshots: [ExerciseSnapshot]
    let hasPR: Bool
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    // BUG-C: inject unitFormatter so volume displays in user's preferred unit
    @Environment(\.unitFormatter) private var unitFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: icon + name/date + duration/volume + menu
            HStack(alignment: .top, spacing: 10) {
                // Dumbbell icon — mirrors the cardio card's heart icon treatment
                Image(systemName: "dumbbell")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.steadyRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Name + date
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.workoutName ?? "Workout")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.atlasText)
                            .lineLimit(1)

                        if hasPR {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("PR")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.atlasAmber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.atlasAmber.opacity(0.15))
                            .cornerRadius(4)
                        }
                    }

                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()

                // Duration + Volume
                VStack(alignment: .trailing, spacing: 2) {
                    if let mins = session.durationMinutes, mins > 0 {
                        Text("\(mins) min")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasText)
                    }

                    if totalVolume > 0 {
                        Text(unitFormatter.displayVolume(totalVolume))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.atlasPrimary)
                    }
                }

                // Menu
                if onDelete != nil || onEdit != nil {
                    Menu {
                        if let onEdit = onEdit {
                            Button {
                                onEdit()
                            } label: {
                                Label("Edit Workout", systemImage: "pencil")
                            }
                        }
                        if let onDelete = onDelete {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete Workout", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }
            
            // Exercise list (top 3)
            if !exerciseSnapshots.isEmpty {
                VStack(spacing: 4) {
                    ForEach(exerciseSnapshots.prefix(3)) { snapshot in
                        ExerciseSnapshotRow(snapshot: snapshot)
                    }
                    
                    let remaining = exerciseSnapshots.count - 3
                    if remaining > 0 {
                        Text("+ \(remaining) more exercise\(remaining == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted.opacity(0.6))
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            }
            
            // Coaching note
            if let note = coachingNote {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .padding(.top, 4)
            }
        }
        .steadyPanel()
    }
    
    // MARK: - Computed
    
    private var totalVolume: Double {
        if let stored = session.totalVolume, stored > 0 { return stored }
        return session.exercises.reduce(0) { total, ex in
            total + ex.sets.reduce(0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
        }
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(session.date) {
            return "Today"
        } else if calendar.isDateInYesterday(session.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            let daysAgo = calendar.dateComponents([.day], from: session.date, to: Date()).day ?? 999
            if daysAgo < 7 {
                formatter.dateFormat = "EEEE"
            } else {
                formatter.dateFormat = "EEE MMM d"
            }
            return formatter.string(from: session.date)
        }
    }
}

// MARK: - Exercise Snapshot Row

struct ExerciseSnapshotRow: View {
    let snapshot: ExerciseSnapshot
    @Environment(\.unitFormatter) private var unitFormatter
    
    var body: some View {
        HStack(spacing: 0) {
            Text(snapshot.name)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            Text(formattedBestSet)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
            
            if let indicator = snapshot.progressionIndicator {
                Text("  \(indicator.displayText(unitFormatter: unitFormatter))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(indicator.color)
            }
        }
    }
    
    private var formattedBestSet: String {
        if snapshot.isBodyweight {
            return "BW × \(snapshot.bestSetReps)"
        }
        return "\(Int(unitFormatter.weightValue(snapshot.bestSetWeight))) × \(snapshot.bestSetReps)"
    }
}

// MARK: - Exercise Snapshot Model

struct ExerciseSnapshot: Identifiable {
    let id = UUID()
    let name: String
    let bestSetWeight: Double
    let bestSetReps: Int
    let isBodyweight: Bool
    let progressionIndicator: ProgressionIndicator?
    
    var bestSetDescription: String {
        if isBodyweight {
            return "BW × \(bestSetReps)"
        }
        return "\(Int(bestSetWeight)) × \(bestSetReps)"
    }
    
    struct ProgressionIndicator {
        let text: String
        let weightDiff: Double?  // raw lbs diff, nil if not a weight change
        let color: Color
        
        func displayText(unitFormatter: UnitFormatter) -> String {
            if let diff = weightDiff {
                return "▲ +\(unitFormatter.displayWeightInt(diff))"
            }
            return text
        }
    }
}

// MARK: - Snapshot Builder

struct WorkoutSnapshotBuilder {
    
    static func buildSnapshots(
        for session: WorkoutSession,
        modelContext: ModelContext
    ) -> [ExerciseSnapshot] {
        let sortedExercises = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
        
        return sortedExercises.map { exercise -> ExerciseSnapshot in
            let bestSet = findBestSet(in: exercise)
            let isBodyweight = bestSet?.isBodyweight ?? false
            
            let indicator = calculateProgression(
                exercise: exercise,
                sessionDate: session.date,
                modelContext: modelContext
            )
            
            return ExerciseSnapshot(
                name: exercise.name,
                bestSetWeight: bestSet?.weight ?? 0,
                bestSetReps: bestSet?.reps ?? 0,
                isBodyweight: isBodyweight,
                progressionIndicator: indicator
            )
        }
    }
    
    static func sessionHasPR(
        session: WorkoutSession,
        modelContext: ModelContext
    ) -> Bool {
        for exercise in session.exercises {
            let currentE1RM = EstimatedMaxCalculator.bestE1RM(from: exercise)
            guard let curr = currentE1RM else { continue }
            
            let hasWeightedSets = exercise.sets.contains { ($0.weight ?? 0) > 0 && !$0.isBodyweight }
            guard hasWeightedSets else { continue }
            
            let history = WorkoutHistoryService.getExerciseHistory(
                for: exercise.name,
                modelContext: modelContext,
                limit: 100
            )
            
            let previousBest = history
                .filter { $0.workoutSession?.date != session.date }
                .compactMap { EstimatedMaxCalculator.bestE1RM(from: $0) }
                .max()
            
            if let prevBest = previousBest, curr > prevBest {
                return true
            }
        }
        return false
    }
    
    private static func findBestSet(in exercise: Exercise) -> WorkoutSet? {
        let weightedSets = exercise.sets.filter { ($0.weight ?? 0) > 0 && !$0.isBodyweight }
        if !weightedSets.isEmpty {
            return weightedSets.max(by: { a, b in
                let aE1RM = EstimatedMaxCalculator.calculate1RM(weight: a.weight ?? 0, reps: a.reps) ?? 0
                let bE1RM = EstimatedMaxCalculator.calculate1RM(weight: b.weight ?? 0, reps: b.reps) ?? 0
                return aE1RM < bE1RM
            })
        }
        return exercise.sets.max(by: { $0.reps < $1.reps })
    }
    
    private static func calculateProgression(
        exercise: Exercise,
        sessionDate: Date,
        modelContext: ModelContext
    ) -> ExerciseSnapshot.ProgressionIndicator? {
        let previous = WorkoutHistoryService.getLastWorkout(
            for: exercise.name,
            modelContext: modelContext,
            beforeDate: sessionDate
        )
        
        guard let prev = previous else { return nil }
        
        let currentE1RM = EstimatedMaxCalculator.bestE1RM(from: exercise)
        let prevE1RM = EstimatedMaxCalculator.bestE1RM(from: prev)
        
        guard let curr = currentE1RM, let prevMax = prevE1RM, prevMax > 0 else { return nil }
        
        let change = (curr - prevMax) / prevMax
        
        if change > 0.02 {
            let currBest = findBestSet(in: exercise)
            let prevBest = findBestSet(in: prev)
            
            if let cw = currBest?.weight, let pw = prevBest?.weight, cw > pw {
                let diff = cw - pw
                return ExerciseSnapshot.ProgressionIndicator(
                    text: "▲",
                    weightDiff: diff,
                    color: .atlasPrimary
                )
            } else if let cr = currBest?.reps, let pr = prevBest?.reps, cr > pr {
                let diff = cr - pr
                return ExerciseSnapshot.ProgressionIndicator(
                    text: "▲ +\(diff)",
                    weightDiff: nil,
                    color: .atlasPrimary
                )
            } else {
                return ExerciseSnapshot.ProgressionIndicator(
                    text: "▲",
                    weightDiff: nil,
                    color: .atlasPrimary
                )
            }
        } else if change < -0.05 {
            return ExerciseSnapshot.ProgressionIndicator(
                text: "▼",
                weightDiff: nil,
                color: .atlasAccent
            )
        }
        
        return nil
    }
}
