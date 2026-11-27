import SwiftUI
import Charts

struct MetricChartView: View {
    let title: String
    let data: [ChartDataPoint]
    let color: Color
    let unit: String
    let metricType: MetricType? // Add this parameter to identify the metric
    
    enum MetricType {
        case hrv
        case rhr
        case vo2Max
        case steps
        case sleep
        case weight
        
        var yAxisRange: ClosedRange<Double> {
            switch self {
            case .hrv: return 0...120
            case .rhr: return 40...100
            case .vo2Max: return 20...70
            case .steps: return 0...20000
            case .sleep: return 0...12
            case .weight: return 100...250 // Will be overridden with dynamic range
            }
        }
        
        var isLowerBetter: Bool {
            switch self {
            case .rhr: return true // Lower resting heart rate is better
            default: return false // Higher is better for all others
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header (hidden when embedded with empty title)
            if !title.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        if let latest = data.last {
                            HStack(spacing: 4) {
                                Text(String(format: "%.1f", latest.value))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(.atlasText)
                                
                                Text(unit)
                                    .font(.system(size: 16))
                                    .foregroundColor(.atlasTextMuted)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Trend indicator
                    if let trend = calculateTrend() {
                        HStack(spacing: 4) {
                            Image(systemName: trend.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(trend.color)
                            
                            Text(String(format: "%.1f%%", abs(trend.percentage)))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(trend.color)
                        }
                    }
                }
            }
            
            // Chart
            if data.isEmpty {
                Text("No data yet")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.05)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: data.count > 14 ? 7 : 1)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 11))
                            .foregroundStyle(Color.atlasTextMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(Color.atlasTextMuted)
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .frame(height: 200)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Y-Axis Domain
    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else { return 0...100 }
        
        if let type = metricType {
            // Use predefined ranges for known metrics
            switch type {
            case .weight:
                // Dynamic range for weight (±20 lbs from data range)
                let values = data.map { $0.value }
                let minVal = values.min() ?? 150
                let maxVal = values.max() ?? 200
                let padding = 20.0
                return (minVal - padding)...(maxVal + padding)
            default:
                return type.yAxisRange
            }
        } else {
            // Fallback: auto-scale with 10% padding
            let values = data.map { $0.value }
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 100
            let range = maxVal - minVal
            let padding = range * 0.1
            return (minVal - padding)...(maxVal + padding)
        }
    }
    
    // MARK: - Trend Calculation
    private func calculateTrend() -> (icon: String, color: Color, percentage: Double)? {
        guard data.count >= 2 else { return nil }
        
        let recentCount = min(3, data.count)
        let recent = Array(data.suffix(recentCount))
        let older = Array(data.prefix(recentCount))
        
        let recentAvg = recent.reduce(0.0) { $0 + $1.value } / Double(recent.count)
        let olderAvg = older.reduce(0.0) { $0 + $1.value } / Double(older.count)
        
        let percentageChange = ((recentAvg - olderAvg) / olderAvg) * 100
        
        // Determine if change is positive based on metric type
        let isLowerBetter = metricType?.isLowerBetter ?? false
        let isPositiveChange = isLowerBetter ? (percentageChange < 0) : (percentageChange > 0)
        
        if abs(percentageChange) > 2 {
            if isPositiveChange {
                return ("arrow.up.right", .green, percentageChange)
            } else {
                return ("arrow.down.right", .red, percentageChange)
            }
        } else {
            return ("arrow.right", .gray, percentageChange)
        }
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

#Preview {
    MetricChartView(
        title: "Sleep Duration",
        data: [
            ChartDataPoint(date: Date().addingTimeInterval(-6*86400), value: 6.8),
            ChartDataPoint(date: Date().addingTimeInterval(-5*86400), value: 7.2),
            ChartDataPoint(date: Date().addingTimeInterval(-4*86400), value: 6.5),
            ChartDataPoint(date: Date().addingTimeInterval(-3*86400), value: 7.5),
            ChartDataPoint(date: Date().addingTimeInterval(-2*86400), value: 7.8),
            ChartDataPoint(date: Date().addingTimeInterval(-1*86400), value: 7.3),
            ChartDataPoint(date: Date(), value: 7.6)
        ],
        color: .blue,
        unit: "hours",
        metricType: .sleep
    )
    .padding()
    .background(Color.atlasBackground)
}