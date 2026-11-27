// AtlasWidgetMediumView.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Medium (4×2): recovery state + today's training | body comp snapshot.

import SwiftUI
import WidgetKit

struct AtlasWidgetMediumView: View {
    let entry: AtlasWidgetEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetRecoveryHeader(recovery: WidgetRecovery(raw: entry.recoveryState), titleSize: 24)
                Spacer(minLength: 8)
                WidgetTrainingLine(entry: entry)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 10) {
                stat(label: "WEIGHT", value: entry.weightText, footnote: entry.weightTrendText)
                stat(label: "BODY FAT", value: entry.bodyFatText, footnote: nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(URL(string: "atlas://today"))
        .containerBackground(for: .widget) {
            Color.widgetBackground
        }
    }

    private func stat(label: String, value: String, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.widgetMuted)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundColor(value.isEmpty ? .widgetMuted : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.widgetMuted)
                    .lineLimit(1)
            }
        }
    }
}
