// BodyTrendChart.swift
// Steady — weight / body fat / lean mass over time, drawn with the shared
// SteadyLineChart: daily readings as faint dots, the 7-day trend as the line,
// an optional goal as a dashed rule.

import SwiftUI

struct BodyTrendChart: View {
    let metric: BodyMetric
    let points: [BodyDayPoint]
    let range: SteadyChartRange
    /// Goal line in the metric's own units (lbs or fraction)
    var goalValue: Double? = nil

    @Environment(\.unitFormatter) private var unitFormatter

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

    private var chartPoints: [SteadyChartPoint] {
        range.filter(points.map {
            SteadyChartPoint(date: $0.date, value: display($0.value), trend: display($0.trend))
        })
    }

    var body: some View {
        SteadyLineChart(
            points: chartPoints,
            tint: tint,
            goal: goalValue.map(display),
            emptyText: "No \(metric.title.lowercased()) readings in this range."
        )
    }
}
