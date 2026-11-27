import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers
import ActivityKit

struct WorkoutLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var previousSessions: [WorkoutSession]
    
    // Optional habit integration (pre-fills when coming from habit card)
    var habit: Habit? = nil
    var onComplete: (() -> Void)? = nil
    
    // Draft restoration (set by parent when resuming)
    var restoredDraft: WorkoutDraft? = nil
    
    // Workout state
    @State private var workoutName: String = "Workout"
    @State private var exercises: [LoggingExercise] = []
    @State private var globalNotes: String = ""
    @State private var showingExercisePicker = false
    @State private var showPRCelebration = false
    @State private var detectedPRs: [(exercise: String, prs: [PersonalRecord])] = []
    @State private var isSaving = false
    
    // ── BUG-005 Fix: Prevent double-save ──
    @State private var hasCompleted = false
    
    // Rest timer state
    @State private var activeRestTimer: RestTimer? = nil
    @State private var workoutStartTime: Date? = nil
    
    // AI coaching state
    @State private var activeCoachingMessage: CoachingMessage? = nil
    
    // Drag and drop state
    @State private var draggingExercise: LoggingExercise? = nil
    
    // ── Fix 4: Dismiss protection ──
    @State private var showCancelConfirmation = false
    
    // ── Fix 5: Exercise swap/delete ──
    @State private var exerciseToSwap: LoggingExercise? = nil
    
    private var userProfile: UserProfile? { profiles.first }
    
    /// True when any sets have been logged — used for dismiss protection + draft saving
    private var hasLoggedData: Bool {
        exercises.contains { $0.sets.contains { $0.isCompleted } }
    }
    
    // MARK: - Computed Stats
    
    private var workoutStats: WorkoutStats {
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { $0.isCompleted }.count
        }
        let elapsedMinutes: Int = {
            guard let startTime = workoutStartTime else { return 0 }
            return Int(Date().timeIntervalSince(startTime) / 60)
        }()
        let totalVolume: Double = exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { $0.isCompleted }.reduce(0) { setTotal, set in
                setTotal + (set.actualWeight ?? 0) * Double(set.actualReps)
            }
        }
        return WorkoutStats(
            totalExercises: exercises.count,
            totalSets: totalSets,
            completedSets: completedSets,
            elapsedMinutes: elapsedMinutes,
            totalVolume: totalVolume
        )
    }
    
    private var workoutInProgress: Bool { workoutStats.completedSets > 0 }
    
    private var progressPercentage: Double {
        guard workoutStats.totalSets > 0 else { return 0 }
        return Double(workoutStats.completedSets) / Double(workoutStats.totalSets)
    }
    
    private var estimatedDuration: Int {
        (workoutStats.totalSets * 3) + (exercises.count * 2)
    }
    
    private var canSave: Bool {
        exercises.contains { $0.sets.contains { $0.isCompleted } }
    }
    
    private var availablePlanWorkouts: [PlannedWorkoutDay] {
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let program = (try? modelContext.fetch(descriptor))?.first else { return [] }
        return program.workoutDays
            .filter { $0.dayType == "strength" }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if !exercises.isEmpty {
                            workoutSummaryCard
                        }
                        
                        if exercises.isEmpty {
                            loadFromPlanSection
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal, 24)
                            
                            addExerciseButton
                        } else {
                            exerciseListSection
                            addExerciseSection
                            globalNotesSection
                            completeButton
                        }
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(24)
                }
                .onTapGesture { hideKeyboard() }
                
                // AI Coaching Message (floating)
                if let message = activeCoachingMessage {
                    VStack {
                        CoachingMessageCard(message: message) {
                            withAnimation(.spring()) { activeCoachingMessage = nil }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 120)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }
                
                // Rest Timer Overlay (floating at bottom)
                if let timer = activeRestTimer {
                    VStack {
                        Spacer()
                        RestTimerCard(
                            timer: timer,
                            onDismiss: { dismissRestTimer() },
                            onAddTime: { activeRestTimer?.addTime(30) }
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasLoggedData {
                            showCancelConfirmation = true
                        } else {
                            WorkoutDraftManager.clearDraft()
                            SharedWorkoutStore.clear()
                            WorkoutLiveActivityManager.shared.endActivity()
                            // FEAT-002: Discard Apple Watch session
                            WorkoutSessionManager.shared.discardWorkoutSession()
                            dismiss()
                        }
                    }
                    .foregroundColor(.atlasTextMuted)
                }
                if !exercises.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            withAnimation {
                                exercises = []
                                workoutName = "Workout"
                                globalNotes = ""
                                workoutStartTime = nil
                                activeRestTimer = nil
                                activeCoachingMessage = nil
                                WorkoutDraftManager.clearDraft()
                                SharedWorkoutStore.clear()
                                WorkoutLiveActivityManager.shared.endActivity()
                                // FEAT-002: Discard Apple Watch session on clear
                                WorkoutSessionManager.shared.discardWorkoutSession()
                            }
                        }
                        .foregroundColor(.atlasTextMuted)
                    }
                }
            }
            .onAppear {
                if let draft = restoredDraft {
                    restoreFromDraft(draft)
                } else {
                    loadFromHabitIfNeeded()
                }
                // FEAT-002: Start Apple Watch workout session
                Task { await WorkoutSessionManager.shared.startWorkoutSession() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if (newPhase == .background || newPhase == .inactive) && hasLoggedData {
                    saveDraft()
                }
                if newPhase == .active {
                    syncFromSharedState()
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    existingExerciseNames: Set(exercises.map { $0.name }),
                    onSelect: { definition in addExercise(definition) }
                )
            }
            .sheet(isPresented: $showPRCelebration, onDismiss: {
                // BUG-005: Dismiss entire workout log flow when PR sheet closes,
                // not just the sheet — prevents landing back on active Complete button
                onComplete?()
                dismiss()
            }) {
                PRCelebrationView(prs: detectedPRs) {
                    onComplete?()
                    dismiss()
                }
            }
            // ── Fix 5: Swap exercise sheet (item-based to avoid blank sheet) ──
            .sheet(item: $exerciseToSwap) { exercise in
                ExerciseSwapSheet(
                    exerciseName: exercise.name,
                    onSelect: { alternative in
                        swapExercise(exercise, with: alternative)
                    }
                )
            }
            .alert("End Workout?", isPresented: $showCancelConfirmation) {
                Button("Discard", role: .destructive) {
                    WorkoutDraftManager.clearDraft()
                    SharedWorkoutStore.clear()
                    WorkoutLiveActivityManager.shared.endActivity()
                    // FEAT-002: Discard Apple Watch session on cancel
                    WorkoutSessionManager.shared.discardWorkoutSession()
                    dismiss()
                }
                Button("Keep Logging", role: .cancel) { }
            } message: {
                Text("You have unsaved workout data. Are you sure you want to discard it?")
            }
        }
        .interactiveDismissDisabled(hasLoggedData)
    }
    
    // MARK: - Draft Persistence
    
    private func saveDraft() {
        WorkoutDraftManager.saveDraft(
            workoutName: workoutName,
            exercises: exercises,
            globalNotes: globalNotes,
            workoutStartTime: workoutStartTime
        )
    }
    
    private func dismissRestTimer() {
        guard let timer = activeRestTimer else { return }
        
        let completedExerciseCount = exercises.filter { ex in
            ex.sets.allSatisfy { $0.isCompleted } && !ex.sets.isEmpty
        }.count
        
        let currentExercise = exercises.first(where: { $0.name == timer.exerciseName })
        let nextSetIndex = currentExercise?.sets.firstIndex(where: { !$0.isCompleted })
        let nextSet = nextSetIndex != nil ? currentExercise?.sets[nextSetIndex!] : nil
        let lastCompleted = currentExercise?.sets.last(where: { $0.isCompleted })
        
        WorkoutLiveActivityManager.shared.updateRestDismissed(
            exerciseName: timer.exerciseName,
            nextSet: (nextSetIndex ?? (currentExercise?.sets.count ?? 1)) + 1,
            totalSets: currentExercise?.sets.count ?? 0,
            nextWeight: nextSet?.actualWeight ?? lastCompleted?.actualWeight,
            nextReps: nextSet?.actualReps ?? lastCompleted?.actualReps ?? 0,
            isBodyweight: currentExercise?.isBodyweight ?? false,
            workoutName: workoutName,
            totalExercises: exercises.count,
            completedExercises: completedExerciseCount,
            workoutStartTime: workoutStartTime
        )
        
        activeRestTimer = nil
    }
    
    private func restoreFromDraft(_ draft: WorkoutDraft) {
        workoutName = draft.workoutName
        exercises = WorkoutDraftManager.restoreExercises(from: draft)
        globalNotes = draft.globalNotes
        workoutStartTime = draft.workoutStartTime
        WorkoutDraftManager.clearDraft()
        SharedWorkoutStore.clear()
        print("✅ Workout restored from draft")
    }
    
    private func syncFromSharedState() {
        guard let shared = SharedWorkoutStore.load() else { return }
        
        // Sync sets logged from lock screen
        for (exIdx, sharedEx) in shared.exercises.enumerated() {
            guard exIdx < exercises.count else { continue }
            for (setIdx, sharedSet) in sharedEx.sets.enumerated() {
                guard setIdx < exercises[exIdx].sets.count else { continue }
                if sharedSet.isCompleted && !exercises[exIdx].sets[setIdx].isCompleted {
                    exercises[exIdx].sets[setIdx].isCompleted = true
                    exercises[exIdx].sets[setIdx].actualWeight = sharedSet.weight
                    exercises[exIdx].sets[setIdx].actualReps = sharedSet.reps
                }
            }
        }
        
        // If rest was skipped from lock screen, clear in-app timer
        if activeRestTimer != nil {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                if !activity.content.state.isResting {
                    activeRestTimer = nil
                    break
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date().formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            TextField("Workout Name", text: $workoutName)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)
                .textFieldStyle(.plain)
        }
    }
    
    // MARK: - Workout Summary Card (with volume)
    
    private var workoutSummaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRESS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                        .tracking(1.5)
                    
                    Text("\(workoutStats.completedSets) of \(workoutStats.totalSets) sets • \(workoutStats.elapsedMinutes) min")
                        .font(.system(size: 15))
                        .foregroundColor(.atlasText)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: progressPercentage)
                        .stroke(Color.atlasPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progressPercentage)
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                }
            }
            
            if workoutStats.totalVolume > 0 {
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 11))
                    Text("Volume: \(unitFormatter.displayVolume(workoutStats.totalVolume))")
                        .font(.system(size: 13))
                }
                .foregroundColor(.atlasTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(workoutInProgress ? Color.atlasPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Load from Plan
    
    private var loadFromPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LOAD FROM YOUR PLAN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            if availablePlanWorkouts.isEmpty {
                Text("No training plan found. Generate a plan in Training Schedule.")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(availablePlanWorkouts, id: \.id) { workout in
                        Button(action: { loadWorkoutFromPlan(workout) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.dayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.atlasText)
                                    Text("\(workout.exercises.count) exercises • \(dayName(for: workout.dayOfWeek))")
                                        .font(.system(size: 13))
                                        .foregroundColor(.atlasTextMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.atlasTextMuted)
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Add Exercise Button (empty state)
    
    private var addExerciseButton: some View {
        Button(action: { showingExercisePicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)
                Text("Add Exercise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasText)
                Spacer()
            }
            .padding(16)
            .background(Color.atlasPrimary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Exercise List with Drag-to-Reorder
    
    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("EXERCISES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
                Spacer()
                Text("Hold & drag to reorder")
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                ForEach(exercises) { exercise in
                    ExerciseLoggingCard(
                        exercise: binding(for: exercise),
                        modelContext: modelContext,
                        onSetCompleted: { exerciseName, setNumber in
                            handleSetCompleted(exerciseName: exerciseName, setNumber: setNumber)
                        },
                        onSwap: {
                            exerciseToSwap = exercise
                        },
                        onDelete: {
                            deleteExercise(exercise)
                        }
                    )
                    .opacity(draggingExercise?.id == exercise.id ? 0.5 : 1.0)
                    .onDrag {
                        self.draggingExercise = exercise
                        return NSItemProvider(object: exercise.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ExerciseDropDelegate(
                        exercise: exercise,
                        exercises: $exercises,
                        draggingExercise: $draggingExercise
                    ))
                }
            }
        }
    }
    
    private func binding(for exercise: LoggingExercise) -> Binding<LoggingExercise> {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else {
            fatalError("Exercise not found")
        }
        return $exercises[index]
    }
    
    // MARK: - Add Exercise Section (when exercises exist)
    
    private var addExerciseSection: some View {
        Button(action: { showingExercisePicker = true }) {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.atlasPrimary)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.atlasPrimary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Global Notes
    
    private var globalNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            TextEditor(text: $globalNotes)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .foregroundColor(.atlasText)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .overlay(
                    Group {
                        if globalNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Add notes about your workout...")
                                    .foregroundColor(.atlasTextMuted.opacity(0.6))
                                Text("• How you felt, energy levels")
                                    .foregroundColor(.atlasTextMuted.opacity(0.5))
                                Text("• What to remember next time")
                                    .foregroundColor(.atlasTextMuted.opacity(0.5))
                            }
                            .font(.system(size: 14))
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                        }
                    }
                )
        }
    }
    
    // MARK: - Complete Button
    
    private var completeButton: some View {
        Button(action: saveWorkout) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.atlasBackground)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Workout")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.atlasBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSave && !hasCompleted ? Color.atlasPrimary : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canSave || isSaving || hasCompleted)
    }
    
    // MARK: - Handle Set Completion
    
    private func handleSetCompleted(exerciseName: String, setNumber: Int) {
        // Start workout timer on first set
        if workoutStartTime == nil {
            workoutStartTime = Date()
            
            let startExercise = exercises.first(where: { $0.name == exerciseName })
            let firstSet = startExercise?.sets.first
            WorkoutLiveActivityManager.shared.startActivity(
                workoutName: workoutName,
                exerciseName: exerciseName,
                totalSets: startExercise?.sets.count ?? 0,
                totalExercises: exercises.count,
                nextWeight: firstSet?.actualWeight,
                nextReps: firstSet?.actualReps ?? 0,
                isBodyweight: startExercise?.isBodyweight ?? false
            )
        }
        
        guard let exerciseIndex = exercises.firstIndex(where: { $0.name == exerciseName }) else { return }
        let exercise = exercises[exerciseIndex]
        
        let completedSets = exercise.sets.filter { $0.isCompleted }.count
        let isLastSet = completedSets == exercise.sets.count
        
        // Generate coaching message
        if let message = generateCoachingMessage(
            exerciseName: exerciseName,
            setNumber: setNumber,
            isLastSet: isLastSet,
            exercise: exercise
        ) {
            activeCoachingMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) { activeCoachingMessage = message }
                DispatchQueue.main.asyncAfter(deadline: .now() + message.duration) {
                    withAnimation(.spring()) {
                        if activeCoachingMessage?.id == message.id {
                            activeCoachingMessage = nil
                        }
                    }
                }
            }
        }
        
        // Rest timer duration
        let definition = ExerciseLibrary.find(name: exerciseName)
        let restTime = definition?.suggestedRestTime ?? 90
        
        // Check if entire workout is done (no more incomplete sets anywhere)
        let isLastSetOfWorkout = isLastSet && !exercises.contains(where: { ex in
            ex.name != exerciseName && ex.sets.contains(where: { !$0.isCompleted })
        })
        
        // Calculate ONE shared end time for both timers
        let restEndDate = (isLastSet || isLastSetOfWorkout) ? nil : Date().addingTimeInterval(TimeInterval(restTime))
        
        // Start rest timer (not on last set of exercise, not on last set of workout)
        if !isLastSet && !isLastSetOfWorkout {
            withAnimation(.spring()) {
                activeRestTimer = RestTimer(
                    duration: restTime,
                    exerciseName: exerciseName,
                    setNumber: setNumber
                )
            }
        }
        
        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Update Live Activity
        let completedExerciseCount = exercises.filter { ex in
            ex.sets.allSatisfy { $0.isCompleted } && !ex.sets.isEmpty
        }.count
        
        let nextSetIndex = exercise.sets.firstIndex(where: { !$0.isCompleted })
        let nextSet = nextSetIndex != nil ? exercise.sets[nextSetIndex!] : nil
        let displaySet = nextSet ?? exercise.sets[setNumber]
        
        WorkoutLiveActivityManager.shared.updateSetCompleted(
            exerciseName: exerciseName,
            currentSet: (nextSetIndex ?? exercise.sets.count) + 1,
            totalSets: exercise.sets.count,
            nextWeight: displaySet.actualWeight,
            nextReps: displaySet.actualReps,
            isBodyweight: exercise.isBodyweight,
            restEndDate: restEndDate,
            workoutName: workoutName,
            totalExercises: exercises.count,
            completedExercises: completedExerciseCount,
            workoutStartTime: workoutStartTime
        )
        
        // Auto-save draft after each set completion
        saveDraft()
        
        // Save shared state for lock screen buttons
        let exerciseIdx = exercises.firstIndex(where: { $0.name == exerciseName }) ?? 0
        let sharedState = SharedWorkoutState(
            workoutName: workoutName,
            exercises: exercises.map { ex in
                SharedWorkoutState.SharedExercise(
                    name: ex.name,
                    exerciseId: ex.exerciseId,
                    sets: ex.sets.map { set in
                        SharedWorkoutState.SharedSet(
                            weight: set.actualWeight,
                            reps: set.actualReps,
                            isCompleted: set.isCompleted,
                            isBodyweight: set.isBodyweight
                        )
                    },
                    isBodyweight: ex.isBodyweight,
                    isTimed: ex.isTimed,
                    weightIncrement: ex.weightIncrement
                )
            },
            currentExerciseIndex: exerciseIdx,
            workoutStartTime: workoutStartTime
        )
        SharedWorkoutStore.save(sharedState)
    }
    
    private func generateCoachingMessage(
        exerciseName: String,
        setNumber: Int,
        isLastSet: Bool,
        exercise: LoggingExercise
    ) -> CoachingMessage? {
        
        if isLastSet {
            return CoachingMessage(
                type: .success,
                title: "\(exerciseName) done ✓",
                message: "All sets complete.",
                icon: "checkmark.circle.fill",
                duration: 3.0
            )
        }
        
        let definition = ExerciseLibrary.find(name: exerciseName)
        if setNumber == 2, let def = definition, def.isCompound, let cue = def.formCues.randomElement() {
            return CoachingMessage(
                type: .info,
                title: "Form check",
                message: cue,
                icon: "eye.fill",
                duration: 4.0
            )
        }
        
        return nil
    }
    
    // MARK: - Add Exercise from Library
    
    private func addExercise(_ definition: ExerciseDefinition) {
        let lastWorkout = WorkoutHistoryService.getLastWorkout(
            for: definition.name,
            modelContext: modelContext
        )
        
        let lastPerformance = lastWorkout.map { WorkoutHistoryService.formatLastPerformance($0) } ?? ""
        let hasHistory = lastWorkout != nil
        let lastWeight = lastWorkout?.sets.first?.weight
        
        var progressionSuggestion: String? = nil
        if let lastWorkout = lastWorkout {
            let history = WorkoutHistoryService.getExerciseHistory(
                for: definition.name,
                modelContext: modelContext,
                limit: 5
            )
            progressionSuggestion = WorkoutHistoryService.suggestProgression(
                for: lastWorkout,
                history: history
            ).recommendation
        }
        
        let sets = (0..<definition.defaultSets).map { _ in
            LoggingSet(
                plannedWeight: lastWeight,
                plannedReps: definition.defaultReps,
                actualWeight: lastWeight,
                actualReps: definition.defaultReps,
                isBodyweight: definition.isBodyweight,
                isTimed: definition.isTimed
            )
        }
        
        exercises.append(LoggingExercise(
            name: definition.name,
            exerciseId: definition.id,
            sets: sets,
            lastPerformance: lastPerformance,
            hasHistory: hasHistory,
            progressionSuggestion: progressionSuggestion,
            weightIncrement: definition.weightIncrement,
            isBodyweight: definition.isBodyweight,
            isTimed: definition.isTimed
        ))
    }
    
    // MARK: - Swap Exercise (Fix 5)
    
    private func swapExercise(_ exercise: LoggingExercise, with alternative: ExerciseAlternatives.Alternative) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        let lastWorkout = WorkoutHistoryService.getLastWorkout(
            for: alternative.name,
            modelContext: modelContext
        )
        let lastPerformance = lastWorkout.map { WorkoutHistoryService.formatLastPerformance($0) } ?? ""
        let hasHistory = lastWorkout != nil
        let lastWeight = lastWorkout?.sets.first?.weight
        
        // Preserve set count from current exercise, but update metadata
        let setCount = exercises[index].sets.count
        let completedSets = exercises[index].sets.filter { $0.isCompleted }
        
        let newSets = (0..<setCount).map { i -> LoggingSet in
            // Keep already-completed sets as-is
            if i < completedSets.count {
                return completedSets[i]
            }
            // New sets get the alternative's defaults
            return LoggingSet(
                plannedWeight: lastWeight,
                plannedReps: alternative.defaultReps,
                actualWeight: lastWeight,
                actualReps: alternative.defaultReps,
                isBodyweight: alternative.isBodyweight,
                isTimed: alternative.isTimed
            )
        }
        
        exercises[index] = LoggingExercise(
            name: alternative.name,
            exerciseId: alternative.id,
            sets: newSets,
            lastPerformance: lastPerformance,
            hasHistory: hasHistory,
            progressionSuggestion: nil,
            weightIncrement: alternative.weightIncrement,
            isBodyweight: alternative.isBodyweight,
            isTimed: alternative.isTimed
        )
        
        exerciseToSwap = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // MARK: - Delete Exercise (Fix 5)
    
    private func deleteExercise(_ exercise: LoggingExercise) {
        withAnimation(.easeInOut(duration: 0.25)) {
            exercises.removeAll { $0.id == exercise.id }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Load from Plan
    
    private func loadFromHabitIfNeeded() {
        guard let habit = habit,
            let dayOfWeek = habit.dayOfWeek else { return }
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let program = (try? modelContext.fetch(descriptor))?.first else { return }
        let workoutDays = program.isEventPlan
            ? (program.workoutWeeks.first { $0.weekNumber == (profiles.first?.currentEventWeek ?? 1) }?.days ?? [])
            : program.workoutDays
        guard let plannedDay = workoutDays.first(where: { $0.dayOfWeek == dayOfWeek }),
            plannedDay.dayType == "strength" else { return }
        loadWorkoutFromPlan(plannedDay)
    }
    
    private func loadWorkoutFromPlan(_ workout: PlannedWorkoutDay) {
        workoutName = workout.dayName
        
        exercises = workout.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { planned -> LoggingExercise in
                let lastWorkout = WorkoutHistoryService.getLastWorkout(
                    for: planned.name,
                    modelContext: modelContext
                )
                
                let lastPerformance = lastWorkout.map { WorkoutHistoryService.formatLastPerformance($0) } ?? ""
                let hasHistory = lastWorkout != nil
                let lastWeight = lastWorkout?.sets.first?.weight
                
                var progressionSuggestion: String? = nil
                if let lastWorkout = lastWorkout {
                    let history = WorkoutHistoryService.getExerciseHistory(
                        for: planned.name,
                        modelContext: modelContext,
                        limit: 5
                    )
                    progressionSuggestion = WorkoutHistoryService.suggestProgression(
                        for: lastWorkout,
                        history: history
                    ).recommendation
                }
                
                let definition = ExerciseLibrary.find(name: planned.name)
                let increment = definition?.weightIncrement ?? 5.0
                let isBodyweight = definition?.isBodyweight ?? planned.isBodyweight
                let isTimed = definition?.isTimed ?? false
                
                let sets = (0..<planned.targetSets).map { _ in
                    LoggingSet(
                        plannedWeight: lastWeight,
                        plannedReps: planned.targetRepsForLogging,
                        actualWeight: lastWeight,
                        actualReps: planned.targetRepsForLogging,
                        isBodyweight: isBodyweight,
                        isTimed: isTimed
                    )
                }
                
                return LoggingExercise(
                    name: planned.name,
                    exerciseId: definition?.id,
                    sets: sets,
                    lastPerformance: lastPerformance,
                    hasHistory: hasHistory,
                    progressionSuggestion: progressionSuggestion,
                    weightIncrement: increment,
                    isBodyweight: isBodyweight,
                    isTimed: isTimed
                )
            }
    }
    
    // MARK: - Save Workout
    
    private func saveWorkout() {
        // BUG-005: Guard against double-save — only execute once
        guard !hasCompleted else { return }
        hasCompleted = true
        isSaving = true
        Task { await performSave() }
    }
    
    private func performSave() async {
        let session = WorkoutSession(date: Date(), workoutName: workoutName)
        session.userProfile = userProfile
        session.notes = globalNotes.isEmpty ? nil : globalNotes
        
        var allPRs: [(exercise: String, prs: [PersonalRecord])] = []
        
        for (index, loggingExercise) in exercises.enumerated() {
            let completedSets = loggingExercise.sets.filter { $0.isCompleted }
            guard !completedSets.isEmpty else { continue }
            
            let exercise = Exercise(name: loggingExercise.name, orderIndex: index)
            exercise.workoutSession = session
            
            for (setIndex, loggingSet) in completedSets.enumerated() {
                let set = WorkoutSet(
                    setNumber: setIndex + 1,
                    weight: loggingSet.isBodyweight ? nil : loggingSet.actualWeight,
                    reps: loggingSet.actualReps,
                    isBodyweight: loggingSet.isBodyweight
                )
                set.rpe = loggingSet.rpe
                set.exercise = exercise
                exercise.sets.append(set)
            }
            
            modelContext.insert(exercise)
            session.exercises.append(exercise)
        }
        
        session.totalVolume = session.exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
        }
        session.totalSets = session.exercises.reduce(0) { $0 + $1.sets.count }
        session.exerciseCount = session.exercises.count
        if let start = workoutStartTime {
            session.durationMinutes = Int(Date().timeIntervalSince(start) / 60)
        }
        
        modelContext.insert(session)
        
        for exercise in session.exercises {
            let prs = WorkoutHistoryService.detectPRs(for: exercise, modelContext: modelContext)
            if !prs.isEmpty {
                allPRs.append((exercise: exercise.name, prs: prs))
            }
        }
        
        if let habit = habit {
            let dataController = DataController(modelContext: modelContext)
            dataController.markHabitComplete(habit)
        } else {
            // BUG-006: When launched ad-hoc (not from a specific habit card),
            // mark the matching training habit for today as complete so the
            // Today tab training card shows checked.
            markMatchingTrainingHabitComplete()
        }
        
        do {
            try modelContext.save()

            if let profile = userProfile {
                StrengthDataMerger.mergeAndUpdate(profile: profile, modelContext: modelContext)
            }
            
            WorkoutDraftManager.clearDraft()
            SharedWorkoutStore.clear()
            WorkoutLiveActivityManager.shared.endActivity()
            
            // FEAT-002: End Apple Watch workout session and save to HealthKit
            await WorkoutSessionManager.shared.endWorkoutSession()
            
            await MainActor.run {
                isSaving = false
                if !allPRs.isEmpty {
                    detectedPRs = allPRs
                    showPRCelebration = true
                    // PRCelebrationView dismissal will call onComplete + dismiss
                } else {
                    onComplete?()
                    dismiss()
                }
            }
        } catch {
            print("❌ Failed to save workout: \(error)")
            await MainActor.run {
                isSaving = false
                // Reset hasCompleted so user can retry on error
                hasCompleted = false
            }
        }
    }
    
    // MARK: - Helpers
    
    /// BUG-006: When launched ad-hoc (not via a Habit card reference), find and mark
    /// today's matching strength training habit complete so the Today tab updates.
    private func markMatchingTrainingHabitComplete() {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date()) - 1 // 0=Sun..6=Sat
        
        // Fetch all strength training habits for today's day of week
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { h in
                h.isTrainingHabit == true &&
                h.trainingDayType == "strength" &&
                h.isActive == true
            }
        )
        guard let trainingHabits = try? modelContext.fetch(habitDescriptor) else { return }
        
        let todaysHabit = trainingHabits.first { h in
            h.dayOfWeek == todayWeekday
        }
        
        if let matchedHabit = todaysHabit {
            let dataController = DataController(modelContext: modelContext)
            // Only mark if not already completed today
            if !dataController.isHabitComplete(habit: matchedHabit, on: Date()) {
                dataController.markHabitComplete(matchedHabit)
                print("✅ BUG-006: Marked training habit '\(matchedHabit.title)' complete for today")
            }
        } else {
            print("ℹ️ BUG-006: No strength training habit found for today (weekday \(todayWeekday)) — ad-hoc workout, no card to mark")
        }
    }
    
    private func dayName(for dayOfWeek: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard dayOfWeek >= 0 && dayOfWeek < days.count else { return "" }
        return days[dayOfWeek]
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Logging Data Models
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct LoggingExercise: Identifiable {
    let id = UUID()
    var name: String
    var exerciseId: String?
    var sets: [LoggingSet]
    var lastPerformance: String
    var hasHistory: Bool = true
    var progressionSuggestion: String?
    var weightIncrement: Double = 5.0
    var isBodyweight: Bool = false
    var isTimed: Bool = false
    
    var completedVolume: Double {
        sets.filter { $0.isCompleted }.reduce(0) { $0 + ($1.actualWeight ?? 0) * Double($1.actualReps) }
    }
    
    var hasCompletedSets: Bool {
        sets.contains { $0.isCompleted }
    }
}

struct LoggingSet: Identifiable {
    let id = UUID()
    var plannedWeight: Double?
    var plannedReps: Int
    var actualWeight: Double?
    var actualReps: Int
    var isBodyweight: Bool
    var isTimed: Bool = false
    var isCompleted: Bool = false
    var rpe: Int? = nil
}

struct WorkoutStats {
    let totalExercises: Int
    let totalSets: Int
    let completedSets: Int
    let elapsedMinutes: Int
    let totalVolume: Double
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Exercise Logging Card (with Swap + Delete)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ExerciseLoggingCard: View {
    @Binding var exercise: LoggingExercise
    let modelContext: ModelContext
    let onSetCompleted: (String, Int) -> Void
    var onSwap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Environment(\.unitFormatter) private var unitFormatter
    
    @State private var showDeleteConfirm = false
    
    private var hasAlternatives: Bool {
        ExerciseAlternatives.hasAlternatives(for: exercise.name)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Exercise header with swap/delete actions
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
                
                Text(exercise.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                if exercise.hasCompletedSets && exercise.completedVolume > 0 {
                    Text(unitFormatter.displayVolume(exercise.completedVolume))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                }
                
                // Swap button
                if hasAlternatives {
                    Button(action: { onSwap?() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.atlasPrimary.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Delete button
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.atlasTextMuted.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if !exercise.lastPerformance.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted)
                        Text("Last: \(exercise.lastPerformance)")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    if let suggestion = exercise.progressionSuggestion {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                                .foregroundColor(.atlasAccent)
                            Text(suggestion)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.atlasAccent)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            if !exercise.hasHistory {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAccent)
                    Text("First time — start light, find your working weight")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAccent)
                }
                .padding(10)
                .background(Color.atlasAccent.opacity(0.1))
                .cornerRadius(8)
            }
            
            VStack(spacing: 6) {
                ForEach($exercise.sets.indices, id: \.self) { index in
                    SetLoggingRow(
                        set: $exercise.sets[index],
                        setNumber: index,
                        weightIncrement: exercise.weightIncrement,
                        isBodyweight: exercise.isBodyweight,
                        isTimed: exercise.isTimed,
                        onCompleted: {
                            onSetCompleted(exercise.name, index)
                        }
                    )
                    .onChange(of: exercise.sets[index].actualWeight) { oldValue, newValue in
                        propagateWeight(from: index, oldValue: oldValue, newValue: newValue)
                    }
                    .onChange(of: exercise.sets[index].actualReps) { oldValue, newValue in
                        propagateReps(from: index, oldValue: oldValue, newValue: newValue)
                    }
                }
            }
            
            HStack {
                Button(action: addSet) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Set")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.atlasPrimary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if showFillRemaining {
                    Button(action: fillRemainingSets) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 12))
                            Text("Fill Remaining")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.atlasPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.atlasPrimary.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(exercise.hasCompletedSets ? Color.atlasPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .alert("Remove Exercise?", isPresented: $showDeleteConfirm) {
            Button("Remove", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(exercise.hasCompletedSets
                 ? "You have logged sets for \(exercise.name). Removing it will discard that data."
                 : "Remove \(exercise.name) from this workout?")
        }
    }
    
    private var showFillRemaining: Bool {
        let hasCompleted = exercise.sets.contains { $0.isCompleted }
        let hasUncompleted = exercise.sets.contains { !$0.isCompleted }
        return hasCompleted && hasUncompleted
    }
    
    // MARK: - Auto-fill Down Logic
    
    /// When weight changes on set N, propagate to subsequent sets that are uncompleted and still at default (0 or nil)
    private func propagateWeight(from index: Int, oldValue: Double?, newValue: Double?) {
        guard let newWeight = newValue else { return }
        for i in (index + 1)..<exercise.sets.count {
            guard !exercise.sets[i].isCompleted else { continue }
            // Only fill if the set is still at default (0 or nil = never manually edited)
            let currentWeight = exercise.sets[i].actualWeight ?? 0
            if currentWeight == 0 || currentWeight == (oldValue ?? 0) {
                exercise.sets[i].actualWeight = newWeight
            }
        }
    }
    
    /// When reps change on set N, propagate to subsequent sets that are uncompleted and still at their planned default
    private func propagateReps(from index: Int, oldValue: Int, newValue: Int) {
        for i in (index + 1)..<exercise.sets.count {
            guard !exercise.sets[i].isCompleted else { continue }
            // Only fill if the set still has the old value (i.e., hasn't been manually edited to something different)
            if exercise.sets[i].actualReps == oldValue {
                exercise.sets[i].actualReps = newValue
            }
        }
    }
    
    private func fillRemainingSets() {
        guard let sourceSet = exercise.sets.first(where: { $0.isCompleted }) else { return }
        
        for index in exercise.sets.indices {
            if !exercise.sets[index].isCompleted {
                exercise.sets[index].actualWeight = sourceSet.actualWeight
                exercise.sets[index].actualReps = sourceSet.actualReps
                exercise.sets[index].isCompleted = true
            }
        }
        
        if let lastIndex = exercise.sets.indices.last {
            onSetCompleted(exercise.name, lastIndex)
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func addSet() {
        let lastSet = exercise.sets.last
        exercise.sets.append(LoggingSet(
            plannedWeight: lastSet?.plannedWeight,
            plannedReps: lastSet?.plannedReps ?? 10,
            actualWeight: lastSet?.actualWeight,
            actualReps: lastSet?.actualReps ?? 10,
            isBodyweight: exercise.isBodyweight,
            isTimed: exercise.isTimed
        ))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Exercise Swap Sheet
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ExerciseSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let exerciseName: String
    let onSelect: (ExerciseAlternatives.Alternative) -> Void
    
    private var alternatives: [ExerciseAlternatives.Alternative] {
        ExerciseAlternatives.alternatives(for: exerciseName)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Current exercise header
                    VStack(spacing: 8) {
                        Text("SWAP EXERCISE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasAccent)
                            .tracking(2)
                        
                        Text(exerciseName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        if let def = ExerciseLibrary.find(name: exerciseName) {
                            Text("\(def.muscleGroup.rawValue) • \(def.category.rawValue)")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    if alternatives.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 36))
                                .foregroundColor(.atlasTextMuted)
                            Text("No alternatives found")
                                .font(.system(size: 16))
                                .foregroundColor(.atlasTextMuted)
                            Text("Ask your coach in chat for suggestions.")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(alternatives) { alt in
                                    Button(action: {
                                        onSelect(alt)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(alt.name)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.atlasText)
                                                
                                                Text(alt.reason)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.atlasTextMuted)
                                                
                                                Text(alt.equipment)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.atlasAccent)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.right.circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(.atlasPrimary)
                                        }
                                        .padding(16)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Set Logging Row
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct SetLoggingRow: View {
    @Environment(\.unitFormatter) private var unitFormatter
    @Binding var set: LoggingSet
    let setNumber: Int
    let weightIncrement: Double   // always in lbs (from ExerciseDefinition)
    let isBodyweight: Bool
    let isTimed: Bool
    let onCompleted: () -> Void
    
    @State private var showRPESelector = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("\(setNumber + 1)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(set.isCompleted ? .atlasPrimary : .atlasTextMuted)
                    .frame(width: 20)
                
                if !set.isCompleted {
                    editableSetRow
                } else {
                    completedSetRow
                }
                
                Spacer()
                
                Button(action: toggleCompletion) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .foregroundColor(set.isCompleted ? .atlasPrimary : .atlasTextMuted.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(set.isCompleted ? Color.atlasPrimary.opacity(0.08) : Color.clear)
            )
            
            if set.isCompleted && !showRPESelector && set.rpe == nil {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showRPESelector = true } }) {
                    Text("+ RPE")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                        .padding(.top, 2)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
            }
            
            if showRPESelector {
                rpeSelector
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            if set.isCompleted && set.rpe != nil && !showRPESelector {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { showRPESelector = true } }) {
                        Text("RPE \(set.rpe!)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.atlasAccent.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }
            }
        }
    }
    
    // BUG-B: binding that converts lbs↔display unit for the weight TextField
    private var displayWeightBinding: Binding<Double?> {
        Binding(
            get: {
                guard let lbs = set.actualWeight else { return nil }
                return unitFormatter.fromLbs(lbs)
            },
            set: { newDisplayValue in
                guard let val = newDisplayValue else { return }
                set.actualWeight = unitFormatter.toLbs(val)
            }
        )
    }

    private var editableSetRow: some View {
        HStack(spacing: 6) {
            if !isBodyweight {
                stepperButton(label: "-\(unitFormatter.incrementLabel(weightIncrement))", action: {
                    let lbsIncrement = unitFormatter.weightIncrementInLbs
                    set.actualWeight = max(0, (set.actualWeight ?? 0) - lbsIncrement)
                })
                
                // BUG-B: show weight in display unit (kg or lbs), store as lbs
                TextField("0", value: displayWeightBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.atlasText)
                    .font(.system(size: 15, weight: .medium))
                
                stepperButton(label: "+\(unitFormatter.incrementLabel(weightIncrement))", action: {
                    let lbsIncrement = unitFormatter.weightIncrementInLbs
                    set.actualWeight = (set.actualWeight ?? 0) + lbsIncrement
                })
            } else {
                Text("BW")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
                    .frame(width: 30)
            }
            
            Text("×")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasTextMuted.opacity(0.6))
            
            stepperButton(label: "−1", action: {
                set.actualReps = max(0, set.actualReps - 1)
            })
            
            TextField("0", value: $set.actualReps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 36)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.atlasText)
                .font(.system(size: 15, weight: .medium))
            
            stepperButton(label: "+1", action: {
                set.actualReps += 1
            })
        }
    }
    
    private var completedSetRow: some View {
        HStack(spacing: 4) {
            if !isBodyweight {
                Text("\(Int(set.actualWeight ?? 0))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.atlasText)
                Text(unitFormatter.weightUnit)
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
            } else {
                Text("BW")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
            }
            
            Text("×")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            
            Text("\(set.actualReps)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasText)
            
            Text(isTimed ? "sec" : "reps")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
        }
    }
    
    private var rpeSelector: some View {
        HStack(spacing: 6) {
            ForEach([6, 7, 8, 9, 10], id: \.self) { rpe in
                Button(action: {
                    set.rpe = rpe
                    withAnimation(.easeInOut(duration: 0.2)) { showRPESelector = false }
                }) {
                    VStack(spacing: 2) {
                        Text("\(rpe)")
                            .font(.system(size: 14, weight: .bold))
                        Text(rpeLabel(rpe))
                            .font(.system(size: 9))
                    }
                    .foregroundColor(set.rpe == rpe ? .atlasBackground : .atlasText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(set.rpe == rpe ? Color.atlasPrimary : Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private func toggleCompletion() {
        if !set.isCompleted {
            set.isCompleted = true
            onCompleted()
        } else {
            set.isCompleted = false
            set.rpe = nil
            showRPESelector = false
        }
    }
    
    private func stepperButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.atlasPrimary)
                .frame(width: 32, height: 32)
                .background(Color.atlasPrimary.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func rpeLabel(_ rpe: Int) -> String {
        switch rpe {
        case 6: return "Easy"
        case 7: return "Mod"
        case 8: return "Hard"
        case 9: return "V.Hard"
        case 10: return "Max"
        default: return ""
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Exercise Picker (Library-based)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let existingExerciseNames: Set<String>
    let onSelect: (ExerciseDefinition) -> Void
    
    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var showCreateCustom = false
    
    private var filteredExercises: [ExerciseDefinition] {
        var results: [ExerciseDefinition]
        if !searchText.isEmpty {
            results = ExerciseLibrary.searchIncludingCustom(searchText, modelContext: modelContext)
        } else if let group = selectedGroup {
            let all = ExerciseLibrary.allIncludingCustom(modelContext: modelContext)
            results = all.filter { $0.muscleGroup == group }
        } else {
            results = ExerciseLibrary.allIncludingCustom(modelContext: modelContext)
        }
        return results
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.atlasTextMuted)
                        TextField("Search exercises", text: $searchText)
                            .foregroundColor(.atlasText)
                            .onChange(of: searchText) { _, _ in
                                if !searchText.isEmpty { selectedGroup = nil }
                            }
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.atlasTextMuted)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            groupTab(label: "All", icon: "list.bullet", isSelected: selectedGroup == nil) {
                                selectedGroup = nil
                                searchText = ""
                            }
                            ForEach(MuscleGroup.allCases.sorted { $0.sortOrder < $1.sortOrder }) { group in
                                groupTab(
                                    label: group.shortName,
                                    icon: group.icon,
                                    isSelected: selectedGroup == group
                                ) {
                                    selectedGroup = group
                                    searchText = ""
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    
                    List {
                        // Create Custom Exercise button — always visible at top
                        Section {
                            Button {
                                showCreateCustom = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.atlasPrimary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Create Custom Exercise")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.atlasPrimary)
                                        Text("Add an exercise not in the library")
                                            .font(.system(size: 12))
                                            .foregroundColor(.atlasTextMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                                }
                            }
                            .listRowBackground(Color.atlasPrimary.opacity(0.08))
                        }
                        
                        ForEach(filteredExercises) { exercise in
                            let isAlreadyAdded = existingExerciseNames.contains(exercise.name)
                            let isCustom = ExerciseLibrary.isCustomExercise(id: exercise.id)
                            
                            Button(action: {
                                guard !isAlreadyAdded else { return }
                                onSelect(exercise)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(exercise.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(isAlreadyAdded ? .atlasTextMuted.opacity(0.4) : .atlasText)
                                            
                                            if isCustom {
                                                Text("Custom")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.atlasAmber)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Color.atlasAmber.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            Text(exercise.equipment.rawValue)
                                                .font(.system(size: 12))
                                            Text("•")
                                                .font(.system(size: 10))
                                            Text(exercise.category.rawValue)
                                                .font(.system(size: 12))
                                            if exercise.isUnilateral {
                                                Text("•")
                                                    .font(.system(size: 10))
                                                Text("Unilateral")
                                                    .font(.system(size: 12))
                                            }
                                        }
                                        .foregroundColor(isAlreadyAdded ? .atlasTextMuted.opacity(0.3) : .atlasTextMuted)
                                    }
                                    Spacer()
                                    if isAlreadyAdded {
                                        Text("Added")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.atlasTextMuted.opacity(0.4))
                                    }
                                }
                            }
                            .disabled(isAlreadyAdded)
                            .listRowBackground(Color.white.opacity(0.03))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .sheet(isPresented: $showCreateCustom) {
                CreateCustomExerciseView(
                    onCreated: { definition in
                        onSelect(definition)
                        dismiss()
                    },
                    prefillName: searchText
                )
            }
        }
    }
    
    private func groupTab(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .atlasBackground : .atlasText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.atlasPrimary : Color.white.opacity(0.08))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Drag and Drop Delegate
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ExerciseDropDelegate: DropDelegate {
    let exercise: LoggingExercise
    @Binding var exercises: [LoggingExercise]
    @Binding var draggingExercise: LoggingExercise?
    
    func performDrop(info: DropInfo) -> Bool {
        draggingExercise = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingExercise,
              dragging.id != exercise.id,
              let from = exercises.firstIndex(where: { $0.id == dragging.id }),
              let to = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        withAnimation(.spring()) {
            exercises.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Coaching Message
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct CoachingMessage: Identifiable {
    let id = UUID()
    let type: MessageType
    let title: String
    let message: String
    let icon: String
    let duration: Double
    
    enum MessageType {
        case success, warning, info
        var color: Color {
            switch self {
            case .success: return .atlasPrimary
            case .warning: return .orange
            case .info: return .atlasAccent
            }
        }
    }
}

struct CoachingMessageCard: View {
    let message: CoachingMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.icon)
                .font(.system(size: 20))
                .foregroundColor(message.type.color)
                .frame(width: 36, height: 36)
                .background(message.type.color.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasText)
                Text(message.message)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.atlasBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 15, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.type.color.opacity(0.5), lineWidth: 1)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Rest Timer
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RestTimer: ObservableObject {
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = true
    let duration: Int
    let exerciseName: String
    let setNumber: Int
    
    private var timer: Timer?
    private var backgroundDate: Date?
    private let backgroundManager = BackgroundTimerManager.shared
    
    init(duration: Int, exerciseName: String, setNumber: Int) {
        self.duration = duration
        self.remainingSeconds = duration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        
        backgroundManager.enableBackgroundTimer()
        backgroundManager.preventScreenSleep()
        backgroundManager.beginBackgroundTask()
        
        requestNotificationPermissionIfNeeded()
        setupLifecycleObservers()
        startTimer()
    }
    
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        backgroundDate = Date()
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func appWillEnterForeground() {
        if let bgDate = backgroundDate {
            let elapsed = Int(Date().timeIntervalSince(bgDate))
            remainingSeconds = max(0, remainingSeconds - elapsed)
            if remainingSeconds == 0 {
                complete()
                return
            }
        }
        backgroundDate = nil
        startTimer()
    }
    
    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.complete()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        backgroundManager.allowScreenSleep()
    }
    
    func resume() {
        backgroundManager.preventScreenSleep()
        startTimer()
    }
    
    func addTime(_ seconds: Int) {
        remainingSeconds += seconds
        if !isRunning {
            backgroundManager.preventScreenSleep()
            startTimer()
        }
    }
    
    private func complete() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        if UIApplication.shared.applicationState != .active {
            sendCompletionNotification()
        }
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Ready for \(exerciseName) — Set \(setNumber + 1)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "rest-timer-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    deinit {
        timer?.invalidate()
        backgroundManager.disableBackgroundTimer()
        backgroundManager.allowScreenSleep()
        backgroundManager.endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Rest Timer Card

struct RestTimerCard: View {
    @ObservedObject var timer: RestTimer
    let onDismiss: () -> Void
    let onAddTime: () -> Void
    
    private var progress: Double {
        guard timer.duration > 0 else { return 0 }
        return 1.0 - (Double(timer.remainingSeconds) / Double(timer.duration))
    }
    
    private var isComplete: Bool { timer.remainingSeconds == 0 }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REST")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                        .tracking(1.5)
                    Text("Next: \(timer.exerciseName) — Set \(timer.setNumber + 1)")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            HStack(spacing: 16) {
                Text(timeString(timer.remainingSeconds))
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundColor(isComplete ? .atlasPrimary : .atlasText)
                    .monospacedDigit()
                
                Spacer()
                
                if !isComplete {
                    HStack(spacing: 12) {
                        Button(action: { timer.isRunning ? timer.pause() : timer.resume() }) {
                            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.atlasText)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        Button(action: onAddTime) {
                            Text("+30s")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.atlasText)
                                .frame(width: 50, height: 40)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Ready!")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.atlasPrimary)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isComplete ? Color.atlasPrimary : Color.atlasAccent)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.atlasBackground)
                .shadow(color: Color.black.opacity(0.3), radius: 20, y: -5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isComplete ? Color.atlasPrimary : Color.atlasAccent.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Keyboard Dismissal
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    WorkoutLogView()
}