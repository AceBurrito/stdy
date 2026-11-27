import SwiftUI
import SwiftData

struct StrengthAssessmentScreen: View {
    @Environment(\.unitFormatter) private var unitFormatter
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @Binding var benchPressMax: String
    @Binding var squatMax: String
    @Binding var deadliftMax: String
    @Binding var pushupRange: LongevityTierCalculation.PushupRange?
    @Binding var canStandFromSitting: Bool?
    @Binding var deadHangRange: LongevityTierCalculation.DeadHangRange?
    @Binding var userExercisesRegularly: Bool
    @Binding var trainingForEvent: Bool  // Kept for interface compatibility, not shown in UI

    let onContinue: () -> Void
    
    @State private var currentStep = 1
    @State private var knowsLiftMaxes = false
    @State private var selectedEquipment: String = "Full Gym"  // ✅ NEW: Equipment selection
    
    private var userProfile: UserProfile? { profiles.first }

    // ✅ UPDATED: Now 6 steps (added equipment at step 5, exercise status at step 6)
    private let totalSteps = 6
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return true // Can skip lift maxes
        case 2:
            return pushupRange != nil
        case 3:
            return canStandFromSitting != nil
        case 4:
            return deadHangRange != nil
        case 5:
            return true // Equipment always has a default
        case 6:
            return true // Exercise status always has a default
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= currentStep ? Color.atlasPrimary : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Strength Assessment")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.atlasText)
                        
                        Text("Step \(currentStep) of \(totalSteps)")
                            .font(.system(size: 15))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .padding(.top, 20)
                    
                    // Questions
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 1:
                            liftMaxesStep
                        case 2:
                            pushupStep
                        case 3:
                            sitToStandStep
                        case 4:
                            deadHangStep
                        case 5:
                            equipmentStep          // ✅ NEW STEP
                        case 6:
                            exerciseStatusStep     // ✅ SHIFTED from step 5 → 6
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Navigation buttons
                    VStack(spacing: 12) {
                        Button(action: handleContinue) {
                            Text(currentStep == totalSteps ? "Complete Assessment" : "Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.atlasBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canProceed ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                                .cornerRadius(12)
                        }
                        .disabled(!canProceed)
                        
                        if currentStep > 1 {
                            Button(action: { currentStep -= 1 }) {
                                Text("Back")
                                    .font(.system(size: 16))
                                    .foregroundColor(.atlasTextMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Pre-fill equipment from profile if available
            if let existing = userProfile?.availableEquipment {
                selectedEquipment = existing
            }
        }
    }
    
    // MARK: - Step 1: Lift Maxes
    
    private var liftMaxesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Do you know your 1-rep max?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("If you track your strength training, enter your max lifts. Otherwise, we'll use bodyweight assessments.")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(4)
            }
            
            Toggle(isOn: $knowsLiftMaxes) {
                Text("I know my 1-rep maxes")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasText)
            }
            .tint(.atlasPrimary)
            
            if knowsLiftMaxes {
                VStack(spacing: 16) {
                    LiftMaxField(
                        label: "Bench Press",
                        placeholder: "185",
                        text: $benchPressMax
                    )
                    
                    LiftMaxField(
                        label: "Squat",
                        placeholder: "225",
                        text: $squatMax
                    )
                    
                    LiftMaxField(
                        label: "Deadlift",
                        placeholder: "315",
                        text: $deadliftMax
                    )
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text("We'll use this as a starting estimate. Your Pace will get more accurate as you log workouts.")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Step 2: Pushups
    
    private var pushupStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How many pushups can you do?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("In a row, with good form, until failure")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
            }
            
            VStack(spacing: 12) {
                ForEach(LongevityTierCalculation.PushupRange.allCases, id: \.self) { range in
                    Button(action: { pushupRange = range }) {
                        HStack {
                            Text(range.rawValue)
                                .font(.system(size: 16))
                                .foregroundColor(.atlasText)
                            
                            Spacer()
                            
                            if pushupRange == range {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.atlasPrimary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.atlasTextMuted.opacity(0.3))
                            }
                        }
                        .padding(16)
                        .background(pushupRange == range ? Color.atlasPrimary.opacity(0.15) : Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Step 3: Sit to Stand
    
    private var sitToStandStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Can you stand up without using your hands?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("From a seated position on the floor, can you stand up without using your hands for support?")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(4)
            }
            
            VStack(spacing: 12) {
                Button(action: { canStandFromSitting = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yes, I can")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasText)
                            
                            Text("Stand up without hands")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                        
                        Spacer()
                        
                        if canStandFromSitting == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.atlasPrimary)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.atlasTextMuted.opacity(0.3))
                        }
                    }
                    .padding(16)
                    .background(canStandFromSitting == true ? Color.atlasPrimary.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { canStandFromSitting = false }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No, I need support")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasText)
                            
                            Text("Use hands or assistance")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                        
                        Spacer()
                        
                        if canStandFromSitting == false {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.atlasPrimary)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.atlasTextMuted.opacity(0.3))
                        }
                    }
                    .padding(16)
                    .background(canStandFromSitting == false ? Color.atlasPrimary.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                    Text("Why this matters:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Text("The sit-to-stand test is a strong predictor of longevity, especially in adults over 40. It measures functional strength and mobility.")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Step 4: Dead Hang
    
    private var deadHangStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How long can you dead hang?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("Hang from a pull-up bar with straight arms until failure")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
            }
            
            VStack(spacing: 12) {
                ForEach(LongevityTierCalculation.DeadHangRange.allCases, id: \.self) { range in
                    Button(action: { deadHangRange = range }) {
                        HStack {
                            Text(range.displayText)
                                .font(.system(size: 16))
                                .foregroundColor(.atlasText)
                            
                            Spacer()
                            
                            if deadHangRange == range {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.atlasPrimary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.atlasTextMuted.opacity(0.3))
                            }
                        }
                        .padding(16)
                        .background(deadHangRange == range ? Color.atlasPrimary.opacity(0.15) : Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Step 5: Equipment (NEW — moved from Training Preferences)

    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What equipment do you have?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)

                Text("This helps us recommend the right training plan for you.")
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(4)
            }

            VStack(spacing: 8) {
                ForEach(equipmentOptions, id: \.0) { option, icon in
                    Button(action: { selectedEquipment = option }) {
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .foregroundColor(selectedEquipment == option ? .atlasPrimary : .atlasTextMuted)
                                .frame(width: 24)

                            Text(option)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(selectedEquipment == option ? .atlasPrimary : .atlasText)

                            Spacer()

                            if selectedEquipment == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.atlasPrimary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.atlasTextMuted.opacity(0.3))
                            }
                        }
                        .padding(14)
                        .background(selectedEquipment == option ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedEquipment == option ? Color.atlasPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private let equipmentOptions: [(String, String)] = [
        ("Bodyweight Only", "figure.walk"),
        ("Dumbbells at Home", "dumbbell.fill"),
        ("Full Gym", "building.2.fill")
    ]
    
    // MARK: - Step 6: Exercise Status (shifted from step 5)
    
    private var exerciseStatusStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("One last question...")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("Do you exercise regularly?")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    userExercisesRegularly = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yes, I work out regularly")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasText)
                            
                            Text("You have a current training routine")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                        
                        Spacer()
                        
                        if userExercisesRegularly {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.atlasPrimary)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.atlasTextMuted.opacity(0.3))
                        }
                    }
                    .padding(16)
                    .background(userExercisesRegularly ? Color.atlasPrimary.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    userExercisesRegularly = false
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No, I'm just starting")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasText)
                            
                            Text("You're new to regular exercise")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                        }
                        
                        Spacer()
                        
                        if !userExercisesRegularly {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.atlasPrimary)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.atlasTextMuted.opacity(0.3))
                        }
                    }
                    .padding(16)
                    .background(!userExercisesRegularly ? Color.atlasPrimary.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleContinue() {
        if currentStep < totalSteps {
            // Set strength data source when leaving step 1
            if currentStep == 1 {
                setStrengthDataSource()
            }
            // Save equipment when leaving step 5
            if currentStep == 5 {
                saveEquipment()
            }
            currentStep += 1
        } else {
            onContinue()
        }
    }
    
    private func setStrengthDataSource() {
        guard let profile = userProfile else { return }
        
        let hasLiftMaxes = !benchPressMax.isEmpty || !squatMax.isEmpty || !deadliftMax.isEmpty
        
        if knowsLiftMaxes && hasLiftMaxes {
            profile.strengthDataSource = "selfReported"
            print("💪 Strength source: selfReported (lift maxes provided)")
        } else if !knowsLiftMaxes {
            profile.strengthDataSource = "dontKnow"
            print("💪 Strength source: dontKnow (no lift maxes)")
        } else {
            profile.strengthDataSource = "bodyweightOnly"
            print("💪 Strength source: bodyweightOnly")
        }
        
        try? modelContext.save()
    }

    /// ✅ NEW: Save equipment selection to profile
    private func saveEquipment() {
        guard let profile = userProfile else { return }
        profile.availableEquipment = selectedEquipment
        try? modelContext.save()
        print("🏋️ Equipment saved: \(selectedEquipment)")
    }
}

struct LiftMaxField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @Environment(\.unitFormatter) private var unitFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
            
            HStack {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.atlasText)
                    .keyboardType(.numberPad)
                
                Text(unitFormatter.weightUnit)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
    }
}