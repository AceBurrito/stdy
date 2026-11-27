import SwiftUI
import SwiftData

struct HabitHeatmapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allHabits: [Habit]
    
    let days: Int // How many days to show
    
    @State private var selectedDate: Date?
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var dateRange: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { daysAgo in
            calendar.date(byAdding: .day, value: -daysAgo, to: today)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Habit Heatmap")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Text("Last \(days) days")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }
            
            if allHabits.filter({ $0.isActive }).isEmpty {
                Text("No active habits to track")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    // Calendar grid
                    calendarGrid
                    
                    // Legend
                    legend
                    
                    // Best/worst days
                    if let analysis = analyzePerformance() {
                        performanceAnalysis(analysis)
                    }
                    
                    // Selected date details
                    if let date = selectedDate {
                        selectedDateDetails(date)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(dateRange, id: \.self) { date in
                dayCell(for: date)
            }
        }
    }
    
    private func dayCell(for date: Date) -> some View {
        let completionRate = getCompletionRate(for: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
        
        return RoundedRectangle(cornerRadius: 4)
            .fill(colorForRate(completionRate))
            .frame(height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? Color.atlasPrimary : (isSelected ? Color.atlasAccent : Color.clear), lineWidth: isToday || isSelected ? 2 : 0)
            )
            .overlay(
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday ? .semibold : .regular))
                    .foregroundColor(completionRate > 0.3 ? .white : .atlasTextMuted)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast) ? nil : date
                }
            }
    }
    
    private func colorForRate(_ rate: Double) -> Color {
        if rate == 0 {
            return Color.white.opacity(0.05)
        } else if rate < 0.33 {
            return Color.red.opacity(0.3)
        } else if rate < 0.67 {
            return Color.orange.opacity(0.5)
        } else {
            return Color.atlasPrimary.opacity(0.8)
        }
    }
    
    // MARK: - Legend
    private var legend: some View {
        HStack(spacing: 8) {
            Text("Less")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
            
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { rate in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForRate(rate))
                    .frame(width: 16, height: 16)
            }
            
            Text("More")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Performance Analysis
    private func analyzePerformance() -> (bestDay: String, worstDay: String, averageRate: Double)? {
        var dayCompletions: [Int: (total: Int, completed: Int)] = [:]
        
        // Calculate completion rates by day of week
        for date in dateRange {
            let weekday = calendar.component(.weekday, from: date)
            let rate = getCompletionRate(for: date)
            let activeHabits = allHabits.filter { $0.isActive }.count
            
            if dayCompletions[weekday] == nil {
                dayCompletions[weekday] = (0, 0)
            }
            
            dayCompletions[weekday]?.total += activeHabits
            dayCompletions[weekday]?.completed += Int(rate * Double(activeHabits))
        }
        
        // Find best and worst days
        let dayRates = dayCompletions.map { (weekday: $0.key, rate: Double($0.value.completed) / Double($0.value.total)) }
        
        guard let best = dayRates.max(by: { $0.rate < $1.rate }),
              let worst = dayRates.min(by: { $0.rate < $1.rate }) else {
            return nil
        }
        
        let bestDayName = calendar.weekdaySymbols[best.weekday - 1]
        let worstDayName = calendar.weekdaySymbols[worst.weekday - 1]
        
        let totalRate = dateRange.map { getCompletionRate(for: $0) }.reduce(0, +) / Double(dateRange.count)
        
        return (bestDayName, worstDayName, totalRate)
    }
    
    private func performanceAnalysis(_ analysis: (bestDay: String, worstDay: String, averageRate: Double)) -> some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 4)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Day")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    Text(analysis.bestDay)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Worst Day")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    Text(analysis.worstDay)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Average")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    Text("\(Int(analysis.averageRate * 100))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                }
            }
        }
    }
    
    // MARK: - Selected Date Details
    private func selectedDateDetails(_ date: Date) -> some View {
        let completionRate = getCompletionRate(for: date)
        let completedCount = getCompletedHabitsCount(for: date)
        let totalCount = allHabits.filter { $0.isActive }.count
        
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 4)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text("\(completedCount) of \(totalCount) habits completed")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                Text("\(Int(completionRate * 100))%")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.atlasPrimary)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getCompletionRate(for date: Date) -> Double {
        let dataController = DataController(modelContext: modelContext)
        let activeHabits = allHabits.filter { $0.isActive }
        
        guard !activeHabits.isEmpty else { return 0 }
        
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { completion in
                completion.date >= startOfDay &&
                completion.date < endOfDay &&
                completion.completed == true
            }
        )
        
        guard let completions = try? modelContext.fetch(descriptor) else {
            return 0
        }
        
        return Double(completions.count) / Double(activeHabits.count)
    }
    
    private func getCompletedHabitsCount(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { completion in
                completion.date >= startOfDay &&
                completion.date < endOfDay &&
                completion.completed == true
            }
        )
        
        guard let completions = try? modelContext.fetch(descriptor) else {
            return 0
        }
        
        return completions.count
    }
}

#Preview {
    HabitHeatmapView(days: 30)
        .padding()
        .background(Color.atlasBackground)
}
