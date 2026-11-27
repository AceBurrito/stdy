import SwiftUI
import SwiftData
import PhotosUI

// Sprint 1B: AI Teardown
// Replaced: ClaudeAPIService call → WeeklyCoachingEngine.generateAnalysis()
// Replaced: AI text analysis view → WeeklyCoachingResultsView (card-based)
// Removed: SubscriptionManager, CoachingChatView, isPro gating
// Kept: Deload detection, protocol recommendation, progressive unlock, all check-in steps

struct EnhancedWeeklyCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \HealthMetrics.date, order: .reverse) private var allMetrics: [HealthMetrics]
    @Query private var allHabits: [Habit]
    @Query(sort: \WeeklyCheckIn.date, order: .reverse) private var checkIns: [WeeklyCheckIn]
    @Query(sort: \BiologicalPaceScore.date, order: .reverse) private var paceScores: [BiologicalPaceScore]
    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true }) private var activePrograms: [TrainingProgram]
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var bodyCompEntries: [BodyCompEntry]

    
    @State private var currentStep = 0
    @State private var energyRating = 3
    @State private var stressRating = 3
    @State private var recoveryRating = 3
    @State private var challengesText = ""
    @State private var winsText = ""
    @State private var showAnalysis = false
    @State private var generatedAnalysis: WeeklyAnalysis?
    @State private var protocolRecommendation: ProtocolRecommendation?
    @State private var isApplyingRecommendation = false
    @State private var showRegressionAlert = false
    @State private var showMovementCelebration = false
    @State private var showProgressiveUnlock = false
    @State private var progressiveUnlockIntervention: Intervention?

    @State private var weightText = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var capturedPhotos: [UIImage] = []
    @State private var showingCamera = false

    // Automated data states
    @State private var strengthSummary: WeeklyStrengthAnalyzer.WeeklyStrengthSummary?
    @State private var cardioSummary: WeeklyCardioAnalyzer.WeeklyCardioSummary?
    @State private var selectedChips: Set<String> = []

    // Health metric averages (this week / last week)
    @State private var sleepAvgThisWeek: Double?
    @State private var sleepAvgLastWeek: Double?
    @State private var hrvAvgThisWeek: Double?
    @State private var hrvAvgLastWeek: Double?
    @State private var rhrAvgThisWeek: Double?
    @State private var rhrAvgLastWeek: Double?
    @State private var stepsAvgThisWeek: Double?
    @State private var stepsAvgLastWeek: Double?
    @State private var vo2MaxThisWeek: Double?
    @State private var vo2MaxLastWeek: Double?
    
    // Deload detection state
    @State private var deloadRecommendation: DeloadDetector.DeloadRecommendation?

    private let contextChips = [
        "🧳 Traveled",
        "🤒 Was sick",
        "😰 High stress",
        "🎉 Social events",
        "😴 Poor sleep",
        "💪 Felt strong",
        "🏃 Extra active",
        "🍕 Diet was off",
        "📅 Schedule disrupted"
    ]
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var recentMetrics: [HealthMetrics] {
        Array(allMetrics.prefix(7))
    }

    private var previousWeight: Double? {
        bodyCompEntries.first?.weight
    }

    private var previousWeightDate: Date? {
        bodyCompEntries.first?.date
    }

    private var weightDelta: Double? {
        guard let prevWeight = previousWeight, let currentWeight = Double(weightText), currentWeight > 0 else { return nil }
        return currentWeight - prevWeight
    }

    private var daysSinceLastWeight: Int {
        previousWeightDate.map {
            Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
        } ?? 0
    }
        
    // Event training computed properties
    
    private var isEventTraining: Bool {
        userProfile?.isTrainingForEvent ?? false
    }
    
    private var activeEventProgram: TrainingProgram? {
        activePrograms.first { $0.isEventPlan }
    }
    
    private var currentEventWeekData: PlannedWorkoutWeek? {
        guard let week = userProfile?.currentEventWeek else { return nil }
        return activeEventProgram?.workoutWeeks.first { $0.weekNumber == week }
    }
    
    // MARK: - Computed Properties
    private var habitCompletionRate: Double {
        let dataController = DataController(modelContext: modelContext)
        return dataController.getWeeklyHabitCompletionRate(profile: userProfile)
    }
    
    private var currentStreak: Int {
        let dataController = DataController(modelContext: modelContext)
        return dataController.getCurrentStreak()
    }
    
    private var avgSleep: Double {
        let sleepValues = recentMetrics.compactMap { $0.sleepDuration }
        guard !sleepValues.isEmpty else { return 0 }
        return sleepValues.reduce(0, +) / Double(sleepValues.count)
    }
    
    private var avgHRV: Double {
        let hrvValues = recentMetrics.compactMap { $0.heartRateVariability }
        guard !hrvValues.isEmpty else { return 0 }
        return hrvValues.reduce(0, +) / Double(hrvValues.count)
    }
    
    private var avgRHR: Double {
        let rhrValues = recentMetrics.compactMap { $0.restingHeartRate }
        guard !rhrValues.isEmpty else { return 0 }
        return rhrValues.reduce(0, +) / Double(rhrValues.count)
    }

    // MARK: - Step Index Mapping

    private var orderedSteps: [StepKind] {
        var steps: [StepKind] = [.dataSummary]
        if strengthSummary?.hasAnyWorkouts == true { steps.append(.strength) }
        if cardioSummary?.hasCardioThisWeek == true || cardioSummary?.hasCardioLastWeek == true { steps.append(.cardio) }
        steps.append(contentsOf: [.context, .weightPhoto, .review])
        return steps
    }

    enum StepKind {
        case dataSummary, strength, cardio, context, weightPhoto, review
    }

    private var currentStepKind: StepKind {
        let steps = orderedSteps
        guard currentStep >= 0 && currentStep < steps.count else { return .dataSummary }
        return steps[currentStep]
    }

    private var isLastStep: Bool {
        currentStep == orderedSteps.count - 1
    }

    // MARK: - Habit Adherence

    private var habitAdherenceData: (completed: Int, total: Int, breakdown: [(name: String, completed: Int, total: Int)]) {
        let dataController = DataController(modelContext: modelContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let activeHabits = allHabits.filter { $0.isActive && $0.habitType == "non_negotiable" && !$0.isTrainingHabit }

        var totalCompleted = 0
        var totalPossible = 0
        var breakdown: [(name: String, completed: Int, total: Int)] = []

        for habit in activeHabits {
            var habitCompleted = 0
            var habitTotal = 0

            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                if habit.appliesTo(date: date) {
                    habitTotal += 1
                    if dataController.isHabitComplete(habit: habit, on: date) {
                        habitCompleted += 1
                    }
                }
            }

            totalCompleted += habitCompleted
            totalPossible += habitTotal
            breakdown.append((name: habit.title, completed: habitCompleted, total: habitTotal))
        }

        return (totalCompleted, totalPossible, breakdown)
    }

    private var trainingAdherence: (completed: Int, prescribed: Int) {
        let dataController = DataController(modelContext: modelContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let trainingHabits = allHabits.filter { $0.isActive && $0.isTrainingHabit }

        var completed = 0
        var prescribed = 0

        for habit in trainingHabits {
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                if habit.appliesTo(date: date) {
                    prescribed += 1
                    if dataController.isHabitComplete(habit: habit, on: date) {
                        completed += 1
                    }
                }
            }
        }

        return (completed, prescribed)
    }

    // MARK: - Health Data Loader

    private func loadHealthData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let thisWeekMetrics = allMetrics.filter {
            let days = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 99
            return days >= 0 && days < 7
        }

        let lastWeekMetrics = allMetrics.filter {
            let days = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 99
            return days >= 7 && days < 14
        }

        func avg(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        sleepAvgThisWeek = avg(thisWeekMetrics.compactMap { $0.sleepDuration })
        sleepAvgLastWeek = avg(lastWeekMetrics.compactMap { $0.sleepDuration })
        hrvAvgThisWeek = avg(thisWeekMetrics.compactMap { $0.heartRateVariability })
        hrvAvgLastWeek = avg(lastWeekMetrics.compactMap { $0.heartRateVariability })
        rhrAvgThisWeek = avg(thisWeekMetrics.compactMap { $0.restingHeartRate })
        rhrAvgLastWeek = avg(lastWeekMetrics.compactMap { $0.restingHeartRate })
        stepsAvgThisWeek = avg(thisWeekMetrics.compactMap { $0.stepCount })
        stepsAvgLastWeek = avg(lastWeekMetrics.compactMap { $0.stepCount })
        vo2MaxThisWeek = avg(thisWeekMetrics.compactMap { $0.vo2Max })
        vo2MaxLastWeek = avg(lastWeekMetrics.compactMap { $0.vo2Max })
    }

    private func loadAnalyzerData() {
        strengthSummary = WeeklyStrengthAnalyzer.analyze(modelContext: modelContext)
        cardioSummary = WeeklyCardioAnalyzer.analyze(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                if let lastCheckIn = userProfile?.lastCheckInDate,
                   Calendar.current.isDate(lastCheckIn, inSameDayAs: Date()) {
                    alreadyCheckedInView
                } else if showAnalysis {
                    analysisView
                } else {
                    checkInFlow
                }
            }
            .navigationTitle("Week \(userProfile?.currentWeek ?? 1) Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasAccent)
                }
            }
        }
        .overlay {
            if showRegressionAlert, let alert = protocolRecommendation?.regressionAlert {
                RegressionInterventionView(
                    alert: alert,
                    onDismiss: { showRegressionAlert = false }
                )
            }
        }
        .overlay {
            if showMovementCelebration, isMovementPlanUpgrade(protocolRecommendation ?? ProtocolRecommendation(action: .maintain, reasoning: "", changes: nil, additions: nil, encouragement: nil, sleepWarning: nil, regressionAlert: nil)) {
                MovementUpgradeCelebrationView(
                    weeksCompleted: getWeeksOnMovementPlan(),
                    avgAdherence: getMovementPlanAdherence(),
                    daysPerWeek: userProfile?.trainingDaysPerWeek ?? 3,
                    onUpgrade: {
                        showMovementCelebration = false
                        upgradeToTrainingPlan()
                    },
                    onDecline: {
                        showMovementCelebration = false
                        protocolRecommendation = nil
                    }
                )
            }
        }
        .overlay {
            if showProgressiveUnlock, let intervention = progressiveUnlockIntervention {
                progressiveUnlockModal(intervention: intervention)
            }
        }

        .onAppear {
            if let lastWeight = previousWeight {
                weightText = String(format: "%.1f", lastWeight)
            } else if let profileWeight = userProfile?.weight {
                weightText = String(format: "%.1f", profileWeight)
            }
            loadHealthData()
            loadAnalyzerData()
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data) {
                        await MainActor.run {
                            capturedPhotos.append(image)
                        }
                    }
                }
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CheckInCameraView { image in
                if let image = image {
                    capturedPhotos.append(image)
                }
            }
        }
    }
    
    private var alreadyCheckedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.atlasPrimary)
            
            Text("Already Checked In Today")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text("You completed your weekly check-in earlier today. Come back next week!")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { dismiss() }) {
                Text("Got it")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasPrimary)
            }
        }
    }
    
    // MARK: - Check-In Flow
    private var checkInFlow: some View {
        VStack(spacing: 0) {
            progressIndicator

            TabView(selection: $currentStep) {
                ForEach(Array(orderedSteps.enumerated()), id: \.offset) { index, step in
                    ScrollView {
                        VStack(spacing: 24) {
                            stepContent(for: step)
                            navigationButtons
                        }
                        .padding(24)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .onAppear {
            loadHealthData()
            loadAnalyzerData()
        }
    }

    @ViewBuilder
    private func stepContent(for step: StepKind) -> some View {
        switch step {
        case .dataSummary:
            dataSummaryStep
        case .strength:
            if let summary = strengthSummary {
                StrengthProgressionView(summary: summary)
            }
        case .cardio:
            if let summary = cardioSummary {
                CardioProgressionView(summary: summary)
            }
        case .context:
            contextInputStep
        case .weightPhoto:
            weightAndPhotosStep
        case .review:
            reviewStep
        }
    }

    // MARK: - Step 0: Automated Data Summary
    private var dataSummaryStep: some View {
        let latestPace = paceScores.first
        let paceStart: Double? = {
            let calendar = Calendar.current
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return nil }
            return paceScores.first { $0.date <= weekAgo }?.paceValue
        }()

        return WeeklyDataSummaryView(
            paceStart: paceStart,
            paceEnd: latestPace?.paceValue,
            paceTrend: latestPace?.trendDirection,
            strongestComponent: latestPace?.strongestComponent,
            weakestComponent: latestPace?.weakestComponent,
            sleepAvg: sleepAvgThisWeek,
            prevSleepAvg: sleepAvgLastWeek,
            hrvAvg: hrvAvgThisWeek,
            prevHrvAvg: hrvAvgLastWeek,
            rhrAvg: rhrAvgThisWeek,
            prevRhrAvg: rhrAvgLastWeek,
            stepsAvg: stepsAvgThisWeek,
            prevStepsAvg: stepsAvgLastWeek,
            vo2Max: vo2MaxThisWeek,
            prevVo2Max: vo2MaxLastWeek,
            habitsCompleted: habitAdherenceData.completed,
            habitsTotal: habitAdherenceData.total,
            sessionsCompleted: trainingAdherence.completed,
            sessionsPrescribed: trainingAdherence.prescribed,
            habitBreakdown: habitAdherenceData.breakdown,
            weekNumber: userProfile?.currentWeek ?? 1
        )
    }

    // MARK: - Context Input Step
    private var contextInputStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 4) {
                Text("CONTEXT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.atlasPrimary)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)

                Text("Anything to Note?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .frame(maxWidth: .infinity)

                Text("Help your coach understand your week")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .frame(maxWidth: .infinity)
            }

            FlowLayout(spacing: 8) {
                ForEach(contextChips, id: \.self) { chip in
                    Button(action: {
                        if selectedChips.contains(chip) {
                            selectedChips.remove(chip)
                        } else {
                            selectedChips.insert(chip)
                        }
                    }) {
                        Text(chip)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedChips.contains(chip) ? .atlasBackground : .atlasText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedChips.contains(chip) ? Color.atlasPrimary : Color.atlasCardDark)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedChips.contains(chip) ? Color.clear : Color.atlasTextMuted.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Additional context (optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.atlasTextMuted)

                TextEditor(text: $challengesText)
                    .font(.system(size: 15))
                    .foregroundColor(.atlasText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(12)
                    .background(Color.atlasCardDark)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.atlasTextMuted.opacity(0.2), lineWidth: 1)
                    )
            }

            Text("This step is optional — skip if nothing unusual happened")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        GeometryReader { geo in
            let progress = Double(currentStep) / Double(max(orderedSteps.count - 1, 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.atlasTextMuted.opacity(0.15))
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.atlasPrimary)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
   
    @ViewBuilder
    private var weightAndPhotosStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Track Your Body")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.atlasText)
            
            Text("Optional — skip if you prefer not to track")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
            
            weightInputCard
            
            photosCard
        }
    }

    @ViewBuilder
    private var weightInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Weight")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.atlasText)
            
            HStack {
                TextField("0.0", text: $weightText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.atlasText)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                
                Text(unitFormatter.weightUnit)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            if let delta = weightDelta {
                HStack(spacing: 6) {
                    Image(systemName: delta < -0.1 ? "arrow.down.right" : (delta > 0.1 ? "arrow.up.right" : "arrow.right"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(delta < -0.1 ? Color(hex: "#4a9e8e") : (delta > 0.1 ? Color(hex: "#d4a054") : .atlasTextMuted))
                    
                    Text(String(format: "%+.1f ", delta) + unitFormatter.weightUnit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(delta < -0.1 ? Color(hex: "#4a9e8e") : (delta > 0.1 ? Color(hex: "#d4a054") : .atlasTextMuted))
                    
                    if daysSinceLastWeight > 0 {
                        Text("from \(daysSinceLastWeight) days ago")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted.opacity(0.6))
                    }
                }
                .padding(.top, 2)
            } else if let prevWeight = previousWeight {
                Text("Last: \(unitFormatter.displayWeight(prevWeight))")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted.opacity(0.6))
                    .padding(.top, 2)
            }
            
            if let goalWeight = userProfile?.goalWeight, goalWeight > 0 {
                HStack(spacing: 4) {
                    Text("Goal:")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                    Text(unitFormatter.displayWeight(goalWeight))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress Photos")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasText)
                Spacer()
                Text("Optional")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
            }
            
            Text("Front and side views recommended. Photos are stored on-device only.")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted)
            
            if !capturedPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(capturedPhotos.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: capturedPhotos[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 120)
                                    .cornerRadius(10)
                                    .clipped()
                                
                                Button(action: {
                                    withAnimation { let _ = capturedPhotos.remove(at: index) }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            HStack(spacing: 12) {
                Button(action: { showingCamera = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 15))
                        Text("Camera")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.atlasPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 4,
                    matching: .images
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 15))
                        Text("Library")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.atlasPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    
    // MARK: - Step: Review
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Ready for Analysis")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.atlasText)

            Text("We'll generate personalized coaching based on your data")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)

            VStack(spacing: 16) {
                MetricsSummaryCard(
                    avgSleep: avgSleep,
                    avgHRV: avgHRV,
                    habitRate: habitCompletionRate,
                    streak: currentStreak
                )

                if !selectedChips.isEmpty || !challengesText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasText)

                        if !selectedChips.isEmpty {
                            Text(selectedChips.joined(separator: "  "))
                                .font(.system(size: 14))
                                .foregroundColor(.atlasText)
                        }

                        if !challengesText.isEmpty {
                            Text(challengesText)
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }

                if let weight = Double(weightText), weight > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body Composition")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasText)

                        SummaryRow(label: "Weight", value: unitFormatter.displayWeight(weight))

                        if let delta = weightDelta {
                            SummaryRow(label: "Change", value: String(format: "%+.1f ", delta) + unitFormatter.weightUnit)
                        }

                        if !capturedPhotos.isEmpty {
                            SummaryRow(label: "Photos", value: "\(capturedPhotos.count) captured")
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }

                if isEventTraining, let weekData = currentEventWeekData {
                    eventTrainingSummaryCard(weekData: weekData)
                }
            }
        }
    }
    
    // MARK: - Event Training Summary Card
    
    private func eventTrainingSummaryCard(weekData: PlannedWorkoutWeek) -> some View {
        let profile = userProfile
        let eventName = profile?.eventName ?? profile?.eventType ?? "Event"
        let currentWeek = profile?.currentEventWeek ?? 1
        let totalWeeks = activeEventProgram?.totalWeeks ?? 12
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasAccent)
                
                Text("Event Training — Week \(currentWeek)/\(totalWeeks)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasText)
            }
            
            VStack(spacing: 8) {
                SummaryRow(label: "Event", value: eventName)
                SummaryRow(label: "Phase", value: weekData.phaseName)
                if let focus = weekData.weekFocus {
                    SummaryRow(label: "Focus", value: focus)
                }
                SummaryRow(label: "Sessions", value: WeeklyCommitHelper.workoutSummary(for: weekData))
            }
        }
        .padding(16)
        .background(Color.atlasAccent.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasAccent.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: {
                    withAnimation { currentStep -= 1 }
                }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                }
            }

            Button(action: handleNextButton) {
                Text(isLastStep ? "Generate Analysis" : "Continue")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.atlasPrimary)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Analysis View (NEW: Card-based, no AI)
    private var analysisView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let analysis = generatedAnalysis {
                    // Card-based coaching results
                    WeeklyCoachingResultsView(analysis: analysis)
                    
                    // Deload recommendation card (appears after coaching cards)
                    if let deload = deloadRecommendation {
                        deloadRecommendationCard(deload)
                    }
                    
                    if let sleepWarning = protocolRecommendation?.sleepWarning {
                        sleepWarningCard(sleepWarning)
                    }
                    
                    if let recommendation = protocolRecommendation {
                        protocolRecommendationCard(recommendation)
                    }
                    
                    Button(action: saveAndDismiss) {
                        Text("Complete Check-In")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(12)
                    }
                } else {
                    // Fallback — should not happen since generation is instant
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(.atlasPrimary)
                            .scaleEffect(1.5)
                        
                        Text("Analyzing your week...")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Deload Recommendation Card
    
    private func deloadRecommendationCard(_ recommendation: DeloadDetector.DeloadRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.atlasAmber.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "battery.25")
                        .font(.system(size: 18))
                        .foregroundColor(.atlasAmber)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recovery Week Recommended")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(recommendation.reason == .hrvDecline ? "Based on HRV trend" : "Scheduled recovery")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                Text(recommendation.severity == .recommended ? "RECOMMENDED" : "SUGGESTED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.atlasBackground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(recommendation.severity == .recommended ? Color.atlasAmber : Color.atlasAccent)
                    .cornerRadius(4)
            }
            
            Text(recommendation.message)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .lineSpacing(6)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What this means:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    Text("Same exercises, same weight")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAmber)
                    Text("50% fewer sets (half the volume)")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasPrimary)
                    Text("Your streak and habits stay intact")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text("Normal programming resumes next week")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            
            HStack(spacing: 12) {
                Button(action: { declineDeload() }) {
                    Text("Not This Week")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { acceptDeload() }) {
                    Text("Accept Deload")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.atlasAmber)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasAmber.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Deload Accept/Decline Actions
    
    private func acceptDeload() {
        guard let profile = userProfile else { return }
        DeloadDetector.acceptDeload(profile: profile)
        try? modelContext.save()
        deloadRecommendation = nil
        print("✅ Deload week accepted")
    }
    
    private func declineDeload() {
        deloadRecommendation = nil
        print("❌ Deload declined")
    }
    
    // MARK: - Protocol Recommendation Card
    private func protocolRecommendationCard(_ recommendation: ProtocolRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
            
            HStack {
                Text("Protocol Adjustment")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Text(actionDisplayName(recommendation.action))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.atlasBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(actionColor(recommendation.action))
                    .cornerRadius(12)
            }
            
            Text(recommendation.reasoning)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .lineSpacing(6)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                if let changes = recommendation.changes {
                    Text("Recommended Changes:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                    
                    ForEach(Array(changes.enumerated()), id: \.offset) { index, change in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                            
                            Text(change)
                                .font(.system(size: 14))
                                .foregroundColor(.atlasText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                if let additions = recommendation.additions {
                    Text("Ready to Add:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                    
                    ForEach(Array(additions.enumerated()), id: \.offset) { index, addition in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasPrimary)
                            
                            Text(addition)
                                .font(.system(size: 14))
                                .foregroundColor(.atlasText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                if let encouragement = recommendation.encouragement {
                    Text(encouragement)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                        .lineSpacing(6)
                        .padding(16)
                        .background(Color.atlasPrimary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if isMovementPlanUpgrade(recommendation) {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                Button(action: { showMovementCelebration = true }) {
                    HStack {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.system(size: 18))
                        Text("View Upgrade Details")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.atlasPrimary)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            } else if recommendation.action != .maintain {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                if isApplyingRecommendation {
                    HStack {
                        ProgressView()
                            .tint(.atlasPrimary)
                        Text("Applying changes...")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    HStack(spacing: 12) {
                        Button(action: { declineRecommendation(recommendation) }) {
                            Text("No Thanks")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { acceptRecommendation(recommendation) }) {
                            Text("Apply Changes")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.atlasBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(actionColor(recommendation.action))
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(actionColor(recommendation.action).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Progressive Unlock Modal
    private func progressiveUnlockModal(intervention: Intervention) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    showProgressiveUnlock = false
                }
            
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You're Crushing It! 🎉")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.atlasText)
                        
                        Text("4+ weeks at 80%+ adherence")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                Text("You've built a rock-solid foundation. Ready to add another habit?")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasText)
                    .lineSpacing(6)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.atlasPrimary.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: intervention.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.atlasPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intervention.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.atlasText)
                            
                            Text("\(intervention.impactScore) impact score")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                        
                        Spacer()
                    }
                    
                    Text(intervention.whyThisMatters)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                        .lineSpacing(5)
                        .padding(16)
                        .background(Color.atlasPrimary.opacity(0.1))
                        .cornerRadius(12)
                    
                    if let current = intervention.currentValue, let target = intervention.targetValue {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.atlasTextMuted)
                                Text(current)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundColor(.atlasTextMuted)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Target")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.atlasTextMuted)
                                Text(target)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                if isApplyingRecommendation {
                    HStack {
                        ProgressView()
                            .tint(.atlasPrimary)
                        Text("Adding new habit...")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 12) {
                        Button(action: { acceptProgressiveUnlock() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Add This Habit")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { declineProgressiveUnlock() }) {
                            Text("Not Yet - Keep Current Habits")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(24)
            .background(Color.atlasBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
            .padding(.horizontal, 24)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
    
    // MARK: - Helper Functions
    private func sleepWarningCard(_ warning: SleepWarningLevel) -> some View {
        Group {
            if warning == .warning {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Alert")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.yellow)
                        
                        Text("Sleep dropped to \(String(format: "%.1f", avgSleep))h this week. If this continues, we'll need to simplify and focus on recovery.")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasText)
                            .lineSpacing(4)
                    }
                }
                .padding(16)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            } else if warning == .critical {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Crisis - Action Required")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("Sleep has been below 6.5h for 2 weeks (\(String(format: "%.1f", avgSleep))h avg). This is the foundation - everything else is secondary until we fix this.")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasText)
                            .lineSpacing(4)
                    }
                }
                .padding(16)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                )
            }
        }
    }
    
    private func isMovementPlanUpgrade(_ recommendation: ProtocolRecommendation) -> Bool {
        guard recommendation.action == .progress,
            let additions = recommendation.additions else {
            return false
        }
        
        return additions.contains(where: { $0.lowercased().contains("training plan") })
    }
    
    private func actionDisplayName(_ action: ProtocolAction) -> String {
        switch action {
        case .simplify: return "SIMPLIFY"
        case .maintain: return "MAINTAIN"
        case .progress: return "PROGRESS"
        }
    }
    
    private func actionColor(_ action: ProtocolAction) -> Color {
        switch action {
        case .simplify: return .orange
        case .maintain: return .blue
        case .progress: return .green
        }
    }
    
    private func handleNextButton() {
        if !isLastStep {
            withAnimation {
                currentStep += 1
            }
        } else {
            generateAnalysis()
        }
    }
    
    private func saveWeightAndPhotos() {
        guard let profile = userProfile else { return }
        
        if let displayValue = Double(weightText), displayValue > 0 {
            // Input is in user's preferred unit; convert to lbs for storage
            let weightInLbs = unitFormatter.toLbs(displayValue)
            let entry = BodyCompEntry(date: Date(), weight: weightInLbs)
            entry.userProfile = profile
            modelContext.insert(entry)
            profile.weight = weightInLbs
            print("✅ Saved BodyCompEntry: \(weightInLbs) lbs")
        }
        
        for photo in capturedPhotos {
            if let photoData = photo.jpegData(compressionQuality: 0.7) {
                let progressPhoto = ProgressPhoto(date: Date(), photoData: photoData)
                progressPhoto.weight = Double(weightText)
                progressPhoto.userProfile = profile
                modelContext.insert(progressPhoto)
                print("✅ Saved ProgressPhoto (\(photoData.count / 1024)KB)")
            }
        }
    }

// ============================================================
// REPLACEMENT for generateAnalysis() in EnhancedWeeklyCheckInView.swift
//
// Find:   private func generateAnalysis() {
// To:     just before // MARK: - Progressive Unlock Actions
//
// Replace the ENTIRE method with the code below.
// ============================================================

    // MARK: - Generate Analysis (Programmatic Engine, No AI)
    
    private func generateAnalysis() {
        saveWeightAndPhotos()
        
        guard let profile = userProfile else {
            showAnalysis = true
            return
        }
        
        // --- Build WeeklyCheckInData for the engine ---
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Pace values
        let latestPace = paceScores.first
        let paceStartVal: Double = {
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
            return paceScores.first { $0.date <= weekAgo }?.paceValue ?? 0
        }()
        
        // Previous week averages (days 7-13)
        let prevWeekMetrics = allMetrics.filter {
            let days = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 99
            return days >= 7 && days < 14
        }
        
        func avg(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }
        
        let sleepPrevAvg = avg(prevWeekMetrics.compactMap { $0.sleepDuration })
        let hrvPrevAvg = avg(prevWeekMetrics.compactMap { $0.heartRateVariability })
        let rhrPrevAvg = avg(prevWeekMetrics.compactMap { $0.restingHeartRate })
        
        // 2-week HRV/RHR trends
        let twoWeeksAgoMetrics = allMetrics.filter {
            let days = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 99
            return days >= 14 && days < 21
        }
        
        let hrvTwoWeeksAgo = avg(twoWeeksAgoMetrics.compactMap { $0.heartRateVariability })
        let rhrTwoWeeksAgo = avg(twoWeeksAgoMetrics.compactMap { $0.restingHeartRate })
        
        let hrvTrend: Double = {
            guard let current = hrvAvgThisWeek, hrvTwoWeeksAgo > 0 else { return 0 }
            return ((current - hrvTwoWeeksAgo) / hrvTwoWeeksAgo) * 100
        }()
        
        let rhrTrend: Double = {
            guard let current = rhrAvgThisWeek else { return 0 }
            return current - rhrTwoWeeksAgo
        }()
        
        // Per-habit adherence
        let dataController = DataController(modelContext: modelContext)
        let activeHabits = allHabits.filter { $0.isActive && $0.habitType == "non_negotiable" && !$0.isTrainingHabit }
        
        var habitDataList: [HabitWeekData] = []
        for habit in activeHabits {
            var completedDays = 0
            var totalDays = 0
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                if habit.appliesTo(date: date) {
                    totalDays += 1
                    if dataController.isHabitComplete(habit: habit, on: date) {
                        completedDays += 1
                    }
                }
            }
            let adherencePercent = totalDays > 0 ? Int(Double(completedDays) / Double(totalDays) * 100) : 0
            habitDataList.append(HabitWeekData(
                habitName: habit.title,
                completedDays: completedDays,
                adherencePercent: adherencePercent,
                streakDays: 0 // TODO: per-habit streak calculation
            ))
        }
        
        // Consecutive weeks above 80%
        let consecutiveWeeksAbove80: Int = {
            var count = 0
            for checkIn in checkIns {
                if (checkIn.habitCompletionRate ?? 0) >= 0.8 {
                    count += 1
                } else {
                    break
                }
            }
            return count
        }()
        
        // Deload tracking
        let weeksSinceDeload: Int = {
            guard let lastDeload = profile.lastDeloadWeekDate else { return 99 }
            return calendar.dateComponents([.weekOfYear], from: lastDeload, to: Date()).weekOfYear ?? 99
        }()
        
        // Training adherence
        let trainingAdh = trainingAdherence
        let training2WeekAdherence: Double = trainingAdh.prescribed > 0
            ? Double(trainingAdh.completed) / Double(trainingAdh.prescribed)
            : 0
        
        // Zone 2 HR range string
        let zone2Range: String = {
            guard let age = profile.age else { return "124-145" }
            let maxHR = 220.0 - Double(age)
            return "\(Int(maxHR * 0.60))-\(Int(maxHR * 0.70))"
        }()
        
        // User context string from chips + free text
        let contextString: String? = {
            var parts: [String] = []
            if !selectedChips.isEmpty {
                parts.append(selectedChips.joined(separator: ", "))
            }
            if !challengesText.isEmpty {
                parts.append(challengesText)
            }
            return parts.isEmpty ? nil : parts.joined(separator: ". ")
        }()
        
        // Weight
        let currentWeight = Double(weightText)
        let prevWeight = previousWeight
        
        // Cardio data from analyzer (using ACTUAL property names from WeeklyCardioSummary)
        let cardioSessionCount = cardioSummary?.thisWeekSessions ?? 0
        let cardioTotalMins = cardioSummary?.thisWeekTotalMinutes ?? 0
        let cardioPrevMins = cardioSummary?.lastWeekTotalMinutes ?? 0
        
        // Zone 2 minutes estimation from session details
        let zone2Mins: Int = {
            guard let details = cardioSummary?.thisWeekSessionDetails else { return 0 }
            return details
                .filter { $0.hrZoneLabel == "Zone 2" || $0.hrZoneLabel == "Zone 1-2" }
                .reduce(0) { $0 + $1.duration }
        }()
        
        let zone2Pct: Double = cardioTotalMins > 0 ? Double(zone2Mins) / Double(cardioTotalMins) : 0
        
        // Build the data struct using the ACTUAL memberwise init
        let checkInData = WeeklyCheckInData(
            paceStart: paceStartVal,
            paceEnd: latestPace?.paceValue ?? 0,
            paceTrend: latestPace?.trendDirection ?? "stable",
            strongestComponent: latestPace?.strongestComponent ?? "Unknown",
            weakestComponent: latestPace?.weakestComponent ?? "Unknown",
            weakestPercentile: 50, // TODO: from Pace breakdown
            sleepAvgHours: sleepAvgThisWeek ?? 0,
            sleepPrevWeekAvg: sleepPrevAvg,
            hrvAvg: hrvAvgThisWeek ?? 0,
            hrvPrevWeekAvg: hrvPrevAvg,
            hrvTrend2Week: hrvTrend,
            rhrAvg: rhrAvgThisWeek ?? 0,
            rhrPrevWeekAvg: rhrPrevAvg,
            rhrTrend2Week: rhrTrend,
            stepsAvg: Int(stepsAvgThisWeek ?? 0),
            habitAdherencePercent: Int(habitCompletionRate * 100),
            trainingAdherencePercent: trainingAdh.prescribed > 0
                ? Int(Double(trainingAdh.completed) / Double(trainingAdh.prescribed) * 100)
                : 0,
            sessionsCompleted: trainingAdh.completed,
            sessionsPrescribed: trainingAdh.prescribed,
            habits: habitDataList,
            consecutiveWeeksAbove80: consecutiveWeeksAbove80,
            totalActiveHabits: activeHabits.count,
            liftProgressions: [], // TODO: wire up from strengthSummary
            cardioSessions: cardioSessionCount,
            cardioTotalMinutes: cardioTotalMins,
            cardioPrevWeekMinutes: cardioPrevMins,
            zone2Minutes: zone2Mins,
            zone2PercentOfTotal: zone2Pct,
            intervalsDetected: false, // TODO: detect from session details
            avgIntervalRecoveryBPM: nil,
            weeksSinceDeload: weeksSinceDeload,
            trainingAdherence2Week: training2WeekAdherence,
            userContext: contextString,
            currentWeight: currentWeight,
            previousWeight: prevWeight,
            zone2HRRange: zone2Range
        )
        
        // --- Generate analysis (instant, synchronous) ---
        let analysis = WeeklyCoachingEngine.generateAnalysis(data: checkInData)
        generatedAnalysis = analysis
        showAnalysis = true
        
        // --- Persist WeeklyCoachingResult ---
        // Uses the ACTUAL init: (weekStart:, weekEnd:, analysis:, paceStart:, paceEnd:)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let result = WeeklyCoachingResult(
            weekStart: weekStart,
            weekEnd: today,
            analysis: analysis,
            paceStart: paceStartVal,
            paceEnd: latestPace?.paceValue
        )
        modelContext.insert(result)
        
        // --- Run protocol adjustment engine ---
        Task {
            // Use the Historical convenience init for the protocol engine
            let currentWeekForEngine = WeeklyCheckInData(
                weekNumber: profile.currentWeek ?? 1,
                habitCompletionRate: habitCompletionRate,
                avgSleep: avgSleep,
                avgHRV: avgHRV,
                avgRHR: avgRHR,
                energyRating: energyRating,
                stressRating: stressRating,
                recoveryRating: recoveryRating,
                challenges: challengesText.isEmpty ? "None mentioned" : challengesText,
                wins: winsText.isEmpty ? "None mentioned" : winsText,
                date: Date()
            )
            
            let previousWeeks = dataController.getPreviousWeeksData(
                count: 4,
                beforeWeek: profile.currentWeek ?? 1
            )
            
            let habitTrends = dataController.getHabitTrends()
            
            do {
                let recommendation = try await ProtocolAdjustmentEngine.analyzeAndRecommend(
                    currentWeek: currentWeekForEngine,
                    previousWeeks: previousWeeks,
                    habitTrends: habitTrends,
                    profile: profile,
                    modelContext: modelContext
                )
                
                let weeklyAdherence = previousWeeks.map { $0.habitCompletionRate }
                
                if ProgressiveUnlockManager.shouldOfferNewIntervention(
                    profile: profile,
                    weeklyAdherence: weeklyAdherence,
                    modelContext: modelContext
                ) {
                    if let intervention = try? await ProgressiveUnlockManager.recommendNextIntervention(
                        profile: profile,
                        modelContext: modelContext
                    ) {
                        await MainActor.run {
                            progressiveUnlockIntervention = intervention
                            showProgressiveUnlock = true
                        }
                    }
                }
                
                // Deload detection
                let deload = DeloadDetector.evaluate(
                    profile: profile,
                    recentMetrics: Array(allMetrics.prefix(21)),
                    recentCheckIns: Array(checkIns.prefix(4)),
                    activeProgram: activePrograms.first { $0.isActive }
                )
                
                let fatiguedHabits = HabitFatigueDetector.detectFatigue(
                    modelContext: modelContext,
                    profile: profile
                )
                
                if !fatiguedHabits.isEmpty {
                    print("⚠️ Detected \(fatiguedHabits.count) fatigued habits")
                }
                
                await MainActor.run {
                    protocolRecommendation = recommendation
                    deloadRecommendation = deload
                    
                    if recommendation.regressionAlert != nil {
                        showRegressionAlert = true
                    }
                }
            } catch {
                print("❌ Protocol adjustment failed: \(error)")
            }
        }
    }
    
    // MARK: - Progressive Unlock Actions
    private func acceptProgressiveUnlock() {
        guard let profile = userProfile,
              let intervention = progressiveUnlockIntervention else { return }
        
        isApplyingRecommendation = true
        
        Task {
            do {
                try ProgressiveUnlockManager.acceptNewIntervention(
                    profile: profile,
                    intervention: intervention,
                    modelContext: modelContext
                )
                
                await MainActor.run {
                    isApplyingRecommendation = false
                    showProgressiveUnlock = false
                    progressiveUnlockIntervention = nil
                    print("✅ Progressive unlock accepted")
                }
            } catch {
                await MainActor.run {
                    isApplyingRecommendation = false
                    print("❌ Failed to accept: \(error)")
                }
            }
        }
    }
    
    private func declineProgressiveUnlock() {
        guard let profile = userProfile else { return }
        
        do {
            try ProgressiveUnlockManager.declineNewIntervention(
                profile: profile,
                modelContext: modelContext
            )
            
            showProgressiveUnlock = false
            progressiveUnlockIntervention = nil
            print("❌ Progressive unlock declined")
        } catch {
            print("❌ Failed to decline: \(error)")
        }
    }
    
    private func upgradeToTrainingPlan() {
        guard let profile = userProfile else { return }
        
        isApplyingRecommendation = true
        profile.movementPlanStartDate = nil
        isApplyingRecommendation = false
        protocolRecommendation = nil
        print("✅ Movement plan cleared — user can pick a new plan from Training tab")
    }
    
    private func getWeeksOnMovementPlan() -> Int {
        guard let startDate = userProfile?.movementPlanStartDate else { return 0 }
        return Calendar.current.dateComponents([.weekOfYear], from: startDate, to: Date()).weekOfYear ?? 0
    }
    
    private func getMovementPlanAdherence() -> Double {
        let dataController = DataController(modelContext: modelContext)
        let previousWeeks = dataController.getPreviousWeeksData(
            count: 6,
            beforeWeek: userProfile?.currentWeek ?? 1
        )
        
        guard !previousWeeks.isEmpty else { return 0.0 }
        
        let avgAdherence = previousWeeks.map { $0.habitCompletionRate }.reduce(0, +) / Double(previousWeeks.count)
        return avgAdherence
    }
    
    private func saveAndDismiss() {
        let weeklyCheckIn = WeeklyCheckIn(
            weekNumber: userProfile?.currentWeek ?? 1,
            date: Date()
        )
        
        weeklyCheckIn.energyLevel = energyRating
        weeklyCheckIn.biggestChallenge = challengesText.isEmpty ? nil : challengesText
        weeklyCheckIn.biggestWin = winsText.isEmpty ? nil : winsText
        weeklyCheckIn.overallRating = (energyRating + (6 - stressRating) + recoveryRating) / 3
        
        weeklyCheckIn.habitCompletionRate = habitCompletionRate
        weeklyCheckIn.sleepAverage = avgSleep
        weeklyCheckIn.hrvAverage = avgHRV
        weeklyCheckIn.rhrAverage = avgRHR
        
        weeklyCheckIn.aiCoachingFeedback = generatedAnalysis?.sections.map { "\($0.title): \($0.body)" }.joined(separator: "\n\n")
        
        weeklyCheckIn.userProfile = userProfile
        
        modelContext.insert(weeklyCheckIn)
        
        if let analysis = generatedAnalysis {
            let coachingEntry = CoachingEntry(
                type: "weekly_checkin",
                title: "Week \(userProfile?.currentWeek ?? 1) Check-In",
                content: analysis.sections.map { "\($0.title): \($0.body)" }.joined(separator: "\n\n"),
                weekNumber: userProfile?.currentWeek
            )
            coachingEntry.userProfile = userProfile
            modelContext.insert(coachingEntry)
        }
        
        if let profile = userProfile {
            profile.currentWeek += 1
            profile.lastCheckInDate = Date()
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func acceptRecommendation(_ recommendation: ProtocolRecommendation) {
        isApplyingRecommendation = true
        
        Task {
            do {
                try HabitModificationEngine.applyRecommendation(
                    recommendation,
                    modelContext: modelContext
                )
                
                await MainActor.run {
                    isApplyingRecommendation = false
                    print("✅ Recommendation accepted")
                    saveAndDismissWithRecommendation(recommendation, accepted: true)
                }
            } catch {
                await MainActor.run {
                    isApplyingRecommendation = false
                    print("❌ Failed to apply: \(error)")
                }
            }
        }
    }
    
    private func declineRecommendation(_ recommendation: ProtocolRecommendation) {
        print("❌ Recommendation declined")
        saveAndDismissWithRecommendation(recommendation, accepted: false)
    }
    
    private func saveAndDismissWithRecommendation(_ recommendation: ProtocolRecommendation, accepted: Bool) {
        let weeklyCheckIn = WeeklyCheckIn(
            weekNumber: userProfile?.currentWeek ?? 1,
            date: Date()
        )
        
        weeklyCheckIn.energyLevel = energyRating
        weeklyCheckIn.biggestChallenge = challengesText.isEmpty ? nil : challengesText
        weeklyCheckIn.biggestWin = winsText.isEmpty ? nil : winsText
        weeklyCheckIn.overallRating = (energyRating + (6 - stressRating) + recoveryRating) / 3
        
        weeklyCheckIn.habitCompletionRate = habitCompletionRate
        weeklyCheckIn.sleepAverage = avgSleep
        weeklyCheckIn.hrvAverage = avgHRV
        weeklyCheckIn.rhrAverage = avgRHR
        
        weeklyCheckIn.aiCoachingFeedback = generatedAnalysis?.sections.map { "\($0.title): \($0.body)" }.joined(separator: "\n\n")
        
        weeklyCheckIn.protocolRecommendation = String(describing: recommendation.action)
        weeklyCheckIn.recommendationAccepted = accepted
        weeklyCheckIn.recommendationReasoning = recommendation.reasoning
        
        weeklyCheckIn.userProfile = userProfile
        
        modelContext.insert(weeklyCheckIn)
        
        if let analysis = generatedAnalysis {
            let coachingEntry = CoachingEntry(
                type: "weekly_checkin",
                title: "Week \(userProfile?.currentWeek ?? 1) Check-In",
                content: analysis.sections.map { "\($0.title): \($0.body)" }.joined(separator: "\n\n"),
                weekNumber: userProfile?.currentWeek
            )
            coachingEntry.userProfile = userProfile
            modelContext.insert(coachingEntry)
        }
        
        if let profile = userProfile {
            profile.currentWeek += 1
            profile.lastCheckInDate = Date()
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Supporting Views

struct RatingSlider: View {
    let title: String
    let subtitle: String
    @Binding var rating: Int
    let lowLabel: String
    let highLabel: String
    var isInverted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
            
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { Double(rating) },
                    set: { rating = Int($0) }
                ), in: 1...5, step: 1)
                .tint(isInverted ? (rating > 3 ? .red : .green) : (rating > 3 ? .green : .red))
                
                HStack {
                    Text(lowLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Text("\(rating)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasPrimary)
                    
                    Spacer()
                    
                    Text(highLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct MetricsSummaryCard: View {
    let avgSleep: Double
    let avgHRV: Double
    let habitRate: Double
    let streak: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week's Metrics")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasText)
            
            VStack(spacing: 8) {
                SummaryRow(label: "Sleep", value: String(format: "%.1fh", avgSleep))
                SummaryRow(label: "HRV", value: String(format: "%.0f ms", avgHRV))
                SummaryRow(label: "Habits", value: "\(Int(habitRate * 100))%")
                SummaryRow(label: "Streak", value: "\(streak) days")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RatingsSummaryCard: View {
    let energy: Int
    let stress: Int
    let recovery: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Ratings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasText)
            
            VStack(spacing: 8) {
                SummaryRow(label: "Energy", value: "\(energy)/5")
                SummaryRow(label: "Stress", value: "\(stress)/5")
                SummaryRow(label: "Recovery", value: "\(recovery)/5")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ReflectionSummaryCard: View {
    let challenges: String
    let wins: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Reflection")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasText)
            
            if !challenges.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Challenges:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    Text(challenges)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                }
            }
            
            if !wins.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wins:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    Text(wins)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
        }
    }
}

struct TrendIndicator: View {
    enum Trend {
        case up, down, flat
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .flat: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .flat: return .gray
            }
        }
    }
    
    let label: String
    let value: String
    let trend: Trend
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
                
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasText)
            }
            
            Spacer()
            
            Image(systemName: trend.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(trend.color)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct CheckInCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        let dismiss: DismissAction
        
        init(onCapture: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onCapture(image)
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            dismiss()
        }
    }
}

#Preview {
    EnhancedWeeklyCheckInView()
}