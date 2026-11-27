import SwiftUI
import SwiftData

struct GoalSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var selectedGoals: Set<String> = []
    
    let onComplete: () -> Void
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    // Updated goal list
    let goals: [(id: String, title: String, subtitle: String, icon: String)] = [
        ("live_longer", "Live Longer", "Maximize healthspan and lifespan", "heart.fill"),
        ("look_better", "Look Better", "Improve body composition and aesthetics", "figure.stand"),
        ("feel_better", "Feel Better", "Boost energy, mood, and recovery", "bolt.fill"),
        ("get_stronger", "Get Stronger", "Build strength and muscle", "figure.strengthtraining.traditional"),
        ("sport_performance", "Sport/Performance", "Train for specific sport or event", "trophy.fill")
    ]
    
    var body: some View {
    ZStack {
        Color.atlasBackground
            .ignoresSafeArea()
        
        VStack(alignment: .leading, spacing: 32) {
            // Header - REDUCED TOP PADDING
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR GOALS")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.atlasAccent)
                    .tracking(1.5)
                
                Text("What are your top two goals?")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.atlasText)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Select 2 goals that matter most to you")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
                    .padding(.top, 4)
            }
            .padding(.top, 20)  // CHANGED FROM 40
            
            // Goal cards - WRAPPED IN SCROLLVIEW
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(goals, id: \.id) { goal in
                        GoalCard(
                            title: goal.title,
                            subtitle: goal.subtitle,
                            icon: goal.icon,
                            isSelected: selectedGoals.contains(goal.id),
                            isDisabled: !selectedGoals.contains(goal.id) && selectedGoals.count >= 2
                        ) {
                            toggleGoal(goal.id)
                        }
                    }
                }
            }
            
            // Continue button - FIXED POSITION
            Button(action: saveAndContinue) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedGoals.count == 2 ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                    .cornerRadius(12)
            }
            .disabled(selectedGoals.count != 2)
            .padding(.bottom, 20)  // CHANGED FROM 40
        }
        .padding(.horizontal, 24)
    }
}
    
    private func toggleGoal(_ goalId: String) {
        if selectedGoals.contains(goalId) {
            selectedGoals.remove(goalId)
        } else if selectedGoals.count < 2 {
            selectedGoals.insert(goalId)
        }
    }
    
    private func saveAndContinue() {
    guard selectedGoals.count == 2, let profile = userProfile else { 
        print("❌ Can't continue - goals: \(selectedGoals.count), profile: \(userProfile != nil)")
        return 
    }
    
    let goalsArray = Array(selectedGoals)
    profile.primaryGoal = goalsArray[0]
    profile.secondaryGoal = goalsArray[1]
    
    do {
        try modelContext.save()
        print("✅ Goals saved: \(goalsArray[0]) + \(goalsArray[1])")
        
        // Call onComplete
        onComplete()
        print("✅ onComplete() called")
        
    } catch {
        print("❌ Save failed: \(error)")
    }
}
}

// MARK: - Goal Card
struct GoalCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.atlasPrimary.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasTextMuted)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasText)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.atlasPrimary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.atlasPrimary : Color.clear, lineWidth: 2)
            )
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

#Preview {
    GoalSelectionView(onComplete: {})
}
