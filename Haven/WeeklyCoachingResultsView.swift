import SwiftUI

struct WeeklyCoachingResultsView: View {
    let analysis: WeeklyAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Your Week in Review")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                ForEach(analysis.sections) { section in
                    CoachingSectionCard(section: section)
                }
            }
            .padding()
        }
        .background(Color.atlasBackground)
    }
}

#Preview {
    let sampleAnalysis = WeeklyAnalysis(sections: [
        CoachingSection(
            type: .paceTrend,
            title: "Pace Trend",
            body: "Your Pace dropped from 0.92 to 0.89 this week — that's meaningful progress. Your sleep is driving the improvement.",
            icon: "gauge.with.needle",
            accentColor: "teal"
        ),
        CoachingSection(
            type: .biggestWin,
            title: "This Week's Win",
            body: "Sleep averaged 7.8h, up from 7.1h.",
            icon: "trophy.fill",
            accentColor: "teal"
        ),
        CoachingSection(
            type: .concern,
            title: "Needs Attention",
            body: "No cardio sessions this week. Even 20 minutes of Zone 2 moves the needle.",
            icon: "exclamationmark.triangle.fill",
            accentColor: "coral"
        ),
        CoachingSection(
            type: .strength,
            title: "Strength",
            body: "↑ Bench Press: 185 → 195 (+5%)\n→ Squat: Holding at 225. Add a rep next session.\n↓ Deadlift: Down from 315 to 295\n\n1 improved, 1 stable, 1 regressed.",
            icon: "dumbbell.fill",
            accentColor: "amber"
        ),
        CoachingSection(
            type: .weeklyFocus,
            title: "This Week's Focus",
            body: "Add one Zone 2 session this week. 20-30 minutes, keep your heart rate in the 124-145 range.",
            icon: "target",
            accentColor: "amber"
        )
    ])

    WeeklyCoachingResultsView(analysis: sampleAnalysis)
}