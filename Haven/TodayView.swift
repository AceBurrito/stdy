// TODAY VIEW — V3 Redesign
// Layout: Hero (Greeting+Pace+Sparkline+Brief+Pills) → Training Card → Compact Habit Circles
// Floating Progress Pill above tab bar — always visible, shows completion state
// No tab swiping — training and habits both visible in single scroll
// Completed habits = coral circles. Incomplete = teal outline. All done = coral celebration.

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Today View

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { $0.isActive == true }) private var habits: [Habit]
    @Query private var profiles: [UserProfile]
    @Query(sort: \BiologicalPaceScore.date, order: .reverse) private var paceScores: [BiologicalPaceScore]
    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true }) private var activePrograms: [TrainingProgram]
    @Query(sort: \MorningBriefEntry.date, order: .reverse) private var briefHistory: [MorningBriefEntry]
    @Query private var allMetrics: [HealthMetrics]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    @Query(sort: \CardioSession.date, order: .reverse) private var allCardioSessions: [CardioSession]
    
    @State private var showingCustomizeProtocol = false
    @State private var selectedDate = Date()
    @State private var showResumeDraftPrompt = false
    @State private var showDraftWorkoutLog = false
    @State private var pendingDraft: WorkoutDraft? = nil
    @State private var showingWeeklyCheckIn = false
    @State private var showWeeklyCommitSheet = false
    @State private var showPaceDetail = false
    @State private var selectedMetric: SelectedMetric? = nil
    
    // Training panel sheets
    @State private var showWorkoutLog = false
    @State private var showCardioLog = false
    
    // Streak milestone state
    @State private var streakMilestoneToShow: StreakMilestone? = nil
    @State private var showStreakCelebrationFullscreen = false
    @State private var showToastMilestone: StreakMilestone? = nil
    @State private var showCardMilestone: StreakMilestone? = nil
    
    // Daily insight auto-present
    @State private var showDailyInsight = false
    
    // Habit reorder
    @State private var showHabitReorder = false
    
    // Widget prompt
    @AppStorage("hasSeenWidgetPrompt") private var hasSeenWidgetPrompt = false
    @State private var showWidgetInstructions = false
    @State private var widgetAlreadyAdded = false
    
    // Deep link: weekly check-in
    @Environment(NavigationRouter.self) private var router
    
    // MARK: - Basic Computed Properties
    
    private var userName: String { profiles.first?.name ?? "Friend" }
    private var latestPace: BiologicalPaceScore? { paceScores.first }
    
    private var last30DaysPace: [Double] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return paceScores.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }.map { $0.paceValue }
    }
    
    // Non-training habits only (for habit circles), sorted by user-defined order
    private var nonTrainingHabits: [Habit] {
        let ai = habits.filter { $0.habitType == "non_negotiable" && !$0.isTrainingHabit && $0.appliesTo(date: selectedDate) }
        let custom = habits.filter { $0.habitType == "custom" && $0.isActive }
        return (ai + custom).sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // Training habits for today
    private var todaysTrainingHabits: [Habit] {
        habits.filter { $0.habitType == "non_negotiable" && $0.isTrainingHabit && $0.appliesTo(date: selectedDate) }
    }
    
    // ALL habits (used only for morning brief context)
    private var allHabits: [Habit] {
        todaysTrainingHabits + nonTrainingHabits
    }
    
    // Progress tracking uses NON-TRAINING habits only — training has its own card
    private var completedCount: Int { nonTrainingCompletedCount }
    private var totalHabitCount: Int { nonTrainingHabits.count }
    
    private var nonTrainingCompletedCount: Int {
        let dc = DataController(modelContext: modelContext)
        return nonTrainingHabits.filter { dc.isHabitComplete(habit: $0, on: selectedDate) }.count
    }
    
    private func isHabitComplete(_ habit: Habit) -> Bool {
        DataController(modelContext: modelContext).isHabitComplete(habit: habit, on: selectedDate)
    }
    
    private var daysSinceActivation: Int {
        guard let profile = profiles.first, let activationDate = profile.planActivationDate else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: activationDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(1, days + 1)
    }
    
    private var hasTrainingToday: Bool { !todaysTrainingHabits.isEmpty }
    
    private var isTrainingComplete: Bool {
        guard let habit = todaysTrainingHabits.first else { return false }
        return isHabitComplete(habit)
    }
    
    // MARK: - Weekly Commit Data
    
    private var activeEventProgram: TrainingProgram? { activePrograms.first { $0.isEventPlan } }
    
    private var shouldShowWeeklyCommitCard: Bool {
        guard let profile = profiles.first else { return false }
        return WeeklyCommitHelper.shouldShowCommitCard(profile: profile)
    }
    
    private var comingWeekNumber: Int {
        guard let profile = profiles.first else { return 1 }
        return WeeklyCommitHelper.comingWeekNumber(profile: profile)
    }
    
    private var comingWeekData: PlannedWorkoutWeek? {
        activeEventProgram?.workoutWeeks.first { $0.weekNumber == comingWeekNumber }
    }
    
    // MARK: - Streak-at-Risk
    
    private var isStreakAtRisk: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 18, completedCount < totalHabitCount else { return false }
        return DataController(modelContext: modelContext).getCurrentStreak() >= 3
    }
    
    private var isAllComplete: Bool {
        guard totalHabitCount > 0 else { return false }
        return completedCount >= totalHabitCount
    }
    
    // MARK: - Training Panel Data
    
    private var todaysPlannedWorkout: PlannedWorkoutDay? {
        let todayDOW = Calendar.current.component(.weekday, from: Date()) - 1
        let program = activePrograms.first
        
        if let eventProgram = activeEventProgram,
           let currentWeek = eventProgram.currentWeekWorkouts {
            return currentWeek.days.first { $0.dayOfWeek == todayDOW }
        }
        
        return program?.workoutDays.first { $0.dayOfWeek == todayDOW }
    }
    
    private var lastSessionVolume: Double? {
        guard let workout = todaysPlannedWorkout, workout.dayType == "strength" else { return nil }
        let dayName = workout.dayName.lowercased()
        return allWorkoutSessions.first { ($0.workoutName ?? "").lowercased().contains(dayName) }?.totalVolume
    }
    
    private var lastSessionDate: Date? {
        guard let workout = todaysPlannedWorkout, workout.dayType == "strength" else { return nil }
        let dayName = workout.dayName.lowercased()
        return allWorkoutSessions.first { ($0.workoutName ?? "").lowercased().contains(dayName) }?.date
    }
    
    private var lastCardioSession: CardioSession? {
        allCardioSessions.first
    }
    
    // MARK: - Metric Pills
    
    private var metricPills: [MetricPillData] {
        var pills: [MetricPillData] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!
        
        let todayM = allMetrics.first { calendar.isDate($0.date, inSameDayAs: today) }
        let yesterdayM = allMetrics.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        let dayBeforeM = allMetrics.first { calendar.isDate($0.date, inSameDayAs: dayBefore) }
        
        if let sleep = todayM?.sleepDuration {
            let c: Color = sleep >= 7.0 ? .atlasPrimary : (sleep >= 6.0 ? .atlasAmber : .atlasAccent)
            pills.append(MetricPillData(shortName: "Sleep", displayValue: String(format: "%.1fh", sleep),
                sublabel: sleep >= 7.0 ? "Optimal" : (sleep >= 6.0 ? "Getting there" : "Low"), color: c, metricType: .sleep, numericValue: sleep))
        }
        if let hrv = yesterdayM?.heartRateVariability {
            let a = arrowFor(current: hrv, previous: dayBeforeM?.heartRateVariability, higherIsBetter: true)
            let c: Color = a == "↑" ? .atlasPrimary : (a == "→" ? .atlasTextMuted : .atlasAmber)
            pills.append(MetricPillData(shortName: "HRV", displayValue: String(format: "%.0f", hrv),
                sublabel: a == "↑" ? "Recovering" : (a == "→" ? "Stable" : "Monitor"), color: c, metricType: .hrv, numericValue: hrv))
        }
        if let rhr = yesterdayM?.restingHeartRate {
            let a = arrowFor(current: rhr, previous: dayBeforeM?.restingHeartRate, higherIsBetter: false)
            let c: Color = a == "↓" ? .atlasPrimary : (a == "→" ? .atlasTextMuted : .atlasAmber)
            pills.append(MetricPillData(shortName: "RHR", displayValue: String(format: "%.0f", rhr),
                sublabel: a == "↓" ? "Improving" : (a == "→" ? "Stable" : "Monitor"), color: c, metricType: .rhr, numericValue: rhr))
        }
        if let steps = yesterdayM?.stepCount {
            let c: Color = steps >= 10000 ? .atlasPrimary : (steps >= 7000 ? .atlasAmber : .atlasTextMuted)
            pills.append(MetricPillData(shortName: "Steps", displayValue: String(format: "%.1fk", steps / 1000.0),
                sublabel: steps >= 10000 ? "Crushed it" : (steps >= 7000 ? "Almost" : "Light day"), color: c, metricType: .steps, numericValue: steps))
        }
        if let vo2 = yesterdayM?.vo2Max {
            pills.append(MetricPillData(shortName: "VO₂", displayValue: String(format: "%.0f", vo2),
                sublabel: vo2 >= 45 ? "Elite" : (vo2 >= 35 ? "Above avg" : "Building"),
                color: vo2 >= 45 ? .atlasPrimary : .atlasTextMuted, metricType: .vo2Max, numericValue: vo2))
        }
        return pills
    }
    
    private func arrowFor(current: Double, previous: Double?, higherIsBetter: Bool) -> String {
        guard let prev = previous else { return "→" }
        let diff = current - prev; let threshold = abs(prev) * 0.05
        if abs(diff) < threshold { return "→" }
        return higherIsBetter ? (diff > 0 ? "↑" : "↓") : (diff < 0 ? "↓" : "↑")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Base background matches gradient top color — seamless under nav bar
                Color(red: 0.075, green: 0.16, blue: 0.15).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // ═══ HERO SURFACE ═══
                        VStack(spacing: 14) {
                            
                            // Toast milestone
                            if let toast = showToastMilestone {
                                StreakToastView(
                                    milestone: toast,
                                    currentStreak: DataController(modelContext: modelContext).getCurrentStreak(),
                                    onDismiss: {
                                        if let profile = profiles.first {
                                            StreakMilestoneEngine.markCelebrated(milestone: toast, profile: profile)
                                            try? modelContext.save()
                                        }
                                        showToastMilestone = nil
                                    }
                                )
                                .appear()
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            // Pace + Sparkline
                            HeroCard(
                                briefHistory: Array(briefHistory.prefix(7)),
                                paceValue: latestPace?.paceValue ?? profiles.first?.latestPaceValue,
                                paceConfidence: latestPace?.confidenceLevel ?? profiles.first?.latestPaceConfidence,
                                paceHistory: last30DaysPace,
                                signals: metricPills,
                                currentStreak: DataController(modelContext: modelContext).getCurrentStreak(),
                                onPaceTap: { showPaceDetail = true },
                                onMetricTap: { type, value, yVal in
                                    selectedMetric = SelectedMetric(type: type, value: value, yesterdayValue: yVal)
                                }
                            )
                            
                            // Milestone celebrations
                            MilestoneStack()
                                .padding(.horizontal, 20)
                            
                            // Card milestone (7, 14 days)
                            if let cardMilestone = showCardMilestone {
                                StreakCardCelebration(
                                    milestone: cardMilestone,
                                    currentStreak: DataController(modelContext: modelContext).getCurrentStreak(),
                                    onDismiss: {
                                        if let profile = profiles.first {
                                            StreakMilestoneEngine.markCelebrated(milestone: cardMilestone, profile: profile)
                                            try? modelContext.save()
                                        }
                                        showCardMilestone = nil
                                    }
                                )
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                            
                            // Weekly Check-In
                            if isWeeklyCheckInDue() {
                                weeklyCheckInCard.padding(.horizontal, 20)
                            }
                            
                            // Weekly Commit Card
                            if shouldShowWeeklyCommitCard, let weekData = comingWeekData {
                                let profile = profiles.first
                                let eventName = profile?.eventName ?? profile?.eventType ?? activeEventProgram?.eventType ?? "Event"
                                let totalWeeks = activeEventProgram?.totalWeeks ?? 12
                                let isDeload = profile != nil ? DeloadDetector.isCurrentlyInDeloadWeek(profile: profile!) : false
                                
                                WeeklyCommitCard(
                                    eventName: eventName, weekNumber: comingWeekNumber, totalWeeks: totalWeeks,
                                    phaseName: isDeload ? "Deload" : weekData.phaseName,
                                    workoutSummary: isDeload
                                        ? WeeklyCommitHelper.workoutSummary(for: weekData) + " — Recovery week: same exercises, 50% volume"
                                        : WeeklyCommitHelper.workoutSummary(for: weekData),
                                    isDeloadWeek: isDeload,
                                    onCommit: { withAnimation { commitToWeek() } },
                                    onAdjust: { showWeeklyCommitSheet = true }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 24)
                        .background(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.075, green: 0.16, blue: 0.15), location: 0.0),
                                    .init(color: Color(red: 0.09, green: 0.13, blue: 0.14), location: 0.55),
                                    .init(color: Color.atlasBackground, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                        )
                        
                        // ═══ CONTENT SURFACE ═══
                        VStack(spacing: 0) {
                            // Inline progress bar — always visible, never floats
                            inlineProgressBar
                            
                            // Habit circles — above training so they're never forgotten
                            compactHabitCircles
                            
                            // Training card
                            trainingSection
                            
                            // Day complete celebration (appears when all habits done)
                            if isAllComplete {
                                DayCompleteCard(
                                    dayNumber: daysSinceActivation,
                                    currentStreak: DataController(modelContext: modelContext).getCurrentStreak()
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                
                                // Widget prompt — one-shot, after first all-habits-complete
                                if !hasSeenWidgetPrompt && !widgetAlreadyAdded {
                                    WidgetPromptCard(
                                        onShowMe: { showWidgetInstructions = true },
                                        onDismiss: { withAnimation { hasSeenWidgetPrompt = true } }
                                    )
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            
                            Spacer(minLength: 80) // Room for tab bar
                        }
                        .animation(.easeOut(duration: 0.4), value: isAllComplete)
                        .background(Color(hex: "#242428"))
                        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
                        .offset(y: -12)
                        .padding(.bottom, -12)
                    }
                }
            }
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isStreakAtRisk {
                        Text("Day \(daysSinceActivation) — streak at risk")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.atlasAccent).tracking(0.5)
                    } else {
                        Text("Day \(daysSinceActivation)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.atlasTextMuted).tracking(1)
                    }
                }
            }
            
            // MARK: - Sheets
            
            .sheet(isPresented: $showPaceDetail) { PaceDetailView() }
            .sheet(item: $selectedMetric) { metric in
                MetricDetailSheet(metric: metric.type, currentValue: metric.value, yesterdayValue: metric.yesterdayValue,
                                  age: profiles.first?.age, biologicalSex: profiles.first?.gender)
            }
            .sheet(isPresented: $showingCustomizeProtocol) { CustomizeProtocolView() }
            .sheet(isPresented: $showingWeeklyCheckIn) { EnhancedWeeklyCheckInView() }
            .sheet(isPresented: $showWeeklyCommitSheet) {
                if let weekData = comingWeekData {
                    let profile = profiles.first
                    let eventName = profile?.eventName ?? profile?.eventType ?? activeEventProgram?.eventType ?? "Event"
                    WeeklyCommitSheet(weekData: weekData, eventName: eventName, weekNumber: comingWeekNumber,
                                      totalWeeks: activeEventProgram?.totalWeeks ?? 12, onCommit: { commitToWeek() })
                }
            }
            .sheet(isPresented: $showWorkoutLog) {
                WorkoutLogView(habit: todaysTrainingHabits.first, onComplete: {
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                })
            }
            .sheet(isPresented: $showCardioLog) {
                ManualCardioLogView(habit: todaysTrainingHabits.first, onComplete: {
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                })
            }
            .alert("Resume Workout?", isPresented: $showResumeDraftPrompt) {
                Button("Resume") { showDraftWorkoutLog = true }
                Button("Discard", role: .destructive) { WorkoutDraftManager.clearDraft(); pendingDraft = nil }
            } message: { Text("You have a workout in progress. Pick up where you left off?") }
            .sheet(isPresented: $showDraftWorkoutLog) {
                WorkoutLogView(onComplete: { pendingDraft = nil }, restoredDraft: pendingDraft)
            }
            
            // MARK: - On Appear
            
            .onAppear {
                checkForWorkoutDraft()
                generateTodaysBriefIfNeeded()
                checkStreakMilestone()
                autoShowDailyInsight()
                if let profile = profiles.first, MonthlyPaceStrengthRefresh.shouldRefresh(profile: profile) {
                    MonthlyPaceStrengthRefresh.refreshFromWorkoutData(profile: profile, modelContext: modelContext)
                }
                
                // Widget: clear Pace changed flag (user has seen the Today tab)
                if let paceValue = paceScores.first?.paceValue ?? profiles.first?.latestPaceValue {
                    WidgetDataWriter.shared.clearPaceChanged(currentPaceValue: paceValue)
                }
                
                // Widget: check if widget is already added
                WidgetCenter.shared.getCurrentConfigurations { result in
                    if case .success(let configs) = result {
                        widgetAlreadyAdded = configs.contains { $0.kind == "AtlasWidget" }
                        if widgetAlreadyAdded { hasSeenWidgetPrompt = true }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceOpenWeeklyCheckIn"))) { _ in
                showingWeeklyCheckIn = true
            }
            .onChange(of: router.showWeeklyCheckIn) { _, newValue in
                if newValue {
                    showingWeeklyCheckIn = true
                    router.showWeeklyCheckIn = false
                }
            }
            .sheet(isPresented: $showWidgetInstructions) {
                WidgetInstructionsView(onDone: {
                    hasSeenWidgetPrompt = true
                    showWidgetInstructions = false
                })
            }
            .sheet(isPresented: $showDailyInsight) {
                if let entry = briefHistory.first {
                    let accent: Color = {
                        switch entry.accentColor {
                        case "amber": return .atlasAmber
                        case "coral": return .atlasAccent
                        default: return .atlasPrimary
                        }
                    }()
                    InsightDetailSheet(entry: entry, accent: accent)
                }
            }
            .fullScreenCover(isPresented: $showStreakCelebrationFullscreen) {
                if let milestone = streakMilestoneToShow {
                    StreakFullscreenCelebration(
                        milestone: milestone,
                        currentStreak: DataController(modelContext: modelContext).getCurrentStreak(),
                        onDismiss: {
                            if let profile = profiles.first {
                                StreakMilestoneEngine.markCelebrated(milestone: milestone, profile: profile)
                                try? modelContext.save()
                            }
                            showStreakCelebrationFullscreen = false; streakMilestoneToShow = nil
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Inline Progress Bar
    
    private var inlineProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Today's progress")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.atlasText.opacity(0.45))
                Spacer()
                Text(isAllComplete
                    ? "All done"
                    : "\(completedCount) of \(totalHabitCount) complete"
                )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAllComplete ? .atlasAccent : .atlasText.opacity(0.65))
            }
            
            ProgressLineView(
                progress: totalHabitCount == 0 ? 0 : Double(completedCount) / Double(totalHabitCount),
                allComplete: isAllComplete
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.4), value: isAllComplete)
    }
    
    // MARK: - Training Section
    
    private var trainingSection: some View {
        VStack(spacing: 0) {
            if hasTrainingToday {
                TrainingDayPanel(
                    todaysWorkout: todaysPlannedWorkout,
                    trainingHabit: todaysTrainingHabits.first,
                    isCompleted: isTrainingComplete,
                    lastSessionVolume: lastSessionVolume,
                    lastSessionDate: lastSessionDate,
                    lastCardioSession: lastCardioSession,
                    onStartWorkout: { showWorkoutLog = true },
                    onStartCardio: { showCardioLog = true },
                    onMarkRestComplete: { markRestDayComplete() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            } else {
                NoTrainingPanel()
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
        }
    }
    
    // MARK: - Compact Habit Circles
    
    private var compactHabitCircles: some View {
        let allNonTrainingComplete = !nonTrainingHabits.isEmpty && nonTrainingCompletedCount >= nonTrainingHabits.count
        
        return VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack {
                NavigationLink(destination: HabitBreakdownView()) {
                    HStack(spacing: 5) {
                        Text("Non-negotiables")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText.opacity(0.45))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.atlasTextMuted.opacity(0.35))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(nonTrainingCompletedCount) of \(nonTrainingHabits.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(allNonTrainingComplete ? .atlasAccent : .atlasTextMuted.opacity(0.45))
                    
                    Button(action: { showingCustomizeProtocol = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasPrimary.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Habit circle row — adaptive layout
            habitCircleRow(allComplete: allNonTrainingComplete)
                .padding(.horizontal, habitCirclePadding)
        }
        .padding(.top, 20)
        .sheet(isPresented: $showHabitReorder) {
            HabitReorderSheet(habits: nonTrainingHabits)
        }
    }
    
    // Adaptive padding based on habit count
    private var habitCirclePadding: CGFloat {
        switch nonTrainingHabits.count {
        case 0...3: return 32
        case 4: return 24
        default: return 16
        }
    }
    
    // Circle size adapts to habit count
    private var circleSize: CGFloat {
        switch nonTrainingHabits.count {
        case 0...3: return 48
        case 4...5: return 44
        case 6: return 40
        default: return 38
        }
    }
    
    @ViewBuilder
    private func habitCircleRow(allComplete: Bool) -> some View {
        if nonTrainingHabits.count <= 6 {
            // Single row, evenly spaced
            HStack(spacing: 0) {
                ForEach(nonTrainingHabits) { habit in
                    CompactHabitCircle(
                        habit: habit,
                        selectedDate: selectedDate,
                        circleSize: circleSize,
                        allHabitsComplete: allComplete,
                        onLongPress: { showHabitReorder = true }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            // Horizontal scroll for 7+
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(nonTrainingHabits) { habit in
                        CompactHabitCircle(
                            habit: habit,
                            selectedDate: selectedDate,
                            circleSize: circleSize,
                            allHabitsComplete: allComplete,
                            onLongPress: { showHabitReorder = true }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Weekly Check-In Card
    
    private var weeklyCheckInCard: some View {
        Button(action: { showingWeeklyCheckIn = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").font(.system(size: 16)).foregroundColor(.atlasPrimary)
                        Text("WEEKLY COACHING AVAILABLE").font(.system(size: 11, weight: .bold)).foregroundColor(.atlasPrimary).tracking(1.5)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 24)).foregroundColor(.atlasPrimary)
                }
                Text("Week \(profiles.first?.currentWeek ?? 1) Review").font(.system(size: 20, weight: .semibold)).foregroundColor(.atlasText)
                Text("Review your progress and get personalized coaching for the week ahead")
                    .font(.system(size: 14)).foregroundColor(.atlasTextMuted).lineSpacing(3)
            }
            .padding(20)
            .background(LinearGradient(colors: [Color.atlasPrimary.opacity(0.15), Color.atlasPrimary.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func commitToWeek() {
        guard let profile = profiles.first else { return }
        profile.weeklyCommitDate = Date()
        try? modelContext.save()
    }
    
    private func markRestDayComplete() {
        guard let habit = todaysTrainingHabits.first else { return }
        let dc = DataController(modelContext: modelContext)
        dc.markHabitComplete(habit, date: selectedDate)
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
    }
    
    private func isWeeklyCheckInDue() -> Bool {
        guard let profile = profiles.first else { return false }
        let calendar = Calendar.current
        let minimumDaysActive = 5
        
        if let activationDate = profile.planActivationDate {
            guard (calendar.dateComponents([.day], from: activationDate, to: Date()).day ?? 0) >= minimumDaysActive else { return false }
        } else if let onboardingDate = profile.onboardingCompletedDate {
            guard (calendar.dateComponents([.day], from: onboardingDate, to: Date()).day ?? 0) >= minimumDaysActive else { return false }
        } else { return false }
        
        let weekday = calendar.component(.weekday, from: Date())
        guard weekday == 1 || weekday == 2 || weekday == 3 else { return false }
        
        if let lastCheckIn = profile.lastCheckInDate {
            let today = calendar.startOfDay(for: Date())
            let daysFromSunday = weekday - 1
            guard let windowStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else { return false }
            if lastCheckIn >= windowStart { return false }
        }
        return true
    }
    
    private func checkForWorkoutDraft() {
        if let draft = WorkoutDraftManager.loadDraft() { pendingDraft = draft; showResumeDraftPrompt = true }
    }
    
    // MARK: - Auto-Present Daily Insight
    
    private func autoShowDailyInsight() {
        // Only auto-present once per day
        let key = "lastInsightAutoPresented"
        if let lastDate = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDateInToday(lastDate) {
            return // Already shown today
        }
        
        // Need a brief to show
        guard briefHistory.first != nil else { return }
        
        // Small delay so the view settles first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showDailyInsight = true
            UserDefaults.standard.set(Date(), forKey: key)
        }
    }
    
    // MARK: - Streak Milestone Check
    
    private func checkStreakMilestone() {
        guard let profile = profiles.first else { return }
        let dc = DataController(modelContext: modelContext)
        let currentStreak = dc.getCurrentStreak()
        
        StreakMilestoneEngine.handleStreakReset(currentStreak: currentStreak, profile: profile)
        dc.updatePersonalBestStreak(profile: profile)
        
        if let milestone = StreakMilestoneEngine.checkForMilestone(currentStreak: currentStreak, profile: profile) {
            streakMilestoneToShow = milestone
            switch milestone.celebrationType {
            case "toast": showToastMilestone = milestone
            case "card": showCardMilestone = milestone
            case "fullscreen":
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showStreakCelebrationFullscreen = true }
            default: break
            }
        }
        try? modelContext.save()
    }
    
    // MARK: - Morning Brief Generation
    
    private func generateTodaysBriefIfNeeded() {
        guard let profile = profiles.first else { return }
        let calendar = Calendar.current
        if let lastDate = profile.lastBriefDate, calendar.isDateInToday(lastDate) { return }
        
        let dc = DataController(modelContext: modelContext)
        let currentStreak = dc.getCurrentStreak()
        let day = daysSinceActivation
        let today = calendar.startOfDay(for: Date())
        
        let todayM = allMetrics.first { calendar.isDate($0.date, inSameDayAs: today) }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayM = allMetrics.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        
        let last7 = allMetrics.filter { let d = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 0; return d >= 0 && d < 7 }
        let prior7 = allMetrics.filter { let d = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 0; return d >= 7 && d < 14 }
        
        let sleepVals7 = last7.compactMap { $0.sleepDuration }
        let sleepAvg7: Double? = sleepVals7.isEmpty ? nil : sleepVals7.reduce(0, +) / Double(sleepVals7.count)
        let hrvVals7 = last7.compactMap { $0.heartRateVariability }
        let hrvAvg7: Double? = hrvVals7.isEmpty ? nil : hrvVals7.reduce(0, +) / Double(hrvVals7.count)
        let hrvVals14 = prior7.compactMap { $0.heartRateVariability }
        let hrvAvg14: Double? = hrvVals14.isEmpty ? nil : hrvVals14.reduce(0, +) / Double(hrvVals14.count)
        let rhrVals7 = last7.compactMap { $0.restingHeartRate }
        let rhrAvg7: Double? = rhrVals7.isEmpty ? nil : rhrVals7.reduce(0, +) / Double(rhrVals7.count)
        
        let allRecentPRs = dc.recentPRs(days: 7)
        let announcedIDs = Set(profile.announcedPRExerciseIDs)
        let filteredPRs = allRecentPRs.filter { pr in !announcedIDs.contains(pr.exerciseName) }
        
        let brief = MorningBriefEngine.generateBrief(
            profile: profile, dayNumber: day, currentStreak: currentStreak,
            lastNightSleep: todayM?.sleepDuration, sleepAvg7Day: sleepAvg7,
            consecutiveNightsAbove7: dc.consecutiveNightsAboveSleep(threshold: 7.0),
            hrvYesterday: yesterdayM?.heartRateVariability, hrvAvg7Day: hrvAvg7, hrvAvg14Day: hrvAvg14,
            rhrYesterday: yesterdayM?.restingHeartRate, rhrAvg7Day: rhrAvg7,
            latestPace: paceScores.first, paceBaseline: profile.paceBaselineValue,
            componentWin: dc.biggestComponentWin(paceScores: Array(paceScores)),
            adherence7Day: dc.getHabitCompletionRateForDays(days: 7),
            recentPRs: filteredPRs,
            todaysTrainingDayName: todaysTrainingHabits.first?.title,
            todaysTrainingDayType: todaysTrainingHabits.first?.trainingDayType ?? (todaysTrainingHabits.isEmpty ? nil : "rest"),
            workoutsLast7Days: dc.workoutCountInLastDays(7),
            totalWorkoutsLogged: allWorkoutSessions.count,
            habitCount: allHabits.count, userName: userName
        )
        
        if brief.varietyKey == "pr_celebration" || brief.varietyKey == "first_pr" {
            for pr in filteredPRs {
                if !profile.announcedPRExerciseIDs.contains(pr.exerciseName) {
                    profile.announcedPRExerciseIDs.append(pr.exerciseName)
                }
            }
        }
        
        let entry = MorningBriefEntry(dayNumber: brief.dayNumber, headline: brief.headline, body: brief.body,
            todayPreview: brief.todayPreview, accentColor: brief.accentColor, icon: brief.icon, varietyKey: brief.varietyKey)
        entry.userProfile = profile
        modelContext.insert(entry)
        
        profile.lastBriefVarietyKey = brief.varietyKey
        profile.lastBriefDate = Date()
        dc.updatePersonalBestStreak(profile: profile)
        try? modelContext.save()
        print("✅ Morning brief generated: \(brief.varietyKey) — \(brief.headline)")
    }
}

// MARK: - Compact Habit Circle

struct CompactHabitCircle: View {
    let habit: Habit
    var selectedDate: Date = Date()
    var circleSize: CGFloat = 44
    var allHabitsComplete: Bool = false
    var onLongPress: (() -> Void)? = nil
    
    @Environment(\.modelContext) private var modelContext
    @State private var isCompleted = false
    @State private var isAnimating = false
    @State private var showingCardioLog = false
    @State private var showingWorkoutLog = false
    
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    
    private var accentColor: Color {
        if allHabitsComplete { return .atlasAccent }
        return habit.habitType == "custom" ? .atlasAmber : .atlasPrimary
    }
    
    private var streak: Int {
        DataController(modelContext: modelContext).getHabitStreak(habit: habit)
    }
    
    // Label: word 1 on top, word 2 below. Never truncates.
    // "Sauna Session: 15min" → "Sauna" / "Session"
    // "Dead Hang: 30s" → "Dead" / "Hang"
    // "Morning Sunlight" → "Morning" / "Sunlight"
    // "Creatine" → "Creatine" / nil (single word)
    // "Sleep: 7+ hours" → "Sleep" / "7+ hours"
    private var labelLines: (line1: String, line2: String?) {
        let title = habit.title
        
        // Strip everything after colon for the name part, but keep colon value as fallback line2
        let namepart: String
        let colonValue: String?
        if let colonRange = title.range(of: ":") {
            namepart = String(title[title.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            colonValue = String(title[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            namepart = title
            colonValue = nil
        }
        
        // Split the name part into words
        let words = namepart.split(separator: " ").map(String.init)
        
        if words.count >= 2 {
            // Two+ words: first word on top, second word below
            return (words[0], words[1])
        } else if words.count == 1 {
            // Single word: use colon value or habit.details as line2
            let detail = colonValue ?? (habit.details.isEmpty ? nil : habit.details)
            // If detail exists, take just the first word of it to keep it short
            if let d = detail {
                let detailWords = d.split(separator: " ").map(String.init)
                return (words[0], detailWords.first)
            }
            return (words[0], nil)
        }
        
        return (title, nil)
    }
    
    // Icon for uncompleted state — gives the circle visual meaning
    private var habitIcon: String {
        let title = habit.title.lowercased()
        if title.contains("sleep") { return "moon.fill" }
        if title.contains("protein") { return "fork.knife" }
        if title.contains("creatine") || title.contains("supplement") { return "pill.fill" }
        if title.contains("step") || title.contains("walk") { return "figure.walk" }
        if title.contains("meditat") || title.contains("mindful") { return "brain.head.profile" }
        if title.contains("water") || title.contains("hydrat") { return "drop.fill" }
        if title.contains("stretch") || title.contains("mobil") { return "figure.flexibility" }
        if title.contains("journal") || title.contains("gratitude") { return "book.fill" }
        if title.contains("read") { return "book.fill" }
        if title.contains("breath") { return "wind" }
        if title.contains("sauna") || title.contains("cold") || title.contains("ice") { return "thermometer.snowflake" }
        if title.contains("hang") || title.contains("grip") { return "hand.raised.fill" }
        if title.contains("sun") || title.contains("morning") { return "sun.max.fill" }
        if title.contains("vitamin") || title.contains("omega") || title.contains("magnesium") { return "pill.fill" }
        if title.contains("floss") || title.contains("teeth") { return "mouth.fill" }
        if habit.isTrainingHabit {
            switch habit.trainingDayType {
            case "cardio": return "figure.run"
            case "strength": return "dumbbell.fill"
            default: return "moon.fill"
            }
        }
        return "circle.dotted"
    }
    
    var body: some View {
        VStack(spacing: 5) {
            // Circle
            Button(action: handleTap) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isCompleted ? accentColor : accentColor.opacity(0.25),
                            lineWidth: 2.5
                        )
                        .background(
                            Circle().fill(isCompleted ? accentColor.opacity(0.15) : accentColor.opacity(0.04))
                        )
                        .frame(width: circleSize, height: circleSize)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: circleSize * 0.32, weight: .bold))
                            .foregroundColor(accentColor)
                    } else {
                        // Habit-specific icon — makes circles feel actionable
                        Image(systemName: habitIcon)
                            .font(.system(size: circleSize * 0.28, weight: .medium))
                            .foregroundColor(accentColor.opacity(0.45))
                    }
                }
                .scaleEffect(isAnimating ? 1.12 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isToday)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLongPress?()
                    }
            )
            
            // Two-line label — fixed height so all circles align vertically
            VStack(spacing: 1) {
                Text(labelLines.line1)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isCompleted ? .atlasText.opacity(0.5) : .atlasText.opacity(0.7))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                if isCompleted && streak > 1 {
                    // Show streak when complete
                    HStack(spacing: 2) {
                        Circle()
                            .fill(Color.atlasAccent)
                            .frame(width: 4, height: 4)
                        Text("\(streak)d")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.atlasAccent.opacity(0.8))
                    }
                } else if let line2 = labelLines.line2 {
                    // Show target/detail
                    Text(line2)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isCompleted ? .atlasTextMuted.opacity(0.35) : .atlasTextMuted.opacity(0.55))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                } else {
                    // Empty spacer to maintain consistent height
                    Text(" ")
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .frame(width: circleSize + 16, height: 28, alignment: .top) // Fixed height for alignment
        }
        .opacity(isCompleted ? 0.7 : 1.0)
        .onAppear { checkCompletionStatus() }
        .onChange(of: selectedDate) { _, _ in checkCompletionStatus() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HabitStatusChanged"))) { _ in
            checkCompletionStatus()
        }
        .sheet(isPresented: $showingCardioLog) {
            ManualCardioLogView(habit: habit, onComplete: {
                checkCompletionStatus()
                NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            })
        }
        .sheet(isPresented: $showingWorkoutLog) {
            WorkoutLogView(habit: habit, onComplete: {
                checkCompletionStatus()
                NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            })
        }
    }
    
    private func checkCompletionStatus() {
        let newValue = DataController(modelContext: modelContext).isHabitComplete(habit: habit, on: selectedDate)
        if newValue != isCompleted {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted = newValue
            }
        }
    }
    
    private func handleTap() {
        guard isToday else { return }
        
        // Undo: tap a completed circle to uncomplete
        if isCompleted {
            let dc = DataController(modelContext: modelContext)
            dc.toggleHabitCompletion(habit: habit, date: selectedDate)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isCompleted = false }
            NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            return
        }
        
        // Training habits open their respective logs
        if habit.isTrainingHabit {
            switch habit.trainingDayType {
            case "cardio": showingCardioLog = true
            case "strength": showingWorkoutLog = true
            default: completeWithAnimation()
            }
        } else {
            completeWithAnimation()
        }
    }
    
    private func completeWithAnimation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isAnimating = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let dc = DataController(modelContext: modelContext)
            dc.toggleHabitCompletion(habit: habit, date: selectedDate)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted = true
                isAnimating = false
            }
            NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
        }
    }
}

// MARK: - Floating Progress Pill

struct FloatingProgressPill: View {
    let completed: Int
    let total: Int
    let isAllComplete: Bool
    let currentStreak: Int
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    private var accentColor: Color {
        isAllComplete ? .atlasAccent : .atlasPrimary
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.15), lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
            }
            
            if isAllComplete {
                Text("All done")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.atlasAccent)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.atlasAccent)
            } else {
                Text("\(completed) of \(total) today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isAllComplete
                    ? Color.atlasAccent.opacity(0.12)
                    : Color(hex: "#1F1F23").opacity(0.92)
                )
        )
        .overlay(
            Capsule()
                .stroke(accentColor.opacity(isAllComplete ? 0.3 : 0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.4), value: isAllComplete)
    }
}

// MARK: - RoundedCorner Shape (top corners only)

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Pulse Opacity Modifier

struct PulseOpacity: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 0.3)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - SelectedMetric

struct SelectedMetric: Identifiable {
    let id = UUID()
    let type: MetricDetailSheet.MetricType
    let value: Double
    let yesterdayValue: Double?
}

// MARK: - Progress Line View (kept for compatibility)

struct ProgressLineView: View {
    let progress: Double
    var allComplete: Bool = false
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.atlasTextMuted.opacity(0.2)).frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: allComplete
                            ? [.atlasAccent, .atlasAccent.opacity(0.8)]
                            : [.atlasPrimary, .atlasPrimary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
                    .animation(.easeInOut(duration: 0.5), value: allComplete)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Slim Training Card (kept for compatibility if needed elsewhere)

struct SlimTrainingCard: View {
    let habit: Habit; var selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @State private var isCompleted = false
    @State private var showingWorkoutLog = false; @State private var showingCardioLog = false
    
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var workoutIcon: String {
        switch habit.trainingDayType {
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio": return "figure.run"
        default: return "figure.mixed.cardio"
        }
    }
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.atlasPrimary.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: workoutIcon).font(.system(size: 18)).foregroundColor(.atlasPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    if !habit.details.isEmpty {
                        Text(habit.details).font(.system(size: 13)).foregroundColor(.white.opacity(0.5)).lineLimit(1)
                    }
                }
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundColor(.atlasPrimary)
                } else if isToday {
                    Image(systemName: "circle").font(.system(size: 22)).foregroundColor(.atlasPrimary.opacity(0.3))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12).frame(height: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color.atlasPrimary.opacity(0.08), Color.atlasPrimary.opacity(0.03)], startPoint: .leading, endPoint: .trailing)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.atlasPrimary.opacity(0.25), lineWidth: 1))
            .opacity(isCompleted ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle()).disabled(!isToday)
        .onAppear { checkCompletionStatus() }
        .onChange(of: selectedDate) { _, _ in checkCompletionStatus() }
        .sheet(isPresented: $showingCardioLog) {
            ManualCardioLogView(habit: habit, onComplete: { checkCompletionStatus(); NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil) })
        }
        .sheet(isPresented: $showingWorkoutLog) {
            WorkoutLogView(habit: habit, onComplete: { checkCompletionStatus(); NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil) })
        }
    }
    
    private func handleTap() {
        guard isToday, !isCompleted else { return }
        if habit.trainingDayType == "cardio" { showingCardioLog = true }
        else if habit.trainingDayType == "strength" { showingWorkoutLog = true }
        else { let dc = DataController(modelContext: modelContext); dc.toggleHabitCompletion(habit: habit, date: selectedDate); checkCompletionStatus() }
    }
    private func checkCompletionStatus() { isCompleted = DataController(modelContext: modelContext).isHabitComplete(habit: habit, on: selectedDate) }
}

struct PrimaryCTAButton: View {
    let title: String; let icon: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.atlasText)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(.atlasText)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(ZStack { Color.atlasCardDark; LinearGradient(colors: [Color.atlasPrimary.opacity(0.15), Color.atlasPrimary.opacity(0.05)], startPoint: .leading, endPoint: .trailing) })
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1))
            .shadow(color: Color.atlasPrimary.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Habit Reorder Sheet

struct HabitReorderSheet: View {
    let habits: [Habit]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var orderedHabits: [Habit] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                List {
                    ForEach(orderedHabits) { habit in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted.opacity(0.4))
                            
                            Text(habit.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasText)
                            
                            Spacer()
                            
                            if habit.habitType == "custom" {
                                Text("Personal")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.atlasAmber)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.atlasAmber.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparatorTint(Color.white.opacity(0.06))
                    }
                    .onMove { from, to in
                        orderedHabits.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Reorder Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOrder()
                        dismiss()
                    }
                    .foregroundColor(.atlasPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            orderedHabits = habits
        }
    }
    
    private func saveOrder() {
        for (index, habit) in orderedHabits.enumerated() {
            habit.sortOrder = index
        }
        try? modelContext.save()
    }
}

#Preview { TodayView() }