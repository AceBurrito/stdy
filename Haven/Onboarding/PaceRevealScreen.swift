import SwiftUI

struct PaceRevealScreen: View {
    let result: PaceResult
    let userName: String
    let onComplete: () -> Void
    
    @State private var displayedPace: Double = 1.00
    @State private var showTranslation = false
    @State private var showConfidence = false
    @State private var showCTA = false
    @State private var animationStarted = false
    
    private var paceColor: Color {
        Self.colorForPace(result.paceValue)
    }
    
    private var translationText: String {
        Self.translationForPace(result.paceValue)
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // The Number
                VStack(spacing: 16) {
                    Text("YOUR PACE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.atlasTextMuted)
                        .tracking(2)
                    
                    Text(String(format: "%.2f", displayedPace))
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(paceColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                
                // Translation
                if showTranslation {
                    Text(translationText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(paceColor == .white ? Color.atlasText.opacity(0.6) : paceColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // Confidence Note
                if showConfidence && result.confidenceLevel != "full" {
                    confidenceNote
                        .padding(.top, 24)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // CTA Buttons
                if showCTA {
                    VStack(spacing: 16) {
                        Button(action: onComplete) {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(Color.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onComplete) {
                            Text("Want help improving your Pace? →")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.atlasPrimary.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            guard !animationStarted else { return }
            animationStarted = true
            runAnimationSequence()
        }
    }
    
    // MARK: - Confidence Note
    
    private var confidenceNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundColor(Color.atlasTextMuted)
            
            Text(confidenceText)
                .font(.system(size: 13))
                .foregroundColor(Color.atlasTextMuted)
                .lineSpacing(2)
        }
        .padding(.horizontal, 40)
    }
    
    private var confidenceText: String {
        switch result.confidenceLevel {
        case "limited":
            return "Based on available data. Connect Apple Watch for a more complete score."
        case "partial":
            return "Limited data available. Your score will improve in accuracy as we collect more health data."
        default:
            return "Based on available data."
        }
    }
    
    // MARK: - Animation Sequence
    
    private func runAnimationSequence() {
        let startDelay: Double = 0.5
        let countUpDuration: Double = 1.5
        let steps = 30
        let stepDuration = countUpDuration / Double(steps)
        let targetPace = result.paceValue
        
        // Count-up animation
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + stepDuration * Double(i)) {
                let progress = easeOut(Double(i) / Double(steps))
                let interpolated = 1.00 + (targetPace - 1.00) * progress
                withAnimation(.none) {
                    displayedPace = interpolated
                }
            }
        }
        
        // Translation fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + countUpDuration + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showTranslation = true
            }
        }
        
        // Confidence note
        let confidenceDelay = startDelay + countUpDuration + 0.9
        DispatchQueue.main.asyncAfter(deadline: .now() + confidenceDelay) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfidence = true
            }
        }
        
        // CTA
        DispatchQueue.main.asyncAfter(deadline: .now() + confidenceDelay + 0.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCTA = true
            }
        }
    }
    
    private func easeOut(_ t: Double) -> Double {
        1.0 - pow(1.0 - t, 3)
    }
    
    // MARK: - Static Helpers (reused by PaceCard)
    
    static func colorForPace(_ pace: Double) -> Color {
        if pace <= 0.95 {
            return Color.atlasPrimary
        } else if pace <= 1.03 {
            return .white
        } else if pace <= 1.10 {
            return Color.atlasAmber
        } else {
            return Color.atlasAccent
        }
    }
    
    static func translationForPace(_ pace: Double) -> String {
        if pace <= 0.95 {
            return "You're aging slower than your calendar age"
        } else if pace <= 1.03 {
            return "You're aging close to your calendar rate"
        } else if pace <= 1.10 {
            return "You're aging slightly faster than your calendar age"
        } else {
            let weeks = (pace - 1.0) * 52
            return "You're aging \(String(format: "%.0f", weeks)) weeks faster per year"
        }
    }
}

// MARK: - Pace Factor Model (kept for potential future use)

struct PaceFactor: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let status: Status
    let label: String
    let percentile: Double
    
    enum Status {
        case good
        case moderate
        case needsAttention
        
        var color: Color {
            switch self {
            case .good: return Color.atlasPrimary
            case .moderate: return Color.atlasAmber
            case .needsAttention: return Color.atlasAccent
            }
        }
    }
}
