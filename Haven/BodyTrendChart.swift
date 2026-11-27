// BodyTrendChart.swift
// Steady — weight / body fat / lean mass over time. Daily readings as faint
// dots, the 7-day trend as a solid line, an optional goal as a dashed rule.

import SwiftUI
import Charts

enum BodyChartRange: Int, CaseIterable, Identifiable {
    case month = 30, quarter = 90, year = 365

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .month: return "30D"
        case .quarter: return "90D"
        case .year: return "1Y"
        }
    }
}

struct BodyTrendChart: View {
    let metric: BodyMetric
    let points: [BodyDayPoint]
    let range: BodyChartRange
    /// Goal line in the metric's own units (lbs or fraction)
    var goalValue: Double? = nil

    @Environment(\.unitFormatter) private var unitFormatter

    private var visible: [BodyDayPoint] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -range.rawValue, to: Date()) else { return points }
        return points.filter { $0.date >= cutoff }
    }

    /// Converts stored units to what the user reads (kg/lbs, or percent)
    private func display(_ value: Double) -> Double {
        switch metric {
        case .bodyFat: return value * 100
        case .weight, .leanMass: return unitFormatter.fromLbs(value)
        }
    }

    private var tint: Color {
        switch metric {
        case .weight: return .atlasPrimary
        case .bodyFat: return .atlasAccent
        case .leanMass: return .steadyGreen
        }
    }

    private var yDomain: ClosedRange<Double> {
        var values = visible.flatMap { [display($0.value), display($0.trend)] }
        if let goalValue { values.append(display(goalValue)) }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.15, metric == .bodyFat ? 0.5 : 1)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        if visible.count < 2 {
            Text(visible.isEmpty
                 ? "No \(metric.title.lowercased()) readings in this range."
                 : "One reading so far. The trend line starts with the second.")
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
        } else {
            Chart {
                ForEach(visible) { point in
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value(metric.title, display(point.value))
                    )
                    .symbolSize(14)
                    .foregroundStyle(tint.opacity(0.35))
                }

                ForEach(visible) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Trend", display(point.trend))
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(tint)
                }

                if let goalValue {
                    RuleMark(y: .value("Goal", display(goalValue)))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.atlasTextMuted)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("GOAL")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(.atlasTextMuted)
                        }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.steadyHairline)
                    AxisValueLabel(format: range == .year ? .dateTime.month(.abbreviated) : .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Color.atlasTextMuted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.steadyHairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0f", v))
                                .font(SteadyType.metric(10, weight: .regular))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }
}
