import SwiftUI
import SwiftData

// MARK: - Milestone Card (for TodayView)

struct MilestoneCardView: View {
    let milestone: ComponentMilestone
    let onDismiss: () -> Void
    let onDetail: () -> Void
    
    private var iconName: String {
        switch milestone.component.lowercased() {
        case "sleep": return "moon.fill"
        case "hrv": return "heart.text.square.fill"
        case "resting hr": return "heart.fill"
        case "vo₂ max": return "lungs.fill"
        case "daily movement": return "figure.walk"
        case "strength": return "dumbbell.fill"
        default: return "star.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
                
                Text("MILESTONE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
                    .tracking(1.5)
                
                Spacer()
                
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasPrimary.opacity(0.6))
            }
            
            // Message
            Text(milestone.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.atlasText)
                .lineSpacing(4)
            
            // Detail (if available)
            if let detail = milestone.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(3)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: onDismiss) {
                    Text("Nice")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.atlasPrimary.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDetail) {
                    Text("Details")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.atlasPrimary.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.atlasPrimary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Milestone List (for TodayView integration)

struct MilestoneStack: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ComponentMilestone> { $0.dismissed == false },
        sort: \ComponentMilestone.date,
        order: .reverse
    ) private var activeMilestones: [ComponentMilestone]
    
    @Query private var profiles: [UserProfile]
    
    @State private var showPaceDetail = false
    
    /// BUG-003: Returns true if we are still within the 7-day grace period after onboarding.
    /// Milestones are still tracked/stored — just not displayed during this window.
    private var isInGracePeriod: Bool {
        guard let profile = profiles.first,
              let completedDate = profile.onboardingCompletedDate else {
            // If no date recorded (older installs), use planActivationDate as fallback
            if let activationDate = profiles.first?.planActivationDate {
                let daysSince = Calendar.current.dateComponents([.day], from: activationDate, to: Date()).day ?? 0
                return daysSince < 7
            }
            return false
        }
        let daysSince = Calendar.current.dateComponents([.day], from: completedDate, to: Date()).day ?? 0
        return daysSince < 7
    }
    
    var body: some View {
        if !activeMilestones.isEmpty && !isInGracePeriod {
            VStack(spacing: 10) {
                ForEach(activeMilestones.prefix(2)) { milestone in
                    MilestoneCardView(
                        milestone: milestone,
                        onDismiss: {
                            dismissMilestone(milestone)
                        },
                        onDetail: {
                            showPaceDetail = true
                        }
                    )
                }
            }
            .sheet(isPresented: $showPaceDetail) {
                PaceDetailView()
            }
        }
    }
    
    private func dismissMilestone(_ milestone: ComponentMilestone) {
        milestone.dismissed = true
        try? modelContext.save()
    }
}