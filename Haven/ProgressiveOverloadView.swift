// ProgressiveOverloadView.swift
// Steady — every lift you've logged, with its trend. Filter by muscle group,
// tap through to the lift's progression chart.

import SwiftUI
import SwiftData

struct ProgressiveOverloadView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var customExercises: [CustomExercise]

    @State private var groupFilter: MuscleGroup? = nil
    @State private var searchText = ""

    private var histories: [LiftHistory] {
        LiftAnalytics.histories(sessions: sessions, resolver: MuscleGroupResolver(customExercises: customExercises))
    }

    private var filtered: [LiftHistory] {
        histories.filter { h in
            (groupFilter == nil || h.group == groupFilter)
            && (searchText.isEmpty || h.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                groupFilterBar
                if filtered.isEmpty {
                    Text(histories.isEmpty ? "Log a workout and your lifts show up here." : "No lifts match.")
                        .font(SteadyType.body)
                        .foregroundColor(.atlasTextMuted)
                        .steadyPanel()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.name) { index, history in
                            if index > 0 { Rectangle().fill(Color.steadyHairline).frame(height: 1) }
                            NavigationLink {
                                ExerciseDetailView(exerciseName: history.name)
                            } label: {
                                LiftRow(history: history)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .steadyPanel(padding: 14)
                }
                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .background(Color.atlasBackground.ignoresSafeArea())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search lifts")
        .navigationTitle("Lifts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("All", selected: groupFilter == nil) { groupFilter = nil }
                ForEach(MuscleGroup.allCases.sorted { $0.sortOrder < $1.sortOrder }) { group in
                    filterChip(group.shortName, selected: groupFilter == group) { groupFilter = group }
                }
            }
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected ? .atlasText : .atlasTextMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.steadyRaised : Color.atlasCardDark)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(selected ? Color.atlasPrimary.opacity(0.6) : Color.steadyHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lift Row (shared with the Strength tab)

struct LiftRow: View {
    let history: LiftHistory
    @Environment(\.unitFormatter) private var unitFormatter

    private var sparkValues: [Double] {
        history.points.suffix(10).compactMap { $0.value(for: history.primaryMetric) }
    }

    private var latestText: String {
        guard let latest = history.latest else { return "—" }
        if history.isBodyweight { return "\(Int(latest)) reps" }
        return unitFormatter.displayWeightInt(latest)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(history.name)
                    .font(SteadyType.bodyEmphasis)
                    .foregroundColor(.atlasText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let group = history.group {
                        Text(group.shortName)
                    }
                    if let last = history.lastDate {
                        Text("·")
                        Text(BodyFormat.relativeDay(last))
                    }
                }
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
            }
            Spacer(minLength: 8)
            SteadySparkline(values: sparkValues, tint: history.trend == .dropping ? .atlasAmber : .atlasPrimary)
                .frame(width: 56, height: 24)
            VStack(alignment: .trailing, spacing: 3) {
                Text(latestText)
                    .font(SteadyType.metric(15))
                    .foregroundColor(.atlasText)
                Text(history.isBodyweight ? "best reps" : "e1RM")
                    .font(SteadyType.caption)
                    .foregroundColor(.steadyTextFaint)
            }
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ProgressiveOverloadView()
    }
}
