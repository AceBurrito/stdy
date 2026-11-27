import SwiftUI

// MARK: - Day Complete Card
// Animated celebration card shown when ALL habits are completed.
// Coral/amber accent, staggered appearance, streak-aware copy.

struct DayCompleteCard: View {
    let dayNumber: Int
    let currentStreak: Int

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.atlasAccent)
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.05), value: appeared)

            Text("ALL HABITS COMPLETE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.3).delay(0.15), value: appeared)

            if currentStreak > 0 {
                Text("🔥 \(currentStreak) day streak")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.atlasText)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.3).delay(0.25), value: appeared)
            }

            Text(streakMessage(currentStreak))
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.3).delay(0.35), value: appeared)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.atlasCardDark)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.atlasAccent.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            appeared = true
        }
    }

    // MARK: - Streak-aware copy

    private func streakMessage(_ streak: Int) -> String {
        switch streak {
        case 0:
            return "Day \(dayNumber) done. Come back tomorrow."
        case 1:
            return "Day 1 in the books. Come back tomorrow."
        case 2:
            return "Two days straight. Building momentum."
        case 3...6:
            return "Keep showing up. Day \(streak + 1) is waiting."
        case 7:
            return "One full week. No days off. This is how habits stick."
        case 8...13:
            return "\(streak) days locked in. This is becoming automatic."
        case 14:
            return "Two weeks. You're proving something to yourself."
        case 15...20:
            return "\(streak) days. Consistency is the real flex."
        case 21:
            return "Three weeks. They say this is when habits form."
        case 22...29:
            return "\(streak) days. Not stopping now."
        case 30:
            return "30 days. Not a streak — a lifestyle."
        case 31...59:
            return "\(streak) days. This is who you are now."
        case 60:
            return "60 days. Relentless."
        case 61...89:
            return "\(streak) days. Most people quit by now. You didn't."
        case 90:
            return "90 days. Unbreakable."
        default:
            return "\(streak) days. No one's stopping you."
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        VStack(spacing: 16) {
            DayCompleteCard(dayNumber: 14, currentStreak: 14)
            DayCompleteCard(dayNumber: 1, currentStreak: 0)
        }
        .padding(.horizontal, 20)
    }
}