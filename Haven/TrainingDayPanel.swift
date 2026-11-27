// MARK: - TrainingDayPanel
// Today's training on the Today tab. Exercise list with targets for strength days,
// zone targets for cardio days, recovery guidance for rest days.
// Completion comes from logged sessions (no habit system), and the panel
// carries a one-line adjustment when recovery is amber or coral.

import SwiftUI
import SwiftData

struct TrainingDayPanel: View {
    let todaysWorkout: PlannedWorkoutDay?
    let isCompleted: Bool
    /// Today's recovery state, used for the adjustment line. Nil when unknown.
    var recoveryState: RecoveryState? = nil

    // Last session context
    let lastSessionVolume: Double?
    let lastSessionDate: Date?
    let lastCardioSession: CardioSession?

    // Actions
    let onStartWorkout: () -> Void
    let onStartCardio: () -> Void

    @Environment(\.unitFormatter) private var unitFormatter

    private var dayType: String {
        todaysWorkout?.dayType ?? "rest"
    }

    private var dayName: String {
        guard let workout = todaysWorkout, workout.dayType != "rest" else { return "Rest Day" }
        return workout.dayName
    }

    private var exercises: [PlannedExercise] {
        todaysWorkout?.exercises.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !isCompleted, dayType != "rest", let adjustment = recoveryState?.trainingAdjustment {
                adjustmentLine(adjustment)
            }

            switch dayType {
            case "strength":
                strengthContent
            case "cardio":
                cardioContent
            default:
                restContent
            }

            if dayType != "rest" {
                if isCompleted {
                    completedBanner
                } else {
                    actionButton
                }
            }
        }
        .background(Color.atlasCardDark)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.steadyHairline, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's training").steadyLabel()
                Text(dayName)
                    .font(SteadyType.title)
                    .foregroundColor(.atlasText)
            }

            Spacer()

            if isCompleted {
                Text("Done").steadyLabel(.atlasPrimary)
            } else if dayType == "strength", !exercises.isEmpty {
                Text("\(exercises.count) exercises")
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func adjustmentLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(recoveryState?.color ?? .atlasAmber)
                .frame(width: 2)
            Text(text)
                .font(SteadyType.caption)
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.steadyHairline)
            .frame(height: 1)
    }

    // MARK: - Strength Day Content

    private var strengthContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            divider

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(exercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", index + 1))
                            .font(SteadyType.metric(12, weight: .medium))
                            .foregroundColor(.steadyTextFaint)

                        Text(exercise.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.atlasText)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if let reps = exercise.targetReps {
                            Text("\(exercise.targetSets) × \(reps)")
                                .font(SteadyType.metric(14, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .padding(.vertical, 9)

                    if index < min(exercises.count, 6) - 1 {
                        divider.opacity(0.6)
                    }
                }

                if exercises.count > 6 {
                    Text("+ \(exercises.count - 6) more")
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasTextMuted)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)

            if let volume = lastSessionVolume, volume > 0 {
                divider
                HStack(spacing: 6) {
                    Text("Last session").steadyLabel(.steadyTextFaint)
                    Text(unitFormatter.displayVolume(volume))
                        .font(SteadyType.metric(13, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    if let date = lastSessionDate {
                        Text("· \(relativeDate(date))")
                            .font(SteadyType.caption)
                            .foregroundColor(.steadyTextFaint)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Cardio Day Content

    private var cardioContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            divider

            VStack(alignment: .leading, spacing: 12) {
                if let workout = todaysWorkout {
                    HStack(alignment: .top, spacing: 24) {
                        if let hrMin = workout.targetHRMin, let hrMax = workout.targetHRMax {
                            stat(label: "Target HR", value: "\(hrMin)–\(hrMax)", unit: "bpm")
                        }
                        if let duration = workout.cardioDuration {
                            stat(label: "Duration", value: "\(duration)", unit: "min")
                        }
                    }

                    if let proto = workout.cardioProtocol, !proto.isEmpty {
                        Text(proto)
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                    }

                    if let notes = workout.cardioNotes, !notes.isEmpty {
                        Text(notes)
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                            .lineLimit(2)
                    }
                }

                if let lastCardio = lastCardioSession {
                    Text("Last: " + cardioSummary(lastCardio))
                        .font(SteadyType.caption)
                        .foregroundColor(.steadyTextFaint)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private func stat(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).steadyLabel(.steadyTextFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(SteadyType.metric(24))
                    .foregroundColor(.atlasText)
                Text(unit)
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
            }
        }
    }

    private func cardioSummary(_ session: CardioSession) -> String {
        var parts: [String] = ["\(session.duration) min"]
        if let hr = session.avgHeartRate { parts.append("\(Int(hr)) bpm avg") }
        if let dist = session.distance, dist > 0 { parts.append(unitFormatter.displayDistance(dist)) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Rest Day Content

    private var restContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            divider
            Text(todaysWorkout == nil
                 ? "Nothing scheduled. Adaptation happens on days like this: walk, stretch, sleep."
                 : "Adaptation happens on days like this. Walk, stretch, sleep.")
                .font(SteadyType.body)
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: {
            if dayType == "cardio" { onStartCardio() } else { onStartWorkout() }
        }) {
            Text(dayType == "cardio" ? "Log Cardio" : "Start Workout")
        }
        .buttonStyle(SteadyPrimaryButtonStyle())
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    private var completedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
            Text(dayType == "cardio" ? "Cardio logged" : "Workout logged")
                .font(SteadyType.bodyEmphasis)
        }
        .foregroundColor(.atlasPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days) days ago" }
        return "\(days / 7)w ago"
    }
}

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        TrainingDayPanel(
            todaysWorkout: nil,
            isCompleted: false,
            recoveryState: .manageIt,
            lastSessionVolume: 12400,
            lastSessionDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            lastCardioSession: nil,
            onStartWorkout: {},
            onStartCardio: {}
        )
        .padding(.horizontal, 20)
    }
}
