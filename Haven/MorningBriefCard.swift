import SwiftUI
import SwiftData

// MARK: - Morning Brief Card

/// Hero card for TodayView displaying the daily personalized brief.
/// Supports swipeable history of the last 7 briefs with custom dot indicators.
struct MorningBriefCard: View {
    let briefHistory: [MorningBriefEntry]

    @State private var selectedPage: Int = 0

    /// The briefs to display, most recent first (max 7).
    private var briefs: [MorningBriefEntry] {
        Array(briefHistory.prefix(7))
    }

    var body: some View {
        if briefs.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                TabView(selection: $selectedPage) {
                    ForEach(Array(briefs.enumerated()), id: \.element.id) { index, entry in
                        BriefCardContent(entry: entry)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 160)
                .fixedSize(horizontal: false, vertical: true)

                // Custom dot indicators
                if briefs.count > 1 {
                    BriefDotIndicator(
                        count: briefs.count,
                        current: selectedPage
                    )
                }
            }
        }
    }
}

// MARK: - Brief Card Content (Single Brief)

private struct BriefCardContent: View {
    let entry: MorningBriefEntry

    private var accentColorValue: Color {
        switch entry.accentColor {
        case "amber": return .atlasAmber
        case "coral": return .atlasAccent
        default: return .atlasPrimary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day number + icon row
            HStack(spacing: 6) {
                Image(systemName: entry.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColorValue)

                Text("DAY \(entry.dayNumber)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColorValue.opacity(0.8))
                    .tracking(1.5)

                Spacer()
            }

            // Headline
            Text(entry.headline)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)

            // Body
            Text(entry.body)
                .font(.system(size: 15))
                .foregroundColor(.atlasText.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Today preview (optional)
            if let preview = entry.todayPreview, !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(accentColorValue)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    accentColorValue.opacity(0.08),
                    accentColorValue.opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColorValue.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Brief Dot Indicator

private struct BriefDotIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                    .frame(width: index == current ? 7 : 5, height: index == current ? 7 : 5)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let entry = MorningBriefEntry(
        dayNumber: 14,
        headline: "Two weeks. The hard part is over.",
        body: "You've built a foundation that most people never build. The data is starting to accumulate. Patterns are forming. Keep stacking days.",
        todayPreview: "Today: Upper Push + 3 habits.",
        accentColor: "teal",
        icon: "star.fill",
        varietyKey: "milestone"
    )

    return ZStack {
        Color.atlasBackground.ignoresSafeArea()
        MorningBriefCard(briefHistory: [entry])
            .padding(.horizontal, 20)
    }
}