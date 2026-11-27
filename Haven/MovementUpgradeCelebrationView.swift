import SwiftUI

struct MovementUpgradeCelebrationView: View {
    let weeksCompleted: Int
    let avgAdherence: Double
    let daysPerWeek: Int
    let onUpgrade: () -> Void
    let onDecline: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.atlasBackground,
                    Color.atlasPrimary.opacity(0.15),
                    Color.atlasBackground
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Top celebration section
                    VStack(spacing: 24) {
                        Spacer().frame(height: 40)
                        
                        // Animated icon
                        ZStack {
                            Circle()
                                .fill(Color.atlasPrimary.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .scaleEffect(showContent ? 1.0 : 0.8)
                            
                            Circle()
                                .fill(Color.atlasPrimary.opacity(0.3))
                                .frame(width: 110, height: 110)
                                .scaleEffect(showContent ? 1.0 : 0.8)
                            
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.atlasPrimary)
                                .scaleEffect(showContent ? 1.0 : 0.5)
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)
                        
                        VStack(spacing: 12) {
                            Text("You've Earned This")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.atlasText)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                            
                            Text("After \(weeksCompleted) weeks of crushing your foundation")
                                .font(.system(size: 17))
                                .foregroundColor(.atlasTextMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                        }
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)
                    }
                    .padding(.bottom, 32)
                    
                    // Stats cards
                    HStack(spacing: 16) {
                        StatCard(
                            icon: "calendar",
                            value: "\(weeksCompleted)",
                            label: "Weeks",
                            color: .atlasPrimary
                        )
                        
                        StatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            value: "\(Int(avgAdherence * 100))%",
                            label: "Adherence",
                            color: .green
                        )
                        
                        StatCard(
                            icon: "figure.walk",
                            value: "\(daysPerWeek)x",
                            label: "Per Week",
                            color: .atlasAccent
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)
                    
                    // Progression visual
                    VStack(spacing: 20) {
                        ProgressionRow(
                            icon: "figure.walk",
                            title: "Foundation Training",
                            subtitle: "Building the base",
                            isHighlighted: false
                        )
                        
                        Image(systemName: "arrow.down")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.atlasPrimary)
                        
                        ProgressionRow(
                            icon: "figure.strengthtraining.traditional",
                            title: "Training Plan",
                            subtitle: "Progressive overload & structure",
                            isHighlighted: true
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: showContent)
                    
                    // Message
                    Text("Your consistency built the foundation.\nNow let's build on it.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.atlasText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: showContent)
                    
                    // Buttons
                    VStack(spacing: 16) {
                        Button(action: onUpgrade) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .font(.system(size: 22))
                                Text("Upgrade to Training Plan")
                                    .font(.system(size: 19, weight: .semibold))
                            }
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.atlasPrimary, Color.atlasPrimary.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.atlasPrimary.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onDecline) {
                            Text("Stay on Foundation Training")
                                .font(.system(size: 16))
                                .foregroundColor(.atlasTextMuted)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
                }
            }
        }
        .onAppear {
            showContent = true
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.atlasText)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.atlasTextMuted)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Progression Row

struct ProgressionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isHighlighted ? Color.atlasPrimary.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(isHighlighted ? .atlasPrimary : .atlasTextMuted)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isHighlighted ? .atlasPrimary : .atlasText)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }
            
            Spacer()
            
            if isHighlighted {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)
            }
        }
        .padding(20)
        .background(
            isHighlighted ? 
                Color.atlasPrimary.opacity(0.1) : 
                Color.white.opacity(0.03)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHighlighted ? Color.atlasPrimary.opacity(0.4) : Color.clear,
                    lineWidth: 2
                )
        )
    }
}

#Preview {
    MovementUpgradeCelebrationView(
        weeksCompleted: 6,
        avgAdherence: 0.85,
        daysPerWeek: 5,
        onUpgrade: {},
        onDecline: {}
    )
}
