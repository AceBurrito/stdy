import SwiftUI
import SwiftData

struct CardioTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @Query(sort: \HealthMetrics.date, order: .reverse) private var healthMetrics: [HealthMetrics]

    @State private var showingManualLog = false
    @State private var sessionToDelete: CardioSession? = nil
    @State private var showDeleteConfirmation = false
    @State private var selectedCardioSession: CardioSession? = nil

    private var userProfile: UserProfile? {
        profiles.first
    }

    private var latestRHR: Double? {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let startOfYesterday = calendar.startOfDay(for: yesterday)

        if let yesterdayMetrics = healthMetrics.first(where: {
            calendar.isDate($0.date, inSameDayAs: startOfYesterday)
        }) {
            return yesterdayMetrics.restingHeartRate
        }
        return healthMetrics.first?.restingHeartRate
    }

    // MARK: - Weekly Computed Properties

    private var sessionsThisWeek: [CardioSession] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return cardioSessions.filter { $0.date >= weekAgo }
    }

    private var zone2SessionsThisWeek: Int {
        sessionsThisWeek.filter { $0.sessionType == CardioActivityType.zone2.rawValue }.count
    }

    private var zone2MinutesThisWeek: Int {
        // If we have zone data, use actual Z2 seconds. Otherwise fall back to session duration.
        let z2Sessions = sessionsThisWeek.filter { $0.sessionType == CardioActivityType.zone2.rawValue }
        let fromZoneData = sessionsThisWeek.compactMap { $0.zone2Seconds }.reduce(0, +)

        if fromZoneData > 0 {
            return Int(fromZoneData / 60)
        }
        return z2Sessions.reduce(0) { $0 + $1.duration }
    }

    private var vo2MaxSessionsThisWeek: Int {
        sessionsThisWeek.filter { $0.sessionType == CardioActivityType.vo2max.rawValue }.count
    }

    private var totalMinutesThisWeek: Int {
        sessionsThisWeek.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        weeklySummarySection
                        heartRateZonesSection
                        recentSessionsSection
                        Spacer()
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Cardio Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingManualLog = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.atlasPrimary)
                    }
                }
            }
            .navigationDestination(item: $selectedCardioSession) { session in
                CardioSessionDetailView(
                    session: session,
                    userAge: userProfile?.age ?? 30,
                    restingHR: latestRHR
                )
            }
        }
        .sheet(isPresented: $showingManualLog) {
            ManualCardioLogView()
        }
        .confirmationDialog(
            "Delete Session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteCardioSession(session)
                }
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            if let session = sessionToDelete {
                let type = CardioActivityType(rawValue: session.sessionType)?.rawValue ?? session.sessionType
                Text("\(type) session on \(session.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted.")
            }
        }
    }

    // MARK: - Weekly Summary

    private var weeklySummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            HStack(spacing: 12) {
                // Zone 2 Minutes (longevity metric — highlighted)
                VStack(spacing: 4) {
                    Text("\(zone2MinutesThisWeek)")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Text("Z2 Min")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.atlasPrimary.opacity(0.1))
                .cornerRadius(12)

                // VO2 Max Sessions
                VStack(spacing: 4) {
                    Text("\(vo2MaxSessionsThisWeek)")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Text("VO2 Max")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

                // Total Sessions / Minutes
                VStack(spacing: 4) {
                    Text("\(sessionsThisWeek.count)")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.atlasAccent)

                    Text("Sessions")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }

            // Total minutes subtitle
            if totalMinutesThisWeek > 0 {
                Text("\(totalMinutesThisWeek) total minutes")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
            }

            // Weekly zone distribution bar (if we have zone data)
            let weeklyBreakdown = CardioWorkoutAnalyzer.weeklyZoneBreakdown(sessions: sessionsThisWeek)
            if weeklyBreakdown.totalSeconds > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ZONE DISTRIBUTION")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1)

                    MiniZoneBar(breakdown: weeklyBreakdown)
                        .frame(height: 6)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Heart Rate Zones

    private var heartRateZonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("YOUR HEART RATE ZONES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)

                Spacer()

                if latestRHR != nil {
                    Text("Personalized")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Text("Estimated")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            if let age = userProfile?.age {
                let zones = CardioZoneCalculator.calculateZones(age: age, restingHR: latestRHR)

                VStack(spacing: 8) {
                    ZoneRow(zone: zones.zone1, zoneNumber: 1, isTarget: false)
                    ZoneRow(zone: zones.zone2, zoneNumber: 2, isTarget: true)
                    ZoneRow(zone: zones.zone3, zoneNumber: 3, isTarget: false)
                    ZoneRow(zone: zones.zone4, zoneNumber: 4, isTarget: false)
                    ZoneRow(zone: zones.zone5, zoneNumber: 5, isTarget: false)
                }

                if latestRHR != nil {
                    Text("Zones calculated using your resting heart rate (\(Int(latestRHR!)) bpm)")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.top, 8)
                } else {
                    Text("Connect Apple Health for personalized zones based on your resting heart rate")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.top, 8)
                }
            } else {
                Text("Add your age in Profile to calculate personalized zones")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECENT SESSIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            if cardioSessions.isEmpty {
                Text("No sessions logged yet. Start tracking your cardio!")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(cardioSessions.prefix(10)) { session in
                        Button {
                            selectedCardioSession = session
                        } label: {
                            CardioSessionRow(
                                session: session,
                                userAge: userProfile?.age ?? 30,
                                restingHR: latestRHR,
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
    }
}

// MARK: - Delete Cardio Session

extension CardioTrackingView {
    func deleteCardioSession(_ session: CardioSession) {
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete cardio session: \(error)")
        }
        sessionToDelete = nil
    }
}

// MARK: - Zone Row

struct ZoneRow: View {
    let zone: HeartRateZone
    let zoneNumber: Int
    let isTarget: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(zoneNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isTarget ? .atlasBackground : .atlasTextMuted)
                .frame(width: 28, height: 28)
                .background(isTarget ? Color.atlasPrimary : Color.white.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .font(.system(size: 15, weight: isTarget ? .semibold : .regular))
                    .foregroundColor(.atlasText)

                Text(zone.purpose)
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
            }

            Spacer()

            Text("\(zone.min)-\(zone.max) bpm")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isTarget ? .atlasPrimary : .atlasText)
        }
        .padding(12)
        .background(isTarget ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTarget ? Color.atlasPrimary : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Cardio Session Row (Updated with mini zone bar and activity icon)

struct CardioSessionRow: View {
    let session: CardioSession
    let userAge: Int
    let restingHR: Double?
    var onDelete: (() -> Void)? = nil

    private var activityType: CardioActivityType {
        CardioActivityType(rawValue: session.sessionType) ?? .generalCardio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Activity icon
                Image(systemName: activityType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.atlasPrimary.opacity(0.15))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.sessionType)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(session.duration) min")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasText)

                    if let avgHR = session.avgHeartRate {
                        Text("\(Int(avgHR)) bpm")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                }

                if let onDelete = onDelete {
                    Menu {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete Session", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                } else {
                    // Chevron for navigation
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                }
            }

            // Mini zone bar (if zone data available)
            if session.hasZoneData {
                MiniZoneBar(breakdown: session.zoneBreakdown)
            }

            // Coaching feedback or legacy Zone 2 verification
            if let feedback = session.coachingFeedback, !feedback.isEmpty {
                Text(feedback)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .lineLimit(2)
            } else if let avgHR = session.avgHeartRate, session.sessionType == CardioActivityType.zone2.rawValue {
                // Fallback: legacy Zone 2 verification for sessions without zone data
                let zones = CardioZoneCalculator.calculateZones(age: userAge, restingHR: restingHR)
                let verification = CardioZoneCalculator.verifyZone2Session(
                    avgHeartRate: avgHR,
                    targetZone: zones.zone2,
                    duration: session.duration
                )

                HStack(spacing: 8) {
                    Image(systemName: verification.withinZone ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(verification.withinZone ? .green : .orange)
                        .font(.system(size: 12))

                    Text(verification.feedback)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Manual Log View (Updated with analysis flow)

struct ManualCardioLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \HealthMetrics.date, order: .reverse) private var healthMetrics: [HealthMetrics]

    @State private var sessionType = "Zone 2"
    @State private var duration = ""
    @State private var avgHeartRate = ""
    @State private var notes = ""
    @State private var targetHRMin: Int? = nil
    @State private var targetHRMax: Int? = nil
    @State private var cardioProtocol: String? = nil
    @State private var cardioNotes: String? = nil

    // Import flow
    @State private var showingImportPrompt = true
    @State private var showingWorkoutPicker = false
    @State private var showingImportConfirmation = false
    @State private var recentWorkouts: [WorkoutSummary] = []
    @State private var isLoadingWorkouts = false
    @State private var selectedWorkout: WorkoutSummary? = nil
    @State private var analysisResult: WorkoutAnalysisResult? = nil
    @State private var isAnalyzing = false

    var habit: Habit? = nil
    var onComplete: (() -> Void)? = nil

    private var userProfile: UserProfile? {
        profiles.first
    }

    let sessionTypes = CardioActivityType.allCases.map { $0.rawValue }

    private var latestRHR: Double? {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let startOfYesterday = calendar.startOfDay(for: yesterday)

        if let yesterdayMetrics = healthMetrics.first(where: {
            calendar.isDate($0.date, inSameDayAs: startOfYesterday)
        }) {
            return yesterdayMetrics.restingHeartRate
        }
        return healthMetrics.first?.restingHeartRate
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Plan info banner
                        if targetHRMin != nil || cardioProtocol != nil {
                            planInfoBanner
                        }

                        // Session Type
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Session Type")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sessionTypes, id: \.self) { type in
                                        Button(action: { sessionType = type }) {
                                            Text(type)
                                                .font(.system(size: 13, weight: .medium))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(sessionType == type ? Color.atlasPrimary : Color.white.opacity(0.08))
                                                .foregroundColor(sessionType == type ? Color.atlasBackground : Color.atlasText)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Duration (minutes)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.atlasText)

                                Spacer()

                                if let planned = getPlannedDuration(), duration.isEmpty {
                                    Text("Target: \(planned) min")
                                        .font(.system(size: 13))
                                        .foregroundColor(.atlasAccent)
                                }
                            }

                            TextField("e.g., 45", text: $duration)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.atlasText)
                        }

                        // Average Heart Rate
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Average Heart Rate (optional)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.atlasText)

                                Spacer()

                                if let min = targetHRMin, let max = targetHRMax {
                                    Text("Target: \(min)-\(max) bpm")
                                        .font(.system(size: 13))
                                        .foregroundColor(.atlasAccent)
                                }
                            }

                            TextField("e.g., 135", text: $avgHeartRate)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.atlasText)
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes (optional)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasText)

                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.atlasText)
                                .font(.system(size: 15))
                                .scrollContentBackground(.hidden)
                        }

                        Spacer()

                        Button(action: saveManualSession) {
                            Text("Save Session")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.atlasBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(duration.isEmpty ? Color.gray : Color.atlasPrimary)
                                .cornerRadius(12)
                        }
                        .disabled(duration.isEmpty)
                    }
                    .padding(24)
                }

                // Analyzing overlay
                if isAnalyzing {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.atlasPrimary)

                        Text("Analyzing workout...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.atlasText)

                        Text("Fetching heart rate data from Apple Health")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .padding(40)
                    .background(Color.atlasCardDark)
                    .cornerRadius(20)
                }
            }
            .navigationTitle("Log Cardio Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasAccent)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingWorkoutPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Import")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .onAppear {
                loadFromTrainingPlan()
            }
            .alert("Import from Apple Health?", isPresented: $showingImportPrompt) {
                Button("Import Workout") {
                    showingWorkoutPicker = true
                }
                Button("Enter Manually", role: .cancel) { }
            } message: {
                Text("Would you like to import a recent workout from Apple Health with full zone analysis?")
            }
            .sheet(isPresented: $showingWorkoutPicker) {
                WorkoutPickerSheet(
                    workouts: $recentWorkouts,
                    isLoading: $isLoadingWorkouts,
                    onSelect: { workout in
                        showingWorkoutPicker = false
                        analyzeAndConfirm(workout)
                    }
                )
                .onAppear {
                    loadRecentWorkouts()
                }
            }
            .sheet(isPresented: $showingImportConfirmation) {
                if let workout = selectedWorkout, let result = analysisResult {
                    CardioImportConfirmationView(
                        workout: workout,
                        analysisResult: result,
                        habit: habit,
                        onComplete: {
                            onComplete?()
                            dismiss()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Plan Info Banner

    private var planInfoBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.atlasAccent)

                Text("FROM YOUR TRAINING PLAN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(1.5)
            }

            if let proto = cardioProtocol {
                Text(proto)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
            }

            if let notes = cardioNotes {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.atlasPrimary.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Load Recent Workouts

    private func loadRecentWorkouts() {
        isLoadingWorkouts = true
        Task {
            let workouts = await HealthKitManager.shared.fetchRecentWorkouts()
            await MainActor.run {
                // Filter out already-imported workouts
                recentWorkouts = workouts.filter { workout in
                    !HealthKitManager.shared.isWorkoutAlreadyImported(workout.hkWorkout, modelContext: modelContext)
                }
                isLoadingWorkouts = false
            }
        }
    }

    // MARK: - Analyze and Confirm

    private func analyzeAndConfirm(_ workout: WorkoutSummary) {
        selectedWorkout = workout
        isAnalyzing = true

        Task {
            let age = userProfile?.age ?? 30
            let result = await HealthKitManager.shared.analyzeWorkout(
                workout.hkWorkout,
                age: age,
                restingHR: latestRHR
            )

            await MainActor.run {
                analysisResult = result
                isAnalyzing = false
                showingImportConfirmation = true
            }
        }
    }

    // MARK: - Load from Training Plan

    private func loadFromTrainingPlan() {
        guard let habit = habit,
              let dayOfWeek = habit.dayOfWeek else {
            return
        }

        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let program = (try? modelContext.fetch(descriptor))?.first else { return }
        let workoutDays = program.isEventPlan
            ? (program.workoutWeeks.first { $0.weekNumber == (profiles.first?.currentEventWeek ?? 1) }?.days ?? [])
            : program.workoutDays
        guard let plannedDay = workoutDays.first(where: { $0.dayOfWeek == dayOfWeek }) else { return }

        guard plannedDay.dayType == "cardio" else { return }

        if let cardioType = plannedDay.cardioType {
            switch cardioType.lowercased() {
            case "zone2": sessionType = "Zone 2"
            case "vo2max", "hiit": sessionType = "VO2 Max"
            default: sessionType = "Zone 2"
            }
        }

        targetHRMin = plannedDay.targetHRMin
        targetHRMax = plannedDay.targetHRMax
        cardioProtocol = plannedDay.cardioProtocol
        cardioNotes = plannedDay.cardioNotes
    }

    private func getPlannedDuration() -> Int? {
        guard let habit = habit,
            let dayOfWeek = habit.dayOfWeek else { return nil }
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let program = (try? modelContext.fetch(descriptor))?.first else { return nil }
        let workoutDays = program.isEventPlan
            ? (program.workoutWeeks.first { $0.weekNumber == (profiles.first?.currentEventWeek ?? 1) }?.days ?? [])
            : program.workoutDays
        return workoutDays.first(where: { $0.dayOfWeek == dayOfWeek })?.cardioDuration
    }

    // MARK: - Save Manual Session

    private func saveManualSession() {
        guard let durationValue = Int(duration) else { return }

        let session = CardioSession(date: Date(), duration: durationValue, sessionType: sessionType)
        session.avgHeartRate = Double(avgHeartRate)
        session.notes = notes.isEmpty ? nil : notes
        session.userProfile = userProfile

        // Check if Zone 2 session was above zone
        if sessionType == CardioActivityType.zone2.rawValue,
           let avgHR = Double(avgHeartRate),
           let age = userProfile?.age {
            let zones = CardioZoneCalculator.calculateZones(age: age, restingHR: latestRHR)
            session.wasAboveZone2 = Int(avgHR) > zones.zone2.max
        }

        modelContext.insert(session)

        if let habit = habit {
            let dataController = DataController(modelContext: modelContext)
            dataController.markHabitComplete(habit)
        }

        do {
            try modelContext.save()
            print("✅ Manual cardio session: \(sessionType) - \(durationValue) min")
            onComplete?()
            dismiss()
        } catch {
            print("❌ Failed to save session: \(error)")
        }
    }
}

// MARK: - Workout Picker Sheet

struct WorkoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workouts: [WorkoutSummary]
    @Binding var isLoading: Bool
    let onSelect: (WorkoutSummary) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.atlasPrimary)

                        Text("Loading workouts...")
                            .font(.system(size: 15))
                            .foregroundColor(.atlasTextMuted)
                    }
                } else if workouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.atlasTextMuted)

                        Text("No Recent Workouts")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.atlasText)

                        Text("No new workouts found in Apple Health from the last 3 days.")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            Text("Select a workout to analyze and import")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                                .padding(.top, 16)

                            ForEach(workouts) { workout in
                                WorkoutRow(workout: workout) {
                                    onSelect(workout)
                                }
                            }

                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Apple Health Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
        }
    }
}

// MARK: - Workout Row

struct WorkoutRow: View {
    let workout: WorkoutSummary
    let onTap: () -> Void
    @Environment(\.unitFormatter) private var unitFormatter

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: iconForWorkout(workout.workoutType))
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.workoutType)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasText)

                        Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    }

                    Spacer()

                    Text("\(Int(workout.duration / 60)) min")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasAccent)
                }

                HStack(spacing: 16) {
                    if let avgHR = workout.avgHeartRate {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            Text("\(Int(avgHR)) avg")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }

                    if let maxHR = workout.maxHeartRate {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("\(Int(maxHR)) max")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }

                    if let distance = workout.distance {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 12))
                                .foregroundColor(.atlasAccent)
                            Text(unitFormatter.displayDistance(distance))
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }

                    if let calories = workout.calories {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("\(Int(calories)) cal")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func iconForWorkout(_ type: String) -> String {
        switch type {
        case "Running": return "figure.run"
        case "Cycling": return "figure.outdoor.cycle"
        case "Walking": return "figure.walk"
        case "Swimming": return "figure.pool.swim"
        case "Rowing": return "figure.rower"
        case "Elliptical": return "figure.elliptical"
        case "Hiking": return "figure.hiking"
        case "HIIT": return "bolt.heart.fill"
        case "Strength Training": return "figure.strengthtraining.traditional"
        default: return "heart.fill"
        }
    }
}

#Preview {
    CardioTrackingView()
}