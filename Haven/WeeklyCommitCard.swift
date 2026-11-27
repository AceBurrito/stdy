import SwiftUI
import SwiftData

// MARK: - Weekly Commit Card (TodayView inline)

struct WeeklyCommitCard: View {
    let eventName: String
    let weekNumber: Int
    let totalWeeks: Int
    let phaseName: String
    let workoutSummary: String
    let isDeloadWeek: Bool
    let onCommit: () -> Void
    let onAdjust: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasAccent)
                
                Text("NEXT WEEK — WEEK \(weekNumber) OF \(totalWeeks)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.atlasAccent)
                    .tracking(1)
                
                Spacer()
                
                if isDeloadWeek {
                    Text("DELOAD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.atlasBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.atlasAmber)
                        .cornerRadius(4)
                }
            }
            
            // Event name + phase
            VStack(alignment: .leading, spacing: 4) {
                Text(eventName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("\(phaseName) Phase")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }
            
            // Workout summary
            Text(workoutSummary)
                .font(.system(size: 14))
                .foregroundColor(.atlasText.opacity(0.8))
                .padding(.vertical, 4)
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCommit) {
                    Text("Looks Good")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.atlasPrimary)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onAdjust) {
                    Text("Adjust My Week")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.atlasPrimary.opacity(0.15))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.atlasCardDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.atlasAccent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Weekly Commit Sheet (Adjust My Week)

struct WeeklyCommitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let weekData: PlannedWorkoutWeek
    let eventName: String
    let weekNumber: Int
    let totalWeeks: Int
    let onCommit: () -> Void
    
    @State private var showingDayReassignment = false
    @State private var selectedDay: PlannedWorkoutDay? = nil
    
    private var sortedDays: [PlannedWorkoutDay] {
        weekData.days.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }
    
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let dayFullNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Text("Week \(weekNumber) Plan")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Spacer()
                    
                    // Invisible balance
                    Button("Cancel") { }
                        .opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Week info
                        VStack(spacing: 6) {
                            Text(eventName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.atlasText)
                            
                            Text("\(weekData.phaseName) Phase • Week \(weekNumber) of \(totalWeeks)")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                            
                            if let focus = weekData.weekFocus {
                                Text(focus)
                                    .font(.system(size: 13))
                                    .foregroundColor(.atlasAccent)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Instruction
                        Text("Tap a day to move it. Commit when your schedule looks right.")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Workout days
                        VStack(spacing: 10) {
                            ForEach(sortedDays) { day in
                                AdjustableWorkoutDayRow(
                                    day: day,
                                    dayName: dayFullName(for: day.dayOfWeek),
                                    dayAbbrev: dayAbbrev(for: day.dayOfWeek),
                                    onChangeDayTapped: {
                                        selectedDay = day
                                        showingDayReassignment = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Commit button
                        Button(action: {
                            onCommit()
                            dismiss()
                        }) {
                            Text("Commit to This Week")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.atlasBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.atlasPrimary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingDayReassignment) {
            if let day = selectedDay {
                DayReassignmentSheet(
                    currentDayOfWeek: day.dayOfWeek,
                    workoutName: day.dayName,
                    onSelect: { newDay in
                        day.dayOfWeek = newDay
                        try? modelContext.save()
                    }
                )
            }
        }
    }
    
    private func dayFullName(for index: Int) -> String {
        guard index >= 0 && index < dayFullNames.count else { return "" }
        return dayFullNames[index]
    }
    
    private func dayAbbrev(for index: Int) -> String {
        guard index >= 0 && index < dayNames.count else { return "?" }
        return dayNames[index]
    }
}

// MARK: - Adjustable Workout Day Row

struct AdjustableWorkoutDayRow: View {
    let day: PlannedWorkoutDay
    let dayName: String
    let dayAbbrev: String
    let onChangeDayTapped: () -> Void
    
    private var isRest: Bool {
        day.dayType == "rest"
    }
    
    private var displayName: String {
        if day.dayType == "rest" {
            return "Rest Day"
        }
        return day.dayName
    }
    
    private var subtitle: String {
        if day.dayType == "strength" {
            return "\(day.exercises.count) exercises"
        } else if day.dayType == "rest" {
            return "Recovery"
        } else if let distance = day.targetDistance, let unit = day.distanceUnit {
            return String(format: "%.1f %@", distance, unit)
        } else if let duration = day.cardioDuration {
            return "\(duration) min"
        }
        return day.dayType.capitalized
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Day badge
            VStack(spacing: 2) {
                Text(dayAbbrev.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
            }
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            // Workout info
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
            
            Spacer()
            
            // Change day button (not for rest days)
            if !isRest {
                Button(action: onChangeDayTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                        
                        Text("Move")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.atlasAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Type icon
            Image(systemName: iconForType(day.dayType))
                .font(.system(size: 16))
                .foregroundColor(colorForType(day.dayType))
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio", "run": return "figure.run"
        case "bike": return "figure.outdoor.cycle"
        case "swim": return "figure.pool.swim"
        case "mobility": return "figure.flexibility"
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
        case "rest": return .atlasTextMuted.opacity(0.5)
        default: return .atlasTextMuted
        }
    }
}

// MARK: - Helper: Build Workout Summary String

struct WeeklyCommitHelper {
    
    /// Generates a summary like "3 runs, 2 strength, 1 rest day"
    static func workoutSummary(for week: PlannedWorkoutWeek) -> String {
        let days = week.days
        
        var counts: [String: Int] = [:]
        for day in days {
            let type = normalizedType(day.dayType)
            counts[type, default: 0] += 1
        }
        
        var parts: [String] = []
        
        // Order: runs, strength, cardio, rest, other
        let orderedTypes = ["run", "strength", "cardio", "bike", "swim", "mobility", "rest"]
        
        for type in orderedTypes {
            if let count = counts[type], count > 0 {
                parts.append("\(count) \(displayName(for: type, count: count))")
                counts.removeValue(forKey: type)
            }
        }
        
        // Any remaining types
        for (type, count) in counts.sorted(by: { $0.key < $1.key }) {
            parts.append("\(count) \(displayName(for: type, count: count))")
        }
        
        return parts.joined(separator: ", ")
    }
    
    /// Determines whether the commit card should show
    static func shouldShowCommitCard(
        profile: UserProfile,
        currentDate: Date = Date()
    ) -> Bool {
        // Must be training for an event
        guard profile.isTrainingForEvent else { return false }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate) // 1 = Sunday, 2 = Monday
        
        // Show on Sunday (1) or Monday (2) as fallback
        guard weekday == 1 || weekday == 2 else { return false }
        
        // Check if already committed for the coming week
        if let commitDate = profile.weeklyCommitDate {
            // The coming week starts on the next Monday
            let nextMonday = nextMondayDate(from: currentDate, calendar: calendar)
            let commitMonday = nextMondayDate(from: commitDate, calendar: calendar)
            
            // If they've already committed for this coming week, don't show
            if commitMonday >= nextMonday {
                return false
            }
        }
        
        return true
    }
    
    /// Gets the week number for the coming week
    static func comingWeekNumber(profile: UserProfile) -> Int {
        // The coming week is currentEventWeek + 1 if today is Sunday,
        // or currentEventWeek if the week hasn't advanced yet
        // For simplicity, we show the NEXT week they'll be training
        let current = profile.currentEventWeek
        let total = totalWeeksForProfile(profile)
        
        // On Sunday, they're reviewing next week
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        if weekday == 1 { // Sunday — show next week
            return min(current + 1, total)
        } else { // Monday fallback — show current week
            return current
        }
    }
    
    // MARK: - Private Helpers
    
    private static func normalizedType(_ type: String) -> String {
        switch type.lowercased() {
        case "run", "cardio_run": return "run"
        case "strength": return "strength"
        case "cardio": return "cardio"
        case "bike", "cycle": return "bike"
        case "swim": return "swim"
        case "mobility", "flexibility": return "mobility"
        case "rest": return "rest"
        default: return type.lowercased()
        }
    }
    
    private static func displayName(for type: String, count: Int) -> String {
        switch type {
        case "run": return count == 1 ? "run" : "runs"
        case "strength": return "strength"
        case "cardio": return "cardio"
        case "bike": return count == 1 ? "bike" : "bikes"
        case "swim": return count == 1 ? "swim" : "swims"
        case "mobility": return "mobility"
        case "rest": return count == 1 ? "rest day" : "rest days"
        default: return type
        }
    }
    
    private static func nextMondayDate(from date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let daysUntilMonday = weekday == 1 ? 1 : (9 - weekday) % 7
        return calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: calendar.startOfDay(for: date))!
    }
    
    private static func totalWeeksForProfile(_ profile: UserProfile) -> Int {
        // This would ideally come from the active TrainingProgram
        // but since we may not have modelContext here, use a reasonable fallback
        return 12
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        WeeklyCommitCard(
            eventName: "Austin Half Marathon",
            weekNumber: 7,
            totalWeeks: 12,
            phaseName: "Build",
            workoutSummary: "3 runs, 2 strength, 1 rest day",
            isDeloadWeek: false,
            onCommit: { },
            onAdjust: { }
        )
        .padding(20)
    }
}
