import SwiftUI

struct CoachingSectionCard: View {
    let section: CoachingSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: section.icon)
                    .foregroundColor(accentColor)
                Text(section.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            Text(section.body)
                .font(.subheadline)
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.atlasCardDark)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    section.type == .weeklyFocus ? Color.atlasAmber : Color.clear,
                    lineWidth: section.type == .weeklyFocus ? 1.5 : 0
                )
        )
    }

    private var accentColor: Color {
        switch section.accentColor {
        case "teal": return .atlasPrimary
        case "amber": return .atlasAmber
        case "coral": return .atlasAccent
        default: return .atlasPrimary
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CoachingSectionCard(section: CoachingSection(
            type: .paceTrend,
            title: "Pace Trend",
            body: "Your Pace dropped from 0.92 to 0.89 this week — that's meaningful progress. Your sleep is driving the improvement.",
            icon: "gauge.with.needle",
            accentColor: "teal"
        ))

        CoachingSectionCard(section: CoachingSection(
            type: .concern,
            title: "Needs Attention",
            body: "Sleep averaged 6.2h — below the 7h minimum. This is limiting everything else.",
            icon: "exclamationmark.triangle.fill",
            accentColor: "coral"
        ))

        CoachingSectionCard(section: CoachingSection(
            type: .weeklyFocus,
            title: "This Week's Focus",
            body: "Get your sleep above 7 hours. Everything else improves when sleep does.",
            icon: "target",
            accentColor: "amber"
        ))
    }
    .padding()
    .background(Color.atlasBackground)
}