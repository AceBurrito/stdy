import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    // Staggered entrance animations
    @State private var logoVisible = false
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var buttonVisible = false
    @State private var glowPulsing = false

    var body: some View {
        ZStack {
            // Background — deep dark with subtle radial glow
            Color.atlasBackground
                .ignoresSafeArea()

            // Subtle ambient glow behind logo area
            RadialGradient(
                colors: [
                    Color.atlasPrimary.opacity(glowPulsing ? 0.06 : 0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 300
            )
            .offset(y: -80)
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                value: glowPulsing
            )

            VStack(spacing: 0) {
                Spacer()
                Spacer()

                // MARK: - Logo
                Image("Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.92)

                // MARK: - Title
                Text("Atlas")
                    .font(.system(size: 46, weight: .light))
                    .foregroundColor(.atlasText)
                    .tracking(2)
                    .padding(.top, 12)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 8)

                // MARK: - Tagline
                Text("Strong enough to carry it all.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(0.3)
                    .padding(.top, 10)
                    .opacity(taglineVisible ? 1 : 0)
                    .offset(y: taglineVisible ? 0 : 6)

                Spacer()
                Spacer()
                Spacer()

                // MARK: - CTA Button
                Button(action: {
                    createUserProfile()
                    onComplete()
                }) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.atlasPrimary)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 28)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 12)

                // Subtle footer
                Text("One-time purchase · No subscription")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.35))
                    .tracking(0.3)
                    .padding(.top, 14)
                    .opacity(buttonVisible ? 1 : 0)

                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            // Staggered reveal — logo first, then title, tagline, button
            withAnimation(.easeOut(duration: 0.7)) {
                logoVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                titleVisible = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
                taglineVisible = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                buttonVisible = true
            }

            // Start ambient glow after entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                glowPulsing = true
            }
        }
    }

    // MARK: - Create Profile

    private func createUserProfile() {
        let dataController = DataController(modelContext: modelContext)
        let profile = dataController.getOrCreateUserProfile()

        profile.currentDay = 1
        profile.currentWeek = 0
        profile.onboardingComplete = false

        try? modelContext.save()
        print("✅ User profile created")
    }
}

#Preview {
    WelcomeView(onComplete: {})
}