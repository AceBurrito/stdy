// AtlasWidgetSmallView.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Small (2×2): recovery state + today's training.

import SwiftUI
import WidgetKit

struct AtlasWidgetSmallView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetRecoveryHeader(recovery: WidgetRecovery(raw: entry.recoveryState))
            Spacer(minLength: 8)
            WidgetTrainingLine(entry: entry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "atlas://today"))
        .containerBackground(for: .widget) {
            Color.widgetBackground
        }
    }
}
