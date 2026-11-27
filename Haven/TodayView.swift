// TODAY VIEW — Steady
// Layout: date line → Recovery hero → Body snapshot (opens Body tab) → Today's training → Insights.
// No habits, no streaks, no Pace. Recovery state drives the training guidance.

import SwiftUI
import SwiftData
import WidgetKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Environment(NavigationRouter.self) private var router
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true }) private var activePrograms: [TrainingProgram]
    @Query(sort: \HealthMetrics.date, order: .reverse) private var allMetrics: [HealthMetrics]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    @Query(sort: \CardioSession.date, order: .reverse) private var allCardioSessions: [CardioSession]
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var bodyCompEntries: [BodyCompEntry]
    @Query private var customExercises: [CustomExercise]

    // Sheets
    @State private var showWorkoutLog = false
    @State private var showCardioLog = false
    @State private var showRecoveryDetail = false
    @State private var showResumeDraftPrompt = false
    @State private var showDraftWorkoutLog = false
    @State private var pendingDraft: WorkoutDraft? = nil

    // Widget prompt (one-shot, after the first completed training day)
    @AppStorage("hasSeenWidgetPrompt") private var hasSeenWidgetPrompt = false
    @State private var showWidgetInstructions = false
    @State private var widgetAlreadyAdded = false

    // MARK: - Derived Data

    private var recovery: RecoveryAssessment? {
        RecoveryScoreCalculator.assess(metrics: allMetrics)
    }

    private var todaysPlannedWorkout: PlannedWorkoutDay? {
        TodayTraining.plannedDay(in: activePrograms.first)
    }

    private var isTrainingComplete: Bool {
        TodayTraining.isCompleted(
            plannedDay: todaysPlannedWorkout,
            workoutSessions: Array(allWorkoutSessions.prefix(20)),
            cardioSessions: Array(allCardioSessions.prefix(20))
        )
    }

    /// Most recent session with the same name as today's planned strength day.
    private var lastMatchingSession: WorkoutSession? {
        guard let workout = todaysPlannedWorkout, workout.dayType == "strength" else { return nil }
        let dayName = workout.dayName.lowercased()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return allWorkoutSessions.first {
            $0.date < startOfToday && ($0.workoutName ?? "").lowercased() == dayName
        }
    }

    private var bodySnapshot: BodySnapshot {
        BodySnapshot.from(entries: Array(bodyCompEntries.prefix(60)), profile: profiles.first)
    }

    private var bodyState: BodyState {
        BodyState.from(entries: Array(bodyCompEntries.prefix(120)), profile: profiles.first)
    }

    private var bodyGoal: BodyGoal? {
        BodyGoal.from(state: bodyState, targetBodyFat: profiles.first?.targetBodyFatPercent)
    }

    private var metabolicAge: MetabolicAge? {
        MetabolicAge.estimate(profile: profiles.first, state: bodyState)
    }

    private var insights: [DailyInsight] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -70, to: Date()) ?? Date()
        let recentSessions = allWorkoutSessions.filter { $0.date >= cutoff }
        let resolver = MuscleGroupResolver(customExercises: customExercises)
        let weekStart = MuscleVolume.weekStart(for: Date())

        let strengthDays = activePrograms.first?.workoutDays.filter { $0.dayType == "strength" } ?? []
        let today = TodayTraining.todayDayOfWeek()          // 0 = Sunday
        let remainingDays: Set<Int> = today == 0 ? [0] : Set(Array(today...6) + [0])
        let daysLeft = strengthDays.filter { remainingDays.contains($0.dayOfWeek) }.count

        let input = InsightInputs(
            metrics: Array(allMetrics.prefix(40)),
            lifts: LiftAnalytics.histories(sessions: recentSessions, resolver: resolver),
            volumeRows: MuscleVolume.rows(sessions: recentSessions, window: .thisWeek, experience: profiles.first?.experienceLevel, resolver: resolver,
                                          plan: PlanVolume.weeklySets(program: activePrograms.first, resolver: resolver)),
            bodyState: bodyState,
            bodyGoal: bodyGoal,
            plannedDaysLeftThisWeek: daysLeft,
            sessionsThisWeek: recentSessions.filter { $0.date >= weekStart }.count,
            plannedSessionsPerWeek: strengthDays.isEmpty ? nil : strengthDays.count,
            unitFormatter: unitFormatter
        )
        return DailyInsightsEngine.insights(input)
    }

    private var recentPRCount: Int {
        DataController(modelContext: modelContext).recentPRs(days: 7).count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    dateHeader

                    RecoveryHeroCard(assessment: recovery) {
                        showRecoveryDetail = true
                    }

                    Button {
                        router.selectedTab = AppTab.body.rawValue
                    } label: {
                        BodySnapshotCard(snapshot: bodySnapshot, goal: bodyGoal, metabolicAge: metabolicAge, showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    TrainingDayPanel(
                        todaysWorkout: todaysPlannedWorkout,
                        isCompleted: isTrainingComplete,
                        recoveryState: recovery?.state,
                        lastSessionVolume: lastMatchingSession?.totalVolume,
                        lastSessionDate: lastMatchingSession?.date,
                        lastCardioSession: allCardioSessions.first,
                        onStartWorkout: { showWorkoutLog = true },
                        onStartCardio: { showCardioLog = true }
                    )

                    let todaysInsights = insights
                    if !todaysInsights.isEmpty {
                        InsightsCard(insights: todaysInsights)
                    }

                    if isTrainingComplete && !hasSeenWidgetPrompt && !widgetAlreadyAdded {
                        WidgetPromptCard(
                            onShowMe: { showWidgetInstructions = true },
                            onDismiss: { withAnimation { hasSeenWidgetPrompt = true } }
                        )
                        .transition(.opacity)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .background(Color.atlasBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            // MARK: Sheets
            .sheet(isPresented: $showRecoveryDetail) {
                RecoveryDetailSheet(assessment: recovery)
            }
            .sheet(isPresented: $showWorkoutLog) {
                WorkoutLogView(plannedDay: todaysPlannedWorkout, onComplete: refreshWidget)
            }
            .sheet(isPresented: $showCardioLog) {
                ManualCardioLogView(plannedDay: todaysPlannedWorkout, onComplete: refreshWidget)
            }
            .alert("Resume Workout?", isPresented: $showResumeDraftPrompt) {
                Button("Resume") { showDraftWorkoutLog = true }
                Button("Discard", role: .destructive) { WorkoutDraftManager.clearDraft(); pendingDraft = nil }
            } message: { Text("You have a workout in progress. Pick up where you left off?") }
            .sheet(isPresented: $showDraftWorkoutLog) {
                WorkoutLogView(onComplete: { pendingDraft = nil; refreshWidget() }, restoredDraft: pendingDraft)
            }
            .sheet(isPresented: $showWidgetInstructions) {
                WidgetInstructionsView(onDone: {
                    hasSeenWidgetPrompt = true
                    showWidgetInstructions = false
                })
            }

            // MARK: Lifecycle
            .onAppear {
                if let draft = WorkoutDraftManager.loadDraft() {
                    pendingDraft = draft
                    showResumeDraftPrompt = true
                }
                WidgetCenter.shared.getCurrentConfigurations { result in
                    if case .success(let configs) = result {
                        let added = configs.contains { $0.kind == "AtlasWidget" }
                        DispatchQueue.main.async {
                            widgetAlreadyAdded = added
                            if added { hasSeenWidgetPrompt = true }
                        }
                    }
                }
            }
            .onChange(of: recovery?.state) { _, _ in
                refreshWidget()
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide)))
                    .font(SteadyType.display(30))
                    .foregroundColor(.atlasText)
                Text(Date().formatted(.dateTime.month(.wide).day()))
                    .steadyLabel()
            }
            Spacer()
            if recentPRCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(recentPRCount)")
                        .font(SteadyType.metric(22))
                        .foregroundColor(.atlasAccent)
                    Text(recentPRCount == 1 ? "PR this week" : "PRs this week")
                        .steadyLabel()
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    private func refreshWidget() {
        WidgetSync.refresh(modelContext: modelContext, unitFormatter: unitFormatter)
    }
}

// MARK: - Body Snapshot Card

struct BodySnapshotCard: View {
    let snapshot: BodySnapshot
    var goal: BodyGoal? = nil
    var metabolicAge: MetabolicAge? = nil
    var showsChevron: Bool = false
    @Environment(\.unitFormatter) private var unitFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Body").steadySectionHeader()
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.steadyTextFaint)
                }
            }

            if snapshot.weight == nil {
                Text("Log your weight on the Body tab to see weight, body fat and metabolic age here.")
                    .font(SteadyType.body)
                    .foregroundColor(.atlasTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    column(
                        label: "Weight",
                        value: snapshot.weight.map { formattedWeight($0) } ?? "—",
                        unit: unitFormatter.weightUnit,
                        footnote: snapshot.weeklyChangeText(unitFormatter: unitFormatter)
                    )
                    separator
                    column(
                        label: "Body fat",
                        value: snapshot.bodyFatPercent.map { String(format: "%.1f", $0 * 100) } ?? "—",
                        unit: snapshot.bodyFatPercent == nil ? "" : "%",
                        footnote: snapshot.bodyFatPercent == nil ? "not logged" : nil
                    )
                    separator
                    column(
                        label: "Metabolic age",
                        value: metabolicAge.map { "\($0.years)" } ?? "—",
                        unit: metabolicAge == nil ? "" : "yrs",
                        footnote: metabolicAgeFootnote,
                        footnoteColor: (metabolicAge.map { $0.years < $0.actualAge } ?? false) ? .atlasPrimary : .atlasTextMuted
                    )
                }
                if let goal {
                    Rectangle().fill(Color.steadyHairline).frame(height: 1)
                    HStack(spacing: 6) {
                        Text("Goal").steadyLabel(.steadyTextFaint)
                        Text(String(format: "%.1f%% · ", goal.targetBodyFat * 100) + unitFormatter.displayWeight(goal.goalWeight))
                            .font(SteadyType.metric(13, weight: .medium))
                            .foregroundColor(.atlasText)
                        Spacer()
                        Text(goalStatus(goal))
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                    }
                }
            }
        }
        .steadyPanel()
    }

    private var metabolicAgeFootnote: String {
        guard let estimate = metabolicAge else {
            return snapshot.bodyFatPercent == nil ? "needs body fat" : "needs age & height"
        }
        let diff = estimate.years - estimate.actualAge
        if diff == 0 { return "= your age" }
        return "\(abs(diff)) yr\(abs(diff) == 1 ? "" : "s") \(diff < 0 ? "younger" : "older")"
    }

    private func goalStatus(_ goal: BodyGoal) -> String {
        if goal.isReached { return "reached" }
        let amount = String(format: "%.1f %@", unitFormatter.fromLbs(abs(goal.toGo)), unitFormatter.weightUnit)
        return amount + (goal.toGo > 0 ? " to lose" : " to gain")
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.steadyHairline)
            .frame(width: 1)
            .padding(.horizontal, 12)
    }

    private func formattedWeight(_ lbs: Double) -> String {
        String(format: "%.1f", unitFormatter.fromLbs(lbs))
    }

    private func column(label: String, value: String, unit: String, footnote: String?, footnoteColor: Color = .atlasTextMuted) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .steadyLabel(.steadyTextFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(SteadyType.metric(24))
                    .foregroundColor(value == "—" ? .steadyTextFaint : .atlasText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
            }
            if let footnote {
                Text(footnote)
                    .font(SteadyType.caption)
                    .foregroundColor(footnoteColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TodayView()
        .environment(NavigationRouter())
}
