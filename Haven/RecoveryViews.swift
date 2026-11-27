// RecoveryViews.swift
// Steady — Recovery Score hero (Today tab) and its detail sheet.

import SwiftUI

// MARK: - Hero

struct RecoveryHeroCard: View {
    /// nil when there is no recovery data at all yet
    let assessment: RecoveryAssessment?
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recovery").steadyLabel()
                    Spacer()
                    if assessment?.isCalibrating == true {
                        Text("Calibrating").steadyLabel(.atlasAmber)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.steadyTextFaint)
                }

                if let assessment {
                    stateBlock(assessment)
                    inputsRow(assessment)
                } else {
                    emptyBlock
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.atlasCardDark)
            .overlay(alignment: .leading) {
                // State color as a solid edge, not a glow
                Rectangle()
                    .fill(assessment?.state.color ?? Color.steadyTextFaint)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.steadyHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func stateBlock(_ assessment: RecoveryAssessment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(assessment.state.title.uppercased())
                .font(SteadyType.display(40))
                .foregroundColor(assessment.state.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(assessment.state.guidance)
                .font(SteadyType.body)
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    private func inputsRow(_ assessment: RecoveryAssessment) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach([RecoveryComponent.Kind.sleep, .hrv, .rhr], id: \.rawValue) { kind in
                RecoveryInputColumn(kind: kind, component: assessment.component(kind))
                if kind != .rhr {
                    Rectangle()
                        .fill(Color.steadyHairline)
                        .frame(width: 1)
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(.top, 16)
    }

    private var emptyBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NO DATA YET")
                .font(SteadyType.display(32))
                .foregroundColor(.atlasTextMuted)
            Text("Recovery reads sleep, HRV and resting heart rate from Apple Health. Wear your watch overnight and check back in the morning.")
                .font(SteadyType.body)
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }
}

private struct RecoveryInputColumn: View {
    let kind: RecoveryComponent.Kind
    let component: RecoveryComponent?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kind.shortLabel).steadyLabel(.steadyTextFaint)
            Text(component?.valueText ?? "—")
                .font(SteadyType.metric(17))
                .foregroundColor(component == nil ? .steadyTextFaint : .atlasText)
            Text(component?.deltaText ?? component?.bandText ?? "no data")
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ScoreBar(score: component?.score)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, kind == .sleep ? 0 : 12)
    }
}

/// Four-segment bar: one lit segment per scoring band (25/50/75/100).
struct ScoreBar: View {
    let score: Int?

    private var litSegments: Int {
        guard let score else { return 0 }
        switch score {
        case ..<40: return 1
        case 40..<65: return 2
        case 65..<85: return 3
        default: return 4
        }
    }

    private var color: Color {
        guard let score else { return .steadyTextFaint }
        return RecoveryState.from(score: score).color
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(i < litSegments ? color : Color.steadyRaised)
                    .frame(height: 3)
            }
        }
    }
}

// MARK: - Detail Sheet

struct RecoveryDetailSheet: View {
    let assessment: RecoveryAssessment?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let assessment {
                        header(assessment)
                        ForEach(assessment.components) { component in
                            componentRow(component)
                        }
                        if !assessment.missingKinds.isEmpty {
                            Text("Missing today: \(assessment.missingKinds.map(\.label).joined(separator: ", ")). The score uses what's available and reweights the rest.")
                                .font(SteadyType.caption)
                                .foregroundColor(.atlasTextMuted)
                        }
                        if assessment.isCalibrating {
                            Text("Your HRV and resting heart rate baselines are still building. Scores settle after about two weeks of overnight data.")
                                .font(SteadyType.caption)
                                .foregroundColor(.atlasAmber)
                        }
                    }
                    howItWorks
                }
                .padding(20)
            }
            .background(Color.atlasBackground.ignoresSafeArea())
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func header(_ assessment: RecoveryAssessment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(assessment.date.formatted(.dateTime.weekday(.wide).month().day()))
                .steadyLabel()
            Text(assessment.state.title.uppercased())
                .font(SteadyType.display(44))
                .foregroundColor(assessment.state.color)
            Text(assessment.state.guidance)
                .font(SteadyType.body)
                .foregroundColor(.atlasText)
            if let adjustment = assessment.state.trainingAdjustment {
                Text(adjustment)
                    .font(SteadyType.body)
                    .foregroundColor(.atlasTextMuted)
            }
        }
    }

    private func componentRow(_ component: RecoveryComponent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(component.kind.label).steadyLabel()
                Spacer()
                Text("\(Int(component.kind.weight * 100))% of score")
                    .font(SteadyType.caption)
                    .foregroundColor(.steadyTextFaint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(component.valueText)
                    .font(SteadyType.metric(28))
                    .foregroundColor(.atlasText)
                if let delta = component.deltaText {
                    Text(delta)
                        .font(SteadyType.body)
                        .foregroundColor(.atlasTextMuted)
                }
            }
            ScoreBar(score: component.score)
            Text(explanation(for: component))
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .steadyPanel()
    }

    private func explanation(for component: RecoveryComponent) -> String {
        switch component.kind {
        case .sleep:
            return "Last night. Scored on fixed bands: 7–8 hours is solid, 8+ is full credit."
        case .hrv:
            let avg = component.baseline.map { String(format: "%.0f ms", $0) } ?? "—"
            return "Your \(component.baselineDays)-day average is \(avg). Higher than usual means you've recovered."
        case .rhr:
            let avg = component.baseline.map { String(format: "%.0f bpm", $0) } ?? "—"
            return "Your \(component.baselineDays)-day average is \(avg). Elevated resting heart rate means you're carrying fatigue."
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it's scored").steadyLabel()
            Text("Sleep counts for 40%, HRV for 35% and resting heart rate for 25%. HRV and resting heart rate are compared with your own 30-day averages, not population norms. Days without data are skipped, never counted as zero.")
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}
