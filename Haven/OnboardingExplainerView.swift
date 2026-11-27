import SwiftUI

// MARK: - Onboarding Explainer Sequence
// 5 swipeable cards explaining Atlas's core value prop.
// Inserted after Welcome/Name (step 0), before Goal Selection (step 1).
//
// Page 0: Pace concept (UNCHANGED)
// Page 1: Biomarkers → Mock Pace Breakdown (UPDATED)
// Page 2: Habits (UNCHANGED)
// Page 3: Training (UNCHANGED)
// Page 4: Weekly Coaching cards (UPDATED — replaces AI coach)

struct OnboardingExplainerView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    private let totalPages = 5

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (hidden on last page)
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            onComplete()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.atlasTextMuted)
                    }
                }
                .frame(height: 20)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Paged content
                TabView(selection: $currentPage) {
                    PaceExplainerPage()
                        .tag(0)
                    BiomarkersExplainerPage()
                        .tag(1)
                    HabitsExplainerPage()
                        .tag(2)
                    TrainingExplainerPage()
                        .tag(3)
                    CoachingExplainerPage()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Footer: dots + button
                HStack {
                    // Page dots
                    HStack(spacing: 7) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.25))
                                .frame(width: index == currentPage ? 22 : 7, height: 7)
                                .animation(.easeInOut(duration: 0.25), value: currentPage)
                        }
                    }

                    Spacer()

                    // Next / Let's Go
                    if currentPage < totalPages - 1 {
                        Button(action: {
                            withAnimation { currentPage += 1 }
                        }) {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.atlasBackground)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Color.atlasPrimary)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: onComplete) {
                            Text("Let's Go")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.atlasPrimary, Color(hex: "#4a9e8e")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

// ============================================================
// MARK: - Page 1: Your body is aging. But how fast? (UNCHANGED)
// ============================================================

private struct PaceExplainerPage: View {
    var body: some View {
        ExplainerPageLayout(
            visual: { AnyView(PaceCardMockup()) },
            headline: "Your body is aging.\nBut how fast?",
            bodyText: "Atlas calculates your **Pace** — the rate your body is actually aging. Below 1.0 means you're aging slower than average. Above, faster. The sparkline shows your trajectory."
        )
    }
}

// ============================================================
// MARK: - Page 2: We measure what matters. (UPDATED)
// Replaced emoji grid with mock Pace breakdown card
// ============================================================

private struct BiomarkersExplainerPage: View {
    var body: some View {
        ExplainerPageLayout(
            visual: { AnyView(MockPaceBreakdown()) },
            headline: "We measure what matters.",
            bodyText: "Your Pace score tracks **six biomarkers** — the strongest predictors of how long and how well you'll live. All pulled from your Apple Watch."
        )
    }
}

// ============================================================
// MARK: - Page 3: Then we build your plan. (UNCHANGED)
// ============================================================

private struct HabitsExplainerPage: View {
    var body: some View {
        ExplainerPageLayout(
            visual: { AnyView(HabitStackMockup()) },
            headline: "Then we build your plan.",
            bodyText: "We assign **2–3 daily habits** backed by research — not 20 things at once. Your passions count too. Cognitive challenge is longevity medicine."
        )
    }
}

// ============================================================
// MARK: - Page 4: Train with purpose. (UNCHANGED)
// ============================================================

private struct TrainingExplainerPage: View {
    var body: some View {
        ExplainerPageLayout(
            visual: { AnyView(TrainingLoggerMockup()) },
            headline: "Train with purpose.",
            bodyText: "A program built for your schedule and goals. **Log every set** with our built-in tracker — swap exercises on the fly, track progressive overload, and watch your strength climb."
        )
    }
}

// ============================================================
// MARK: - Page 5: Coaching that knows your data. (UPDATED)
// Replaced AI chat mockup with weekly coaching cards
// ============================================================

private struct CoachingExplainerPage: View {
    var body: some View {
        ExplainerPageLayout(
            visual: { AnyView(MockCoachingCards()) },
            headline: "Coaching that knows your data.",
            bodyText: "Every week, Atlas analyzes your trends and tells you exactly what to focus on. **No fluff** — just what the data says."
        )
    }
}

// ============================================================
// MARK: - Shared Page Layout
// ============================================================

private struct ExplainerPageLayout: View {
    let visual: () -> AnyView
    let headline: String
    let bodyText: String
    var headlineSuffix: AnyView? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Visual area
            visual()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)

            // Text content
            VStack(alignment: .leading, spacing: 10) {
                // Headline
                if let suffix = headlineSuffix {
                    HStack(alignment: .center, spacing: 6) {
                        Text(headline)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.atlasText)
                            .lineSpacing(2)
                        suffix
                    }
                } else {
                    Text(headline)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.atlasText)
                        .lineSpacing(2)
                }

                // Body with markdown-style bold
                Text(attributedBody)
                    .font(.system(size: 14))
                    .foregroundColor(Color.atlasTextMuted)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
    }

    // Parse **bold** markers into AttributedString
    private var attributedBody: AttributedString {
        var result = AttributedString()
        let parts = bodyText.components(separatedBy: "**")
        for (index, part) in parts.enumerated() {
            var attr = AttributedString(part)
            if index % 2 == 1 {
                attr.font = .system(size: 14, weight: .semibold)
                attr.foregroundColor = Color.atlasPrimary
            }
            result += attr
        }
        return result
    }
}

// ============================================================
// MARK: - NEW VISUAL: Mock Pace Breakdown (Page 2)
// Static card mimicking the real PaceDetailView component rows
// ============================================================

private struct MockPaceBreakdown: View {
    // Hardcoded sample data for the demo
    private let sampleComponents: [(name: String, icon: String, percentile: Double, subtitle: String)] = [
        ("Sleep",        "bed.double.fill",        72, "7.2h avg"),
        ("HRV",          "heart.text.square.fill",  65, "42ms avg"),
        ("Resting HR",   "heart.fill",              81, "58 bpm"),
        ("VO₂ Max",      "lungs.fill",              48, "38.2 ml/kg/min"),
        ("Movement",     "figure.walk",             70, "8,241 steps"),
        ("Strength",     "dumbbell.fill",           59, "Bench: 185 lbs"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("YOUR PACE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)

                Spacer()

                Text("0.95")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#4a9e8e"))
            }
            .padding(.bottom, 14)

            // Component rows
            VStack(spacing: 8) {
                ForEach(sampleComponents, id: \.name) { component in
                    MockComponentRow(
                        name: component.name,
                        icon: component.icon,
                        percentile: component.percentile,
                        subtitle: component.subtitle
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.atlasCardDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }
}

private struct MockComponentRow: View {
    let name: String
    let icon: String
    let percentile: Double
    let subtitle: String

    private var color: Color {
        if percentile >= 65 { return Color.atlasPrimary }
        if percentile >= 35 { return Color.atlasAmber }
        return Color.atlasAccent
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.atlasText)

                Spacer()

                Text("\(Int(percentile))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(color)
                        .frame(width: max(geo.size.width * (percentile / 100), 4), height: 5)
                }
            }
            .frame(height: 5)

            // Subtitle
            HStack {
                Spacer()
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
    }
}

// ============================================================
// MARK: - NEW VISUAL: Mock Coaching Cards (Page 5)
// 3 static cards reusing CoachingSectionCard visual style
// ============================================================

private struct MockCoachingCards: View {
    var body: some View {
        VStack(spacing: 10) {
            // Card 1: Pace Trend
            MockCoachingCard(
                icon: "gauge.with.needle",
                title: "Pace Trend",
                message: "Your Pace dropped from 1.02 to 0.95 — that's meaningful progress. Your sleep is driving the improvement.",
                accentColor: .atlasPrimary,
                hasBorder: false
            )

            // Card 2: This Week's Win
            MockCoachingCard(
                icon: "trophy.fill",
                title: "This Week's Win",
                message: "Your bench press estimated max jumped 8%.",
                accentColor: .atlasPrimary,
                hasBorder: false
            )

            // Card 3: This Week's Focus (amber border)
            MockCoachingCard(
                icon: "target",
                title: "This Week's Focus",
                message: "Add one Zone 2 session. 20–30 minutes, keep your heart rate in the 124–145 range.",
                accentColor: .atlasAmber,
                hasBorder: true
            )
        }
        .padding(.horizontal, 8)
    }
}

private struct MockCoachingCard: View {
    let icon: String
    let title: String
    let message: String
    let accentColor: Color
    let hasBorder: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.atlasCardDark)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    hasBorder ? Color.atlasAmber : Color.clear,
                    lineWidth: hasBorder ? 1.5 : 0
                )
        )
    }
}

// ============================================================
// MARK: - UNCHANGED VISUALS (Pages 1, 3)
// All code below is carried forward without modification
// (Page 4 training mock was updated separately above)
// ============================================================

// MARK: - Visual: Static Pace Card Mockup (Page 1)

private struct PaceCardMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("YOUR PACE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.atlasTextMuted)
                    .tracking(1.5)
                Spacer()
                Text("0.94")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.atlasTextMuted.opacity(0.6))
            }
            .padding(.bottom, 6)

            // Hero
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("6%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("slower")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 2)

            Text("Aging slower than expected")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#4a9e8e"))
                .padding(.bottom, 10)

            // Sparkline label
            Text("LAST 30 DAYS")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color(hex: "#3e3e48"))
                .tracking(1.5)
                .padding(.bottom, 4)

            // Static sparkline
            ExplainerSparkline()
                .frame(height: 44)
                .padding(.bottom, 6)

            // Footer
            HStack {
                Text("▼ Improving")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#4a9e8e"))
                Spacer()
                Text("↓ 3% this month")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.atlasTextMuted.opacity(0.5))
            }
            .padding(.top, 6)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#14211e"), Color(hex: "#111116")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "#4a9e8e").opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
        .padding(.horizontal, 8)
    }
}

// MARK: - Static Sparkline for Explainer

private struct ExplainerSparkline: View {
    private let sampleData: [Double] = [
        1.01, 1.00, 1.01, 0.99, 1.00, 0.99, 0.98, 0.99,
        0.98, 0.97, 0.98, 0.97, 0.96, 0.97, 0.96, 0.96,
        0.95, 0.96, 0.95, 0.95, 0.94, 0.95, 0.94, 0.94
    ]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            let minVal: Double = 0.90
            let maxVal: Double = 1.06
            let range = maxVal - minVal

            let points: [CGPoint] = sampleData.enumerated().map { index, value in
                let x = width * CGFloat(index) / CGFloat(max(sampleData.count - 1, 1))
                let normalized = CGFloat((value - minVal) / range)
                let y = height * (1.0 - normalized)
                return CGPoint(x: x, y: y)
            }

            let baselineNormalized = CGFloat((1.0 - minVal) / range)
            let baselineY = height * (1.0 - baselineNormalized)

            ZStack {
                // Dashed baseline
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: width, y: baselineY))
                }
                .stroke(Color(hex: "#2a2a34"), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // 1.0 label
                Text("1.0")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#3e3e48"))
                    .position(x: width - 10, y: baselineY - 8)

                if points.count > 1 {
                    // Gradient fill
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: baselineY))
                        path.addLine(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: baselineY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4a9e8e").opacity(0.18), Color(hex: "#4a9e8e").opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    // Sparkline stroke
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color(hex: "#4a9e8e"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // End dot
                    if let lastPoint = points.last {
                        Circle()
                            .fill(Color(hex: "#4a9e8e").opacity(0.25))
                            .frame(width: 12, height: 12)
                            .position(lastPoint)
                        Circle()
                            .fill(Color(hex: "#4a9e8e"))
                            .frame(width: 6, height: 6)
                            .position(lastPoint)
                    }
                }
            }
        }
    }
}

// MARK: - Visual: Habit Stack Mockup (Page 3 — UNCHANGED)

private struct HabitStackMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR STARTING HABITS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color.atlasTextMuted.opacity(0.4))
                .tracking(1.5)
                .padding(.bottom, 2)

            HabitMockRow(icon: "☀️", name: "Morning Sunlight", detail: "10 min · Circadian reset",
                         iconColor: Color(hex: "#4a9e8e"), checked: true, style: .active)
            HabitMockRow(icon: "🥩", name: "Protein Target", detail: "Track daily intake",
                         iconColor: Color(hex: "#4a9e8e"), checked: true, style: .active)
            HabitMockRow(icon: "🎸", name: "Guitar Practice", detail: "30 min · Cognitive reserve",
                         iconColor: Color(hex: "#d4a054"), checked: true, style: .cognitive)

            Text("ADDED OVER TIME")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color.atlasTextMuted.opacity(0.3))
                .tracking(1.5)
                .padding(.top, 6)
                .padding(.bottom, 2)

            HabitMockRow(icon: "🧊", name: "Cold Exposure", detail: "When you're ready",
                         iconColor: .clear, checked: false, style: .future)
            HabitMockRow(icon: "🧘", name: "Breathwork", detail: "Layered in month 2+",
                         iconColor: .clear, checked: false, style: .future)

            HStack(spacing: 6) {
                Text("↓")
                    .font(.system(size: 12, weight: .bold))
                Text("Pace drops as habits stick")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#4a9e8e"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color(hex: "#4a9e8e").opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#4a9e8e").opacity(0.2), lineWidth: 1)
            )
            .padding(.top, 6)
        }
        .padding(.horizontal, 8)
    }
}

private enum HabitMockStyle {
    case active, cognitive, future
}

private struct HabitMockRow: View {
    let icon: String
    let name: String
    let detail: String
    let iconColor: Color
    let checked: Bool
    let style: HabitMockStyle

    private var borderColor: Color {
        switch style {
        case .active: return Color(hex: "#4a9e8e").opacity(0.25)
        case .cognitive: return Color(hex: "#d4a054").opacity(0.25)
        case .future: return Color.white.opacity(0.06)
        }
    }

    private var bgColor: Color {
        switch style {
        case .active: return Color(hex: "#4a9e8e").opacity(0.05)
        case .cognitive: return Color(hex: "#d4a054").opacity(0.05)
        case .future: return Color.white.opacity(0.02)
        }
    }

    private var checkColor: Color {
        switch style {
        case .active: return Color(hex: "#4a9e8e")
        case .cognitive: return Color(hex: "#d4a054")
        case .future: return Color.atlasTextMuted.opacity(0.2)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(style == .future ? Color.white.opacity(0.04) : iconColor.opacity(0.12))
                .cornerRadius(7)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(style == .future ? Color.atlasTextMuted.opacity(0.4) : .atlasText)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(Color.atlasTextMuted.opacity(style == .future ? 0.3 : 0.7))
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(checkColor, lineWidth: 1.5)
                    .frame(width: 18, height: 18)

                if checked {
                    Circle()
                        .fill(checkColor)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.atlasBackground)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(bgColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
        .opacity(style == .future ? 0.5 : 1.0)
    }
}

// MARK: - Visual: Mock Training Schedule (Page 4 — UPDATED)
// Mirrors the real TrainingDayCard layout from TrainingProgramView

private struct TrainingLoggerMockup: View {
    // Sample week: 4-day Upper/Lower + 2 cardio + 1 rest
    private let sampleDays: [(day: String, name: String, subtitle: String, type: String, zonePill: String?, isToday: Bool)] = [
        ("MON", "Upper Body",       "5 exercises",                     "strength", nil,      true),
        ("TUE", "30 min Cardio",    "Run, bike, row, or swim",         "cardio",   "ZONE 2", false),
        ("WED", "Lower Body",       "5 exercises",                     "strength", nil,      false),
        ("THU", "Rest Day",         "Recovery",                        "rest",     nil,      false),
        ("FRI", "Upper Body",       "5 exercises",                     "strength", nil,      false),
        ("SAT", "25 min Cardio",    "Intervals",                       "cardio",   "VO2 MAX",false),
        ("SUN", "Rest Day",         "Recovery",                        "rest",     nil,      false),
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(sampleDays, id: \.day) { item in
                MockTrainingDayRow(
                    dayLabel: item.day,
                    workoutName: item.name,
                    subtitle: item.subtitle,
                    workoutType: item.type,
                    zonePill: item.zonePill,
                    isToday: item.isToday
                )
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct MockTrainingDayRow: View {
    let dayLabel: String
    let workoutName: String
    let subtitle: String
    let workoutType: String
    let zonePill: String?
    let isToday: Bool

    private var isRest: Bool { workoutType == "rest" }

    private var iconName: String {
        switch workoutType {
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio":   return "figure.run"
        case "rest":     return "moon.fill"
        default:         return "circle.fill"
        }
    }

    private var iconColor: Color {
        switch workoutType {
        case "strength": return .atlasPrimary
        case "cardio":   return .atlasAccent
        case "rest":     return .atlasTextMuted.opacity(0.3)
        default:         return .atlasTextMuted
        }
    }

    private var zonePillColor: Color {
        guard let pill = zonePill else { return .clear }
        switch pill {
        case "ZONE 2":  return .atlasPrimary
        case "VO2 MAX": return .orange
        default:         return .atlasAccent
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Day badge
            Text(dayLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isToday ? .atlasBackground : (isRest ? .atlasTextMuted.opacity(0.5) : .atlasTextMuted))
                .frame(width: 36, height: 36)
                .background(isToday ? Color.atlasPrimary : (isRest ? Color.white.opacity(0.03) : Color.white.opacity(0.08)))
                .cornerRadius(8)

            // Workout info
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(workoutName)
                            .font(.system(size: 13, weight: isToday && !isRest ? .semibold : .medium))
                            .foregroundColor(isRest ? .atlasTextMuted : .atlasText)

                        if let pill = zonePill {
                            Text(pill)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.atlasBackground)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(zonePillColor)
                                .cornerRadius(3)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isRest ? .atlasTextMuted.opacity(0.5) : .atlasTextMuted)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)

                    if !isRest {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isRest ? Color.white.opacity(0.02) :
                (isToday ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.04))
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isToday && !isRest ? Color.atlasPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingExplainerView {
        print("Explainer complete")
    }
}