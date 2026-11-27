import SwiftUI
import SwiftData

struct HabitHistoryTab: View {
    let habit: Habit
    @Environment(\.modelContext) private var modelContext
    
    @State private var completionData: [Date: Bool] = [:]
    @State private var currentStreak = 0
    @State private var longestStreak = 0
    @State private var totalCompletions = 0
    
    private let calendar = Calendar.current
    
    // Last 30 days
    private var last30Days: [Date] {
        (0..<30).compactMap { daysAgo in
            calendar.date(byAdding: .day, value: -daysAgo, to: Date())
        }.reversed()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats cards
                statsSection
                
                // 30-day calendar
                calendarSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .onAppear {
            loadCompletionData()
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            HabitStatCard(
                title: "Current",
                value: "\(currentStreak)",
                subtitle: "day streak",
                icon: "flame.fill",
                color: .orange
            )
            
            HabitStatCard(
                title: "Longest",
                value: "\(longestStreak)",
                subtitle: "day streak",
                icon: "star.fill",
                color: .atlasPrimary
            )
            
            HabitStatCard(
                title: "Total",
                value: "\(totalCompletions)",
                subtitle: "completed",
                icon: "checkmark.circle.fill",
                color: .atlasAccent
            )
        }
    }
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 30 Days")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasText)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(last30Days, id: \.self) { date in
                    DayCell(
                        date: date,
                        isCompleted: completionData[calendar.startOfDay(for: date)] ?? false,
                        isToday: calendar.isDateInToday(date)
                    )
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .atlasPrimary, text: "Completed")
                LegendItem(color: .white.opacity(0.1), text: "Incomplete")
                LegendItem(color: .atlasAccent, text: "Today")
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
    }
    
    private func loadCompletionData() {
        let dataController = DataController(modelContext: modelContext)
        
        // Load completion data for last 30 days
        var data: [Date: Bool] = [:]
        for date in last30Days {
            let startOfDay = calendar.startOfDay(for: date)
            data[startOfDay] = dataController.isHabitComplete(habit: habit, on: date)
        }
        completionData = data
        
        // Calculate streaks
        currentStreak = dataController.getHabitStreak(habit: habit)
        longestStreak = calculateLongestStreak()
        totalCompletions = data.values.filter { $0 }.count
    }
    
    private func calculateLongestStreak() -> Int {
        var longest = 0
        var current = 0
        
        for date in last30Days {
            let startOfDay = calendar.startOfDay(for: date)
            if completionData[startOfDay] == true {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        
        return longest
    }
}

// MARK: - Habit Stat Card
struct HabitStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.atlasText)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.atlasTextMuted)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let isCompleted: Bool
    let isToday: Bool
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.atlasAccent.opacity(0.3))
            } else if isCompleted {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.atlasPrimary)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            }
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.atlasBackground)
            } else {
                Text(dayNumber)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isToday ? .atlasText : .atlasTextMuted)
            }
        }
        .frame(height: 36)
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, HabitCompletion.self, configurations: config)
    let context = container.mainContext
    
    let habit = Habit(
        title: "Morning Sunlight",
        details: "10 minutes within 1 hour of waking",
        pillar: "Sleep"
    )
    context.insert(habit)
    
    // Add some mock completions
    for i in 0..<20 {
        if i % 3 != 0 { // Complete 2 out of 3 days
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let completion = HabitCompletion(date: date, completed: true)
            completion.habit = habit
            context.insert(completion)
        }
    }
    
    return HabitHistoryTab(habit: habit)
        .modelContainer(container)
        .background(Color.atlasBackground)
}
