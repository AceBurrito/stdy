// WidgetColors.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Color constants and shared bits for the home screen widget. The widget runs
// in a separate process and cannot access the main app's Color extensions or
// RecoveryState, so these mirror the app's values.

import SwiftUI

extension Color {
    static let widgetTeal = Color(red: 0.357, green: 0.643, blue: 0.643)   // #5BA4A4
    static let widgetCoral = Color(red: 0.878, green: 0.471, blue: 0.337)  // #E07856
    static let widgetAmber = Color(red: 1.0, green: 0.761, blue: 0.416)    // #FFC26A
    static let widgetGreen = Color(red: 0.486, green: 0.769, blue: 0.541)  // #7CC48A
    static let widgetBackground = Color(red: 0.059, green: 0.063, blue: 0.067) // #0F1011
    static let widgetMuted = Color(red: 0.557, green: 0.565, blue: 0.576)  // #8E9093
}

/// Mirrors the app's RecoveryState (raw values must match).
struct WidgetRecovery {
    let raw: String

    var title: String {
        switch raw {
        case "ready": return "Ready to Crush"
        case "good": return "Good to Go"
        case "manage": return "Manage It"
        case "recover": return "Recover"
        default: return "No data"
        }
    }

    var color: Color {
        switch raw {
        case "ready": return .widgetGreen
        case "good": return .widgetTeal
        case "manage": return .widgetAmber
        case "recover": return .widgetCoral
        default: return .widgetMuted
        }
    }
}

/// "RECOVERY" label + state title with a solid color edge.
struct WidgetRecoveryHeader: View {
    let recovery: WidgetRecovery
    var titleSize: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(recovery.color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("RECOVERY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.widgetMuted)
                Text(recovery.title.uppercased())
                    .font(.system(size: titleSize, weight: .bold).width(.condensed))
                    .foregroundColor(recovery.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Today's training line.
struct WidgetTrainingLine: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TODAY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.widgetMuted)
            HStack(spacing: 4) {
                Text(entry.isRestDay ? "Rest Day" : entry.workoutName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(entry.workoutCompleted ? .widgetMuted : .white)
                    .lineLimit(1)
                if entry.workoutCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.widgetTeal)
                }
            }
            if !entry.isRestDay && !entry.workoutCompleted && entry.workoutType == "strength" && entry.workoutExerciseCount > 0 {
                Text("\(entry.workoutExerciseCount) exercises")
                    .font(.system(size: 11))
                    .foregroundColor(.widgetMuted)
            }
        }
    }
}
