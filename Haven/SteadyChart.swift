// SteadyChart.swift
// Steady — the one chart style used across the app (Sprint 3 chart overhaul).
//
// - SteadyLineChart: raw readings as faint dots, a solid line (through the trend
//   when there is one), PRs as solid markers, an optional dashed goal rule.
// - SteadyBarChart: weekly bars with an optional dashed target.
// - SteadySparkline: axis-free line for list rows.
//
// Flat color, hairline grid, tabular axis labels. No gradients or area fills.

import SwiftUI
import Charts

// MARK: - Data

struct SteadyChartPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
    /// Smoothed value; when present the line follows this and the raw value shows as a dot
    var trend: Double? = nil
    /// Drawn as a solid marker (e.g. a PR)
    var isHighlighted: Bool = false
}

enum SteadyChartRange: Int, CaseIterable, Identifiable {
    case month = 30, quarter = 90, year = 365, all = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .month: return "30D"
        case .quarter: return "90D"
        case .year: return "1Y"
        case .all: return "All"
        }
    }

    func filter(_ points: [SteadyChartPoint], now: Date = Date()) -> [SteadyChartPoint] {
        guard self != .all, let cutoff = Calendar.current.date(byAdding: .day, value: -rawValue, to: now) else { return points }
        return points.filter { $0.date >= cutoff }
    }
}

// MARK: - Line Chart

struct SteadyLineChart: View {
    let points: [SteadyChartPoint]
    var tint: Color = .atlasPrimary
    var goal: Double? = nil
    var height: CGFloat = 180
    /// Format for y-axis labels
    var axisFormat: (Double) -> String = { String(format: "%.0f", $0) }
    var emptyText: String = "Not enough data yet."

    private var hasTrend: Bool { points.contains { $0.trend != nil } }

    private var span: TimeInterval {
        guard let first = points.first?.date, let last = points.last?.date else { return 0 }
        return last.timeIntervalSince(first)
    }

    private var yDomain: ClosedRange<Double> {
        var values = points.flatMap { [$0.value, $0.trend].compactMap { $0 } }
        if let goal { values.append(goal) }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.15, max(abs(hi) * 0.01, 0.5))
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        if points.count < 2 {
            Text(points.isEmpty ? emptyText : "One reading so far. The line starts with the second.")
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: height)
        } else {
            Chart {
                if hasTrend {
                    ForEach(points) { p in
                        PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                            .symbolSize(14)
                            .foregroundStyle(tint.opacity(0.35))
                    }
                }

                ForEach(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Line", p.trend ?? p.value))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(tint)
                }

                ForEach(points.filter(\.isHighlighted)) { p in
                    PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                        .symbol(.diamond)
                        .symbolSize(48)
                        .foregroundStyle(Color.atlasAmber)
                }

                if !hasTrend, let last = points.last {
                    PointMark(x: .value("Date", last.date), y: .value("Value", last.value))
                        .symbolSize(36)
                        .foregroundStyle(tint)
                }

                if let goal {
                    RuleMark(y: .value("Goal", goal))
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
                    AxisValueLabel(format: span > 200 * 86_400 ? .dateTime.month(.abbreviated) : .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Color.atlasTextMuted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.steadyHairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(axisFormat(v))
                                .font(SteadyType.metric(10, weight: .regular))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Bar Chart

struct SteadyBarChart: View {
    struct Bar: Identifiable {
        var id: Date { date }
        let date: Date
        let value: Double
        /// Current, unfinished period: drawn lighter
        var isPartial: Bool = false
    }

    let bars: [Bar]
    var tint: Color = .atlasPrimary
    var target: Double? = nil
    var height: CGFloat = 120

    var body: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(x: .value("Week", bar.date, unit: .weekOfYear), y: .value("Value", bar.value), width: .ratio(0.6))
                    .foregroundStyle(bar.isPartial ? tint.opacity(0.4) : tint)
                    .cornerRadius(2)
            }
            if let target {
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.atlasTextMuted)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Color.atlasTextMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
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
        .frame(height: height)
    }
}

// MARK: - Sparkline

struct SteadySparkline: View {
    let values: [Double]
    var tint: Color = .atlasPrimary

    var body: some View {
        if values.count >= 2, let lo = values.min(), let hi = values.max() {
            let pad = max((hi - lo) * 0.1, 0.5)
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("i", index), y: .value("v", value))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(tint)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (lo - pad)...(hi + pad))
        } else {
            Rectangle().fill(Color.clear)
        }
    }
}
