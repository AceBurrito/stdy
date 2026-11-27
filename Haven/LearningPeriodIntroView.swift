import SwiftUI
import SwiftData

struct LearningPeriodIntroView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showTodayView = false
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo or Icon
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.atlasPrimary)
                
                // Title
                VStack(spacing: 16) {
                    Text("Your 7-Day Journey")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.atlasText)
                        .multilineTextAlignment(.center)
                    
                    Text("Before we build your personalized plan, we'll spend the next week teaching you the foundations of longevity.")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                }
                
                // What to Expect
                VStack(spacing: 20) {
                    LearningFeature(
                        icon: "brain.head.profile",
                        title: "Daily Lessons",
                        description: "Learn about the 5 pillars of longevity (2-3 min each)"
                    )
                    
                    LearningFeature(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Track Your Baseline",
                        description: "We'll gather data to understand your starting point"
                    )
                    
                    LearningFeature(
                        icon: "calendar",
                        title: "Daily Check-ins",
                        description: "Quick questions about sleep, energy, and stress"
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Start Button
                VStack(spacing: 12) {
                    Button(action: {
                        markOnboardingComplete()
                        showTodayView = true
                    }) {
                        Text("Enter atlas")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.atlasBackground)
                            .tracking(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(2)
                    }

                    Text("We'll guide you day by day")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showTodayView) {
            TodayView()
        }
    }
    
    private func markOnboardingComplete() {
        let dataController = DataController(modelContext: modelContext)
        let profile = dataController.getOrCreateUserProfile()
        profile.onboardingComplete = true
        
        do {
            try modelContext.save()
            print("✅ Onboarding marked complete")
        } catch {
            print("❌ Failed to save onboarding status: \(error)")
        }
    }
}

struct LearningFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.atlasAccent)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

#Preview {
    LearningPeriodIntroView()
}
