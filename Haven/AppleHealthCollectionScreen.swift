import SwiftUI

struct AppleHealthConnectionScreen: View {
    let healthKitManager: HealthKitManager
    let onConnect: () -> Void
    let onSkip: () -> Void
    
    @State private var isConnecting = false
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    Spacer().frame(height: 40)
                    
                    // Hero Section
                    VStack(spacing: 20) {
                        // Apple Health Logo
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 12) {
                            Text("Connect Apple Health")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(.atlasText)
                                .multilineTextAlignment(.center)
                            
                            Text("For the best experience")
                                .font(.system(size: 16))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    
                    // Benefits - UPDATED COPY (Part 3)
                    VStack(spacing: 16) {
                        Text("WHY THIS MATTERS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.5)
                        
                        // ✅ FIX: All 3 cards use identical frame/padding via BenefitCard
                        VStack(spacing: 12) {
                            BenefitCard(
                                icon: "checkmark.circle.fill",
                                title: "Zero Manual Logging",
                                description: "Your sleep, heart rate, and workouts sync automatically. Just live your life—we'll track what matters."
                            )
                            
                            BenefitCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Honest Baselines from Real Data",
                                description: "Your Longevity Tier is calculated from actual biomarkers—VO2 Max, HRV, sleep quality—not guesses or estimates."
                            )
                            
                            // ✅ UPDATED: "Adaptive Intelligence" → "Adaptive Coaching", no AI references
                            BenefitCard(
                                icon: "chart.xyaxis.line",
                                title: "Adaptive Coaching",
                                description: "Every week, Atlas analyzes your trends and tells you exactly what to focus on. As you improve, your plan evolves with you."
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // What We Track
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WHAT WE TRACK")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.5)
                        
                        VStack(spacing: 8) {
                            DataPointRow(icon: "moon.fill", label: "Sleep duration & quality")
                            DataPointRow(icon: "heart.fill", label: "Heart rate & VO2 Max")
                            DataPointRow(icon: "waveform.path.ecg", label: "Heart rate variability (HRV)")
                            DataPointRow(icon: "figure.run", label: "Workouts & activity")
                            DataPointRow(icon: "scalemass.fill", label: "Body metrics")
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Privacy Note
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.atlasPrimary)
                            Text("Your data stays private and is never shared")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.atlasText)
                        }
                        
                        Text("We only read the data needed for your longevity plan. Nothing is shared or sold.")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 40)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: handleConnect) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .tint(.atlasBackground)
                                } else {
                                    Text("Connect Apple Health")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(12)
                        }
                        .disabled(isConnecting)
                        
                        Button(action: onSkip) {
                            Text("I'll enter data manually")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func handleConnect() {
        isConnecting = true
        
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                
                await MainActor.run {
                    isConnecting = false
                    onConnect()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    print("❌ Failed to connect Apple Health: \(error)")
                    // Still proceed - user can connect later
                    onConnect()
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.atlasPrimary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)  // ✅ FIX: Ensures all cards stretch to same width
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct DataPointRow: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.atlasPrimary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
            
            Spacer()
        }
    }
}

#Preview {
    AppleHealthConnectionScreen(
        healthKitManager: HealthKitManager(),
        onConnect: {},
        onSkip: {}
    )
}