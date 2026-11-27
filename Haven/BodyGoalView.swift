// BodyGoalView.swift
// Steady — pick a target body fat %, see the goal weight it implies.
// Goal weight = today's lean mass ÷ (1 − target), so it moves as lean mass moves.

import SwiftUI
import SwiftData

struct BodyGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var entries: [BodyCompEntry]

    @State private var targetPercent: Double = 15
    @State private var showLog = false

    private var profile: UserProfile? { profiles.first }
    private var state: BodyState { BodyState.from(entries: entries, profile: profile) }

    private var preview: BodyGoal? {
        BodyGoal.from(state: state, targetBodyFat: targetPercent / 100)
    }

    private var range: ClosedRange<Double> {
        profile?.gender?.lowercased() == "female" ? 14...40 : 6...35
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if state.latestBodyFat == nil {
                        needsBodyFat
                    } else {
                        currentPanel
                        targetPanel
                        resultPanel
                        Text("Assumes you keep your current lean mass. If you build muscle on the way, the goal weight rises with it.")
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
            }
            .background(Color.atlasBackground.ignoresSafeArea())
            .navigationTitle("Body Fat Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundColor(.atlasPrimary)
                        .disabled(state.latestBodyFat == nil)
                }
            }
            .sheet(isPresented: $showLog) {
                AddWeightView()
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Sections

    private var needsBodyFat: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Needs a body fat reading").steadyLabel()
            Text("Your goal weight comes from your lean mass, which needs a body fat %. Log one from a smart scale, DEXA, calipers or your best estimate.")
                .font(SteadyType.body)
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Log body fat") { showLog = true }
                .buttonStyle(SteadyPrimaryButtonStyle())
        }
        .steadyPanel()
    }

    private var currentPanel: some View {
        HStack(alignment: .top, spacing: 0) {
            stat("Body fat", state.latestBodyFat.map { String(format: "%.1f", $0 * 100) } ?? "—", "%")
            stat("Lean mass", state.leanMass.map { String(format: "%.1f", unitFormatter.fromLbs($0)) } ?? "—", unitFormatter.weightUnit)
            stat("Weight", (state.trendWeight ?? state.latestWeight).map { String(format: "%.1f", unitFormatter.fromLbs($0)) } ?? "—", unitFormatter.weightUnit)
        }
        .steadyPanel()
    }

    private var targetPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Target body fat").steadyLabel()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", targetPercent))
                    .font(SteadyType.display(48))
                    .foregroundColor(.atlasText)
                Text("%")
                    .font(SteadyType.title)
                    .foregroundColor(.atlasTextMuted)
                Spacer()
                Stepper("", value: $targetPercent, in: range, step: 0.5)
                    .labelsHidden()
            }
            Slider(value: $targetPercent, in: range, step: 0.5)
                .tint(.atlasPrimary)
        }
        .steadyPanel()
    }

    @ViewBuilder
    private var resultPanel: some View {
        if let goal = preview {
            VStack(alignment: .leading, spacing: 10) {
                Text("Goal weight").steadyLabel()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", unitFormatter.fromLbs(goal.goalWeight)))
                        .font(SteadyType.display(40))
                        .foregroundColor(.atlasPrimary)
                    Text(unitFormatter.weightUnit)
                        .font(SteadyType.title)
                        .foregroundColor(.atlasTextMuted)
                }
                Text(BodyGoalText.summary(goal, unitFormatter: unitFormatter))
                    .font(SteadyType.body)
                    .foregroundColor(.atlasTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .steadyPanel()
        }
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).steadyLabel(.steadyTextFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(SteadyType.metric(20)).foregroundColor(.atlasText)
                Text(unit).font(SteadyType.caption).foregroundColor(.atlasTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func load() {
        if let target = profile?.targetBodyFatPercent {
            targetPercent = (target * 100 * 2).rounded() / 2
        } else if let current = state.latestBodyFat {
            // Start a few points under where they are now
            targetPercent = ((current * 100 - 4) * 2).rounded() / 2
        }
        targetPercent = min(max(targetPercent, range.lowerBound), range.upperBound)
    }

    private func save() {
        guard let profile else { return }
        profile.targetBodyFatPercent = targetPercent / 100
        if let goal = preview { profile.goalWeight = goal.goalWeight }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared goal copy

enum BodyGoalText {
    /// "8.4 lbs to lose · on pace for Mar 14" style line.
    static func summary(_ goal: BodyGoal, unitFormatter: UnitFormatter) -> String {
        if goal.isReached { return "You're at your target. Hold it, or set a new one." }
        let amount = String(format: "%.1f %@", unitFormatter.fromLbs(abs(goal.toGo)), unitFormatter.weightUnit)
        let verb = goal.toGo > 0 ? "to lose" : "to gain"
        if let date = goal.projectedDate {
            let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            let when = sameYear
                ? date.formatted(.dateTime.month(.abbreviated).day())
                : date.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(amount) \(verb). At your current rate, around \(when)."
        }
        return "\(amount) \(verb). A projected date shows once your trend is heading that way."
    }
}

#Preview {
    BodyGoalView()
}
