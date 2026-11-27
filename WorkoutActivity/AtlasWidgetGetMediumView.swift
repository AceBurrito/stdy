// AtlasWidgetMediumView.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Medium (4×2): left, today's recovery call and why; right, today's workout
// with its first exercises. Body numbers live in the app (they change slowly
// and don't decide anything about today).

import SwiftUI
import WidgetKit

struct AtlasWidgetMediumView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            WidgetRecoveryBlock(entry: entry, titleSize: 24, showsSignals: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle()
                .fill(Color.widgetHairline)
                .frame(width: 1)

            WidgetWorkoutPreview(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .widgetURL(URL(string: "atlas://today"))
        .containerBackground(for: .widget) {
            Color.widgetBackground
        }
    }
}

/// Today's workout: name, then up to three exercises with sets × reps.
struct WidgetWorkoutPreview: View {
    let entry: AtlasWidgetEntry
    private let maxRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetLabel(text: "Today")
            HStack(spacing: 4) {
                Text(entry.isRestDay ? "Rest day" : entry.workoutName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(entry.workoutCompleted ? .widgetMuted : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if entry.workoutCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.widgetTeal)
                }
            }

            if entry.workoutCompleted {
                note("Done for today. Recover well.")
            } else if entry.isRestDay {
                note("Walk, stretch, or take it easy.")
            } else if !entry.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(entry.exercises.prefix(maxRows).enumerated()), id: \.offset) { _, exercise in
                        HStack(spacing: 6) {
                            Text(exercise.name)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(exercise.scheme)
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundColor(.widgetMuted)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    if entry.exercises.count > maxRows {
                        Text("+\(entry.exercises.count - maxRows) more")
                            .font(.system(size: 11))
                            .foregroundColor(.widgetMuted)
                    }
                }
                .padding(.top, 2)
            } else if !entry.workoutDetail.isEmpty {
                note(entry.workoutDetail)
            } else if entry.workoutExerciseCount > 0 {
                note("\(entry.workoutExerciseCount) exercises")
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.widgetMuted)
            .lineLimit(2)
    }
}
