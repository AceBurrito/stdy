// WorkoutHistoryView.swift
// Steady — Strength tab.
// Layout: this week (sessions, sets, volume + 8-week sets chart) → working sets
// per muscle group vs. minimums → lifts and their trends → recent workouts.

import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]
    @Query private var customExercises: [CustomExercise]
    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true }) private var activePrograms: [TrainingProgram]

    @State private var showingWorkoutLog = false
    @State private var volumeWindow: VolumeWindow = .thisWeek
    @State private var selectedSession: WorkoutSession? = nil
    @State private var sessionToDelete: WorkoutSession? = nil

    private var resolver: MuscleGroupResolver { MuscleGroupResolver(customExercises: customExercises) }
    private var weeklySummary: WeeklyStrengthSummary { WeeklyStrengthSummary.calculate(from: workoutSessions) }

    /// Sessions from the last 10 weeks are enough for every panel on this tab
    private var recentSessions: [WorkoutSession] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -70, to: Date()) else { return workoutSessions }
        return workoutSessions.filter { $0.date >= cutoff }
    }

    private var planSets: [MuscleGroup: Int]? {
        PlanVolume.weeklySets(program: activePrograms.first, resolver: resolver)
    }

    private var volumeRows: [MuscleVolumeRow] {
        MuscleVolume.rows(sessions: recentSessions, window: volumeWindow, experience: profiles.first?.experienceLevel, resolver: resolver, plan: planSets)
    }

    private var weeklyBars: [SteadyBarChart.Bar] {
        let totals = MuscleVolume.weeklyTotals(sessions: recentSessions, weeks: 8)
        return totals.enumerated().map { index, week in
            SteadyBarChart.Bar(date: week.weekStart, value: Double(week.sets), isPartial: index == totals.count - 1)
        }
    }

    private var lifts: [LiftHistory] {
        LiftAnalytics.histories(sessions: workoutSessions, resolver: resolver)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if workoutSessions.isEmpty {
                        emptyPanel
                    } else {
                        weekPanel
                        musclePanel
                        liftsPanel
                        recentPanel
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .background(Color.atlasBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedSession) { session in
                WorkoutDetailView(session: session)
            }
            .sheet(isPresented: $showingWorkoutLog) {
                WorkoutLogView()
            }
            .confirmationDialog(
                "Delete Workout?",
                isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }),
                titleVisibility: .visible,
                presenting: sessionToDelete
            ) { session in
                Button("Delete", role: .destructive) { WorkoutDeletion.delete(session, modelContext: modelContext) }
                Button("Cancel", role: .cancel) { }
            } message: { session in
                Text("\(session.workoutName ?? "Workout") on \(session.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strength")
                    .font(SteadyType.display(30))
                    .foregroundColor(.atlasText)
                Text(workoutSessions.first.map { "Last workout " + BodyFormat.relativeDay($0.date) } ?? "No workouts yet")
                    .steadyLabel()
            }
            Spacer()
            Button { showingWorkoutLog = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(width: 36, height: 36)
                    .background(Color.atlasPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("Log workout")
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No workouts yet").steadyLabel()
            Text("Log a workout to start tracking sets per muscle, estimated maxes and progression for every lift.")
                .font(SteadyType.body)
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Log workout") { showingWorkoutLog = true }
                .buttonStyle(SteadyPrimaryButtonStyle())
        }
        .steadyPanel()
    }

    // MARK: - This Week

    private var weekPanel: some View {
        let s = weeklySummary
        return VStack(alignment: .leading, spacing: 14) {
            Text("This week").steadyLabel()
            HStack(alignment: .top, spacing: 0) {
                statColumn("Sessions", "\(s.sessionsCompleted)", "", delta(s.sessionsTrend))
                divider
                statColumn("Sets", "\(s.setsCompleted)", "", delta(s.setsTrend))
                divider
                statColumn("Volume", volumeNumber(s.totalVolume), unitFormatter.weightUnit, volumeDelta(s.volumeTrend))
            }
            SteadyBarChart(bars: weeklyBars)
            Text("Working sets per week. This week is shown lighter until it's done.")
                .font(SteadyType.caption)
                .foregroundColor(.steadyTextFaint)
        }
        .steadyPanel()
    }

    private func delta(_ value: Int) -> String {
        value == 0 ? "same as last wk" : String(format: "%@%d vs last wk", value > 0 ? "+" : "−", abs(value))
    }

    private func volumeDelta(_ lbs: Double) -> String {
        let v = unitFormatter.fromLbs(lbs)
        if abs(v) < 1 { return "same as last wk" }
        return (v > 0 ? "+" : "−") + volumeNumber(abs(lbs)) + " vs last wk"
    }

    /// Volume in the user's unit, shortened past 10k
    private func volumeNumber(_ lbs: Double) -> String {
        let v = unitFormatter.fromLbs(lbs)
        return v >= 10_000 ? String(format: "%.1fk", v / 1000) : Int(v.rounded()).formatted()
    }

    // MARK: - Muscle Volume

    private var musclePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sets per muscle").steadyLabel()
                Spacer()
                let under = volumeRows.filter { $0.target > 0 && ($0.status == .under || $0.status == .none) }.count
                if volumeWindow != .thisWeek {
                    Text(under == 0 ? "all targets met" : "\(under) under target")
                        .font(SteadyType.caption)
                        .foregroundColor(under == 0 ? .atlasPrimary : .atlasAmber)
                }
            }
            SteadySegmented(options: VolumeWindow.allCases, selection: $volumeWindow) { $0.title }
            VStack(spacing: 10) {
                ForEach(volumeRows) { row in
                    MuscleVolumeBar(row: row)
                }
            }
            Text(volumeFootnote)
                .font(SteadyType.caption)
                .foregroundColor(.steadyTextFaint)
                .fixedSize(horizontal: false, vertical: true)
            if !planShortRows.isEmpty {
                planCheck
            }
        }
        .steadyPanel()
    }

    private var planShortRows: [MuscleVolumeRow] {
        volumeRows.filter { $0.planIsShort }
    }

    /// Where the plan itself falls short of the usual weekly minimum.
    private var planCheck: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Color.steadyHairline).frame(height: 1)
            Text("Plan check").steadyLabel(.atlasAmber)
            ForEach(planShortRows) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.group.shortName)
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasText)
                    Spacer()
                    Text("plan \(row.target) · min \(row.minimum) · add \(row.minimum - row.target)")
                        .font(SteadyType.metric(12, weight: .regular))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            Text("Your plan gives these groups fewer sets a week than the usual minimum for growth. Add sets to an exercise for them in Training Schedule.")
                .font(SteadyType.caption)
                .foregroundColor(.steadyTextFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private var volumeFootnote: String {
        let base = planSets != nil
            ? "The tick is the sets your plan gives each muscle group per week. Sets count toward the exercise's main muscle."
            : "The tick is your weekly minimum: 10 working sets for big muscle groups, 6 for arms and core, scaled to your experience. Set up a plan and the targets follow it instead. Sets count toward the exercise's main muscle."
        if volumeWindow == .thisWeek {
            let day = Calendar.current.component(.weekday, from: Date())
            let daysLeft = day == 1 ? 0 : 8 - day
            return daysLeft > 0 ? base + " \(daysLeft) day\(daysLeft == 1 ? "" : "s") left this week." : base
        }
        return base
    }

    // MARK: - Lifts

    private var liftsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Lifts").steadyLabel()
                Spacer()
                NavigationLink { AllTimePRsView() } label: {
                    Text("Records")
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasPrimary)
                }
                .padding(.trailing, 12)
                NavigationLink { ProgressiveOverloadView() } label: {
                    Text("All \(lifts.count)")
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasPrimary)
                }
            }
            .padding(.bottom, 4)
            ForEach(Array(lifts.prefix(5).enumerated()), id: \.element.name) { index, lift in
                if index > 0 { Rectangle().fill(Color.steadyHairline).frame(height: 1) }
                NavigationLink {
                    ExerciseDetailView(exerciseName: lift.name)
                } label: {
                    LiftRow(history: lift)
                }
                .buttonStyle(.plain)
            }
        }
        .steadyPanel()
    }

    // MARK: - Recent Workouts

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent workouts").steadyLabel()
                Spacer()
                NavigationLink { AllWorkoutsView() } label: {
                    Text("All \(workoutSessions.count)")
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasPrimary)
                }
            }
            ForEach(workoutSessions.prefix(4)) { session in
                WorkoutCardButton(
                    session: session,
                    previous: previousSameWorkout(session),
                    onOpen: { selectedSession = session },
                    onDelete: { sessionToDelete = session }
                )
            }
        }
    }

    private func previousSameWorkout(_ session: WorkoutSession) -> WorkoutSession? {
        guard let name = session.workoutName else { return nil }
        return workoutSessions.first { $0.id != session.id && $0.workoutName == name && $0.date < session.date }
    }

    // MARK: - Pieces

    private var divider: some View {
        Rectangle().fill(Color.steadyHairline).frame(width: 1).padding(.horizontal, 12)
    }

    private func statColumn(_ label: String, _ value: String, _ unit: String, _ footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).steadyLabel(.steadyTextFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(SteadyType.metric(22))
                    .foregroundColor(.atlasText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit).font(SteadyType.caption).foregroundColor(.atlasTextMuted)
                }
            }
            Text(footnote)
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Muscle Volume Bar

struct MuscleVolumeBar: View {
    let row: MuscleVolumeRow

    private var color: Color {
        switch row.status {
        case .none: return .steadyTextFaint
        case .under: return .atlasAmber
        case .met: return .atlasPrimary
        case .high: return .atlasAccent
        }
    }

    private var scale: Double { max(Double(row.ceiling), Double(row.target), row.sets, 1) }

    private var setsText: String {
        row.sets.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(row.sets))" : String(format: "%.1f", row.sets)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(row.group.shortName)
                .font(SteadyType.caption)
                .foregroundColor(.atlasText)
                .frame(width: 84, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.steadyRaised)
                    Rectangle().fill(color).frame(width: geo.size.width * min(row.sets / scale, 1))
                    Rectangle()
                        .fill(Color.atlasText.opacity(0.7))
                        .frame(width: 2)
                        .offset(x: geo.size.width * Double(row.target) / scale - 1)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            HStack(spacing: 2) {
                Text(setsText)
                    .font(SteadyType.metric(13))
                    .foregroundColor(row.status == .none ? .steadyTextFaint : .atlasText)
                Text("/\(row.target)")
                    .font(SteadyType.metric(11, weight: .regular))
                    .foregroundColor(.steadyTextFaint)
            }
            .frame(width: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.group.rawValue): \(setsText) of \(row.target) \(row.planned == nil ? "minimum" : "planned") sets")
    }
}

// MARK: - Workout Card Button

/// History card with its snapshot, PR flag and coaching note, used on the tab and in All Workouts.
struct WorkoutCardButton: View {
    let session: WorkoutSession
    let previous: WorkoutSession?
    let onOpen: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button(action: onOpen) {
            WorkoutHistoryCard(
                session: session,
                coachingNote: StrengthCoachingEngine.generateNote(for: session, previousSession: previous, modelContext: modelContext),
                exerciseSnapshots: WorkoutSnapshotBuilder.buildSnapshots(for: session, modelContext: modelContext),
                hasPR: WorkoutSnapshotBuilder.sessionHasPR(session: session, modelContext: modelContext),
                onDelete: onDelete
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Deletion

enum WorkoutDeletion {
    /// Deletes a session and the PRs it set. Exercises and sets cascade.
    static func delete(_ session: WorkoutSession, modelContext: ModelContext) {
        let sessionId = session.id
        let prs = (try? modelContext.fetch(FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { $0.workoutSessionId == sessionId }
        ))) ?? []
        prs.forEach { modelContext.delete($0) }
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete workout: \(error)")
        }
    }
}

// MARK: - All Workouts

struct AllWorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var selectedSession: WorkoutSession? = nil
    @State private var sessionToDelete: WorkoutSession? = nil

    private var grouped: [(title: String, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        var result: [(title: String, sessions: [WorkoutSession])] = []
        var currentKey: DateComponents? = nil
        for session in sessions {
            let key = calendar.dateComponents([.year, .month], from: session.date)
            if key != currentKey {
                result.append((title: session.date.formatted(.dateTime.month(.wide).year()), sessions: []))
                currentKey = key
            }
            result[result.count - 1].sessions.append(session)
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(grouped, id: \.title) { group in
                    HStack {
                        Text(group.title).steadyLabel()
                        Spacer()
                        Text("\(group.sessions.count) session\(group.sessions.count == 1 ? "" : "s")")
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                    }
                    .padding(.top, 8)
                    ForEach(group.sessions) { session in
                        WorkoutCardButton(
                            session: session,
                            previous: sessions.first { $0.id != session.id && $0.workoutName == session.workoutName && $0.date < session.date },
                            onOpen: { selectedSession = session },
                            onDelete: { sessionToDelete = session }
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
        .confirmationDialog(
            "Delete Workout?",
            isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }),
            titleVisibility: .visible,
            presenting: sessionToDelete
        ) { session in
            Button("Delete", role: .destructive) { WorkoutDeletion.delete(session, modelContext: modelContext) }
            Button("Cancel", role: .cancel) { }
        } message: { session in
            Text("\(session.workoutName ?? "Workout") on \(session.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted.")
        }
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
                            .font(SteadyType.display(28))
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
                    
                    Rectangle().fill(Color.steadyHairline).frame(height: 1)
                    
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
                                .steadyPanel(padding: 12)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
        .steadyPanel()
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
                                        .font(SteadyType.metric(17))
                                        .foregroundColor(.atlasText)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                                }
                                .steadyPanel()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    WorkoutHistoryView()
}
