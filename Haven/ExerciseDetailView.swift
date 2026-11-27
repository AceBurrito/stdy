import SwiftUI
import SwiftData
import Charts

// MARK: - Exercise Detail View
// Unified view showing e1RM hero card with sparkline, personal records,
// and full session history for a single exercise.

struct ExerciseDetailView: View {
    let exerciseName: String
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @State private var exerciseHistory: [Exercise] = []
    @State private var e1rmTrend: [EstimatedMaxDataPoint] = []
    @State private var prs: ExercisePRs = ExercisePRs(
        maxWeight: nil, maxWeightDate: nil,
        maxVolume: nil, maxVolumeDate: nil,
        maxReps: nil, maxRepsDate: nil,
        maxBestSet: nil, maxBestSetDate: nil
    )
    
    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    e1rmHeroCard
                    personalRecordsSection
                    sessionHistorySection
                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }
    
    // MARK: - e1RM Hero Card
    
    private var e1rmHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ESTIMATED 1RM")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            if let latest = e1rmTrend.last {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(latest.estimatedMax))")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(unitFormatter.weightUnit)
                        .font(.system(size: 18))
                        .foregroundColor(.atlasTextMuted)
                }
                
                // Trend vs previous session
                if e1rmTrend.count >= 2 {
                    let prev = e1rmTrend[e1rmTrend.count - 2].estimatedMax
                    let diff = latest.estimatedMax - prev
                    let sign = diff >= 0 ? "+" : ""
                    
                    HStack(spacing: 4) {
                        Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12))
                        Text("\(sign)\(unitFormatter.displayWeightInt(abs(diff))) from last session")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(diff >= 0 ? .atlasPrimary : .atlasAccent)
                }
                
                // Sparkline chart
                if e1rmTrend.count >= 2 {
                    e1rmSparkline
                        .frame(height: 80)
                        .padding(.top, 8)
                }
            } else {
                Text("No weighted sets logged yet")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - e1RM Sparkline
    
    @ViewBuilder
    private var e1rmSparkline: some View {
        let minVal = (e1rmTrend.map(\.estimatedMax).min() ?? 0) * 0.95
        let maxVal = (e1rmTrend.map(\.estimatedMax).max() ?? 100) * 1.05
        
        Chart(e1rmTrend) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("e1RM", point.estimatedMax)
            )
            .foregroundStyle(Color.atlasPrimary)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Min", minVal),
                yEnd: .value("e1RM", point.estimatedMax)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.atlasPrimary.opacity(0.2), Color.atlasPrimary.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            PointMark(
                x: .value("Date", point.date),
                y: .value("e1RM", point.estimatedMax)
            )
            .foregroundStyle(Color.atlasPrimary)
            .symbolSize(point.id == e1rmTrend.last?.id ? 30 : 15)
        }
        .chartYScale(domain: minVal...maxVal)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
    
    // MARK: - Personal Records Section
    
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL RECORDS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            VStack(spacing: 8) {
                if let bestE1RM = e1rmTrend.map(\.estimatedMax).max() {
                    let bestDate = e1rmTrend.first(where: { $0.estimatedMax == bestE1RM })?.date
                    prRow(label: "Best e1RM", value: unitFormatter.displayWeightInt(Double(Int(bestE1RM))), date: bestDate)
                }
                
                if let maxW = prs.maxWeight {
                    prRow(label: "Heaviest", value: unitFormatter.displayWeightInt(maxW), date: prs.maxWeightDate)
                }
                
                if let maxR = prs.maxReps {
                    prRow(label: "Most Reps", value: "\(maxR) reps", date: prs.maxRepsDate)
                }
            }
            
            if e1rmTrend.isEmpty && prs.maxWeight == nil {
                Text("Log more sessions to build your PR history")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .padding(.vertical, 8)
            }
        }
    }
    
    private func prRow(label: String, value: String, date: Date?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.atlasText)
            
            if let date = date {
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted.opacity(0.7))
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Session History
    
    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HISTORY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            if exerciseHistory.isEmpty {
                Text("No sessions found for this exercise")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .padding(16)
            } else {
                VStack(spacing: 1) {
                    ForEach(exerciseHistory, id: \.id) { exercise in
                        sessionHistoryRow(exercise: exercise)
                    }
                }
                .cornerRadius(12)
            }
        }
    }
    
    private func sessionHistoryRow(exercise: Exercise) -> some View {
        let sessionDate = exercise.workoutSession?.date ?? Date()
        let sortedSets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
        let currentE1RM = EstimatedMaxCalculator.bestE1RM(from: exercise)
        
        // Check if this session was a PR (e1RM higher than all other sessions)
        let isSessionPR: Bool = {
            guard let curr = currentE1RM else { return false }
            let otherBests = exerciseHistory
                .filter { $0.id != exercise.id }
                .compactMap { EstimatedMaxCalculator.bestE1RM(from: $0) }
            return otherBests.allSatisfy { curr > $0 } && !otherBests.isEmpty
        }()
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sessionDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                if isSessionPR {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("PR")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.atlasBackground)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.atlasPrimary)
                    .cornerRadius(4)
                }
                
                if let e1rm = currentE1RM {
                    Text("e1RM: \(Int(e1rm))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            // Sets display
            Text(sortedSets.map { set in
                if set.isBodyweight {
                    return "BW×\(set.reps)"
                } else if let w = set.weight {
                    return "\(Int(w))×\(set.reps)"
                } else {
                    return "\(set.reps) reps"
                }
            }.joined(separator: ", "))
            .font(.system(size: 13))
            .foregroundColor(.atlasTextMuted)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
    }
    
    // MARK: - Load Data
    
    private func loadData() {
        exerciseHistory = WorkoutHistoryService.getExerciseHistory(
            for: exerciseName,
            modelContext: modelContext,
            limit: 30
        )
        
        e1rmTrend = EstimatedMaxCalculator.e1RMTrend(
            exerciseName: exerciseName,
            modelContext: modelContext,
            limit: 20
        )
        
        prs = WorkoutHistoryService.findPRs(
            for: exerciseName,
            modelContext: modelContext
        )
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exerciseName: "Bench Press")
    }
}