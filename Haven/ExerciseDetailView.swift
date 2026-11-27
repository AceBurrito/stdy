// ExerciseDetailView.swift
// Steady — one lift's progressive overload: where it is now, the trend
// (e1RM, top set, volume or reps), records, and every session.

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exerciseName: String

    @Environment(\.unitFormatter) private var unitFormatter
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var customExercises: [CustomExercise]

    @State private var metric: LiftMetric? = nil
    @State private var range: SteadyChartRange = .all

    private var history: LiftHistory? {
        LiftAnalytics.history(named: exerciseName, sessions: sessions, resolver: MuscleGroupResolver(customExercises: customExercises))
    }

    private func metrics(for history: LiftHistory) -> [LiftMetric] {
        history.isBodyweight ? [.reps] : [.e1rm, .topSet, .volume]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let history, !history.points.isEmpty {
                    heroPanel(history)
                    chartPanel(history)
                    recordsPanel(history)
                    sessionsPanel(history)
                } else {
                    Text("No sessions logged for this exercise yet.")
                        .font(SteadyType.body)
                        .foregroundColor(.atlasTextMuted)
                        .steadyPanel()
                }
                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: - Hero

    private func heroPanel(_ history: LiftHistory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(history.isBodyweight ? "Best reps, last session" : "Estimated 1RM, last session").steadyLabel()
                Spacer()
                TrendChip(trend: history.trend)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(primaryText(history.latest, history: history))
                    .font(SteadyType.display(48))
                    .foregroundColor(.atlasText)
                Text(history.isBodyweight ? "reps" : unitFormatter.weightUnit)
                    .font(SteadyType.title)
                    .foregroundColor(.atlasTextMuted)
            }
            HStack(spacing: 16) {
                if let best = history.best {
                    labeled("Best", primaryText(best, history: history))
                }
                if let change = history.change() {
                    labeled("8 weeks", String(format: "%@%.1f%%", change >= 0 ? "+" : "−", abs(change) * 100))
                }
                labeled("Sessions", "\(history.points.count)")
            }
            if !history.isBodyweight {
                Text("e1RM uses the Epley formula on your best set, capped at 12 reps.")
                    .font(SteadyType.caption)
                    .foregroundColor(.steadyTextFaint)
            }
        }
        .steadyPanel()
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).steadyLabel(.steadyTextFaint)
            Text(value)
                .font(SteadyType.metric(15))
                .foregroundColor(.atlasText)
        }
    }

    private func primaryText(_ value: Double?, history: LiftHistory) -> String {
        guard let value else { return "—" }
        return history.isBodyweight ? "\(Int(value))" : String(format: "%.0f", unitFormatter.fromLbs(value))
    }

    // MARK: - Chart

    private func chartPanel(_ history: LiftHistory) -> some View {
        let options = metrics(for: history)
        let selected = metric.flatMap { options.contains($0) ? $0 : nil } ?? options[0]
        let points = range.filter(history.points.compactMap { p -> SteadyChartPoint? in
            guard let v = p.value(for: selected) else { return nil }
            let shown = selected == .reps ? v : unitFormatter.fromLbs(v)
            return SteadyChartPoint(date: p.date, value: shown, isHighlighted: p.isPR && selected == history.primaryMetric)
        })

        return VStack(alignment: .leading, spacing: 14) {
            if options.count > 1 {
                SteadySegmented(options: options, selection: Binding(get: { selected }, set: { metric = $0 })) { $0.title }
            }
            SteadyLineChart(
                points: points,
                tint: .atlasPrimary,
                axisFormat: { v in v >= 10_000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v) },
                emptyText: "No sessions in this range."
            )
            HStack {
                SteadySegmented(options: SteadyChartRange.allCases, selection: $range) { $0.title }
            }
            if history.points.contains(where: \.isPR) {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.atlasAmber)
                    Text("New best")
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
        .steadyPanel()
    }

    // MARK: - Records

    private func recordsPanel(_ history: LiftHistory) -> some View {
        let bestE1RM = history.points.filter { $0.e1rm != nil }.max { ($0.e1rm ?? 0) < ($1.e1rm ?? 0) }
        let heaviest = history.points.filter { $0.topWeight != nil }.max { ($0.topWeight ?? 0) < ($1.topWeight ?? 0) }
        let mostVolume = history.points.filter { $0.volume > 0 }.max { $0.volume < $1.volume }
        let mostReps = history.points.max { $0.bestReps < $1.bestReps }

        return VStack(alignment: .leading, spacing: 0) {
            Text("Records").steadyLabel().padding(.bottom, 8)
            if let p = bestE1RM, let v = p.e1rm {
                recordRow("Best e1RM", unitFormatter.displayWeightInt(v), p.date)
            }
            if let p = heaviest, let w = p.topWeight {
                recordRow("Heaviest set", "\(unitFormatter.displayWeightInt(w)) × \(p.topReps)", p.date)
            }
            if let p = mostVolume {
                recordRow("Most volume", unitFormatter.displayVolume(p.volume), p.date)
            }
            if let p = mostReps, p.bestReps > 0 {
                recordRow("Most reps", "\(p.bestReps)", p.date)
            }
        }
        .steadyPanel()
    }

    private func recordRow(_ label: String, _ value: String, _ date: Date) -> some View {
        HStack {
            Text(label)
                .font(SteadyType.body)
                .foregroundColor(.atlasTextMuted)
            Spacer()
            Text(value)
                .font(SteadyType.metric(15))
                .foregroundColor(.atlasText)
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(SteadyType.caption)
                .foregroundColor(.steadyTextFaint)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Sessions

    private func sessionsPanel(_ history: LiftHistory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sessions").steadyLabel().padding(.bottom, 8)
            ForEach(Array(history.points.reversed().enumerated()), id: \.element.id) { index, point in
                if index > 0 { Rectangle().fill(Color.steadyHairline).frame(height: 1) }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(SteadyType.bodyEmphasis)
                            .foregroundColor(.atlasText)
                        if point.isPR {
                            Text("BEST")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.atlasBackground)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.atlasAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Spacer()
                        if let e1rm = point.e1rm {
                            Text("e1RM \(Int(unitFormatter.fromLbs(e1rm).rounded()))")
                                .font(SteadyType.metric(12, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    Text(setsText(point.sets))
                        .font(SteadyType.metric(13, weight: .regular))
                        .foregroundColor(.atlasTextMuted)
                }
                .padding(.vertical, 10)
            }
        }
        .steadyPanel()
    }

    private func setsText(_ sets: [WorkoutSet]) -> String {
        sets.map { set in
            if set.isBodyweight || (set.weight ?? 0) == 0 { return "BW×\(set.reps)" }
            return "\(Int(unitFormatter.fromLbs(set.weight ?? 0).rounded()))×\(set.reps)"
        }
        .joined(separator: "  ")
    }
}

// MARK: - Trend Chip

struct TrendChip: View {
    let trend: LiftTrend

    private var color: Color {
        switch trend {
        case .progressing: return .atlasPrimary
        case .holding: return .atlasTextMuted
        case .dropping: return .atlasAmber
        case .building: return .steadyTextFaint
        }
    }

    var body: some View {
        Text(trend.title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.5), lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exerciseName: "Bench Press (Barbell)")
    }
}
