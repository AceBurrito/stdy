// AtlasWidgetSmallView.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Small (2×2) home screen widget layout.
// Shows: top line (check-in / pace / streak), habit dots, today's workout.

import SwiftUI
import WidgetKit

struct AtlasWidgetSmallView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top line
            WidgetTopLine(entry: entry)

            Spacer()

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.vertical, 6)

            // Bottom section
            VStack(alignment: .leading, spacing: 4) {
                // Habit dots
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<entry.habitsTotal, id: \.self) { i in
                            Circle()
                                .fill(
                                    i < entry.habitStates.count && entry.habitStates[i]
                                        ? Color.widgetTeal
                                        : Color.white.opacity(0.2)
                                )
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("\(entry.habitsCompleted)/\(entry.habitsTotal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // Today's workout
                HStack(spacing: 4) {
                    Text(workoutIcon)
                        .font(.caption2)
                    Text(workoutLabel)
                        .font(.caption.bold())
                        .foregroundColor(entry.workoutCompleted ? .secondary : .white)
                        .lineLimit(1)
                    if entry.workoutCompleted {
                        Text("✓")
                            .font(.caption2.bold())
                            .foregroundColor(.widgetTeal)
                    }
                }
            }
        }
        .padding(14)
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

    private var workoutIcon: String {
        if entry.isRestDay { return "😌" }
        if entry.workoutType == "cardio" { return "🏃" }
        return "🏋️"
    }

    private var workoutLabel: String {
        if entry.isRestDay { return "Rest Day" }
        return entry.workoutName
    }

    private var widgetURL: URL {
        if entry.checkInAvailable && !entry.checkInCompleted {
            return URL(string: "atlas://checkin")!
        }
        return URL(string: "atlas://today")!
    }
}
