import SwiftUI
import SwiftData

struct ProteinLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    @State private var grams: String = ""
    @State private var isEstimated: Bool = false
    @State private var showingGoalSetup: Bool = false
    
    var onComplete: ((Bool) -> Void)? // Returns whether goal was hit
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var proteinGoal: Int? {
        userProfile?.proteinGoal
    }
    
    private var goalProgress: Double {
        guard let goal = proteinGoal, let entered = Int(grams), goal > 0 else { return 0 }
        return Double(entered) / Double(goal)
    }
    
    private var hitGoal: Bool {
        goalProgress >= 0.85
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Goal display
                    if let goal = proteinGoal {
                        goalSection(goal: goal)
                    } else {
                        noGoalSection
                    }
                    
                    // Input section
                    inputSection
                    
                    // Estimate toggle
                    estimateToggle
                    
                    Spacer()
                    
                    // Save button
                    saveButton
                }
                .padding(24)
            }
            .navigationTitle("Log Protein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
            .sheet(isPresented: $showingGoalSetup) {
                ProteinGoalSetupView()
            }
        }
    }
    
    // MARK: - Goal Section
    private func goalSection(goal: Int) -> some View {
        VStack(spacing: 12) {
            Text("YOUR GOAL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Text("\(goal)g")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.atlasText)
            
            if !grams.isEmpty {
                HStack(spacing: 8) {
                    Text("\(Int(goalProgress * 100))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(hitGoal ? .green : .atlasTextMuted)
                    
                    if hitGoal {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - No Goal Section
    private var noGoalSection: some View {
        VStack(spacing: 12) {
            Text("No protein goal set")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
            
            Button(action: { showingGoalSetup = true }) {
                Text("Set Protein Target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Intake")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
            
            HStack {
                TextField("e.g., 150", text: $grams)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.atlasText)
                
                Text("grams")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Estimate Toggle
    private var estimateToggle: some View {
        Button(action: { isEstimated.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: isEstimated ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isEstimated ? .atlasPrimary : .atlasTextMuted)
                
                Text("This is an estimate")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasText)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveEntry) {
            Text("Save")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(grams.isEmpty ? Color.atlasTextMuted.opacity(0.3) : Color.atlasPrimary)
                .cornerRadius(12)
        }
        .disabled(grams.isEmpty)
    }
    
    // MARK: - Save
    private func saveEntry() {
        guard let gramsValue = Int(grams) else { return }
        
        let entry = ProteinEntry(date: Date(), grams: gramsValue, isEstimated: isEstimated)
        entry.userProfile = userProfile
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            print("✅ Protein logged: \(gramsValue)g")
            onComplete?(hitGoal)
            dismiss()
        } catch {
            print("❌ Failed to save protein: \(error)")
        }
    }
}

#Preview {
    ProteinLogSheet()
}
