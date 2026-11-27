import Foundation
import SwiftData

class DataController {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - User Profile
    func getOrCreateUserProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        
        if let existingProfile = try? modelContext.fetch(descriptor).first {
            return existingProfile
        }
        
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        
        do {
            try modelContext.save()
            print("✅ Created new user profile")
        } catch {
            print("❌ Failed to create profile: \(error)")
        }
        
        return newProfile
    }
    
    // MARK: - Lessons
    func getLessonForDay(_ day: Int) -> Lesson? {
        let descriptor = FetchDescriptor<Lesson>(
            predicate: #Predicate<Lesson> { $0.dayNumber == day }
        )
        
        if let existingLesson = try? modelContext.fetch(descriptor).first {
            return existingLesson
        }
        
        // If lesson doesn't exist, create it with default content
        let lesson = createDefaultLesson(for: day)
        return lesson
    }
    
    private func createDefaultLesson(for day: Int) -> Lesson {
        let lesson = Lesson(dayNumber: day)
        
        switch day {
        case 1:
            lesson.title = "The Framework"
            lesson.content = "Welcome to your longevity journey. Today we'll cover the five pillars that predict long-term health outcomes..."
        case 2:
            lesson.title = "VO2 Max"
            lesson.content = "VO2 Max is the strongest predictor of all-cause mortality. Here's why it matters and how to improve it..."
        case 3:
            lesson.title = "Muscle & Strength"
            lesson.content = "Muscle mass and strength provide a 2-3x mortality benefit. Let's understand the mechanisms..."
        case 4:
            lesson.title = "Recovery Metrics"
            lesson.content = "HRV and RHR tell us how well your body is recovering. Here's how to interpret and optimize them..."
        case 5:
            lesson.title = "Body Composition"
            lesson.content = "Body composition matters more than scale weight. Understanding visceral fat and muscle distribution..."
        case 6:
            lesson.title = "Metabolic Health"
            lesson.content = "Glucose control, insulin sensitivity, and metabolic flexibility are foundational to longevity..."
        default:
            lesson.title = "Lesson \(day)"
            lesson.content = "Content for day \(day)"
        }
        
        modelContext.insert(lesson)
        
        do {
            try modelContext.save()
            print("✅ Created lesson for day \(day)")
        } catch {
            print("❌ Failed to create lesson: \(error)")
        }
        
        return lesson
    }
    
    func isLessonComplete(day: Int) -> Bool {
        let descriptor = FetchDescriptor<LessonProgress>(
            predicate: #Predicate<LessonProgress> { $0.dayNumber == day && $0.completed == true }
        )
        
        if let progress = try? modelContext.fetch(descriptor).first {
            return progress.completed
        }
        
        return false
    }
    
    func markLessonComplete(day: Int) {
        let descriptor = FetchDescriptor<LessonProgress>(
            predicate: #Predicate<LessonProgress> { $0.dayNumber == day }
        )
        
        if let existingProgress = try? modelContext.fetch(descriptor).first {
            existingProgress.completed = true
            existingProgress.completedAt = Date()
        } else {
            let newProgress = LessonProgress(dayNumber: day)
            newProgress.completed = true
            newProgress.completedAt = Date()
            modelContext.insert(newProgress)
        }
        
        do {
            try modelContext.save()
            print("✅ Marked lesson \(day) complete")
        } catch {
            print("❌ Failed to mark lesson complete: \(error)")
        }
    }
    
   // MARK: - Create Habit
func createHabit(
    title: String,
    details: String,
    pillar: String,
    habitType: String = "non_negotiable",
    isTrainingHabit: Bool = false,
    trainingDayType: String? = nil,
    isUnlocked: Bool = true,
    dayOfWeek: Int? = nil,
    howToGuide: String? = nil,              
    researchCitation: String? = nil,   
    interventionId: String? = nil  
) {
    let habit = Habit(
        title: title,
        details: details,
        pillar: pillar,
        habitType: habitType,
        isTrainingHabit: isTrainingHabit,
        trainingDayType: trainingDayType,
        isUnlocked: isUnlocked,
        dayOfWeek: dayOfWeek,
        howToGuide: howToGuide,              
        researchCitation: researchCitation,
        interventionId: interventionId   
    )
    habit.userProfile = getOrCreateUserProfile()
    modelContext.insert(habit)
    
    do {
        try modelContext.save()
        print("✅ Created habit: \(title) [\(habitType)]")
    } catch {
        print("❌ Failed to create habit: \(error)")
    }
}
    
    func toggleHabitCompletion(habit: Habit, date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let habitId = habit.id
        
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { completion in
                completion.habit?.id == habitId &&
                completion.date >= startOfDay &&
                completion.date < endOfDay
            }
        )
        
        if let existingCompletion = try? modelContext.fetch(descriptor).first {
            // Toggle existing completion
            existingCompletion.completed.toggle()
            print("✅ Toggled habit completion: \(habit.title) -> \(existingCompletion.completed)")
        } else {
            // Create new completion
            let completion = HabitCompletion(date: date, completed: true)
            completion.habit = habit
            modelContext.insert(completion)
            print("✅ Created habit completion: \(habit.title)")
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save habit completion: \(error)")
        }
    }

    // MARK: - Mark Habit Complete (No Toggle)
func markHabitComplete(_ habit: Habit, date: Date = Date()) {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let habitId = habit.id
    
    let descriptor = FetchDescriptor<HabitCompletion>(
        predicate: #Predicate<HabitCompletion> { completion in
            completion.habit?.id == habitId &&
            completion.date >= startOfDay &&
            completion.date < endOfDay
        }
    )
    
    // Only create if not already complete
    if let existing = try? modelContext.fetch(descriptor).first {
        existing.completed = true
    } else {
        let completion = HabitCompletion(date: date, completed: true)
        completion.habit = habit
        modelContext.insert(completion)
    }
    
    do {
        try modelContext.save()
        print("✅ Marked habit complete: \(habit.title)")
    } catch {
        print("❌ Failed to mark habit complete: \(error)")
    }
}
    
    func isHabitCompleteToday(habit: Habit) -> Bool {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        let habitId = habit.id
        
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { completion in
                completion.habit?.id == habitId &&
                completion.date >= startOfToday &&
                completion.date < endOfToday &&
                completion.completed == true
            }
        )
        
        return (try? modelContext.fetch(descriptor).first) != nil
    }

    // MARK: - Check Habit Completion for Specific Date
func isHabitComplete(habit: Habit, on date: Date) -> Bool {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let habitId = habit.id
    
    let descriptor = FetchDescriptor<HabitCompletion>(
        predicate: #Predicate<HabitCompletion> { completion in
            completion.habit?.id == habitId &&
            completion.date >= startOfDay &&
            completion.date < endOfDay &&
            completion.completed == true
        }
    )
    
    return (try? modelContext.fetch(descriptor).first) != nil
}
    
    func getHabitStreak(habit: Habit) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        let habitId = habit.id
        
        while true {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else {
                break
            }
            
            let currentCheckDate = checkDate
            let currentNextDay = nextDay
            
            let descriptor = FetchDescriptor<HabitCompletion>(
                predicate: #Predicate<HabitCompletion> { completion in
                    completion.habit?.id == habitId &&
                    completion.date >= currentCheckDate &&
                    completion.date < currentNextDay &&
                    completion.completed == true
                }
            )
            
            if (try? modelContext.fetch(descriptor).first) != nil {
                streak += 1
                guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = prevDate
            } else {
                break
            }
        }
        
        return streak
    }
    
   // MARK: - Weekly Check-In Helpers
// MARK: - Weekly Check-In Helpers
func getWeeklyHabitCompletionRate(profile: UserProfile?) -> Double {
    guard let profile = profile else {
        print("❌ No user profile")
        return 0.0
    }
    
    let calendar = Calendar.current
    let now = Date()
    
    // Get all active habits
    let habitDescriptor = FetchDescriptor<Habit>(
        predicate: #Predicate<Habit> { $0.isActive == true }
    )
    
    guard let habits = try? modelContext.fetch(habitDescriptor), !habits.isEmpty else {
        print("❌ No active habits")
        return 0.0
    }
    
    // Determine tracking period
    let trackingStartDate: Date
    let daysToCount: Int
    
    if let weekStart = profile.currentWeekStartDate {
        // We're in a week cycle (Sunday-Saturday)
        trackingStartDate = weekStart
        
        // Calculate days elapsed in current week
        let startOfToday = calendar.startOfDay(for: now)
        let daysElapsed = calendar.dateComponents([.day], from: weekStart, to: startOfToday).day ?? 0
        
        // Include today (add 1), max 7 days
        daysToCount = min(daysElapsed + 1, 7)
        
        print("📅 Week-based tracking: \(daysToCount) days since Sunday")
    } else if let activationDate = profile.planActivationDate {
        // First incomplete week (activation → today)
        trackingStartDate = activationDate
        
        let startOfActivation = calendar.startOfDay(for: activationDate)
        let startOfToday = calendar.startOfDay(for: now)
        let daysElapsed = calendar.dateComponents([.day], from: startOfActivation, to: startOfToday).day ?? 0
        
        // Include today (add 1)
        daysToCount = daysElapsed + 1
        
        print("📅 First week tracking: \(daysToCount) days since activation")
    } else {
        // Fallback: no dates set (shouldn't happen)
        print("⚠️ No tracking dates set, using 7-day lookback")
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return 0.0
        }
        trackingStartDate = weekAgo
        daysToCount = 7
    }
    
    // Get completions since tracking start
    let completionDescriptor = FetchDescriptor<HabitCompletion>(
        predicate: #Predicate<HabitCompletion> { completion in
            completion.date >= trackingStartDate && completion.completed == true
        }
    )
    
    guard let completions = try? modelContext.fetch(completionDescriptor) else {
        print("❌ Could not fetch completions")
        return 0.0
    }
    
    // Calculate adherence
    let totalOpportunities = habits.count * daysToCount
    let totalCompleted = completions.count
    
    print("📊 Adherence: \(totalCompleted) / \(totalOpportunities) opportunities (\(habits.count) habits × \(daysToCount) days) = \(totalOpportunities > 0 ? Double(totalCompleted) / Double(totalOpportunities) : 0.0)")
    
    return totalOpportunities > 0 ? Double(totalCompleted) / Double(totalOpportunities) : 0.0
}
    
    // MARK: - Habit Analytics (Current Period)
    func getHabitCompletionRateForPeriod(habit: Habit, days: Int) -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return 0.0
        }
        
        // Calculate days elapsed in the tracking window
        let startOfTrackingPeriod = calendar.startOfDay(for: startDate)
        let startOfToday = calendar.startOfDay(for: now)
        let daysElapsed = calendar.dateComponents([.day], from: startOfTrackingPeriod, to: startOfToday).day ?? days
        
        // Include today as a full day (add 1)
        let daysToCount = min(daysElapsed + 1, days)
        
        let habitId = habit.id
        
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { completion in
                completion.habit?.id == habitId &&
                completion.date >= startDate &&
                completion.completed == true
            }
        )
        
        guard let completions = try? modelContext.fetch(descriptor) else {
            return 0.0
        }
        
        // Divide by actual days elapsed, not full period
        return daysToCount > 0 ? Double(completions.count) / Double(daysToCount) : 0.0
    }

    // MARK: - Overall Habit Completion Rate
func getHabitCompletionRateForDays(days: Int) -> Double {
    let calendar = Calendar.current
    let now = Date()
    guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
        return 0.0
    }
    
    // Get all active habits
    let habitDescriptor = FetchDescriptor<Habit>(
        predicate: #Predicate { $0.isActive == true }
    )
    
    guard let habits = try? modelContext.fetch(habitDescriptor), !habits.isEmpty else {
        return 0.0
    }
    
    // Get all completions in the date range
    let completionDescriptor = FetchDescriptor<HabitCompletion>(
        predicate: #Predicate { $0.date >= startDate }
    )
    
    guard let completions = try? modelContext.fetch(completionDescriptor) else {
        return 0.0
    }
    
    // Calculate: total completions / (habits * days)
    let totalPossible = habits.count * days
    let totalCompleted = completions.filter { $0.completed }.count
    
    guard totalPossible > 0 else { return 0.0 }
    
    return Double(totalCompleted) / Double(totalPossible)
}
    
    // MARK: - Habit Analytics (Historical)
    func getHabitCompletionRateHistorical(habit: Habit, daysAgo: Int, duration: Int) -> Double? {
        let endDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let startDate = Calendar.current.date(byAdding: .day, value: -duration, to: endDate)!
        
        // Fetch all completions for this habit
        let descriptor = FetchDescriptor<HabitCompletion>()
        
        guard let allCompletions = try? modelContext.fetch(descriptor) else {
            return nil
        }
        
        // Filter in Swift instead of predicate
        let filteredCompletions = allCompletions.filter { completion in
            guard let completionHabit = completion.habit else { return false }
            return completionHabit.id == habit.id &&
                   completion.date >= startDate &&
                   completion.date < endDate &&
                   completion.completed == true
        }
        
        return Double(filteredCompletions.count) / Double(duration)
    }
    
   func getCurrentStreak() -> Int {
    let calendar = Calendar.current
    var streak = 0
    var checkDate = calendar.startOfDay(for: Date())
    
    // Get all active habits
    let habitDescriptor = FetchDescriptor<Habit>(
        predicate: #Predicate<Habit> { $0.isActive == true }
    )
    
    guard let habits = try? modelContext.fetch(habitDescriptor), !habits.isEmpty else {
        return 0
    }
    
    // Check each day going backwards
    while true {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else {
            break
        }
        
        let currentCheckDate = checkDate
        let currentNextDay = nextDay
        
        // Get habits that apply to this specific day
        let dayOfWeek = calendar.component(.weekday, from: checkDate) - 1 // 0 = Sunday
        let habitsForDay = habits.filter { habit in
            if let habitDayOfWeek = habit.dayOfWeek {
                return habitDayOfWeek == dayOfWeek
            }
            return true // Non-day-specific habits apply every day
        }
        
        // If no habits apply to this day, count it as complete and continue
        guard !habitsForDay.isEmpty else {
            streak += 1
            guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = prevDate
            continue
        }
        
        let completionDescriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { completion in
                completion.date >= currentCheckDate &&
                completion.date < currentNextDay &&
                completion.completed == true
            }
        )
        
        guard let completions = try? modelContext.fetch(completionDescriptor) else {
            break
        }
        
        // Check if all habits FOR THIS DAY were completed
        let completedHabitIds = Set(completions.compactMap { $0.habit?.id })
        let allHabitsCompleted = habitsForDay.allSatisfy { completedHabitIds.contains($0.id) }
        
        if allHabitsCompleted {
            streak += 1
            guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = prevDate
        } else {
            break
        }
    }
    
    return streak
}

    // MARK: - Weekly Check-In Analysis
    func getWeeklyCheckInData(weekNumber: Int) -> WeeklyCheckInData? {
        let descriptor = FetchDescriptor<WeeklyCheckIn>(
            predicate: #Predicate { $0.weekNumber == weekNumber }
        )
        
        guard let checkIn = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return WeeklyCheckInData(
            weekNumber: checkIn.weekNumber,
            habitCompletionRate: checkIn.habitCompletionRate ?? 0,
            avgSleep: checkIn.sleepAverage ?? 0,
            avgHRV: checkIn.hrvAverage ?? 0,
            avgRHR: checkIn.rhrAverage ?? 0,
            energyRating: checkIn.energyLevel ?? 3,
            stressRating: 3,
            recoveryRating: 3,
            challenges: checkIn.biggestChallenge ?? "None noted",
            wins: checkIn.biggestWin ?? "None noted",
            date: checkIn.date
        )
    }

    func getPreviousWeeksData(count: Int, beforeWeek: Int) -> [WeeklyCheckInData] {
        let descriptor = FetchDescriptor<WeeklyCheckIn>(
            predicate: #Predicate { $0.weekNumber < beforeWeek },
            sortBy: [SortDescriptor(\.weekNumber, order: .reverse)]
        )
        
        guard let checkIns = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return Array(checkIns.prefix(count)).compactMap { checkIn in
            WeeklyCheckInData(
                weekNumber: checkIn.weekNumber,
                habitCompletionRate: checkIn.habitCompletionRate ?? 0,
                avgSleep: checkIn.sleepAverage ?? 0,
                avgHRV: checkIn.hrvAverage ?? 0,
                avgRHR: checkIn.rhrAverage ?? 0,
                energyRating: checkIn.energyLevel ?? 3,
                stressRating: 3,
                recoveryRating: 3,
                challenges: checkIn.biggestChallenge ?? "None noted",
                wins: checkIn.biggestWin ?? "None noted",
                date: checkIn.date
            )
        }
    }

    func getHabitTrends() -> [HabitTrend] {
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        guard let habits = try? modelContext.fetch(habitDescriptor) else {
            return []
        }
        
        return habits.map { habit in
            let currentWeekRate = getHabitCompletionRateForPeriod(habit: habit, days: 7)
            let previousWeekRate = getHabitCompletionRateHistorical(habit: habit, daysAgo: 7, duration: 7)
            
            let trend: String
            let analysis: String
            
            if let prevRate = previousWeekRate {
                let change = currentWeekRate - prevRate
                if change > 0.15 {
                    trend = "improving"
                    analysis = "Up \(Int(change * 100))% from last week"
                } else if change < -0.15 {
                    trend = "declining"
                    analysis = "Down \(Int(abs(change) * 100))% from last week"
                } else {
                    trend = "stable"
                    analysis = "Consistent with last week"
                }
            } else {
                trend = "new"
                analysis = "First week of tracking"
            }
            
            return HabitTrend(
                habitName: habit.title,
                currentWeekRate: currentWeekRate,
                previousWeekRate: previousWeekRate,
                trend: trend,
                analysis: analysis
            )
        }
    }

    // MARK: - Morning Brief Data Helpers (Sprint 1 — Engagement Overhaul)

    /// Returns the number of consecutive nights where sleep duration >= threshold hours.
    /// Checks backwards from last night. Returns 0 if last night was below threshold.
    func consecutiveNightsAboveSleep(threshold: Double) -> Int {
        let calendar = Calendar.current
        var count = 0
        let checkDate = calendar.startOfDay(for: Date()) // Start from today (last night's sleep)

        let descriptor = FetchDescriptor<HealthMetrics>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let allMetrics = try? modelContext.fetch(descriptor) else { return 0 }

        for dayOffset in 0..<30 {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: checkDate) else { break }
            let metric = allMetrics.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
            guard let sleep = metric?.sleepDuration, sleep >= threshold else { break }
            count += 1
        }
        return count
    }

    /// Returns recent PersonalRecords from the last N days.
    func recentPRs(days: Int) -> [PersonalRecord] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Returns the 7-day rolling average of a component percentile, compared to the prior 7-day average.
    /// Returns (currentAvg, previousAvg, delta) or nil if insufficient data.
    func componentPercentileDelta(
        component: String,
        paceScores: [BiologicalPaceScore]
    ) -> (current: Double, previous: Double, delta: Double)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let sevenAgo = calendar.date(byAdding: .day, value: -7, to: today),
              let fourteenAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return nil }

        let recentScores = paceScores.filter { $0.date >= sevenAgo && $0.date < today }
        let priorScores = paceScores.filter { $0.date >= fourteenAgo && $0.date < sevenAgo }

        guard recentScores.count >= 3, priorScores.count >= 3 else { return nil }

        func avg(_ scores: [BiologicalPaceScore]) -> Double? {
            let values: [Double] = scores.compactMap { score in
                switch component {
                case "Sleep": return score.sleepPercentile
                case "HRV": return score.hrvPercentile
                case "Resting HR": return score.rhrPercentile
                case "VO₂ Max": return score.vo2MaxPercentile
                case "Daily Movement": return score.stepsPercentile
                case "Strength": return score.strengthPercentile
                default: return nil
                }
            }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        guard let currentAvg = avg(recentScores), let previousAvg = avg(priorScores) else { return nil }
        return (current: currentAvg, previous: previousAvg, delta: currentAvg - previousAvg)
    }

    /// Returns the biggest component win (highest positive delta ≥ 5 points) across all 6 components.
    func biggestComponentWin(paceScores: [BiologicalPaceScore]) -> (component: String, delta: Double, currentPercentile: Double)? {
        let components = ["Sleep", "HRV", "Resting HR", "VO₂ Max", "Daily Movement", "Strength"]
        var bestWin: (component: String, delta: Double, currentPercentile: Double)?

        for component in components {
            if let result = componentPercentileDelta(component: component, paceScores: paceScores),
               result.delta >= 5.0 {
                if bestWin == nil || result.delta > bestWin!.delta {
                    bestWin = (component: component, delta: result.delta, currentPercentile: result.current)
                }
            }
        }
        return bestWin
    }

    /// Returns the number of workouts logged in the last N days.
    func workoutCountInLastDays(_ days: Int) -> Int {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return 0 }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.date >= cutoff }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Updates longestStreakEver on UserProfile if current streak exceeds it.
    func updatePersonalBestStreak(profile: UserProfile) {
        let current = getCurrentStreak()
        if current > profile.longestStreakEver {
            profile.longestStreakEver = current
        }
    }
}