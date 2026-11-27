// LONGEVITY TIER CARD - Reusable Component
// Used in: TodayView, Weekly Check-ins, Monthly Reevaluation, Tier Reveals

import SwiftUI

// MARK: - Longevity Tier Card
struct LongevityTierCard: View {
    let tier: LongevityTier
    var showAnimation: Bool = false
    
    @State private var animateSegments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Longevity Tier")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Text(tier.percentileText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Segmented progress bar
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < tier.segmentsFilled ? tier.color : tier.color.opacity(0.2))
                        .frame(height: 8)
                        .shadow(
                            color: index < tier.segmentsFilled ? tier.color.opacity(0.5) : .clear,
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                        .scaleEffect(animateSegments && index < tier.segmentsFilled ? 1.0 : 0.0, anchor: .leading)
                        .animation(
                            showAnimation ? .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05) : nil,
                            value: animateSegments
                        )
                }
            }
            
            // Tier name
            Text(tier.name.uppercased())
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(tier.color)
                .tracking(1)
            
            // Description
            Text(tier.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    tier.color.opacity(0.08),
                    tier.color.opacity(0.03),
                    Color.white.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tier.color.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            if showAnimation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateSegments = true
                }
            } else {
                animateSegments = true
            }
        }
    }
}

// MARK: - Longevity Tier Model
enum LongevityTier: String, CaseIterable, Codable {
    case elite
    case optimal
    case phoenix
    case rising
    case atRisk
    
    var name: String {
        switch self {
        case .elite: return "Elite"
        case .optimal: return "Optimal"
        case .phoenix: return "Phoenix"
        case .rising: return "Rising"
        case .atRisk: return "At Risk"
        }
    }
    
    var description: String {
        switch self {
        case .elite: return "Exceptional longevity metrics."
        case .optimal: return "Longevity-optimized and consistent."
        case .phoenix: return "Transformed. Strong upward trajectory."
        case .rising: return "Above average. Building momentum."
        case .atRisk: return "Your starting point. Focus on fundamentals."
        }
    }
    
    var percentileText: String {
        switch self {
        case .elite: return "Top 5%"
        case .optimal: return "Top 15%"
        case .phoenix: return "Top 30%"
        case .rising: return "50-70th percentile"
        case .atRisk: return "Bottom 50%"
        }
    }
    
    var color: Color {
        switch self {
        case .elite: return Color(red: 0.36, green: 0.64, blue: 0.64) // Teal
        case .optimal: return Color(red: 0.4, green: 0.7, blue: 0.5) // Green-teal
        case .phoenix: return Color(red: 1.0, green: 0.76, blue: 0.42) // Amber
        case .rising: return Color(red: 0.36, green: 0.64, blue: 0.64) // Teal (longevity brand color)
        case .atRisk: return Color(red: 1.0, green: 0.45, blue: 0.35) // Red-coral
        }
    }
    
    var segmentsFilled: Int {
        switch self {
        case .elite: return 8
        case .optimal: return 6
        case .phoenix: return 4
        case .rising: return 3
        case .atRisk: return 2
        }
    }
}

// MARK: - Tier Reveal View (for celebrations)
struct TierRevealView: View {
    let oldTier: LongevityTier?
    let newTier: LongevityTier
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Title
                VStack(spacing: 8) {
                    if let old = oldTier, old.rawValue != newTier.rawValue {
                        Text("TIER UP! 🔥")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("YOUR TIER")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let old = oldTier, old.rawValue != newTier.rawValue {
                        Text("You've progressed from \(old.name) to \(newTier.name)")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 20)
                
                // New Tier Card
                LongevityTierCard(tier: newTier, showAnimation: true)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Continue button
                Button(action: { dismiss() }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(newTier.color)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Usage Examples in Different Contexts

// 1. TODAY VIEW - Simple display
struct TodayViewTierExample: View {
    var body: some View {
        LongevityTierCard(tier: .rising)
            .padding(.horizontal, 20)
    }
}

// 2. WEEKLY CHECK-IN - Show tier with context
struct WeeklyCheckInTierExample: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Current Standing")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            LongevityTierCard(tier: .rising)
                .padding(.horizontal, 20)
            
            Text("Keep up your consistency to progress to Phoenix tier.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// 3. MONTHLY REEVALUATION - Show tier change
struct MonthlyReevaluationTierExample: View {
    let previousTier: LongevityTier = .atRisk
    let currentTier: LongevityTier = .rising
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Month 1 Progress")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // Before
            VStack(alignment: .leading, spacing: 8) {
                Text("BEFORE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                
                LongevityTierCard(tier: previousTier)
            }
            .padding(.horizontal, 20)
            
            Image(systemName: "arrow.down")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.3))
            
            // After
            VStack(alignment: .leading, spacing: 8) {
                Text("NOW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                
                LongevityTierCard(tier: currentTier, showAnimation: true)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Preview
#Preview("Tier Card") {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 30) {
                ForEach(LongevityTier.allCases, id: \.self) { tier in
                    LongevityTierCard(tier: tier)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 40)
        }
    }
}

#Preview("Tier Reveal") {
    TierRevealView(oldTier: .atRisk, newTier: .rising)
}