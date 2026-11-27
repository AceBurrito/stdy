import SwiftUI
import SwiftData

struct MetricDetailSheet: View {
    @Environment(\.unitFormatter) private var unitFormatter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HealthMetrics.date, order: .reverse) private var allMetrics: [HealthMetrics]
    
    let metric: MetricType
    let currentValue: Double  // 7-day average
    let yesterdayValue: Double?  // Yesterday's single value
    let age: Int?
    let biologicalSex: String?
    
    @State private var selectedTimeframe: TrendTimeframe = .week
    
    enum TrendTimeframe: String, CaseIterable {
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
    }
    
    enum MetricType {
        case sleep
        case hrv
        case rhr
        case steps
        case vo2Max
        case weight
        case adherence
        
        var title: String {
            switch self {
            case .sleep: return "Sleep Duration"
            case .hrv: return "Heart Rate Variability"
            case .rhr: return "Resting Heart Rate"
            case .steps: return "Daily Steps"
            case .vo2Max: return "VO₂ Max"
            case .weight: return "Body Weight"
            case .adherence: return "Adherence"
            }
        }
        
        var icon: String {
            switch self {
            case .sleep: return "bed.double.fill"
            case .hrv: return "waveform.path.ecg"
            case .rhr: return "heart.fill"
            case .steps: return "figure.walk"
            case .vo2Max: return "lungs.fill"
            case .weight: return "scalemass.fill"
            case .adherence: return "chart.bar.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .sleep: return .atlasPrimary       // teal — sleep up = good
            case .hrv: return .atlasPrimary          // teal — HRV up = good
            case .rhr: return .atlasAccent           // coral — RHR is context-dependent
            case .steps: return .atlasPrimary        // teal — activity = positive
            case .vo2Max: return .atlasPrimary       // teal — VO2 up = good
            case .weight: return .atlasTextMuted     // neutral — weight is context-dependent
            case .adherence: return .atlasPrimary
            }
        }
        
        var unit: String {
            switch self {
            case .sleep: return "hours"
            case .hrv: return "ms"
            case .rhr: return "bpm"
            case .steps: return "steps"
            case .vo2Max: return "ml/kg/min"
            case .weight: return "lbs"
            case .adherence: return "%"
            }
        }
        
        /// Bridge to MetricChartView.MetricType for chart rendering
        var chartMetricType: MetricChartView.MetricType? {
            switch self {
            case .sleep: return .sleep
            case .hrv: return .hrv
            case .rhr: return .rhr
            case .steps: return .steps
            case .vo2Max: return .vo2Max
            case .weight: return .weight
            case .adherence: return nil
            }
        }
        
        func description(age: Int?, sex: String?) -> String {
            switch self {
            case .sleep:
                return "Sleep is the foundation of recovery and performance. During deep sleep, your body repairs tissue, consolidates memory, and regulates hormones. Insufficient sleep impairs cognitive function, increases injury risk, and reduces training adaptations."
            case .hrv:
                return "HRV measures the variation in time between heartbeats. Higher HRV indicates better recovery and nervous system balance. It's one of the most reliable indicators of readiness to train hard."
            case .rhr:
                return "Your resting heart rate is measured when you're completely at rest. Lower RHR typically indicates better cardiovascular fitness. An elevated RHR can signal stress, overtraining, or illness."
            case .steps:
                return "Daily steps reflect your baseline activity level. Movement throughout the day improves metabolic health, reduces all-cause mortality, and aids recovery between training sessions."
            case .vo2Max:
                return "VO₂ Max measures your body's maximum oxygen consumption during intense exercise. It's the single best predictor of cardiovascular fitness and longevity. Higher VO₂ Max correlates with reduced all-cause mortality."
            case .weight:
                return "Body weight trends over time (not daily fluctuations) indicate whether you're in a caloric surplus, deficit, or maintenance. Track alongside body composition for full picture."
            case .adherence:
                return "Consistency beats perfection. High adherence to your habits (80%+) drives long-term results. Missing occasional days is normal—what matters is getting back on track quickly."
            }
        }
        
        func getRange(age: Int?, sex: String?) -> (optimal: ClosedRange<Double>, average: ClosedRange<Double>, poor: ClosedRange<Double>)? {
            switch self {
            case .sleep:
                return (
                    optimal: 7.5...9.0,
                    average: 6.5...7.5,
                    poor: 0...6.5
                )
            case .hrv:
                // Varies significantly by age and sex
                if let age = age {
                    if age < 30 {
                        return (optimal: 60...120, average: 40...60, poor: 0...40)
                    } else if age < 50 {
                        return (optimal: 50...100, average: 30...50, poor: 0...30)
                    } else {
                        return (optimal: 40...80, average: 25...40, poor: 0...25)
                    }
                }
                return (optimal: 50...100, average: 30...50, poor: 0...30)
            case .rhr:
                // Lower is better
                if sex?.lowercased() == "male" {
                    return (optimal: 40...60, average: 60...70, poor: 70...100)
                } else {
                    return (optimal: 45...65, average: 65...75, poor: 75...100)
                }
            case .steps:
                return (
                    optimal: 10000...20000,
                    average: 7000...10000,
                    poor: 0...7000
                )
            case .vo2Max:
                // Varies by age and sex
                if let age = age, let sex = sex {
                    if sex.lowercased() == "male" {
                        if age < 30 {
                            return (optimal: 50...70, average: 40...50, poor: 20...40)
                        } else if age < 50 {
                            return (optimal: 45...65, average: 35...45, poor: 20...35)
                        } else {
                            return (optimal: 40...60, average: 30...40, poor: 20...30)
                        }
                    } else {
                        if age < 30 {
                            return (optimal: 45...65, average: 35...45, poor: 20...35)
                        } else if age < 50 {
                            return (optimal: 40...60, average: 30...40, poor: 20...30)
                        } else {
                            return (optimal: 35...55, average: 25...35, poor: 20...25)
                        }
                    }
                }
                return (optimal: 45...65, average: 35...45, poor: 20...35)
            case .adherence:
                return (
                    optimal: 85...100,
                    average: 70...85,
                    poor: 0...70
                )
            case .weight:
                return nil // Too individual
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Drag indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)
                    
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 48))
                            .foregroundColor(metric.color)
                            .frame(width: 80, height: 80)
                            .background(metric.color.opacity(0.15))
                            .cornerRadius(20)
                        
                        Text(metric.title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        // 7-day average (main value)
                        VStack(spacing: 4) {
                            Text("7-Day Average")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                            
                            HStack(spacing: 6) {
                                Text(String(format: "%.1f", currentValue))
                                    .font(.system(size: 36, weight: .light))
                                    .foregroundColor(.atlasText)
                                
                                Text(metric == .weight ? unitFormatter.weightUnit : metric.unit)
                                    .font(.system(size: 20))
                                    .foregroundColor(.atlasTextMuted)
                            }
                            
                            // Yesterday's value as context
                            if let yesterday = yesterdayValue {
                                Text("Yesterday: \(String(format: "%.1f", yesterday)) \(metric == .weight ? unitFormatter.weightUnit : metric.unit)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.atlasTextMuted.opacity(0.7))
                            }
                        }
                    }
                    
                    // Trend Chart
                    trendChartSection
                    
                    // Range indicator (if available)
                    if let ranges = metric.getRange(age: age, sex: biologicalSex) {
                        rangeIndicator(ranges: ranges)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 24)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why It Matters")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        Text(metric.description(age: age, sex: biologicalSex))
                            .font(.system(size: 15))
                            .foregroundColor(.atlasTextMuted)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    
                    // Key insights
                    if let insights = getKeyInsights() {
                        keyInsightsSection(insights)
                    }
                    
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Trend Chart Section
    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timeframe picker
            HStack(spacing: 0) {
                ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                    Button(action: { selectedTimeframe = timeframe }) {
                        Text(timeframe.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedTimeframe == timeframe ? .atlasBackground : .atlasTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedTimeframe == timeframe ? Color.atlasPrimary : Color.clear)
                            .cornerRadius(6)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
            
            // Chart
            let chartData = trendChartData
            if chartData.isEmpty {
                Text("No trend data yet")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 160)
            } else {
                MetricChartView(
                    title: "",
                    data: chartData,
                    color: metric.color,
                    unit: metric == .weight ? unitFormatter.weightUnit : metric.unit,
                    metricType: metric.chartMetricType
                )
                .frame(height: 200)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Trend Chart Data
    private var trendChartData: [ChartDataPoint] {
        let days = selectedTimeframe.days
        let metrics = Array(allMetrics.prefix(days))
        
        return metrics.reversed().compactMap { m in
            let value: Double?
            switch metric {
            case .sleep: value = m.sleepDuration
            case .hrv: value = m.heartRateVariability
            case .rhr: value = m.restingHeartRate
            case .steps: value = m.stepCount
            case .vo2Max: value = m.vo2Max
            case .weight: value = m.weight
            case .adherence: value = nil
            }
            guard let v = value else { return nil }
            return ChartDataPoint(date: m.date, value: v)
        }
    }
    
    // MARK: - Range Indicator
    private func rangeIndicator(ranges: (optimal: ClosedRange<Double>, average: ClosedRange<Double>, poor: ClosedRange<Double>)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Position")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasText)
            
            VStack(spacing: 8) {
                // Visual bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background segments
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.red.opacity(0.3))
                            Rectangle()
                                .fill(Color.orange.opacity(0.3))
                            Rectangle()
                                .fill(Color.green.opacity(0.3))
                        }
                        .frame(height: 40)
                        .cornerRadius(8)
                        
                        // Current value indicator
                        let position = calculatePosition(value: currentValue, ranges: ranges)
                        Circle()
                            .fill(metric.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: geometry.size.width * position - 8)
                    }
                }
                .frame(height: 40)
                
                // Labels
                HStack {
                    Text("Poor")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Text("Average")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Text("Optimal")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            // Status message
            Text(getStatusMessage(ranges: ranges))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(getStatusColor(ranges: ranges))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(getStatusColor(ranges: ranges).opacity(0.15))
                .cornerRadius(8)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Key Insights Section
    private func keyInsightsSection(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasAccent)
                            .frame(width: 20)
                        
                        Text(insight)
                            .font(.system(size: 14))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Functions
    
    private func calculatePosition(value: Double, ranges: (optimal: ClosedRange<Double>, average: ClosedRange<Double>, poor: ClosedRange<Double>)) -> Double {
        let total = ranges.optimal.upperBound - ranges.poor.lowerBound
        let position = (value - ranges.poor.lowerBound) / total
        return max(0, min(1, position))
    }
    
    private func getStatusMessage(ranges: (optimal: ClosedRange<Double>, average: ClosedRange<Double>, poor: ClosedRange<Double>)) -> String {
        if ranges.optimal.contains(currentValue) {
            return "Excellent! You're in the optimal range."
        } else if ranges.average.contains(currentValue) {
            return "Good. Room for improvement to reach optimal."
        } else {
            return "Needs attention. Focus on improving this metric."
        }
    }
    
    private func getStatusColor(ranges: (optimal: ClosedRange<Double>, average: ClosedRange<Double>, poor: ClosedRange<Double>)) -> Color {
        if ranges.optimal.contains(currentValue) {
            return .green
        } else if ranges.average.contains(currentValue) {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getKeyInsights() -> [String]? {
        switch metric {
        case .sleep:
            if currentValue < 7 {
                return [
                    "Most adults need 7-9 hours for optimal recovery",
                    "Sleep debt accumulates and impairs performance",
                    "Prioritize consistent bedtime routines"
                ]
            } else {
                return [
                    "Quality matters more than quantity after 7+ hours",
                    "Track sleep consistency alongside duration",
                    "REM and deep sleep stages are key for recovery"
                ]
            }
        case .hrv:
            if let age = age, age < 50, currentValue < 40 {
                return [
                    "Low HRV may indicate stress or overtraining",
                    "Prioritize sleep, reduce alcohol, manage stress",
                    "Consider deload weeks if persistently low"
                ]
            } else {
                return [
                    "Track trends over time, not daily values",
                    "7-day rolling average is most useful",
                    "HRV drops during hard training blocks (normal)"
                ]
            }
        case .rhr:
            if currentValue > 70 {
                return [
                    "Lower RHR develops with consistent cardio",
                    "Elevated RHR may indicate stress or illness",
                    "Elite endurance athletes: 40-50 bpm"
                ]
            } else {
                return [
                    "Good cardiovascular fitness indicated",
                    "Monitor for sudden increases (5+ bpm)",
                    "Morning RHR is most reliable measurement"
                ]
            }
        case .vo2Max:
            return [
                "VO₂ Max declines ~10% per decade without training",
                "Interval training (HIIT) improves VO₂ Max most",
                "Higher VO₂ Max = reduced mortality risk"
            ]
        case .steps:
            if currentValue < 7000 {
                return [
                    "Start with 7,000 steps/day baseline",
                    "10,000+ steps correlates with better health",
                    "NEAT (non-exercise activity) aids fat loss"
                ]
            } else {
                return [
                    "Excellent daily movement",
                    "Steps complement, don't replace training",
                    "Walking aids recovery between sessions"
                ]
            }
        case .adherence:
            if currentValue < 80 {
                return [
                    "80% adherence drives long-term results",
                    "Identify barriers to consistency",
                    "Simplify habits if struggling to maintain"
                ]
            } else {
                return [
                    "Outstanding consistency",
                    "Perfect adherence isn't required",
                    "Sustainable > optimal but unsustainable"
                ]
            }
        case .weight:
            return [
                "Track weekly average, not daily weight",
                "0.5-1% bodyweight change per week is safe",
                "Pair with body composition for full picture"
            ]
        }
    }
}

#Preview {
    MetricDetailSheet(
        metric: .hrv,
        currentValue: 58,  // 7-day average
        yesterdayValue: 45,  // Yesterday's value
        age: 35,
        biologicalSex: "Male"
    )
}