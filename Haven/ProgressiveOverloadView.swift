import SwiftUI
import SwiftData
import Charts

struct ProgressiveOverloadView: View {
    @Environment(\.unitFormatter) private var unitFormatter
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    
    private var uniqueExercises: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in sessions {
            for exercise in session.exercises {
                let name = exercise.name.lowercased()
                if !seen.contains(name) {
                    seen.insert(name)
                    result.append(exercise.name)
                }
            }
        }
        return result
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            if uniqueExercises.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Track your progress over time")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(uniqueExercises.prefix(10), id: \.self) { exercise in
                            NavigationLink(destination: ExerciseProgressDetailView(exerciseName: exercise)) {
                                ExerciseProgressRow(exerciseName: exercise, modelContext: modelContext)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Progressive Overload")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.atlasTextMuted)
            
            Text("No Progress Data Yet")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.atlasText)
            
            Text("Log workouts to track your progressive overload")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Exercise Progress Row (with e1RM)

struct ExerciseProgressRow: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let exerciseName: String
    let modelContext: ModelContext
    
    private var history: [Exercise] {
        WorkoutHistoryService.getExerciseHistory(for: exerciseName, modelContext: modelContext, limit: 5)
    }
    
    private var latestWeight: Double? {
        history.first?.sets.compactMap { $0.weight }.max()
    }
    
    private var estimatedMax: EstimatedMaxResult? {
        EstimatedMaxCalculator.bestE1RM(exerciseName: exerciseName, modelContext: modelContext, daysBack: 30)
    }
    
    private var trend: String {
        guard history.count >= 2 else { return "→" }
        let recent = history[0].sets.compactMap { $0.weight }.max() ?? 0
        let previous = history[1].sets.compactMap { $0.weight }.max() ?? 0
        if recent > previous { return "↑" }
        if recent < previous { return "↓" }
        return "→"
    }
    
    private var isCompoundLift: Bool {
        EstimatedMaxCalculator.compoundLiftCategory(for: exerciseName) != nil
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasText)
                
                HStack(spacing: 8) {
                    Text("\(history.count) sessions")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    // Show e1RM badge for weighted exercises
                    if let e1rm = estimatedMax {
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack(spacing: 3) {
                            Text("e1RM")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isCompoundLift ? .atlasPrimary : .atlasTextMuted)
                            
                            Text("\(Int(e1rm.estimatedMax))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isCompoundLift ? .atlasPrimary : .atlasText)
                        }
                    }
                }
            }
            
            Spacer()
            
            if let weight = latestWeight {
                HStack(spacing: 4) {
                    Text(unitFormatter.displayWeightInt(weight))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(trend)
                        .font(.system(size: 16))
                        .foregroundColor(trend == "↑" ? .green : trend == "↓" ? .red : .atlasTextMuted)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Progress Detail View (with e1RM chart + card)

struct ExerciseProgressDetailView: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let exerciseName: String
    @Environment(\.modelContext) private var modelContext
    
    private var history: [Exercise] {
        WorkoutHistoryService.getExerciseHistory(for: exerciseName, modelContext: modelContext, limit: 20)
    }
    
    private var estimatedMax: EstimatedMaxResult? {
        EstimatedMaxCalculator.bestE1RM(exerciseName: exerciseName, modelContext: modelContext, daysBack: 30)
    }
    
    private var e1rmTrend: [EstimatedMaxDataPoint] {
        EstimatedMaxCalculator.e1RMTrend(exerciseName: exerciseName, modelContext: modelContext, limit: 20)
    }
    
    private var isCompoundLift: Bool {
        EstimatedMaxCalculator.compoundLiftCategory(for: exerciseName) != nil
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // PRs for this exercise
                    let prs = WorkoutHistoryService.findPRs(for: exerciseName, modelContext: modelContext)
                    
                    if prs.maxWeight != nil || prs.maxReps != nil {
                        prSection(prs: prs)
                    }
                    
                    // Estimated 1RM card
                    if let e1rm = estimatedMax {
                        estimatedMaxSection(e1rm: e1rm)
                    }
                    
                    // e1RM trend chart (only if we have 2+ data points)
                    if e1rmTrend.count >= 2 {
                        e1rmChartSection
                    }
                    
                    // History
                    historySection
                }
                .padding(24)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Estimated Max Section
    
    private func estimatedMaxSection(e1rm: EstimatedMaxResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("ESTIMATED 1-REP MAX")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
                
                if isCompoundLift {
                    Text("• PACE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.atlasPrimary.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            
            HStack(alignment: .bottom, spacing: 16) {
                // Big number
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(e1rm.estimatedMax))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                    
                    Text("lbs estimated max")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                // Basis
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Based on")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text(e1rm.basisDescription)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(e1rm.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .padding(20)
            .background(Color.atlasPrimary.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
            )
            
            // Explanation
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
                
                Text("Calculated using the Epley formula from your best set in the last 30 days")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
                
                if isCompoundLift {
                    Text("• Used in your Pace score")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
    }
    
    // MARK: - e1RM Trend Chart
    
    private var e1rmChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTIMATED MAX TREND")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Chart(e1rmTrend) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.estimatedMax)
                )
                .foregroundStyle(Color.atlasPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.estimatedMax)
                )
                .foregroundStyle(Color.atlasPrimary)
                .symbolSize(60)
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.estimatedMax)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.atlasPrimary.opacity(0.2), Color.atlasPrimary.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 10))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 10))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(16)
            .background(Color.white.opacity(0.03))
            .cornerRadius(16)
        }
    }
    
    // MARK: - PR Section
    
    private func prSection(prs: ExercisePRs) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL RECORDS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            HStack(spacing: 16) {
                if let weight = prs.maxWeight {
                    VStack(spacing: 4) {
                        Text("\(Int(weight))")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.yellow)
                        Text(unitFormatter.weightUnit)
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if let reps = prs.maxReps {
                    VStack(spacing: 4) {
                        Text("\(reps)")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.atlasPrimary)
                        Text("reps")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // e1RM as a third PR card
                if let e1rm = estimatedMax {
                    VStack(spacing: 4) {
                        Text("\(Int(e1rm.estimatedMax))")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.cyan)
                        Text("e1RM")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HISTORY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            ForEach(history, id: \.id) { exercise in
                ExerciseHistoryRow(exercise: exercise)
            }
        }
    }
}

// MARK: - Exercise History Row

struct ExerciseHistoryRow: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let exercise: Exercise
    
    private var summary: String {
        let sets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
        return sets.map { set in
            if let weight = set.weight {
                return "\(Int(weight))x\(set.reps)"
            } else {
                return "\(set.reps)"
            }
        }.joined(separator: ", ")
    }
    
    private var sessionE1RM: Double? {
        EstimatedMaxCalculator.bestE1RM(from: exercise)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.workoutSession?.date.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                // Show per-session e1RM
                if let e1rm = sessionE1RM {
                    Text("e1RM: \(Int(e1rm))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.atlasPrimary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            Text(summary)
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        ProgressiveOverloadView()
    }
}