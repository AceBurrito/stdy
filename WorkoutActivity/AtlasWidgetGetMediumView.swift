// AtlasWidgetMediumView.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Medium (4×2) home screen widget layout.
// Shows: top line message + streak, habit names with completion dots,
// today's workout with exercise count.

import SwiftUI
import WidgetKit

struct AtlasWidgetMediumView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        VStack(spacing: 0) {
            // Top section — message + streak
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    // Top line message
                    if entry.checkInAvailable && !entry.checkInCompleted {
                        HStack(spacing: 4) {
                            Text("📋")
                            Text("Weekly check-in ready")
                                .font(.caption.bold())
                                .foregroundColor(.widgetCoral)
                        }
                        Text("Tap to review your week")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if entry.paceChanged {
                        HStack(spacing: 4) {
                            Text(entry.paceDirection == "improved" ? "▼" : "▲")
                                .font(.caption2)
                            Text("Pace \(entry.paceDirection)")
                                .font(.caption.bold())
                                .foregroundColor(
                                    entry.paceDirection == "improved"
                                        ? .widgetTeal
                                        : .widgetCoral
                                )
                        }
                        Text("Tap to see details")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if entry.streakCount > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("🔥 \(entry.streakCount) day")
                            .font(.caption.bold())
                            .foregroundColor(.widgetCoral)
                        Text("streak")
                            .font(.caption2)
                            .foregroundColor(.widgetCoral.opacity(0.7))
                    }
                }
            }

            Spacer().frame(height: 10)

            // Bottom section — habits (left) + training (right)
            HStack(alignment: .top, spacing: 16) {
                // Habits list
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<min(entry.habitNames.count, 3), id: \.self) { i in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(
                                    i < entry.habitStates.count && entry.habitStates[i]
                                        ? Color.widgetTeal
                                        : Color.white.opacity(0.2)
                                )
                                .frame(width: 7, height: 7)

                            Text(entry.habitNames[i])
                                .font(.caption2)
                                .foregroundColor(
                                    i < entry.habitStates.count && entry.habitStates[i]
                                        ? .white : .secondary
                                )
                                .lineLimit(1)

                            if i < entry.habitStates.count && entry.habitStates[i] {
                                Text("✓")
                                    .font(.caption2.bold())
                                    .foregroundColor(.widgetTeal)
                            }
                        }
                    }

                    Text("\(entry.habitsCompleted) of \(entry.habitsTotal) done")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                Spacer()

                // Training
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(entry.isRestDay ? "😌" : (entry.workoutType == "cardio" ? "🏃" : "🏋️"))
                            .font(.callout)
                        Text(entry.isRestDay ? "Rest Day" : entry.workoutName)
                            .font(.caption.bold())
                            .foregroundColor(entry.workoutCompleted ? .secondary : .white)
                            .lineLimit(1)
                    }

                    if !entry.isRestDay && !entry.workoutCompleted {
                        Text(entry.workoutType == "cardio"
                             ? "Cardio"
                             : "\(entry.workoutExerciseCount) exercises")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if entry.workoutCompleted {
                        Text("✓ Done")
                            .font(.caption2.bold())
                            .foregroundColor(.widgetTeal)
                    }
                }
            }
        }
        .padding(16)
        .widgetURL(widgetURL)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.16),
                    Color(red: 0.07, green: 0.07, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var widgetURL: URL {
        if entry.checkInAvailable && !entry.checkInCompleted {
            return URL(string: "atlas://checkin")!
        }
        return URL(string: "atlas://today")!
    }
}
