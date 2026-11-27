import SwiftUI

// MARK: - Streak Celebration View

/// Presents streak milestone celebrations at three visual tiers:
/// - Toast (3 days): small banner, auto-dismiss
/// - Card (7, 14 days): dismissable card with confetti
/// - Fullscreen (21, 30, 50, 100 days): full overlay with radial animation

struct StreakCelebrationView: View {
    let milestone: StreakMilestone
    let currentStreak: Int
    let onDismiss: () -> Void

    var body: some View {
        switch milestone.celebrationType {
        case "toast":
            StreakToastView(milestone: milestone, currentStreak: currentStreak, onDismiss: onDismiss)
        case "card":
            StreakCardCelebration(milestone: milestone, currentStreak: currentStreak, onDismiss: onDismiss)
        default:
            StreakFullscreenCelebration(milestone: milestone, currentStreak: currentStreak, onDismiss: onDismiss)
        }
    }
}

// MARK: - Toast (3 Days)

struct StreakToastView: View {
    let milestone: StreakMilestone
    let currentStreak: Int
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var hasTriggeredHaptic = false

    var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                Text("🔥")
                    .font(.system(size: 18))

                Text("\(currentStreak) days — it's becoming a habit.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.atlasPrimary.opacity(0.15),
                        Color.atlasPrimary.opacity(0.05)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // Auto-show and auto-dismiss after 3 seconds
    func appear() -> some View {
        self
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = true
                }
                if !hasTriggeredHaptic {
                    hasTriggeredHaptic = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onDismiss()
                    }
                }
            }
    }
}

// MARK: - Card Celebration (7, 14 Days)

struct StreakCardCelebration: View {
    let milestone: StreakMilestone
    let currentStreak: Int
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var confettiParticles: [ConfettiParticle] = []

    var body: some View {
        VStack(spacing: 16) {
            // Confetti overlay
            ZStack {
                ForEach(confettiParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: particle.x, y: showContent ? particle.endY : particle.startY)
                        .opacity(showContent ? 0 : 1)
                        .animation(
                            .easeOut(duration: particle.duration).delay(particle.delay),
                            value: showContent
                        )
                }
            }
            .frame(height: 0)
            .clipped()

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.atlasPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.atlasText)

                    Text("\(currentStreak)-day streak")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .padding(8)
                }
            }

            // Progress summary
            HStack(spacing: 20) {
                StreakStatPill(label: "Streak", value: "\(currentStreak)", color: .atlasPrimary)
                StreakStatPill(label: "Milestone", value: milestone.name, color: .atlasAmber)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.atlasPrimary.opacity(0.1),
                    Color.atlasPrimary.opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            generateConfetti()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    private func generateConfetti() {
        let colors: [Color] = [.atlasPrimary, .atlasAmber, .atlasAccent, .white.opacity(0.6)]
        confettiParticles = (0..<20).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...8),
                x: CGFloat.random(in: -150...150),
                startY: CGFloat.random(in: -20...0),
                endY: CGFloat.random(in: -120 ... -40),
                duration: Double.random(in: 0.8...1.5),
                delay: Double.random(in: 0...0.3)
            )
        }
    }
}

// MARK: - Fullscreen Celebration (21, 30, 50, 100 Days)

struct StreakFullscreenCelebration: View {
    let milestone: StreakMilestone
    let currentStreak: Int
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showBurst = false
    @State private var burstParticles: [BurstParticle] = []

    private var milestoneMessage: String {
        switch milestone.days {
        case 21:
            return "Research says 21 days builds a habit.\nYou just proved it."
        case 30:
            return "A full month of consistency.\nThis is who you are now."
        case 50:
            return "50 days. Most people never get here.\nYou're in rare territory."
        case 100:
            return "100 days. A century of commitment.\nThis is extraordinary."
        default:
            return "\(currentStreak) days of showing up.\nThe compound effect is real."
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.atlasBackground
                .ignoresSafeArea()

            // Semi-transparent accent gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.atlasPrimary.opacity(0.2),
                    Color.atlasBackground.opacity(0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: showContent)

            // Radial burst particles
            ForEach(burstParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: showBurst ? particle.endX : 0, y: showBurst ? particle.endY : 0)
                    .opacity(showBurst ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: particle.duration).delay(particle.delay),
                        value: showBurst
                    )
            }

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.atlasPrimary.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .scaleEffect(showContent ? 1.0 : 0.6)

                    Circle()
                        .fill(Color.atlasPrimary.opacity(0.25))
                        .frame(width: 100, height: 100)
                        .scaleEffect(showContent ? 1.0 : 0.6)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                        .scaleEffect(showContent ? 1.0 : 0.3)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.65), value: showContent)

                Spacer().frame(height: 32)

                // Streak count
                Text("\(currentStreak)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.atlasText)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)

                Text("DAYS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(3)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: showContent)

                Spacer().frame(height: 24)

                // Milestone name
                Text(milestone.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.atlasPrimary)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 15)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: showContent)

                Spacer().frame(height: 16)

                // Message
                Text(milestoneMessage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.atlasText.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 15)
                    .animation(.easeOut(duration: 0.5).delay(0.45), value: showContent)

                Spacer()

                // Continue button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.atlasPrimary)
                        .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
            }
        }
        .onAppear {
            generateBurstParticles()

            // Staggered haptic: success then heavy impact
            let notificationGen = UINotificationFeedbackGenerator()
            notificationGen.notificationOccurred(.success)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let impactGen = UIImpactFeedbackGenerator(style: .heavy)
                impactGen.impactOccurred()
            }

            withAnimation {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showBurst = true
            }
        }
    }

    private func generateBurstParticles() {
        let colors: [Color] = [.atlasPrimary, .atlasAmber, .atlasAccent, .white.opacity(0.5)]
        burstParticles = (0..<30).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...220)
            return BurstParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                endX: cos(angle) * distance,
                endY: sin(angle) * distance,
                duration: Double.random(in: 0.6...1.2),
                delay: Double.random(in: 0...0.15)
            )
        }
    }
}

// MARK: - Supporting Views

private struct StreakStatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.atlasTextMuted)
                .textCase(.uppercase)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Particle Models

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let duration: Double
    let delay: Double
}

struct BurstParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let duration: Double
    let delay: Double
}

// MARK: - Preview

#Preview {
    let milestone = StreakMilestone(days: 21, name: "Habit Formed", celebrationType: "fullscreen")
    return StreakFullscreenCelebration(
        milestone: milestone,
        currentStreak: 21,
        onDismiss: {}
    )
}