// WidgetTopLine.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Shared top-line component for the Atlas home screen widget.
// Priority: 1) Check-in available  2) Pace changed  3) Nothing (streak only)

import SwiftUI

struct WidgetTopLine: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        HStack {
            // Priority 1: Check-in available
            if entry.checkInAvailable && !entry.checkInCompleted {
                HStack(spacing: 4) {
                    Text("📋")
                        .font(.caption2)
                    Text("Check-in ready")
                        .font(.caption.bold())
                        .foregroundColor(.widgetCoral)
                }
            }
            // Priority 2: Pace changed
            else if entry.paceChanged {
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
            }
            // Priority 3: Nothing — empty (streak still shows on the right)

            Spacer()

            // Streak (always visible when > 0)
            if entry.streakCount > 0 {
                Text("🔥 \(entry.streakCount)d")
                    .font(.caption2.bold())
                    .foregroundColor(.widgetCoral)
            }
        }
    }
}
