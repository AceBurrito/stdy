import SwiftUI
import SwiftData

struct ProteinGoalSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    @State private var customGrams: String = ""
    @State private var selectedOption: GoalOption? = nil
    
    enum GoalOption: String, CaseIterable {
        case currentWeight = "currentWeight"
        case goalWeight = "goalWeight"
        case custom = "custom"
    }
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var currentWeightGoal: Int {
        guard let weight = userProfile?.weight else { return 150 }
        return Int(weight * 0.85) // Middle ground between 0.8 and 1.0
    }
    
    private var goalWeightGoal: Int {
        guard let goalWeight = userProfile?.goalWeight else { return currentWeightGoal }
        return Int(goalWeight * 0.85)
    }
    
    private var hasGoalWeight: Bool {
        userProfile?.goalWeight != nil && userProfile?.goalWeight != userProfile?.weight
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection
                        
                        // Recommendation info
                        infoSection
                        
                        // Options
                        optionsSection
                        
                        // Custom input
                        if selectedOption == .custom {
                            customInputSection
                        }
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Save button
                        saveButton
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Set Protein Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROTEIN TARGET")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Text("Choose your daily goal")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.atlasAccent)
                Text("Why 0.8-1g per pound?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasText)
            }
            
            Text("Research shows 0.8-1g of protein per pound of bodyweight optimizes muscle maintenance, recovery, and satiety for longevity.")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.atlasAccent.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(spacing: 12) {
            // Current weight option
            GoalOptionCard(
                title: "Based on Current Weight",
                subtitle: "\(Int(userProfile?.weight ?? 0)) lbs × 0.85",
                value: "\(currentWeightGoal)g/day",
                isSelected: selectedOption == .currentWeight,
                action: { selectedOption = .currentWeight }
            )
            
            // Goal weight option (if different)
            if hasGoalWeight {
                GoalOptionCard(
                    title: "Based on Goal Weight",
                    subtitle: "\(Int(userProfile?.goalWeight ?? 0)) lbs × 0.85",
                    value: "\(goalWeightGoal)g/day",
                    isSelected: selectedOption == .goalWeight,
                    action: { selectedOption = .goalWeight }
                )
            }
            
            // Custom option
            GoalOptionCard(
                title: "Custom",
                subtitle: "Set your own target",
                value: customGrams.isEmpty ? "—" : "\(customGrams)g/day",
                isSelected: selectedOption == .custom,
                action: { selectedOption = .custom }
            )
        }
    }
    
    // MARK: - Custom Input
    private var customInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your target")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
            
            HStack {
                TextField("e.g., 180", text: $customGrams)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.atlasText)
                
                Text("grams/day")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveGoal) {
            Text("Set Goal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                .cornerRadius(12)
        }
        .disabled(!canSave)
    }
    
    private var canSave: Bool {
        switch selectedOption {
        case .currentWeight, .goalWeight:
            return true
        case .custom:
            return !customGrams.isEmpty && Int(customGrams) != nil
        case nil:
            return false
        }
    }
    
    private func saveGoal() {
        guard let profile = userProfile, let option = selectedOption else { return }
        
        switch option {
        case .currentWeight:
            profile.proteinGoal = currentWeightGoal
            profile.proteinGoalSource = "currentWeight"
        case .goalWeight:
            profile.proteinGoal = goalWeightGoal
            profile.proteinGoalSource = "goalWeight"
        case .custom:
            if let grams = Int(customGrams) {
                profile.proteinGoal = grams
                profile.proteinGoalSource = "custom"
            }
        }
        
        try? modelContext.save()
        print("✅ Protein goal set: \(profile.proteinGoal ?? 0)g (\(profile.proteinGoalSource ?? ""))")
        dismiss()
    }
}

// MARK: - Goal Option Card
struct GoalOptionCard: View {
    let title: String
    let subtitle: String
    let value: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasText)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .atlasPrimary : .atlasText)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .atlasPrimary : .atlasTextMuted.opacity(0.5))
            }
            .padding(16)
            .background(isSelected ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.atlasPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProteinGoalSetupView()
}
