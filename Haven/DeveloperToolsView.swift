import SwiftUI
import SwiftData

struct DeveloperToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \HealthMetrics.date, order: .reverse) private var healthMetrics: [HealthMetrics]
    
    @State private var selectedDate = Date()
    @State private var showSuccess = false
    @State private var importStatus = ""
    @State private var checkInImportText = ""
    @State private var showCheckInImport = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Warning header
                        warningSection
                        
                        // Health Metrics Management
                        healthMetricsSection
                        
                        // Plan activation
                        planActivationSection
                        
                        // Quick seed options
                        quickSeedSection
                        
                        // Manual import
                        manualImportSection
                        
                        // Status
                        if !importStatus.isEmpty {
                            statusSection
                        }
                        
                        Spacer()
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Developer Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.atlasPrimary)
                }
            }
        }
    }
    
    // MARK: - Warning Section
    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Developer Tools")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            Text("These tools are for testing and development. Use with caution.")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Health Metrics Section
    private var healthMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HEALTH METRICS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            // Current metrics info
            VStack(alignment: .leading, spacing: 8) {
                Text("Stored Records: \(healthMetrics.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasText)
                
                if let latest = healthMetrics.first {
                    Text("Latest: \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text("Sleep: \(latest.sleepDuration != nil ? String(format: "%.1fh", latest.sleepDuration!) : "—"), HRV: \(latest.heartRateVariability != nil ? "\(Int(latest.heartRateVariability!))" : "—"), RHR: \(latest.restingHeartRate != nil ? "\(Int(latest.restingHeartRate!))" : "—")")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            // Action buttons
            VStack(spacing: 12) {
                QuickSeedButton(
                    title: "Clear All Health Metrics",
                    subtitle: "Delete all stored metrics to force re-fetch",
                    icon: "trash",
                    action: clearHealthMetrics
                )
                
                QuickSeedButton(
                    title: "Force Refresh from HealthKit",
                    subtitle: "Sync last 7 days from Apple Health",
                    icon: "arrow.clockwise",
                    action: forceRefreshHealthMetrics
                )
                
                QuickSeedButton(
                    title: "List All Metrics Dates",
                    subtitle: "Show dates of all stored records",
                    icon: "list.bullet",
                    action: listAllMetricsDates
                )
            }
        }
    }
    
    // MARK: - Plan Activation Section
    private var planActivationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BACKDATE PLAN ACTIVATION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Text("Set when your longevity plan started")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            
            DatePicker("Plan Start Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            
            Button(action: setPlanActivationDate) {
                Text("Set Plan Activation Date")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.atlasPrimary)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Quick Seed Section
    private var quickSeedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QUICK SEED (6 WEEKS)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Text("Populate with sample data for testing")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            
            VStack(spacing: 12) {
                QuickSeedButton(
                    title: "Seed Habits & Completions",
                    subtitle: "3 habits + 6 weeks at 85% adherence",
                    icon: "checklist",
                    action: seedHabitsAndCompletions
                )
                
                QuickSeedButton(
                    title: "Seed Weekly Check-ins",
                    subtitle: "3 weeks of check-in data",
                    icon: "calendar",
                    action: seedWeeklyCheckIns
                )
                
                QuickSeedButton(
                    title: "Seed Health Metrics",
                    subtitle: "Daily metrics for 21 days",
                    icon: "heart.text.square",
                    action: seedHealthMetrics
                )
                
                QuickSeedButton(
                    title: "Seed Workout History",
                    subtitle: "15 workouts over 3 weeks",
                    icon: "figure.strengthtraining.traditional",
                    action: seedWorkoutHistory
                )
                
                QuickSeedButton(
                    title: "🧪 Seed Everything",
                    subtitle: "All data for complete testing",
                    icon: "star.fill",
                    action: seedEverything
                )

                QuickSeedButton(
                    title: "Launch Weekly Check-In",
                    subtitle: "Open check-in flow directly",
                    icon: "sparkles",
                    action: {
                        NotificationCenter.default.post(
                            name: Notification.Name("ForceOpenWeeklyCheckIn"),
                            object: nil
                        )
                    }
                )

            }
        }
    }
    
    // MARK: - Manual Import Section
    private var manualImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MANUAL IMPORT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Text("Import your real weekly check-in data")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            
            Button(action: { showCheckInImport.toggle() }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasPrimary)
                    
                    Text("Import Weekly Check-ins")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Spacer()
                    
                    Image(systemName: showCheckInImport ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if showCheckInImport {
                checkInImportForm
            }
        }
    }
    
    private var checkInImportForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste your data (one per line):")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.atlasText)
            
            Text("Format: Week #, Date, Energy, Rating, Sleep, HRV, RHR, Habits%")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
            
            Text("Example:\nWeek 1, 2024-12-23, 7, 8, 7.2, 42, 62, 85")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.atlasTextMuted.opacity(0.7))
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
            
            TextEditor(text: $checkInImportText)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.atlasText)
                .font(.system(size: 13, design: .monospaced))
            
            HStack(spacing: 12) {
                Button(action: { checkInImportText = "" }) {
                    Text("Clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: importWeeklyCheckIns) {
                    Text("Import")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.atlasPrimary)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(Color.atlasPrimary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATUS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Text(importStatus)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Health Metrics Actions
    
    private func clearHealthMetrics() {
        var deletedCount = 0
        
        for metric in healthMetrics {
            modelContext.delete(metric)
            deletedCount += 1
        }
        
        do {
            try modelContext.save()
            importStatus = "✅ Deleted \(deletedCount) health metrics records. Re-open app to trigger fresh fetch."
        } catch {
            importStatus = "❌ Failed to delete: \(error.localizedDescription)"
        }
    }
    
    private func forceRefreshHealthMetrics() {
        importStatus = "🔄 Fetching from HealthKit..."
        
        let context = modelContext
        Task {
            await HealthKitManager.shared.syncMissingMetrics(modelContext: context, daysBack: 7)
            
            await MainActor.run {
                importStatus = "✅ Synced last 7 days from HealthKit"
            }
        }
    }
    
    private func listAllMetricsDates() {
        if healthMetrics.isEmpty {
            importStatus = "📋 No health metrics stored"
            return
        }
        
        let dateStrings = healthMetrics.map { metric in
            let dateStr = metric.date.formatted(date: .abbreviated, time: .omitted)
            let sleep = metric.sleepDuration != nil ? String(format: "%.1fh", metric.sleepDuration!) : "—"
            let hrv = metric.heartRateVariability != nil ? "\(Int(metric.heartRateVariability!))ms" : "—"
            let rhr = metric.restingHeartRate != nil ? "\(Int(metric.restingHeartRate!))bpm" : "—"
            return "\(dateStr): S:\(sleep) H:\(hrv) R:\(rhr)"
        }
        
        importStatus = "📋 Stored Metrics:\n" + dateStrings.joined(separator: "\n")
    }
    
    // MARK: - Seed Actions
    
    private func setPlanActivationDate() {
        guard let profile = userProfile else { return }
        
        DataSeeder.seedPlanActivation(
            profile: profile,
            activationDate: selectedDate,
            modelContext: modelContext
        )
        
        importStatus = "✅ Plan activation date set to \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }
    
    private func seedHabitsAndCompletions() {
        guard let profile = userProfile else { return }
        
        // Check if habits already exist
        let habitDescriptor = FetchDescriptor<Habit>()
        let existingHabits = (try? modelContext.fetch(habitDescriptor)) ?? []
        
        var habits: [Habit] = []
        
        if existingHabits.isEmpty {
            // Create 3 core habits
            let habit1 = Habit(title: "Sleep 7+ hours", details: "In bed by 10pm", pillar: "Sleep")
            habit1.userProfile = profile
            modelContext.insert(habit1)
            habits.append(habit1)
            
            let habit2 = Habit(title: "Zone 2 Cardio", details: "30min walk/bike", pillar: "Fitness")
            habit2.userProfile = profile
            modelContext.insert(habit2)
            habits.append(habit2)
            
            let habit3 = Habit(title: "Protein Target", details: "150g daily", pillar: "Nutrition")
            habit3.userProfile = profile
            modelContext.insert(habit3)
            habits.append(habit3)
        } else {
            habits = existingHabits
        }
        
        // Backfill completions for last 6 weeks (85% adherence)
        let calendar = Calendar.current
        let today = Date()
        
        for weekOffset in 0..<6 {
            for dayOffset in 0..<7 {
                let targetDate = calendar.date(byAdding: .day, value: -(weekOffset * 7 + dayOffset), to: today)!
                
                for habit in habits {
                    // Check if completion already exists
                    let existingCompletion = habit.completions?.first { completion in
                        calendar.isDate(completion.date, inSameDayAs: targetDate)
                    }
                    
                    if existingCompletion == nil {
                        // 85% completion rate
                        if Double.random(in: 0...1) < 0.85 {
                            let completion = HabitCompletion(date: targetDate, completed: true)
                            completion.habit = habit
                            modelContext.insert(completion)
                        }
                    }
                }
            }
        }
        
        do {
            try modelContext.save()
            importStatus = "✅ Seeded 3 habits + 6 weeks of completions (85% adherence)"
        } catch {
            importStatus = "❌ Failed to seed habits: \(error.localizedDescription)"
        }
    }
    
    private func seedWeeklyCheckIns() {
        guard let profile = userProfile else { return }
        
        // Generate 3 weeks of check-in data
        let calendar = Calendar.current
        var checkIns: [SeedWeeklyCheckInData] = []
        
        for week in 1...3 {
            guard let weekDate = calendar.date(byAdding: .weekOfYear, value: -4 + week, to: Date()) else { continue }
            
            checkIns.append(SeedWeeklyCheckInData(
                weekNumber: week,
                date: weekDate,
                energyLevel: Int.random(in: 6...9),
                overallRating: Int.random(in: 6...9),
                biggestWin: "Stayed consistent with training",
                biggestChallenge: "Managing sleep with work stress",
                sleepAverage: Double.random(in: 6.5...7.5),
                hrvAverage: Double.random(in: 35...50),
                rhrAverage: Double.random(in: 58...66),
                habitCompletionRate: Double.random(in: 0.7...0.95),
                aiCoachingFeedback: nil
            ))
        }
        
        DataSeeder.seedWeeklyCheckIns(profile: profile, checkIns: checkIns, modelContext: modelContext)
        importStatus = "✅ Seeded 3 weekly check-ins"
    }
    
    private func seedHealthMetrics() {
        guard let profile = userProfile else { return }
        
        // Generate 21 days of health metrics
        let calendar = Calendar.current
        var metrics: [SeedHealthMetricData] = []
        
        for day in 0..<21 {
            guard let date = calendar.date(byAdding: .day, value: -21 + day, to: Date()) else { continue }
            
            metrics.append(SeedHealthMetricData(
                date: date,
                sleepDuration: Double.random(in: 6.2...7.8),
                hrv: Double.random(in: 30...55),
                rhr: Double.random(in: 56...68),
                vo2Max: 37.17,
                weight: Double.random(in: 218...222)
            ))
        }
        
        DataSeeder.seedHealthMetrics(profile: profile, metrics: metrics, modelContext: modelContext)
        importStatus = "✅ Seeded 21 days of health metrics"
    }
    
    private func seedWorkoutHistory() {
        guard let profile = userProfile else { return }
        
        // Generate 15 workouts over 3 weeks (5 per week)
        let calendar = Calendar.current
        var workouts: [SeedWorkoutData] = []
        
        let exercises = ["Bench Press", "Squat", "Overhead Press", "Deadlift", "Dips"]
        
        for week in 0..<3 {
            for day in [1, 2, 4, 5, 6] {
                guard let workoutDate = calendar.date(byAdding: .day, value: -21 + (week * 7) + day, to: Date()) else { continue }
                
                let exerciseName = exercises.randomElement()!
                let baseWeight = exerciseName == "Bench Press" ? 185.0 : (exerciseName == "Squat" ? 225.0 : 135.0)
                let progressionWeight = baseWeight + Double(week * 5)
                
                let workoutExercises = [
                    SeedExerciseData(
                        name: exerciseName,
                        sets: [
                            SeedSetData(weight: progressionWeight, reps: 10, isBodyweight: false),
                            SeedSetData(weight: progressionWeight, reps: 10, isBodyweight: false),
                            SeedSetData(weight: progressionWeight, reps: Int.random(in: 8...10), isBodyweight: false)
                        ]
                    )
                ]
                
                workouts.append(SeedWorkoutData(
                    date: workoutDate,
                    name: "Workout",
                    exercises: workoutExercises
                ))
            }
        }
        
        DataSeeder.seedWorkouts(profile: profile, workouts: workouts, modelContext: modelContext)
        importStatus = "✅ Seeded 15 workouts with progressive overload"
    }
    
    private func seedEverything() {
        guard let profile = userProfile else {
            importStatus = "❌ No profile found"
            return
        }
        
        // Set profile to Week 6 Movement Plan (ready for upgrade)
        profile.currentWeek = 6
        profile.movementPlanStartDate = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())
        profile.planActivationDate = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())
        profile.currentWeekStartDate = Calendar.current.date(byAdding: .day, value: -((Calendar.current.component(.weekday, from: Date()) - 1)), to: Date()) // Last Sunday
        
        // Seed all data
        seedHabitsAndCompletions()
        seedWeeklyCheckIns()
        seedHealthMetrics()
        seedWorkoutHistory()
        
        try? modelContext.save()
        
        importStatus = """
        ✅ Complete! Seeded for Week 6 Movement Plan:
        • 3 habits (85% adherence over 6 weeks)
        • 3 weekly check-ins
        • 21 days health metrics
        • 15 workouts
        • Ready for Training Plan upgrade test!
        """
    }
    
    // MARK: - Import Weekly Check-ins from Text
    private func importWeeklyCheckIns() {
        guard let profile = userProfile else {
            importStatus = "❌ No user profile found"
            return
        }
        
        let lines = checkInImportText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            importStatus = "❌ No data to import"
            return
        }
        
        var imported = 0
        var failed = 0
        
        for line in lines {
            if let checkInData = parseCheckInLine(line) {
                let checkIn = WeeklyCheckIn(weekNumber: checkInData.weekNumber, date: checkInData.date)
                checkIn.userProfile = profile
                
                checkIn.energyLevel = checkInData.energyLevel
                checkIn.overallRating = checkInData.overallRating
                checkIn.sleepAverage = checkInData.sleepAverage
                checkIn.hrvAverage = checkInData.hrvAverage
                checkIn.rhrAverage = checkInData.rhrAverage
                checkIn.habitCompletionRate = checkInData.habitCompletionRate
                
                checkIn.biggestWin = "Imported from data"
                checkIn.biggestChallenge = "Imported from data"
                checkIn.aiCoachingFeedback = DataSeeder.generateMockCoaching(week: checkInData.weekNumber)
                
                modelContext.insert(checkIn)
                imported += 1
            } else {
                failed += 1
                print("⚠️ Failed to parse line: \(line)")
            }
        }
        
        do {
            try modelContext.save()
            importStatus = "✅ Imported \(imported) check-ins" + (failed > 0 ? " (\(failed) failed)" : "")
            checkInImportText = ""
            showCheckInImport = false
        } catch {
            importStatus = "❌ Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func parseCheckInLine(_ line: String) -> SeedWeeklyCheckInData? {
        // Expected format: Week 1, 2024-12-23, 7, 8, 7.2, 42, 62, 85
        let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard parts.count >= 8 else {
            print("⚠️ Not enough parts: \(parts.count)")
            return nil
        }
        
        // Parse week number
        let weekString = parts[0].replacingOccurrences(of: "Week ", with: "")
        guard let weekNumber = Int(weekString) else {
            print("⚠️ Invalid week number: \(parts[0])")
            return nil
        }
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: parts[1]) else {
            print("⚠️ Invalid date: \(parts[1])")
            return nil
        }
        
        // Parse metrics (handle 0 as nil for missing data)
        let energy = Int(parts[2])
        let rating = Int(parts[3])
        let sleep = Double(parts[4])
        let hrv = Double(parts[5])
        let rhr = Double(parts[6])
        
        guard let hrvValue = hrv, let rhrValue = rhr else {
            print("⚠️ Invalid HRV/RHR")
            return nil
        }
        
        // Parse habit completion (remove % if present)
        let habitString = parts[7].replacingOccurrences(of: "%", with: "")
        let habitPercent = Double(habitString)
        let habitRate = habitPercent != nil ? habitPercent! / 100.0 : nil
        
        return SeedWeeklyCheckInData(
            weekNumber: weekNumber,
            date: date,
            energyLevel: energy == 0 ? nil : energy,
            overallRating: rating == 0 ? nil : rating,
            biggestWin: nil,
            biggestChallenge: nil,
            sleepAverage: sleep == 0 ? nil : sleep,
            hrvAverage: hrvValue,
            rhrAverage: rhrValue,
            habitCompletionRate: habitRate,
            aiCoachingFeedback: nil
        )
    }
}

// MARK: - Quick Seed Button
struct QuickSeedButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DeveloperToolsView()
}
