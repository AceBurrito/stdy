import SwiftUI
import SwiftData

struct HabitBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { $0.isActive == true }) private var habits: [Habit]
    @Query private var profiles: [UserProfile]
    
    @State private var selectedTimeframe: Timeframe = .week
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    enum Timeframe: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case all = "All"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return 365
            }
        }
        
        var label: String {
            switch self {
            case .week: return "this week"
            case .month: return "this month"
            case .all: return "all time"
            }
        }
    }
    
    // Days since plan activation (capped by timeframe)
    private var daysSinceActivation: Int {
        guard let activationDate = userProfile?.planActivationDate else { return 1 }
        let calendar = Calendar.current
        let startOfActivation = calendar.startOfDay(for: activationDate)
        let startOfToday = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: startOfActivation, to: startOfToday).day ?? 0
        return max(1, days + 1) // +1 because activation day counts
    }
    
    // Effective days to count (min of timeframe and days since activation)
    private var effectiveDays: Int {
        min(selectedTimeframe.days, daysSinceActivation)
    }
    
    // Non-training habits (Sleep, Protein, etc.)
    private var nonTrainingHabits: [Habit] {
        habits.filter { !$0.isTrainingHabit }
    }
    
    // Training habits (strength, cardio, rest)
    private var trainingHabits: [Habit] {
        habits.filter { $0.isTrainingHabit }
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe picker
                    timeframePicker
                    
                    if habits.isEmpty {
                        emptyState
                    } else {
                        // Training card (consolidated)
                        if !trainingHabits.isEmpty {
                            TrainingConsolidatedCard(
                                trainingHabits: trainingHabits,
                                modelContext: modelContext,
                                timeframe: selectedTimeframe,
                                effectiveDays: effectiveDays,
                                activationDate: userProfile?.planActivationDate
                            )
                        }
                        
                        // Individual non-training habits
                        ForEach(nonTrainingHabits) { habit in
                            HabitDetailCard(
                                habit: habit,
                                modelContext: modelContext,
                                timeframe: selectedTimeframe,
                                effectiveDays: effectiveDays,
                                activationDate: userProfile?.planActivationDate
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Habit Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Timeframe Picker
    private var timeframePicker: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Button(action: { selectedTimeframe = timeframe }) {
                    Text(timeframe.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .atlasBackground : .atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTimeframe == timeframe ? Color.atlasPrimary : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.atlasTextMuted)
            
            Text("No active habits yet")
                .font(.system(size: 17))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Training Consolidated Card

struct TrainingConsolidatedCard: View {
    let trainingHabits: [Habit]
    let modelContext: ModelContext
    let timeframe: HabitBreakdownView.Timeframe
    let effectiveDays: Int
    let activationDate: Date?
    
    private var completionStats: (completed: Int, total: Int, rate: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let activation = activationDate else {
            return (0, 0, 0)
        }
        
        let activationStart = calendar.startOfDay(for: activation)
        
        var totalDays = 0
        var completedDays = 0
        
        // Only count days from activation to today, capped by effectiveDays
        for dayOffset in 0..<effectiveDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // Skip if before activation
            if date < activationStart { continue }
            
            let weekday = calendar.component(.weekday, from: date) - 1 // 0 = Sunday
            
            if let habitForDay = trainingHabits.first(where: { $0.dayOfWeek == weekday }) {
                totalDays += 1
                
                if let completions = habitForDay.completions {
                    let dayStart = calendar.startOfDay(for: date)
                    let isCompleted = completions.contains { completion in
                        calendar.isDate(completion.date, inSameDayAs: dayStart) && completion.completed
                    }
                    if isCompleted {
                        completedDays += 1
                    }
                }
            }
        }
        
        let rate = totalDays > 0 ? Double(completedDays) / Double(totalDays) : 0
        return (completedDays, totalDays, rate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.atlasPrimary.opacity(0.15))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        Text("Strength, Cardio & Rest Days")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
                
                Spacer()
                
                // Completion percentage
                Text("\(Int(completionStats.rate * 100))%")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.atlasPrimary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.atlasPrimary)
                        .frame(width: geometry.size.width * completionStats.rate, height: 8)
                }
            }
            .frame(height: 8)
            
            // Stats
            HStack {
                Text("\(completionStats.completed) of \(completionStats.total) days")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                
                Spacer()
                
                Text("\(strengthCount) strength • \(cardioCount) cardio • \(restCount) rest")
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted.opacity(0.7))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var strengthCount: Int {
        trainingHabits.filter { $0.trainingDayType == "strength" }.count
    }
    
    private var cardioCount: Int {
        trainingHabits.filter { $0.trainingDayType == "cardio" }.count
    }
    
    private var restCount: Int {
        trainingHabits.filter { $0.trainingDayType == "rest" }.count
    }
}

// MARK: - Habit Detail Card (for non-training habits)

struct HabitDetailCard: View {
    let habit: Habit
    let modelContext: ModelContext
    let timeframe: HabitBreakdownView.Timeframe
    let effectiveDays: Int
    let activationDate: Date?
    
    private var completionStats: (completed: Int, total: Int, rate: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let activation = activationDate else {
            return (0, 0, 0)
        }
        
        let activationStart = calendar.startOfDay(for: activation)
        
        var totalDays = 0
        var completedDays = 0
        
        for dayOffset in 0..<effectiveDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // Skip if before activation
            if date < activationStart { continue }
            
            // Check if habit applies to this day
            if habit.appliesTo(date: date) {
                totalDays += 1
                
                if let completions = habit.completions {
                    let isCompleted = completions.contains { completion in
                        calendar.isDate(completion.date, inSameDayAs: date) && completion.completed
                    }
                    if isCompleted {
                        completedDays += 1
                    }
                }
            }
        }
        
        let rate = totalDays > 0 ? Double(completedDays) / Double(totalDays) : 0
        return (completedDays, totalDays, rate)
    }
    
    private var iconForPillar: String {
        switch habit.pillar.lowercased() {
        case "sleep": return "bed.double.fill"
        case "nutrition": return "fork.knife"
        case "recovery": return "heart.fill"
        case "fitness": return "figure.run"
        default: return "star.fill"
        }
    }
    
    private var colorForPillar: Color {
        switch habit.pillar.lowercased() {
        case "sleep": return .blue
        case "nutrition": return .green
        case "recovery": return .purple
        case "fitness": return .orange
        default: return .atlasPrimary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: iconForPillar)
                        .font(.system(size: 20))
                        .foregroundColor(colorForPillar)
                        .frame(width: 44, height: 44)
                        .background(colorForPillar.opacity(0.15))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        Text(habit.pillar)
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
                
                Spacer()
                
                // Completion percentage
                Text("\(Int(completionStats.rate * 100))%")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(colorForPillar)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForPillar)
                        .frame(width: geometry.size.width * completionStats.rate, height: 8)
                }
            }
            .frame(height: 8)
            
            // Stats
            Text("\(completionStats.completed) of \(completionStats.total) days")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        HabitBreakdownView()
    }
}
