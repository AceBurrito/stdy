import SwiftUI
import SwiftData

@main
struct havenApp: App {
    
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var router = NavigationRouter()
    
    init() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                window.overrideUserInterfaceStyle = .dark
            }
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.atlasBackground)
        
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.atlasPrimary)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.atlasPrimary)]
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().overrideUserInterfaceStyle = .dark
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Color.atlasBackground)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().overrideUserInterfaceStyle = .dark
    }
    
    // MARK: - CloudKit-backed Model Container
    // All SwiftData models sync automatically to iCloud via CloudKit.
    // If iCloud is disabled on the device, SwiftData falls back to local-only storage.
    // ProgressPhoto records are included in the schema but photoData is excluded from
    // CloudKit sync via the model configuration (handled by SwiftData automatically for
    // Data properties exceeding CloudKit's inline limit — they are stored as CKAssets).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            UserCapabilityAssessment.self,
            EventTemplate.self,
            EventMasterPlan.self,
            EventWeeklyCheckIn.self,
            DailyCheckIn.self,
            HealthMetrics.self,
            Habit.self,
            HabitCompletion.self,
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            CardioSession.self,
            WeeklyCheckIn.self,
            TrainingProgram.self,
            PersonalRecord.self,
            LongevityPlan.self,
            BodyCompEntry.self,
            ProgressPhoto.self,
            ProteinEntry.self,
            PlannedWorkoutDay.self,
            PlannedExercise.self,
            CoachingEntry.self,
            PlannedWorkoutWeek.self,
            LongevityTierHistory.self,
            Lesson.self,
            LessonProgress.self,
            BiologicalPaceScore.self,
            ComponentMilestone.self,
            WeeklyCoachingResult.self,
            MorningBriefEntry.self,
            WorkoutRoutine.self,
            RoutineExercise.self,
            CustomExercise.self,
        ])
        
        // CloudKit-backed configuration.
        // .automatic uses the user's default iCloud account and falls back to
        // local-only storage gracefully when iCloud is unavailable.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ Database initialized (CloudKit-backed)")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environmentObject(purchaseManager)
                .environment(router)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "atlas" else { return }
        
        switch url.host {
        case "today":
            router.selectedTab = 0
        case "checkin":
            router.selectedTab = 0
            // Small delay to let the tab switch settle before presenting the sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                router.showWeeklyCheckIn = true
            }
        case "habits":
            router.selectedTab = 0
        case "training":
            router.selectedTab = 1
        default:
            router.selectedTab = 0
        }
    }
}

// MARK: - Root View (Handles Onboarding vs Main App)
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Habit> { $0.isActive == true }) private var habits: [Habit]
    @State private var refreshTimer: Timer?
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    // Derive the UnitFormatter from the stored user preference so every view
    // in the hierarchy automatically uses the correct unit system.
    private var unitFormatter: UnitFormatter {
        UnitFormatter(system: userProfile?.effectiveUnitSystem ?? UnitSystem.deviceDefault)
    }
    
    var body: some View {
        Group {
            if let profile = userProfile, profile.onboardingComplete {
                ContentView()
                    .environment(\.unitFormatter, unitFormatter)
                    .task {
                        // BUG-015: Clean up any stale Live Activities from previous sessions
                        WorkoutLiveActivityManager.shared.cleanupStaleActivities()
                        
                        await HealthKitManager.shared.syncMetricsWithSmartRefresh(modelContext: modelContext)
                        await TemplateManager.loadTemplatesFromBundle(modelContext: modelContext)
                        
                        // Phase 3 fix: migrate any raw exerciseID strings saved as exercise names
                        PlanCommitter.migrateRawExerciseIDs(modelContext: modelContext)
                        
                        // Routine system: migrate existing day-owned exercises to shared routines
                        PlanCommitter.migrateToRoutines(modelContext: modelContext)
                        
                        #if DEBUG
                        PlanCommitter.validateTemplateCatalog()
                        #endif
                    }
                    .onAppear {
                        checkEventWeekAndRefreshHabits()
                        scheduleDailyNotifications()
                        HealthKitManager.shared.setupHealthKitObservers(modelContext: modelContext)
                        refreshTimer = HealthKitManager.shared.startPeriodicRefresh(modelContext: modelContext)
                        
                        // Widget: full data sync on appear
                        syncWidgetData()
                    }
                    .onDisappear {
                        refreshTimer?.invalidate()
                        refreshTimer = nil
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HabitStatusChanged"))) { _ in
                        scheduleDailyNotifications()
                        syncWidgetHabits()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // BUG-015: Clean up stale Live Activities on every foreground entry
                        WorkoutLiveActivityManager.shared.cleanupStaleActivities()
                        
                        Task {
                            await HealthKitManager.shared.syncMetricsWithSmartRefresh(modelContext: modelContext)
                        }
                        
                        // Widget: full data sync on foreground
                        syncWidgetData()
                    }
            } else {
                NewOnboardingFlow()
                    .environment(\.unitFormatter, unitFormatter)
                    .task {
                        await TemplateManager.loadTemplatesFromBundle(modelContext: modelContext)
                    }
            }
        }
    }

    // MARK: - Check Event Week and Refresh Habits
    private func checkEventWeekAndRefreshHabits() {
        guard let profile = userProfile else { return }
        
        if profile.trainingMode == "event",
        let lastAdvance = profile.lastEventWeekAdvanceDate {
            let calendar = Calendar.current
            let daysSinceLastAdvance = calendar.dateComponents([.day], from: lastAdvance, to: Date()).day ?? 0
            if daysSinceLastAdvance >= 7 {
                let weeksToAdvance = daysSinceLastAdvance / 7
                let totalWeeks = (try? modelContext.fetch(FetchDescriptor<TrainingProgram>(predicate: #Predicate { $0.isActive == true })).first?.totalWeeks) ?? 52
                let newWeek = min(profile.currentEventWeek + weeksToAdvance, totalWeeks)
                if newWeek != profile.currentEventWeek {
                    profile.currentEventWeek = newWeek
                    profile.lastEventWeekAdvanceDate = calendar.date(byAdding: .day, value: weeksToAdvance * 7, to: lastAdvance)
                    try? modelContext.save()
                }
            }
        }
        
        TrainingHabitManager.checkAndRefreshHabitsIfNeeded(profile: profile, modelContext: modelContext)
    }
    
    // MARK: - Schedule Daily Notifications
    private func scheduleDailyNotifications() {
        let dataController = DataController(modelContext: modelContext)
        
        let today = Date()
        let todaysHabits = habits.filter { habit in
            habit.habitType == "non_negotiable" && habit.appliesTo(date: today)
        }
        
        let incompleteCount = todaysHabits.filter { habit in
            !dataController.isHabitComplete(habit: habit, on: today)
        }.count
        
        let currentStreak = dataController.getCurrentStreak()
        
        if incompleteCount > 0 {
            NotificationManager.shared.scheduleEveningReminder(incompleteCount: incompleteCount)
            NotificationManager.shared.scheduleStreakAtRiskReminder(incompleteCount: incompleteCount, currentStreak: currentStreak)
        } else {
            NotificationManager.shared.cancelDailyReminders()
        }
        
        NotificationManager.shared.printPendingNotifications()
    }
    
    // MARK: - Widget Data Sync
    
    /// Full widget data refresh — call on app launch, foreground, and midnight rollover.
    private func syncWidgetData() {
        guard let profile = userProfile else { return }
        let dc = DataController(modelContext: modelContext)
        let today = Date()
        
        // Habits (non-training only, matching TodayView logic)
        let nonTrainingHabits = habits.filter {
            ($0.habitType == "non_negotiable" && !$0.isTrainingHabit && $0.appliesTo(date: today))
            || ($0.habitType == "custom" && $0.isActive)
        }.sorted { $0.sortOrder < $1.sortOrder }
        
        let habitNames = nonTrainingHabits.map { $0.title }
        let habitStates = nonTrainingHabits.map { dc.isHabitComplete(habit: $0, on: today) }
        let habitsCompleted = habitStates.filter { $0 }.count
        
        // Training
        let todayDOW = Calendar.current.component(.weekday, from: today) - 1
        let activeProgram = (try? modelContext.fetch(
            FetchDescriptor<TrainingProgram>(predicate: #Predicate { $0.isActive == true })
        ))?.first
        
        let eventProgram = activeProgram?.isEventPlan == true ? activeProgram : nil
        let todaysWorkout: PlannedWorkoutDay? = {
            if let ep = eventProgram, let currentWeek = ep.currentWeekWorkouts {
                return currentWeek.days.first { $0.dayOfWeek == todayDOW }
            }
            return activeProgram?.workoutDays.first { $0.dayOfWeek == todayDOW }
        }()
        
        let workoutName = todaysWorkout?.dayName ?? "Rest Day"
        let workoutType = todaysWorkout?.dayType ?? "rest"
        let isRestDay = todaysWorkout == nil || workoutType == "rest"
        let exerciseCount = todaysWorkout?.exercises.count ?? 0
        
        // Training habit completion
        let trainingHabits = habits.filter { $0.habitType == "non_negotiable" && $0.isTrainingHabit && $0.appliesTo(date: today) }
        let workoutCompleted = trainingHabits.first.map { dc.isHabitComplete(habit: $0, on: today) } ?? false
        
        // Streak
        let streak = dc.getCurrentStreak()
        
        // Pace change detection
        let sharedDefaults = UserDefaults(suiteName: "group.com.atlas.workouts")
        let lastSeenPace = sharedDefaults?.double(forKey: "widget_lastSeenPaceValue") ?? 0
        let currentPace = profile.latestPaceValue ?? 0
        let paceChanged = abs(currentPace - lastSeenPace) > 0.001 && lastSeenPace > 0
        let paceDirection = currentPace < lastSeenPace ? "improved" : "update"
        
        // Check-in
        let checkInAvailable = isWeeklyCheckInDue(profile: profile)
        let checkInCompleted: Bool = {
            guard let lastCheckIn = profile.lastCheckInDate else { return false }
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: today)
            let daysFromSunday = weekday - 1
            guard let windowStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: calendar.startOfDay(for: today)) else { return false }
            return lastCheckIn >= windowStart
        }()
        
        // Day count
        let dayCount: Int = {
            guard let activationDate = profile.planActivationDate else { return 1 }
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: activationDate), to: Calendar.current.startOfDay(for: today)).day ?? 0
            return max(1, days + 1)
        }()
        
        WidgetDataWriter.shared.updateAll(
            paceChanged: paceChanged,
            paceDirection: paceDirection,
            checkInAvailable: checkInAvailable,
            checkInCompleted: checkInCompleted,
            streakCount: streak,
            habitsTotal: nonTrainingHabits.count,
            habitsCompleted: habitsCompleted,
            habitNames: habitNames,
            habitStates: habitStates,
            workoutName: workoutName,
            workoutExerciseCount: exerciseCount,
            workoutType: workoutType,
            isRestDay: isRestDay,
            workoutCompleted: workoutCompleted,
            dayCount: dayCount
        )
    }
    
    /// Partial widget sync — habits only. Called on HabitStatusChanged notification.
    private func syncWidgetHabits() {
        let dc = DataController(modelContext: modelContext)
        let today = Date()
        
        let nonTrainingHabits = habits.filter {
            ($0.habitType == "non_negotiable" && !$0.isTrainingHabit && $0.appliesTo(date: today))
            || ($0.habitType == "custom" && $0.isActive)
        }.sorted { $0.sortOrder < $1.sortOrder }
        
        let habitNames = nonTrainingHabits.map { $0.title }
        let habitStates = nonTrainingHabits.map { dc.isHabitComplete(habit: $0, on: today) }
        let habitsCompleted = habitStates.filter { $0 }.count
        let streak = dc.getCurrentStreak()
        
        WidgetDataWriter.shared.updateHabits(
            completed: habitsCompleted,
            total: nonTrainingHabits.count,
            names: habitNames,
            states: habitStates,
            streak: streak
        )
    }
    
    /// Duplicated check-in logic (matches TodayView.isWeeklyCheckInDue)
    private func isWeeklyCheckInDue(profile: UserProfile) -> Bool {
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
}