import SwiftUI
import SwiftData

// MARK: - Plan Preview View
// Shows the selected template plan with workouts pre-assigned to days.
// Users can:
// 1. See the full 7-day week (training days + rest days)
// 2. Tap a day to swap it (uses existing day picker)
// 3. Confirm to advance to the cardio step
//
// ✅ UPDATED: Cardio add-on removed (moved to dedicated CardioOnboardingStepView).
// ✅ UPDATED: "Start This Plan" → "Continue" (plan commits after cardio step).

struct PlanPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    let template: TrainingPlanTemplate

    /// Called when user taps Continue — advances to cardio step (does NOT commit yet)
    var onConfirm: (() -> Void)?

    /// Called when user wants to go back to plan selection
    var onBack: (() -> Void)?

    @State private var dayAssignments: [DayAssigner.DayAssignment] = []
    @State private var showTooltip = true
    @State private var expandedDay: Int? = nil
    @State private var showDayPicker = false
    @State private var selectedSwapDay: Int? = nil

    private var userProfile: UserProfile? { profiles.first }

    /// Rest days from current assignments — passed to CardioOnboardingStepView
    var currentRestDays: [Int] {
        dayAssignments
            .filter { $0.workoutType == "rest" }
            .map { $0.dayOfWeek }
    }

    /// Current day assignments — needed by the onboarding flow for commit
    var currentDayAssignments: [DayAssigner.DayAssignment] {
        dayAssignments
    }

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    // Plan summary
                    planSummaryCard

                    // Tooltip
                    if showTooltip {
                        tooltipBanner
                    }

                    // 7-day schedule
                    weekScheduleSection

                    // Continue button (advances to cardio step)
                    continueButton

                    // Back button
                    backButton

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            dayAssignments = DayAssigner.assignDays(for: template)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREVIEW YOUR PLAN")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)

            Text(template.name)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)
        }
        .padding(.top, 8)
    }

    // MARK: - Plan Summary

    private var planSummaryCard: some View {
        HStack(spacing: 16) {
            SummaryPill(value: "\(template.strengthDays)", label: "days/week")
            SummaryPill(value: template.splitType, label: "split")
            SummaryPill(value: template.equipmentTier.displayName, label: "equipment")
        }
    }

    // MARK: - Tooltip

    private var tooltipBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 16))
                .foregroundColor(.atlasPrimary)

            Text("Tap a day to swap it")
                .font(.system(size: 14))
                .foregroundColor(.atlasText)

            Spacer()

            Button(action: { withAnimation { showTooltip = false } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .padding(12)
        .background(Color.atlasPrimary.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Week Schedule

    private var weekScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR WEEK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)

            ForEach(dayAssignments, id: \.dayOfWeek) { assignment in
                DayPreviewRow(
                    assignment: assignment,
                    isExpanded: expandedDay == assignment.dayOfWeek,
                    onTap: {
                        if assignment.workoutType == "strength" {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedDay = expandedDay == assignment.dayOfWeek ? nil : assignment.dayOfWeek
                            }
                        }
                    },
                    onSwap: {
                        selectedSwapDay = assignment.dayOfWeek
                        showDayPicker = true
                    }
                )
            }
        }
    }

    // MARK: - Continue (was "Start This Plan")

    private var continueButton: some View {
        Button(action: { onConfirm?() }) {
            HStack(spacing: 8) {
                Text("Continue")                       // ✅ RENAMED from "Start This Plan"
                    .font(.system(size: 18, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.atlasBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.atlasPrimary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }

    private var backButton: some View {
        Button(action: { onBack?() ?? dismiss() }) {
            Text("Back to Plans")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Day Preview Row (unchanged)

struct DayPreviewRow: View {
    let assignment: DayAssigner.DayAssignment
    let isExpanded: Bool
    let onTap: () -> Void
    let onSwap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Text(DayAssigner.dayName(for: assignment.dayOfWeek))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .frame(width: 36, alignment: .leading)

                    Text(assignment.workoutName)
                        .font(.system(size: 15, weight: assignment.workoutType == "rest" ? .regular : .medium))
                        .foregroundColor(assignment.workoutType == "rest" ? .atlasTextMuted.opacity(0.5) : .atlasText)

                    Spacer()

                    if assignment.workoutType == "strength" {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasPrimary)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
                .padding(.vertical, 12)

                if isExpanded, let workout = assignment.templateWorkout {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(workout.exercises.prefix(3).enumerated()), id: \.offset) { _, exercise in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.atlasPrimary.opacity(0.4))
                                    .frame(width: 4, height: 4)

                                Text(exercise.exerciseID)
                                    .font(.system(size: 13))
                                    .foregroundColor(.atlasTextMuted)

                                Spacer()

                                Text("\(exercise.sets)×\(exercise.reps)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.atlasTextMuted.opacity(0.7))
                            }
                        }

                        if workout.exercises.count > 3 {
                            Text("+\(workout.exercises.count - 3) more")
                                .font(.system(size: 12))
                                .foregroundColor(.atlasTextMuted.opacity(0.5))
                                .padding(.leading, 12)
                        }

                        Button(action: onSwap) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 11))
                                Text("Swap Day")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.atlasPrimary)
                            .padding(.top, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 12)
                    .padding(.leading, 50)
                }
            }
            .padding(.horizontal, 14)
            .background(
                assignment.workoutType == "strength"
                    ? Color.white.opacity(0.04)
                    : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Summary Pill (unchanged)

struct SummaryPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasText)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}