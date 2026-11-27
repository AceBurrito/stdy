import SwiftUI
import SwiftData

// MARK: - Strength Tab (Complete Redesign)
// Matches the Cardio tab's elegance and information density.
// Layout: THIS WEEK summary → Navigation links → Rich workout history

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    @State private var showingWorkoutLog = false
    @State private var sessionToDelete: WorkoutSession? = nil
    @State private var showDeleteConfirmation = false
    // BUG-D: programmatic navigation so swipeActions work
    @State private var selectedSession: WorkoutSession? = nil
    
    private var userProfile: UserProfile? { profiles.first }
    
    // MARK: - Computed Data
    
    private var weeklySummary: WeeklyStrengthSummary {
        WeeklyStrengthSummary.calculate(from: workoutSessions)
    }
    
    /// Group workouts by month for display
    private var groupedWorkouts: [(String, [WorkoutSession])] {
        let grouped = Dictionary(grouping: workoutSessions) { session in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: session.date)
        }
        return grouped.sorted { pair1, pair2 in
            guard let d1 = pair1.1.first?.date, let d2 = pair2.1.first?.date else { return false }
            return d1 > d2
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                if workoutSessions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            weeklySummarySection
                            navigationLinksSection
                            workoutHistorySection
                            Spacer().frame(height: 40)
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Strength")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingWorkoutLog = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.atlasPrimary)
                    }
                }
            }
            .navigationDestination(item: $selectedSession) { session in
                WorkoutDetailView(session: session)
            }
            .sheet(isPresented: $showingWorkoutLog) {
                WorkoutLogView()
            }
            .confirmationDialog(
                "Delete Workout?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        deleteWorkout(session)
                    }
                }
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
            } message: {
                if let session = sessionToDelete {
                    Text("\(session.workoutName ?? "Workout") on \(session.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted.")
                }
            }
        }
    }

    // MARK: - Delete Workout

    private func deleteWorkout(_ session: WorkoutSession) {
        // Delete PRs that were set in this specific workout session
        let sessionId = session.id
        let prDescriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { $0.workoutSessionId == sessionId }
        )
        if let prs = try? modelContext.fetch(prDescriptor) {
            for pr in prs {
                modelContext.delete(pr)
            }
        }

        // SwiftData cascades deletion to Exercise → WorkoutSet via deleteRule: .cascade
        modelContext.delete(session)

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete workout: \(error)")
        }

        sessionToDelete = nil
    }
    
    // MARK: - THIS WEEK Summary Cards
    
    private var weeklySummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            HStack(spacing: 12) {
                // Total Volume
                StrengthSummaryCard(
                    value: weeklySummary.formattedVolume,
                    label: "Total Volume",
                    unit: unitFormatter.weightUnit,
                    trend: weeklySummary.formattedVolumeTrend,
                    trendPositive: weeklySummary.volumeTrend >= 0,
                    accentColor: .atlasPrimary
                )
                
                // Sets Completed
                StrengthSummaryCard(
                    value: "\(weeklySummary.setsCompleted)",
                    label: "Sets",
                    unit: nil,
                    trend: weeklySummary.formattedSetsTrend,
                    trendPositive: weeklySummary.setsTrend >= 0,
                    accentColor: .atlasAccent
                )
                
                // Sessions
                StrengthSummaryCard(
                    value: "\(weeklySummary.sessionsCompleted)",
                    label: "Sessions",
                    unit: nil,
                    trend: weeklySummary.formattedSessionsTrend,
                    trendPositive: weeklySummary.sessionsTrend >= 0,
                    accentColor: .white
                )
            }
        }
    }
    
    // MARK: - Workout History (Rich Cards)
    
    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedWorkouts, id: \.0) { month, sessions in
                monthSection(month: month, sessions: sessions)
            }
        }
    }
    
    private func monthSection(month: String, sessions: [WorkoutSession]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(month.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
                
                Spacer()
                
                Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
            }
            
            VStack(spacing: 8) {
                ForEach(sessions) { session in
                    let snapshots = WorkoutSnapshotBuilder.buildSnapshots(for: session, modelContext: modelContext)
                    let hasPR = WorkoutSnapshotBuilder.sessionHasPR(session: session, modelContext: modelContext)
                    let prevSession = findPreviousSameWorkout(session)
                    let coachingNote = StrengthCoachingEngine.generateNote(
                        for: session,
                        previousSession: prevSession,
                        modelContext: modelContext
                    )
                    
                    Button {
                        selectedSession = session
                    } label: {
                        WorkoutHistoryCard(
                            session: session,
                            coachingNote: coachingNote,
                            exerciseSnapshots: snapshots,
                            hasPR: hasPR,
                            onDelete: {
                                sessionToDelete = session
                                showDeleteConfirmation = true
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    /// Find the previous session with the same workout name (for volume comparison)
    private func findPreviousSameWorkout(_ session: WorkoutSession) -> WorkoutSession? {
        guard let name = session.workoutName else { return nil }
        return workoutSessions.first(where: {
            $0.id != session.id &&
            $0.workoutName == name &&
            $0.date < session.date
        })
    }
    
    // MARK: - Navigation Links (Bottom)
    
    private var navigationLinksSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: AllTimePRsView()) {
                    QuickLinkCard(
                        icon: "trophy.fill",
                        title: "All-Time PRs",
                        subtitle: "Your best lifts",
                        color: .yellow
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: ProgressiveOverloadView()) {
                    QuickLinkCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Progress",
                        subtitle: "Volume trends",
                        color: .atlasPrimary
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundColor(.atlasTextMuted)
            
            Text("No Training History")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.atlasText)
            
            Text("Start logging workouts to track volume, PRs, and progression")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingWorkoutLog = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Your First Workout")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasBackground)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.atlasPrimary)
                .cornerRadius(12)
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Summary Card (Shared Component)
// Reusable card matching the Cardio tab's summary card design

struct StrengthSummaryCard: View {
    let value: String
    let label: String
    let unit: String?
    let trend: String
    let trendPositive: Bool
    let accentColor: Color
    
    private var isSame: Bool { trend.contains("same") }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.atlasTextMuted)
            
            // Trend arrow
            HStack(spacing: 2) {
                if !isSame {
                    Image(systemName: trendPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(trend)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSame ? .atlasTextMuted.opacity(0.5) : (trendPositive ? .atlasPrimary : .atlasAccent))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(accentColor.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Workout Detail View (Updated)
// Shows full exercise details when tapping a workout card

struct WorkoutDetailView: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let session: WorkoutSession
    
    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.workoutName ?? "Workout")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.atlasText)
                        
                        HStack(spacing: 8) {
                            Text(session.date.formatted(date: .long, time: .shortened))
                                .font(.system(size: 15))
                                .foregroundColor(.atlasTextMuted)
                            
                            if let mins = session.durationMinutes, mins > 0 {
                                Text("· \(mins) min")
                                    .font(.system(size: 15))
                                    .foregroundColor(.atlasTextMuted)
                            }
                        }
                        
                        // Volume summary
                        if let vol = session.totalVolume, vol > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "scalemass.fill")
                                    .font(.system(size: 12))
                                Text(unitFormatter.displayVolume(vol) + " total volume")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.atlasPrimary)
                            .padding(.top, 4)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Exercises
                    if session.exercises.isEmpty {
                        Text("No exercises recorded")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasTextMuted)
                            .padding(20)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(session.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                                NavigationLink(destination: ExerciseDetailView(exerciseName: exercise.name)) {
                                    ExerciseDetailCard(exercise: exercise)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Notes
                    if let notes = session.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.atlasAccent)
                                .tracking(2)
                            
                            Text(notes)
                                .font(.system(size: 15))
                                .foregroundColor(.atlasText)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise Detail Card (in Workout Detail)

struct ExerciseDetailCard: View {
    let exercise: Exercise
    @Environment(\.unitFormatter) private var unitFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
            }
            
            VStack(spacing: 6) {
                ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                    HStack {
                        Text("Set \(set.setNumber)")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                            .frame(width: 60, alignment: .leading)
                        
                        if set.isBodyweight {
                            Text("Bodyweight × \(set.reps)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasText)
                        } else if let weight = set.weight {
                            Text("\(unitFormatter.displayWeightInt(weight)) × \(set.reps)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasText)
                        } else {
                            Text("\(set.reps) reps")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasText)
                        }
                        
                        Spacer()
                        
                        if let rpe = set.rpe {
                            Text("RPE \(rpe)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.atlasAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.atlasAccent.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .italic()
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - All-Time PRs View (Renamed from PersonalRecordsView)

struct AllTimePRsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    
    /// Build a deduplicated list of exercises with their best e1RM
    private var exercisePRs: [(name: String, e1rm: Double, date: Date)] {
        var bestByExercise: [String: (e1rm: Double, date: Date)] = [:]
        
        for session in sessions {
            for exercise in session.exercises {
                guard let e1rm = EstimatedMaxCalculator.bestE1RM(from: exercise) else { continue }
                let key = exercise.name
                if let existing = bestByExercise[key] {
                    if e1rm > existing.e1rm {
                        bestByExercise[key] = (e1rm, session.date)
                    }
                } else {
                    bestByExercise[key] = (e1rm, session.date)
                }
            }
        }
        
        return bestByExercise
            .map { (name: $0.key, e1rm: $0.value.e1rm, date: $0.value.date) }
            .sorted { $0.e1rm > $1.e1rm }
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()
            
            if exercisePRs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 60))
                        .foregroundColor(.atlasTextMuted)
                    Text("No PRs Yet")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.atlasText)
                    Text("Keep lifting and your records will appear here")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(exercisePRs, id: \.name) { pr in
                            NavigationLink(destination: ExerciseDetailView(exerciseName: pr.name)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pr.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.atlasText)
                                        
                                        Text(pr.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                            .font(.system(size: 12))
                                            .foregroundColor(.atlasTextMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(unitFormatter.displayWeightInt(pr.e1rm))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.atlasPrimary)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("All-Time PRs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryView()
    }
}