import SwiftUI
import SwiftData

// MARK: - Free Intervention Selection View
// Tier-free version: hardcoded max 3 selections for free tier

struct FreeInterventionSelectionView: View {
    let recommendations: InterventionRecommendationResponse
    let onContinue: ([Intervention]) -> Void
    
    @State private var selectedInterventions: Set<String> = []
    @State private var userInputs: [String: InterventionUserInput] = [:]
    @State private var pendingInputIntervention: Intervention? = nil
    
    private let maxSelections = 3
    
    private var selectionsRemaining: Int {
        maxSelections - selectedInterventions.count
    }
    
    private var canContinue: Bool {
        selectedInterventions.count >= 1 && selectedInterventions.count <= maxSelections
    }
    
    private var isAtLimit: Bool {
        selectedInterventions.count >= maxSelections
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        summaryCard
                        selectionInstructions
                        interventionCards
                        
                        // Buffer for floating button
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            
            // Floating CTA
            VStack {
                Spacer()
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .sheet(item: $pendingInputIntervention) { intervention in
            if let template = InterventionLibrary.allInterventions.first(where: { $0.id == intervention.id }) {
                InterventionUserInputSheet(
                    intervention: intervention,
                    template: template,
                    onSave: { customName, duration in
                        userInputs[intervention.id] = InterventionUserInput(
                            interventionId: intervention.id,
                            customName: customName,
                            durationMinutes: duration
                        )
                        pendingInputIntervention = nil
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            handleContinue()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR DAILY NON-NEGOTIABLES")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.atlasPrimary)
                .tracking(2)
            
            Text("Choose 2–3 habits you'll commit to every day.")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)
                .lineSpacing(4)
            
            Text("Start small — you can always add more once these are locked in. Atlas tracks your streaks and uses your consistency to guide your weekly coaching.")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recommendations.recommendationSummary)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .lineSpacing(6)
        }
        .padding(20)
        .background(Color.atlasPrimary.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Selection Instructions
    
    private var selectionInstructions: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isAtLimit ? Color.green : Color.atlasPrimary)
                    .frame(width: 40, height: 40)
                
                Text("\(selectedInterventions.count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.atlasBackground)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if isAtLimit {
                    Text("Ready to go!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("You can change these anytime")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                } else if selectedInterventions.isEmpty {
                    Text("Select up to \(maxSelections) habits")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text("Tap cards to select your starting habits")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                } else {
                    Text("\(selectionsRemaining) more available")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text("Select up to \(maxSelections) total")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.atlasBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Intervention Cards
    
    private var interventionCards: some View {
        VStack(spacing: 16) {
            ForEach(Array(recommendations.interventions.enumerated()), id: \.element.id) { index, intervention in
                FreeInterventionCard(
                    intervention: intervention,
                    rank: index + 1,
                    isSelected: selectedInterventions.contains(intervention.id),
                    isDisabled: isAtLimit && !selectedInterventions.contains(intervention.id),
                    onTap: {
                        toggleSelection(intervention.id)
                    }
                )
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 12) {
                Text(canContinue ? "Start with These Habits" : "Select at Least 1 Habit")
                    .font(.system(size: 18, weight: .bold))
                
                if canContinue {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(canContinue ? .atlasBackground : .atlasTextMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                canContinue ?
                    LinearGradient(
                        colors: [Color.atlasPrimary, Color.atlasPrimary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(14)
            .shadow(color: canContinue ? Color.atlasPrimary.opacity(0.3) : Color.clear, radius: 12, x: 0, y: 6)
        }
        .disabled(!canContinue)
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ id: String) {
        if selectedInterventions.contains(id) {
            selectedInterventions.remove(id)
            // Also remove any user input for this intervention
            userInputs.removeValue(forKey: id)
        } else if selectedInterventions.count < maxSelections {
            selectedInterventions.insert(id)
        }
    }
    
    private func handleContinue() {
        var selected = recommendations.interventions.filter { selectedInterventions.contains($0.id) }
        
        // Check if any selected interventions need user input that we atlas't collected yet
        let needsInput = selected.filter { intervention in
            let template = InterventionLibrary.allInterventions.first { $0.id == intervention.id }
            return template?.requiresUserInput == true && userInputs[intervention.id] == nil
        }
        
        if let next = needsInput.first {
            // Show input sheet for the next intervention that needs it
            pendingInputIntervention = next
        } else {
            // All inputs collected (or none needed) — apply custom names and continue
            for i in 0..<selected.count {
                if let input = userInputs[selected[i].id] {
                    selected[i].customTitle = input.customName
                    selected[i].customDuration = input.durationMinutes
                }
            }
            onContinue(selected)
        }
    }
}

// MARK: - Free Intervention Card

struct FreeInterventionCard: View {
    let intervention: Intervention
    let rank: Int
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.atlasPrimary : Color.white.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: intervention.icon)
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? .atlasBackground : .atlasPrimary)
                    }
                    
                    // Title & Rank
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("#\(rank)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.atlasPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.atlasPrimary.opacity(0.2))
                                .cornerRadius(6)
                            
                            Text("\(intervention.impactScore)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.atlasTextMuted)
                            
                            Text("impact")
                                .font(.system(size: 11))
                                .foregroundColor(.atlasTextMuted.opacity(0.7))
                        }
                        
                        Text(intervention.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.atlasText)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Checkmark
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.atlasPrimary)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 28))
                            .foregroundColor(isDisabled ? .white.opacity(0.08) : .white.opacity(0.2))
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Why This Matters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why this matters")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasPrimary)
                    
                    Text(intervention.whyThisMatters)
                        .font(.system(size: 14))
                        .foregroundColor(.atlasText)
                        .lineSpacing(5)
                }
                
                // Current → Target
                if let current = intervention.currentValue {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                            Text(current)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.atlasAmber)
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                            Text(intervention.targetValue ?? "")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
                
                // Research Citation
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                    
                    Text(intervention.researchCitation)
                        .font(.system(size: 11))
                        .foregroundColor(.atlasTextMuted.opacity(0.7))
                }
            }
            .padding(20)
            .background(
                isSelected ?
                    Color.atlasPrimary.opacity(0.1) :
                    Color.white.opacity(isDisabled ? 0.02 : 0.05)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.atlasPrimary : Color.white.opacity(isDisabled ? 0.05 : 0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}