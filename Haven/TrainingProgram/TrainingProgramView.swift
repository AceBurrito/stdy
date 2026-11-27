import SwiftUI
import SwiftData

struct TrainingProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<TrainingProgram> { $0.isActive == true })
    private var activePrograms: [TrainingProgram]
    
    @State private var showingChangePlan = false
    @State private var showingEventSetupSheet = false
    @State private var viewingWeek: Int = 1
    @State private var isLoadingWeek = false
    @State private var trainingTab: TrainingTabSelection = .schedule

    enum TrainingTabSelection: String, CaseIterable {
        case schedule = "Schedule"
        case routines = "Routines"
    }

    // No-plan empty state sheet triggers
    @State private var showNoPlanBrowse = false
    @State private var showNoPlanCustom = false
    @State private var showNoPlanEvent = false

    // Day reassignment state
    @State private var workoutToMove: PlannedWorkoutDay? = nil

    // Workout detail sheet (item-based to fix blank sheet bug)
    @State private var sheetWorkout: PlannedWorkoutDay? = nil

    private func ensureWeekDataExists(weekNumber: Int) {
        if activeProgram?.workoutWeeks.first(where: { $0.weekNumber == weekNumber }) != nil {
            return
        }
        
        guard let profile = userProfile else { return }
        
        isLoadingWeek = true
        
        Task {
            do {
                let _ = try await EventPlanGenerator.ensureWeekExists(
                    profile: profile,
                    modelContext: modelContext,
                    weekNumber: weekNumber
                )
                
                await MainActor.run {
                    isLoadingWeek = false
                }
            } catch {
                print("❌ Failed to load week \(weekNumber): \(error)")
                await MainActor.run {
                    isLoadingWeek = false
                }
            }
        }
    }
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var activeProgram: TrainingProgram? {
        activePrograms.first
    }
    
    private var isEventPlan: Bool {
        activeProgram?.isEventPlan ?? false
    }
    
    private var currentEventWeek: Int {
        userProfile?.currentEventWeek ?? 1
    }
    
    private var totalWeeks: Int {
        activeProgram?.totalWeeks ?? 1
    }
    
    private var currentWeekData: PlannedWorkoutWeek? {
        let week = activeProgram?.workoutWeeks.first { $0.weekNumber == viewingWeek }
        return week
    }
    
    private var workoutDaysForDisplay: [PlannedWorkoutDay] {
        if isEventPlan {
            return currentWeekData?.days.sorted { $0.dayOfWeek < $1.dayOfWeek } ?? []
        } else {
            return activeProgram?.workoutDays.sorted { $0.dayOfWeek < $1.dayOfWeek } ?? []
        }
    }
    
    // Full 7-day week: real workouts + rest day placeholders
    private var fullWeekForDisplay: [PlannedWorkoutDay] {
        let realDays = workoutDaysForDisplay
        var allDays: [PlannedWorkoutDay] = []
        
        for dayIndex in 0..<7 {
            if let realDay = realDays.first(where: { $0.dayOfWeek == dayIndex }) {
                allDays.append(realDay)
            } else {
                let restDay = PlannedWorkoutDay(dayType: "rest", dayName: "Rest Day", dayOfWeek: dayIndex, orderIndex: dayIndex)
                allDays.append(restDay)
            }
        }
        
        return allDays
    }
    
    private var todayDayOfWeek: Int {
        Calendar.current.component(.weekday, from: Date()) - 1
    }
    
    private var daysUntilEvent: Int? {
        guard let eventDate = userProfile?.eventDate ?? activeProgram?.eventDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let event = calendar.startOfDay(for: eventDate)
        return calendar.dateComponents([.day], from: today, to: event).day
    }
    
    private var eventHasPassed: Bool {
        guard let days = daysUntilEvent else { return false }
        return days < 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                if let program = activeProgram {
                    VStack(spacing: 0) {
                        // Segmented control (only for non-event plans)
                        if !isEventPlan {
                            Picker("", selection: $trainingTab) {
                                ForEach(TrainingTabSelection.allCases, id: \.self) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        }

                        if trainingTab == .routines && !isEventPlan {
                            RoutinesListView()
                        } else {
                            ScrollView {
                                VStack(spacing: 24) {
                                    // UX-001: One-time training intro card for new users
                                    if let profile = userProfile, !profile.hasSeenTrainingIntro {
                                        TrainingIntroCard(program: program) {
                                            userProfile?.hasSeenTrainingIntro = true
                                            try? modelContext.save()
                                        }
                                    }
                                    
                                    if isEventPlan {
                                        eventCountdownSection
                                    }
                                    
                                    if isEventPlan && totalWeeks > 1 {
                                        weekSelectorSection
                                    }
                                    
                                    headerSection(program: program)
                                    scheduleSection
                                    bottomActionsSection
                                    
                                    Spacer().frame(height: 40)
                                }
                                .padding(24)
                            }
                        }
                    }
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Training Program")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            
            // Workout detail sheet (item-based — fixes blank sheet bug)
            .sheet(item: $sheetWorkout) { workout in
                if workout.dayType == "strength" || workout.exercises.count > 0 {
                    PlannedWorkoutDetailView(workoutDay: workout)
                } else {
                    CardioWorkoutDetailView(workoutDay: workout)
                }
            }
            .sheet(isPresented: $showingChangePlan) {
                ChangePlanView()
            }
            .sheet(isPresented: $showingEventSetupSheet) {
                EventCreationFlow()
            }
            .sheet(item: $workoutToMove) { workout in
                DayReassignmentView(
                    workout: workout,
                    allWorkouts: workoutDaysForDisplay,
                    onSelect: { newDay in
                        reassignWorkoutToDay(workout, newDay: newDay)
                    }
                )
            }
            .onAppear {
                checkEventStatus()
                if isEventPlan {
                    viewingWeek = currentEventWeek
                }
            }
        }
    }
    
    // MARK: - Week Selector Section
    private var weekSelectorSection: some View {
        let maxViewableWeek = totalWeeks
        
        return VStack(spacing: 12) {
            HStack {
                Button(action: {
                    if viewingWeek > 1 {
                        viewingWeek -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(viewingWeek > 1 ? .atlasPrimary : .atlasTextMuted.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                }
                .disabled(viewingWeek <= 1)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("WEEK \(viewingWeek) OF \(totalWeeks)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(viewingWeek == currentEventWeek ? .atlasPrimary : .atlasText)
                        .tracking(1)
                    
                    if let weekData = currentWeekData {
                        Text(weekData.phaseName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.atlasAccent)
                        
                        if let focus = weekData.weekFocus {
                            Text(focus)
                                .font(.system(size: 11))
                                .foregroundColor(.atlasTextMuted)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    } else {
                        Text("Loading...")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    if viewingWeek == currentEventWeek {
                        Text("CURRENT WEEK")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.atlasBackground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.atlasPrimary)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if viewingWeek < maxViewableWeek {
                        viewingWeek += 1
                        ensureWeekDataExists(weekNumber: viewingWeek)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(viewingWeek < maxViewableWeek ? .atlasPrimary : .atlasTextMuted.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                }
                .disabled(viewingWeek >= maxViewableWeek)
            }
            
            if viewingWeek != currentEventWeek {
                Button(action: { viewingWeek = currentEventWeek }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12))
                        Text("Jump to Current Week")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.atlasPrimary)
                    .padding(.vertical, 8)
                }
            }
            
            if viewingWeek > currentEventWeek {
                Text("Preview • Your complete plan based on proven training methods")
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted)
                    .italic()
            }
            
            weekProgressBar
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Week Progress Bar
    private var weekProgressBar: some View {
        VStack(spacing: 8) {
            if let program = activeProgram, let phasesJSON = program.phasesJSON,
               let phasesData = phasesJSON.data(using: .utf8),
               let phases = try? JSONDecoder().decode([String: [Int]].self, from: phasesData) {
                
                GeometryReader { geometry in
                    let width = geometry.size.width
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(Color.atlasPrimary)
                            .frame(width: width * CGFloat(currentEventWeek) / CGFloat(totalWeeks), height: 6)
                            .cornerRadius(3)
                        
                        Circle()
                            .fill(viewingWeek == currentEventWeek ? Color.atlasPrimary : Color.atlasAccent)
                            .frame(width: 12, height: 12)
                            .offset(x: width * CGFloat(viewingWeek - 1) / CGFloat(max(totalWeeks - 1, 1)) - 6)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    ForEach(["base", "build", "peak", "taper"], id: \.self) { phase in
                        if let range = phases[phase], range.count == 2 {
                            Text(phase.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(currentWeekData?.phaseName.lowercased() == phase ? .atlasPrimary : .atlasTextMuted)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Event Countdown Section
    private var eventCountdownSection: some View {
        VStack(spacing: 12) {
            if eventHasPassed {
                eventCompletedCard
            } else if let days = daysUntilEvent {
                let eventName = userProfile?.eventName ?? userProfile?.eventType ?? activeProgram?.eventType ?? "Event"
                
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(days)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.atlasPrimary)
                        Text("days")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(width: 70)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UNTIL \(eventName.uppercased())")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasAccent)
                            .tracking(1.5)
                        
                        if let eventDate = userProfile?.eventDate ?? activeProgram?.eventDate {
                            Text(eventDate.formatted(date: .long, time: .omitted))
                                .font(.system(size: 15))
                                .foregroundColor(.atlasText)
                        }
                        
                        if let weekData = currentWeekData {
                            Text("\(weekData.phaseName) Phase • Week \(currentEventWeek)/\(totalWeeks)")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.atlasPrimary.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Event Completed Card
    private var eventCompletedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundColor(.yellow)
            
            VStack(spacing: 4) {
                Text("🎉 Event Complete!")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                if let eventName = userProfile?.eventName ?? userProfile?.eventType {
                    Text("How did \(eventName) go?")
                        .font(.system(size: 15))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    switchToLongevityMode()
                    showingChangePlan = true
                }) {
                    Text("Choose a New Training Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.atlasPrimary)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingEventSetupSheet = true }) {
                    Text("Train for Another Event")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Header
    private func headerSection(program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEventPlan {
                Text(program.eventType?.uppercased() ?? "EVENT TRAINING")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
            } else {
                Text("YOUR TRAINING WEEK")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
            }
            
            if let splitType = program.splitType, !isEventPlan {
                Text(formatSplitType(splitType))
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.atlasText)
            } else if isEventPlan, let weekData = currentWeekData {
                Text("Week \(viewingWeek): \(weekData.phaseName)")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.atlasText)
            } else {
                Text("Training Schedule")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.atlasText)
            }
            
            HStack(spacing: 12) {
                Label("\(program.daysPerWeek) days/week", systemImage: "calendar")
                if let volume = currentWeekData?.totalVolume {
                    Label(volume, systemImage: "clock")
                } else {
                    Label("\(program.minutesPerSession) min", systemImage: "clock")
                }
            }
            .font(.system(size: 14))
            .foregroundColor(.atlasTextMuted)
            
            if let summary = program.programSummary {
                Text(summary)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(spacing: 12) {
            ForEach(fullWeekForDisplay, id: \.dayOfWeek) { day in
                let isRestPlaceholder = !workoutDaysForDisplay.contains(where: { $0.id == day.id })
                
                TrainingDayCard(
                    workoutDay: day,
                    isToday: day.dayOfWeek == todayDayOfWeek && (!isEventPlan || viewingWeek == currentEventWeek),
                    isEventPlan: isEventPlan,
                    isRestPlaceholder: isRestPlaceholder,
                    onTap: {
                        guard !isRestPlaceholder else { return }
                        if day.dayType == "strength" || day.exercises.count > 0 {
                            sheetWorkout = day
                        } else if day.dayType == "cardio" || day.dayType == "run" || day.dayType == "bike" || day.dayType == "swim" {
                            sheetWorkout = day
                        }
                    },
                    onMoveTap: {
                        workoutToMove = day
                    }
                )
            }
        }
    }
    
    // MARK: - Bottom Actions Section
    private var bottomActionsSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Change Plan button
            Button(action: { showingChangePlan = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                    
                    Text("Change Plan")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.atlasPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.atlasPrimary.opacity(0.12))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Event Training CTA
            if !isEventPlan {
                Button(action: { showingEventSetupSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                        
                        Text("Training for an event?")
                            .font(.system(size: 15, weight: .medium))
                        
                        Text("Marathon, Hyrox, Triathlon...")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .foregroundColor(.atlasAccent)
                    .padding(.vertical, 12)
                }
            } else {
                Button(action: {
                    switchToLongevityMode()
                    showingChangePlan = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14))
                        
                        Text("Switch back to Longevity Training")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.atlasTextMuted)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Empty State (No Plan — Never a Dead End)
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)
                
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 48))
                    .foregroundColor(.atlasPrimary.opacity(0.4))
                
                VStack(spacing: 8) {
                    Text("No Active Training Plan")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text("Choose how you want to train:")
                        .font(.system(size: 15))
                        .foregroundColor(.atlasTextMuted)
                }
                
                VStack(spacing: 12) {
                    // Browse catalog plans
                    Button(action: { showNoPlanBrowse = true }) {
                        NoPlanOptionCard(
                            icon: "list.bullet.clipboard",
                            iconColor: .atlasPrimary,
                            title: "Browse Training Plans",
                            subtitle: "Curated programs for every level"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Build custom
                    Button(action: { showNoPlanCustom = true }) {
                        NoPlanOptionCard(
                            icon: "hammer.fill",
                            iconColor: .atlasPrimary,
                            title: "Build Custom Program",
                            subtitle: "Design your own weekly schedule"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Event training
                    Button(action: { showNoPlanEvent = true }) {
                        NoPlanOptionCard(
                            icon: "trophy.fill",
                            iconColor: .atlasAmber,
                            title: "Train for an Event",
                            subtitle: "HYROX, marathon, triathlon, and more"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showNoPlanBrowse) {
            NavigationStack {
                NoPlanBrowseWrapper()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showNoPlanBrowse = false }
                                .foregroundColor(.atlasPrimary)
                        }
                    }
            }
        }
        .sheet(isPresented: $showNoPlanCustom) {
            CustomPlanBuilderView(
                onComplete: { showNoPlanCustom = false },
                onBack: { showNoPlanCustom = false }
            )
        }
        .sheet(isPresented: $showNoPlanEvent) {
            EventCreationFlow(onComplete: {
                showNoPlanEvent = false
            })
        }
    }
    
    // MARK: - Helpers
    
    private func formatSplitType(_ split: String) -> String {
        switch split.lowercased() {
        case "upper_lower": return "Upper/Lower Split"
        case "push_pull_legs", "ppl": return "Push/Pull/Legs"
        case "full_body": return "Full Body"
        case "bro_split": return "Body Part Split"
        case "event_specific": return "Event Training"
        default: return split.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    private func checkEventStatus() {
        guard let profile = userProfile else { return }
        
        // Advance event week if needed (inline replacement for TrainingPlanGenerator.checkAndAdvanceEventWeek)
        if profile.trainingMode == "event",
           let startDate = profile.eventPlanStartDate,
           let lastAdvance = profile.lastEventWeekAdvanceDate {
            let calendar = Calendar.current
            let daysSinceLastAdvance = calendar.dateComponents([.day], from: lastAdvance, to: Date()).day ?? 0
            if daysSinceLastAdvance >= 7 {
                let weeksToAdvance = daysSinceLastAdvance / 7
                let newWeek = min(profile.currentEventWeek + weeksToAdvance, totalWeeks)
                if newWeek != profile.currentEventWeek {
                    profile.currentEventWeek = newWeek
                    profile.lastEventWeekAdvanceDate = calendar.date(byAdding: .day, value: weeksToAdvance * 7, to: lastAdvance)
                    try? modelContext.save()
                }
            }
            viewingWeek = profile.currentEventWeek
        }
    }

    private func reassignWorkoutToDay(_ workout: PlannedWorkoutDay, newDay: Int) {
        let oldDay = workout.dayOfWeek
        
        // If there's a workout on the target day, swap them
        if let existingWorkout = workoutDaysForDisplay.first(where: { $0.dayOfWeek == newDay && $0.id != workout.id }) {
            existingWorkout.dayOfWeek = oldDay
        }
        
        workout.dayOfWeek = newDay
        
        // Mark as user-edited
        if let program = activeProgram {
            program.hasUserEdits = true
        }
        
        try? modelContext.save()
        
        // Refresh training habits to reflect new day assignments
        if let profile = userProfile {
            TrainingHabitManager.createTrainingHabits(
                profile: profile,
                modelContext: modelContext
            )
        }
        
        print("✅ Moved \(workout.dayName) from day \(oldDay) to day \(newDay)")
    }
    
    private func switchToLongevityMode() {
        guard let profile = userProfile else { return }
        
        print("🔄 [TrainingProgramView] Switching from event training to longevity mode")
        
        let masterPlanDescriptor = FetchDescriptor<EventMasterPlan>(
            predicate: #Predicate { $0.isActive == true }
        )
        if let masterPlans = try? modelContext.fetch(masterPlanDescriptor) {
            for plan in masterPlans {
                plan.isActive = false
            }
        }
        
        let programDescriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true && $0.isEventPlan == true }
        )
        if let programs = try? modelContext.fetch(programDescriptor) {
            for program in programs {
                program.isActive = false
            }
        }
        
        let assessmentDescriptor = FetchDescriptor<UserCapabilityAssessment>()
        if let assessments = try? modelContext.fetch(assessmentDescriptor) {
            for assessment in assessments.filter({ $0.userProfile?.id == profile.id }) {
                modelContext.delete(assessment)
            }
        }
        
        profile.trainingMode = "longevity"
        profile.isTrainingForEvent = false
        profile.eventType = nil
        profile.eventName = nil
        profile.eventDate = nil
        profile.hasExistingPlan = false
        profile.existingPlanDetails = nil
        profile.existingPlanWeek = nil
        profile.eventCompletedDate = nil
        profile.currentEventWeek = 1
        profile.eventPlanStartDate = nil
        profile.lastEventWeekAdvanceDate = nil
        
        do {
            try modelContext.save()
            print("✅ [TrainingProgramView] Successfully switched to longevity mode")
        } catch {
            print("❌ [TrainingProgramView] Error saving longevity mode switch: \(error)")
        }
    }
}

// MARK: - Training Day Card

struct TrainingDayCard: View {
    let workoutDay: PlannedWorkoutDay
    let isToday: Bool
    var isEventPlan: Bool = false
    var isRestPlaceholder: Bool = false
    var onTap: (() -> Void)? = nil
    var onMoveTap: (() -> Void)? = nil
    
    private var dayName: String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard workoutDay.dayOfWeek >= 0 && workoutDay.dayOfWeek < days.count else { return "?" }
        return days[workoutDay.dayOfWeek]
    }
    
    private var isStrength: Bool {
        workoutDay.dayType == "strength"
    }
    
    private var isTappable: Bool {
        guard !isRestPlaceholder else { return false }
        return workoutDay.dayType == "strength" ||
        workoutDay.dayType == "cardio" ||
        workoutDay.dayType == "run" ||
        workoutDay.dayType == "bike" ||
        workoutDay.dayType == "swim" ||
        workoutDay.dayType == "mobility" ||
        workoutDay.exercises.count > 0
    }
    
    private var workoutDisplayName: String {
        if isRestPlaceholder { return "Rest Day" }
        
        if let activityName = workoutDay.userActivityName, !activityName.isEmpty {
            return activityName
        }
        
        if workoutDay.dayType == "strength" {
            return workoutDay.dayName
        } else if workoutDay.dayType == "cardio" || workoutDay.dayType == "run" || workoutDay.dayType == "bike" || workoutDay.dayType == "swim" {
            if let duration = workoutDay.cardioDuration {
                return "\(duration) min Cardio"
            } else {
                return "Cardio Workout"
            }
        } else if workoutDay.dayType == "mobility" {
            if let duration = workoutDay.cardioDuration {
                return "\(duration) min Mobility"
            } else {
                return "Mobility"
            }
        } else if workoutDay.dayType == "rest" {
            return "Rest Day"
        } else if workoutDay.isBrickWorkout {
            return workoutDay.dayName
        } else {
            return workoutDay.dayName
        }
    }
    
    private var isRest: Bool {
        isRestPlaceholder || workoutDay.dayType == "rest"
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Day badge — tap to move (only for real workouts)
            if !isRest {
                Button(action: { onMoveTap?() }) {
                    VStack(spacing: 2) {
                        Text(dayName.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isToday ? .atlasBackground : .atlasTextMuted)
                        
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 9))
                            .foregroundColor(isToday ? .atlasBackground.opacity(0.7) : .atlasTextMuted.opacity(0.5))
                    }
                    .frame(width: 44, height: 60)
                    .background(isToday ? Color.atlasPrimary : Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Rest day badge — not tappable
                VStack(spacing: 2) {
                    Text(dayName.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isToday ? .atlasBackground : .atlasTextMuted.opacity(0.5))
                }
                .frame(width: 44, height: 60)
                .background(isToday ? Color.atlasPrimary.opacity(0.5) : Color.white.opacity(0.03))
                .cornerRadius(10)
            }
            
            // Workout card — tap to open detail
            Button(action: { onTap?() }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(workoutDisplayName)
                                .font(.system(size: 16, weight: isToday && !isRest ? .semibold : .medium))
                                .foregroundColor(isRest ? .atlasTextMuted : .atlasText)
                            
                            if !isRest,
                               let cardioType = workoutDay.cardioType,
                               workoutDay.dayType != "rest",
                               workoutDay.dayType != "mobility" {
                                zonePill(cardioType)
                            }
                        }
                        
                        if !isRest {
                            workoutSubtitle
                        } else {
                            Text("Recovery")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: isRest ? "moon.fill" : iconForType(workoutDay.dayType))
                            .font(.system(size: 18))
                            .foregroundColor(isRest ? .atlasTextMuted.opacity(0.3) : colorForType(workoutDay.dayType))
                        
                        if isTappable {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
                .padding(16)
                .background(
                    isRest ? Color.white.opacity(0.02) :
                    (isToday ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday && !isRest ? Color.atlasPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isTappable)
        }
    }
    
    private func zonePill(_ type: String) -> some View {
        Text(formatZoneType(type))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.atlasBackground)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(colorForZone(type))
            .cornerRadius(4)
    }
    
    @ViewBuilder
    private var workoutSubtitle: some View {
        if workoutDay.dayType == "strength" {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(workoutDay.exercises.count) exercises")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                
                // FEAT-003: Show secondary cardio if present
                if workoutDay.hasSecondaryCardio,
                   let duration = workoutDay.secondaryCardioDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.atlasAmber)
                        Text("+ \(workoutDay.secondaryCardioZone ?? "Zone 2") · \(duration) min")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasAmber)
                    }
                }
            }
                
        } else if workoutDay.dayType == "rest" {
            Text("Recovery")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                
        } else if workoutDay.dayType == "mobility" {
            if let duration = workoutDay.cardioDuration {
                Text("\(duration) min • Flexibility & recovery")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            } else {
                Text("Flexibility & recovery")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
            
        } else if workoutDay.isBrickWorkout {
            if let structure = workoutDay.workoutStructure {
                Text(structure)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .lineLimit(1)
            } else if let duration = workoutDay.cardioDuration {
                Text("\(duration) min • Multi-sport")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }
            
        } else if let distance = workoutDay.targetDistance, let unit = workoutDay.distanceUnit {
            HStack(spacing: 4) {
                Text(String(format: "%.1f %@", distance, unit))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasAccent)
                
                if let duration = workoutDay.cardioDuration {
                    Text("• ~\(duration) min")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
        } else if workoutDay.dayType == "cardio" || workoutDay.dayType == "run" || workoutDay.dayType == "bike" || workoutDay.dayType == "swim" {
            if let activityName = workoutDay.userActivityName, !activityName.isEmpty {
                if let duration = workoutDay.cardioDuration {
                    Text("\(duration) min")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                } else {
                    Text("Cardio workout")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
            } else if let proto = workoutDay.cardioProtocol, !proto.isEmpty {
                Text(proto)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasAccent)
                    .lineLimit(1)
            } else if let duration = workoutDay.cardioDuration {
                Text("\(duration) min • Run, bike, row, or swim")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            } else {
                Text("Run, bike, row, or swim")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
            
        } else if let duration = workoutDay.cardioDuration {
            Text("\(duration) min")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                
        } else {
            Text(workoutDay.dayType.capitalized)
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio": return "figure.run"
        case "run": return "figure.run"
        case "bike": return "figure.outdoor.cycle"
        case "swim": return "figure.pool.swim"
        case "mobility": return "figure.flexibility"
        case "brick": return "arrow.triangle.2.circlepath"
        case "rest": return "moon.fill"
        default: return "circle.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "strength": return .atlasPrimary
        case "cardio", "run": return .atlasAccent
        case "bike": return .green
        case "swim": return .blue
        case "mobility": return .purple
        case "brick": return .orange
        case "rest": return .atlasTextMuted.opacity(0.5)
        default: return .atlasTextMuted
        }
    }
    
    private func formatZoneType(_ type: String) -> String {
        switch type.lowercased() {
        case "zone2": return "ZONE 2"
        case "vo2max", "hiit": return "VO2 MAX"
        case "tempo": return "TEMPO"
        default: return type.uppercased()
        }
    }
    
    private func colorForZone(_ type: String) -> Color {
        switch type.lowercased() {
        case "zone2": return .atlasPrimary
        case "vo2max", "hiit": return .orange
        case "tempo": return .yellow
        default: return .atlasAccent
        }
    }
}

// MARK: - UX-001: Training Program Intro Card (shown once after onboarding)

struct TrainingIntroCard: View {
    let program: TrainingProgram
    let onDismiss: () -> Void
    
    private var strengthDayCount: Int {
        program.workoutDays.filter { $0.dayType == "strength" }.count
    }
    
    private var cardioDayCount: Int {
        program.workoutDays.filter { $0.dayType == "cardio" }.count
    }
    
    private var weeklyStructure: String {
        var parts: [String] = []
        if strengthDayCount > 0 { parts.append("\(strengthDayCount) strength day\(strengthDayCount == 1 ? "" : "s")") }
        if cardioDayCount > 0 { parts.append("\(cardioDayCount) cardio day\(cardioDayCount == 1 ? "" : "s")") }
        return parts.joined(separator: " and ")
    }
    
    /// Best available display name for the program
    private var displayName: String {
        if let summary = program.programSummary, !summary.isEmpty { return summary }
        if let split = program.splitType, !split.isEmpty { return split }
        return "\(program.daysPerWeek)-Day Program"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.atlasPrimary.opacity(0.12))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOUR TRAINING PROGRAM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.atlasPrimary)
                        .tracking(1.5)
                    
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                }
            }
            
            Text("Based on your goals and fitness level, we've set you up with \(weeklyStructure) per week.")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(4)
            
            Text("Tap any day to preview the workout. You can swap exercises, move days around, or switch plans at any time.")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(4)
            
            Button(action: onDismiss) {
                Text("Got It")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.atlasPrimary)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.atlasPrimary.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - NoPlanOptionCard

struct NoPlanOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(16)
        .background(Color.atlasCardDark)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - NoPlanBrowseWrapper
// Self-contained flow: PlanSelection → PlanPreview → Cardio → Commit → Dismiss
// Replicates the onboarding plan commit flow for use from the Training tab empty state.

struct NoPlanBrowseWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    @State private var selectedTemplate: TrainingPlanTemplate? = nil
    @State private var showPlanPreview = false
    @State private var showCardioStep = false
    @State private var showCustomBuilder = false
    @State private var pendingDayAssignments: [DayAssigner.DayAssignment] = []
    
    private var userProfile: UserProfile? { profiles.first }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            if showCustomBuilder {
                CustomPlanBuilderView(
                    onComplete: {
                        createTrainingHabits()
                        dismiss()
                    },
                    onBack: {
                        showCustomBuilder = false
                    }
                )
            } else if showCardioStep, let template = selectedTemplate {
                let restDays = pendingDayAssignments
                    .filter { $0.workoutType == "rest" }
                    .map { $0.dayOfWeek }
                
                CardioOnboardingStepView(
                    restDays: restDays,
                    onContinue: { cardioDays in
                        commitPlanWithCardio(template: template, cardioDays: cardioDays)
                        createTrainingHabits()
                        dismiss()
                    },
                    onSkip: {
                        commitPlanWithCardio(template: template, cardioDays: [])
                        createTrainingHabits()
                        dismiss()
                    }
                )
            } else if showPlanPreview, let template = selectedTemplate {
                PlanPreviewView(
                    template: template,
                    onConfirm: {
                        pendingDayAssignments = DayAssigner.assignDays(for: template)
                        showCardioStep = true
                    },
                    onBack: {
                        showPlanPreview = false
                        selectedTemplate = nil
                        showCardioStep = false
                    }
                )
            } else {
                PlanSelectionView(
                    onPlanSelected: { template in
                        selectedTemplate = template
                        showPlanPreview = true
                    },
                    onBuildYourOwn: {
                        showCustomBuilder = true
                    },
                    onEventTraining: {
                        // Handled by the parent — NoPlanView has its own event sheet
                        dismiss()
                    }
                )
            }
        }
    }
    
    private func commitPlanWithCardio(
        template: TrainingPlanTemplate,
        cardioDays: [PlanCommitter.CardioDayConfig]
    ) {
        guard let profile = userProfile else { return }
        
        PlanCommitter.commitTemplatePlan(
            template: template,
            dayAssignments: pendingDayAssignments,
            cardioDays: cardioDays,
            userProfile: profile,
            modelContext: modelContext
        )
    }
    
    private func createTrainingHabits() {
        guard let profile = userProfile else { return }
        TrainingHabitManager.createTrainingHabits(
            profile: profile,
            modelContext: modelContext
        )
    }
}

#Preview {
    TrainingProgramView()
}