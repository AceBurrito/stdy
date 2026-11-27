import SwiftUI
import SwiftData

struct HealthTrendsView: View {
    @Query(sort: \HealthMetrics.date, order: .reverse) private var allMetrics: [HealthMetrics]
    
    @State private var selectedTimeframe: Timeframe = .week
    
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
    }
    
    private var metrics: [HealthMetrics] {
        Array(allMetrics.prefix(selectedTimeframe.days))
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Timeframe picker
                    timeframePicker
                    
                    if metrics.isEmpty {
                        emptyState
                    } else {
                        // Sleep chart
                        MetricChartView(
                            title: "Sleep Duration",
                            data: sleepChartData,
                            color: .atlasPrimary,
                            unit: "hours",
                            metricType: .sleep
                        )
                        
                        // HRV chart
                        if !hrvChartData.isEmpty {
                            MetricChartView(
                                title: "Heart Rate Variability",
                                data: hrvChartData,
                                color: .atlasPrimary,
                                unit: "ms",
                                metricType: .hrv
                            )
                        }
                        
                        // RHR chart
                        if !rhrChartData.isEmpty {
                            MetricChartView(
                                title: "Resting Heart Rate",
                                data: rhrChartData,
                                color: .atlasAccent,
                                unit: "bpm",
                                metricType: .rhr
                            )
                        }

                        // VO2 Max chart
                        if !vo2ChartData.isEmpty {
                            MetricChartView(
                                title: "VO2 Max",
                                data: vo2ChartData,
                                color: .atlasPrimary,
                                unit: "ml/kg/min",
                                metricType: .vo2Max
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Health Trends")
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
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.atlasTextMuted)
            
            Text("No health data yet")
                .font(.system(size: 17))
                .foregroundColor(.atlasTextMuted)
            
            Text("Connect Apple Health to see your trends")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var sleepChartData: [ChartDataPoint] {
        metrics.reversed().compactMap { metric in
            guard let sleep = metric.sleepDuration else { return nil }
            return ChartDataPoint(date: metric.date, value: sleep)
        }
    }
    
    private var hrvChartData: [ChartDataPoint] {
        metrics.reversed().compactMap { metric in
            guard let hrv = metric.heartRateVariability else { return nil }
            return ChartDataPoint(date: metric.date, value: hrv)
        }
    }
    
    private var rhrChartData: [ChartDataPoint] {
        metrics.reversed().compactMap { metric in
            guard let rhr = metric.restingHeartRate else { return nil }
            return ChartDataPoint(date: metric.date, value: rhr)
        }
    }

    private var vo2ChartData: [ChartDataPoint] {
        metrics.reversed().compactMap { metric in
            guard let vo2 = metric.vo2Max else { return nil }
            return ChartDataPoint(date: metric.date, value: vo2)
        }
    }
}

#Preview {
    NavigationView {
        HealthTrendsView()
    }
}