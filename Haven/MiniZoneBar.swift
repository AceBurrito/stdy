import SwiftUI

// MARK: - Mini Zone Bar (thin colored bar showing zone distribution at a glance)

struct MiniZoneBar: View {
    let breakdown: ZoneBreakdown

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if breakdown.totalSeconds > 0 {
                    zoneSegment(width: geo.size.width * breakdown.zone1Percent, color: zoneColor(1))
                    zoneSegment(width: geo.size.width * breakdown.zone2Percent, color: zoneColor(2))
                    zoneSegment(width: geo.size.width * breakdown.zone3Percent, color: zoneColor(3))
                    zoneSegment(width: geo.size.width * breakdown.zone4Percent, color: zoneColor(4))
                    zoneSegment(width: geo.size.width * breakdown.zone5Percent, color: zoneColor(5))
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                }
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
    }

    @ViewBuilder
    private func zoneSegment(width: CGFloat, color: Color) -> some View {
        if width > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(width, 1)) // Minimum 1pt so tiny zones are visible
        }
    }

}

// MARK: - Zone Color (standalone, used by MiniZoneBar, FullZoneBreakdownView, and detail views)

func zoneColor(_ zone: Int) -> Color {
    switch zone {
    case 1: return Color(hex: "#4A9FD9")   // Cool blue
    case 2: return Color.atlasPrimary    // Teal (longevity zone)
    case 3: return Color(hex: "#F5C542")     // Amber/yellow
    case 4: return Color.atlasAccent     // Coral/orange
    case 5: return Color(hex: "#E04848")     // Red
    default: return Color.gray
    }
}

// MARK: - Full Zone Breakdown Bar (for detail/confirmation views)

struct FullZoneBreakdownView: View {
    let breakdown: ZoneBreakdown

    var body: some View {
        VStack(spacing: 8) {
            zoneRow(zone: 1, label: "Z1", seconds: breakdown.zone1Seconds, percent: breakdown.zone1Percent)
            zoneRow(zone: 2, label: "Z2", seconds: breakdown.zone2Seconds, percent: breakdown.zone2Percent)
            zoneRow(zone: 3, label: "Z3", seconds: breakdown.zone3Seconds, percent: breakdown.zone3Percent)
            zoneRow(zone: 4, label: "Z4", seconds: breakdown.zone4Seconds, percent: breakdown.zone4Percent)
            zoneRow(zone: 5, label: "Z5", seconds: breakdown.zone5Seconds, percent: breakdown.zone5Percent)
        }
    }

    private func zoneRow(zone: Int, label: String, seconds: Double, percent: Double) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(zoneColor(zone))
                .frame(width: 24, alignment: .leading)

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 16)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(zoneColor(zone))
                        .frame(width: max(geo.size.width * percent, percent > 0 ? 2 : 0), height: 16)
                        .cornerRadius(3)
                }
            }
            .frame(height: 16)

            // Time and percent
            HStack(spacing: 4) {
                Text(formatDuration(seconds))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.atlasText)
                    .frame(width: 44, alignment: .trailing)

                Text("(\(Int(percent * 100))%)")
                    .font(.system(size: 11))
                    .foregroundColor(.atlasTextMuted)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Mini bar
        MiniZoneBar(breakdown: ZoneBreakdown(
            zone1Seconds: 259, zone2Seconds: 1020, zone3Seconds: 1328,
            zone4Seconds: 366, zone5Seconds: 599, totalSeconds: 3572
        ))
        .padding(.horizontal, 24)

        // Full breakdown
        FullZoneBreakdownView(breakdown: ZoneBreakdown(
            zone1Seconds: 259, zone2Seconds: 1020, zone3Seconds: 1328,
            zone4Seconds: 366, zone5Seconds: 599, totalSeconds: 3572
        ))
        .padding(24)
    }
    .background(Color.atlasBackground)
}