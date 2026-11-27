import SwiftUI
import SwiftData

// MARK: - Change Plan View
// Shown when user taps "Change Plan" on TrainingProgramView.
// Flow:
// 1. Shows on-demand training analysis (weeks, adherence, lift progressions)
// 2. User taps "Explore Plans" → navigates to PlanSelectionView with bias
// 3. Or taps "Keep Current Plan" to dismiss

struct ChangePlanView: View {
    @Environment(\.unitFormatter) private var unitFormatter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<TrainingProgram> { $0.isActive == true && $0.isEventPlan == false },
        sort: \TrainingProgram.generatedDate,
        order: .reverse
    ) private var activePrograms: [TrainingProgram]

    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]

    @State private var analysis: TrainingStatusAnalyzer.TrainingAnalysis? = nil
    @State private var showPlanSelection = false
    @State private var showPlanPreview = false
    @State private var selectedTemplate: TrainingPlanTemplate? = nil
    @State private var showCustomBuilder = false

    private var program: TrainingProgram? { activePrograms.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                if showCustomBuilder {
                    CustomPlanBuilderView(
                        onComplete: { dismiss() },
                        onBack: { showCustomBuilder = false }
                    )
                } else if showPlanPreview, let template = selectedTemplate {
                    PlanPreviewView(
                        template: template,
                        onConfirm: { dismiss() },
                        onBack: {
                            showPlanPreview = false
                            selectedTemplate = nil
                        }
                    )
                } else if showPlanSelection {
                    PlanSelectionView(
                        excludingPlanID: program?.planTemplateID,
                        bias: analysis?.bias,
                        onPlanSelected: { template in
                            selectedTemplate = template
                            showPlanPreview = true
                        },
                        onBuildYourOwn: { showCustomBuilder = true },
                        onEventTraining: {
                            // Route to existing EventCreationFlow — dismiss this sheet
                            // and let the parent handle navigation
                            dismiss()
                        },
                        onKeepCurrent: { dismiss() },
                        isChangePlanFlow: true
                    )
                } else {
                    analysisView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
                ToolbarItem(placement: .principal) {
                    Text("CHANGE PLAN")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1.5)
                }
            }
        }
        .onAppear {
            if let prog = program {
                analysis = TrainingStatusAnalyzer.analyze(
                    program: prog,
                    workoutSessions: workoutSessions,
                    modelContext: modelContext
                )
            }
        }
    }

    // MARK: - Analysis View

    private var analysisView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR CURRENT PLAN")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1.5)

                    if let prog = program {
                        Text(prog.programSummary ?? "Training Program")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.atlasText)
                    }
                }

                if let analysis = analysis {
                    // Stats row
                    HStack(spacing: 16) {
                        AnalysisStat(
                            value: "\(analysis.weeksActive)",
                            label: "weeks",
                            color: .atlasPrimary
                        )
                        AnalysisStat(
                            value: "\(Int(analysis.adherencePercent))%",
                            label: "adherence",
                            color: analysis.adherencePercent >= 70 ? .atlasPrimary : .atlasAmber
                        )
                        AnalysisStat(
                            value: "\(analysis.liftProgressions.count)",
                            label: "lifts tracked",
                            color: .atlasTextMuted
                        )
                    }

                    // Lift progressions
                    if !analysis.liftProgressions.isEmpty {
                        liftProgressionSection(analysis.liftProgressions)
                    }

                    // Assessment text
                    assessmentCard(analysis.assessmentText)

                } else if program == nil {
                    // No active program
                    VStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 40))
                            .foregroundColor(.atlasTextMuted.opacity(0.3))

                        Text("No active training plan")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: { withAnimation { showPlanSelection = true } }) {
                        Text("Explore New Plans")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if program != nil {
                        Button(action: { dismiss() }) {
                            Text("Keep Current Plan")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Lift Progression Section

    private func liftProgressionSection(_ progressions: [TrainingStatusAnalyzer.LiftProgression]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LIFT PROGRESSION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)

            ForEach(Array(progressions.prefix(6).enumerated()), id: \.offset) { _, lift in
                HStack(spacing: 12) {
                    // Trend indicator
                    Text(lift.trend.rawValue)
                        .font(.system(size: 16))
                        .frame(width: 24)

                    // Lift name
                    Text(lift.exerciseName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                        .lineLimit(1)

                    Spacer()

                    // e1RM values
                    if let current = lift.currentE1RM {
                        Text(unitFormatter.displayWeightInt(current))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(colorForTrend(lift.trend))
                    }

                    // Change %
                    if let change = lift.changePercent {
                        Text(String(format: "%+.0f%%", change))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(colorForTrend(lift.trend))
                            .frame(width: 50, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Assessment Card

    private func assessmentCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasPrimary)

                Text("ASSESSMENT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
                    .tracking(1.5)
            }

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.atlasPrimary.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasPrimary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func colorForTrend(_ trend: TrainingStatusAnalyzer.LiftProgression.Trend) -> Color {
        switch trend {
        case .improving: return .atlasPrimary
        case .stalling: return .atlasAmber
        case .declining: return .atlasAccent
        case .insufficient: return .atlasTextMuted
        }
    }
}

// MARK: - Analysis Stat

struct AnalysisStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
}