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
        tabBarAppearance.shadowColor = UIColor(Color.steadyHairline)

        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.atlasTextMuted)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.atlasTextMuted)]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.atlasPrimary)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.atlasPrimary)]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().overrideUserInterfaceStyle = .dark

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Color.atlasBackground)
        navBarAppearance.shadowColor = .clear
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.atlasText)]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.atlasText)]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().overrideUserInterfaceStyle = .dark
    }

    // MARK: - CloudKit-backed Model Container
    // All SwiftData models sync automatically to iCloud via CloudKit.
    // If iCloud is disabled on the device, SwiftData falls back to local-only storage.
    //
    // Steady pivot (Nov 2026): Habit, Pace, longevity, nutrition, event and
    // check-in models were removed from the schema. SwiftData's lightweight
    // migration drops their tables; workouts, PRs, body comp, photos and
    // programs carry forward untouched.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            HealthMetrics.self,
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            CardioSession.self,
            TrainingProgram.self,
            PersonalRecord.self,
            BodyCompEntry.self,
            ProgressPhoto.self,
            PlannedWorkoutDay.self,
            PlannedExercise.self,
            PlannedWorkoutWeek.self,
            WorkoutRoutine.self,
            RoutineExercise.self,
            CustomExercise.self,
        ])

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
        case "strength":
            router.selectedTab = AppTab.strength.rawValue
        case "body":
            router.selectedTab = AppTab.body.rawValue
        case "training":
            router.selectedTab = AppTab.more.rawValue
        default:
            // "today" and legacy Atlas links ("checkin", "habits")
            router.selectedTab = AppTab.today.rawValue
        }
    }
}

// MARK: - Root View (Handles Onboarding vs Main App)
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Query private var profiles: [UserProfile]
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

                        // Steady pivot: clear Atlas-era reminders and widget keys
                        NotificationManager.shared.removeLegacyReminders()
                        WidgetDataWriter.shared.removeLegacyKeys()

                        // BUG-014 pattern: HealthKitManager gates this with isSyncing + 30s interval
                        await HealthKitManager.shared.syncMetricsWithSmartRefresh(modelContext: modelContext)

                        // Phase 3 fix: migrate any raw exerciseID strings saved as exercise names
                        PlanCommitter.migrateRawExerciseIDs(modelContext: modelContext)

                        // Routine system: migrate existing day-owned exercises to shared routines
                        PlanCommitter.migrateToRoutines(modelContext: modelContext)

                        #if DEBUG
                        PlanCommitter.validateTemplateCatalog()
                        #endif

                        // Widget: refresh once recovery inputs are synced
                        syncWidgetData()
                    }
                    .onAppear {
                        HealthKitManager.shared.setupHealthKitObservers(modelContext: modelContext)
                        refreshTimer = HealthKitManager.shared.startPeriodicRefresh(modelContext: modelContext)
                        syncWidgetData()
                    }
                    .onDisappear {
                        refreshTimer?.invalidate()
                        refreshTimer = nil
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // BUG-015: Clean up stale Live Activities on every foreground entry
                        WorkoutLiveActivityManager.shared.cleanupStaleActivities()

                        Task {
                            await HealthKitManager.shared.syncMetricsWithSmartRefresh(modelContext: modelContext)
                            syncWidgetData()
                        }

                        syncWidgetData()
                    }
            } else {
                NewOnboardingFlow()
                    .environment(\.unitFormatter, unitFormatter)
            }
        }
    }

    // MARK: - Widget Data Sync

    /// Full widget refresh — launch, foreground, and after HealthKit sync.
    private func syncWidgetData() {
        guard userProfile != nil else { return }
        WidgetSync.refresh(modelContext: modelContext, unitFormatter: unitFormatter)
    }
}
