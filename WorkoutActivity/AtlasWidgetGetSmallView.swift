// AtlasWidgetSmallView.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Small (2×2): today's recovery call + today's workout.

import SwiftUI
import WidgetKit

struct AtlasWidgetSmallView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetRecoveryBlock(entry: entry, titleSize: 22, showsSignals: false)
            Spacer(minLength: 6)
            WidgetTrainingLine(entry: entry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "atlas://today"))
        .containerBackground(for: .widget) {
            Color.widgetBackground
        }
    }
}
