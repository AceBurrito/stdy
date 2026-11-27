import SwiftUI
import SwiftData

// MARK: - Plan Selection View
// Shows 3-4 recommended plans based on the user's profile.
// Never shows the full catalog — curated recommendations only.
// Also provides paths to Build Your Own and Event Training.
//
// Used in:
// 1. Onboarding (steps 7-8)
// 2. Change Plan flow (from TrainingProgramView)

struct PlanSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    /// Optional: current plan ID to exclude from recommendations (Change Plan flow)
    var excludingPlanID: String?

    /// Optional: bias from TrainingStatusAnalyzer (Change Plan flow)
    var bias: PlanRecommendationEngine.RecommendationBias?

    /// Called when a plan is selected — navigates to PlanPreviewView
    var onPlanSelected: ((TrainingPlanTemplate) -> Void)?

    /// Called when Build Your Own is tapped
    var onBuildYourOwn: (() -> Void)?

    /// Called when Event Training is tapped
    var onEventTraining: (() -> Void)?

    /// Called when Keep Current Plan is tapped (Change Plan flow only)
    var onKeepCurrent: (() -> Void)?

    /// Whether we're in the Change Plan flow (shows "Keep Current" button)
    var isChangePlanFlow: Bool = false

    private var userProfile: UserProfile? { profiles.first }

    private var recommendedPlans: [TrainingPlanTemplate] {
        guard let profile = userProfile else { return [] }
        return PlanRecommendationEngine.recommend(
            primaryGoal: profile.primaryGoal,
            secondaryGoal: profile.secondaryGoal,
            equipment: profile.availableEquipment,
            experience: profile.experienceLevel,
            bias: bias,
            excludingPlanID: excludingPlanID
        )
    }

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    // Recommended Plans
                    if !recommendedPlans.isEmpty {
                        recommendedSection
                    }

                    // Divider
                    dividerLine

                    // Build Your Own
                    buildYourOwnCard

                    // Event Training
                    eventTrainingCard

                    // Keep Current (Change Plan only)
                    if isChangePlanFlow {
                        keepCurrentButton
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isChangePlanFlow ? "CHANGE PLAN" : "YOUR PLAN")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)

            Text(isChangePlanFlow ? "Pick your next program" : "We found plans for you")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)

            Text("Based on your goals, equipment, and experience")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    // MARK: - Recommended Plans

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECOMMENDED FOR YOU")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)

            ForEach(Array(recommendedPlans.enumerated()), id: \.element.id) { index, plan in
                PlanCard(plan: plan, rank: index + 1) {
                    onPlanSelected?(plan)
                }
            }
        }
    }

    // MARK: - Divider

    private var dividerLine: some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            Text("OR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .padding(.horizontal, 12)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Build Your Own

    private var buildYourOwnCard: some View {
        Button(action: { onBuildYourOwn?() }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.atlasPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "hammer.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Build Your Own")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Text("Pick exercises, days, and sets yourself")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Event Training

    private var eventTrainingCard: some View {
        Button(action: { onEventTraining?() }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.atlasAmber.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasAmber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Train for an Event")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Text("HYROX, marathon, triathlon, and more")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Keep Current

    private var keepCurrentButton: some View {
        Button(action: { onKeepCurrent?() }) {
            Text("Keep Current Plan")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.atlasTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: TrainingPlanTemplate
    let rank: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: rank + name
                HStack(alignment: .top) {
                    // Rank badge
                    if rank == 1 {
                        Text("TOP PICK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.atlasPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.atlasPrimary.opacity(0.15))
                            .cornerRadius(4)
                    }

                    Spacer()

                    // Days + split
                    Text("\(plan.strengthDays) days · \(plan.splitType)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                }

                // Plan name
                Text(plan.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasText)

                // Tagline
                Text(plan.tagline)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(3)

                // Equipment + experience tags
                HStack(spacing: 8) {
                    TagPill(text: plan.equipmentTier.displayName, color: .atlasPrimary)
                    TagPill(text: plan.experienceLevel.rawValue, color: .atlasAmber)
                }
            }
            .padding(16)
            .background(
                rank == 1
                    ? Color.atlasPrimary.opacity(0.06)
                    : Color.white.opacity(0.04)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        rank == 1 ? Color.atlasPrimary.opacity(0.3) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}
