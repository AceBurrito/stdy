import SwiftUI
import SwiftData

// MARK: - Strength Reassessment Wrapper
// Wraps StrengthAssessmentScreen for standalone use from the Strength tab.
// Pre-fills existing values from UserProfile so users see their current data.
// On completion, saves to profile and triggers Pace recalculation.

struct StrengthReassessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    // Bindings for StrengthAssessmentScreen
    @State private var benchPressMax: String = ""
    @State private var squatMax: String = ""
    @State private var deadliftMax: String = ""
    @State private var pushupRange: LongevityTierCalculation.PushupRange? = nil
    @State private var canStandFromSitting: Bool? = nil
    @State private var deadHangRange: LongevityTierCalculation.DeadHangRange? = nil
    @State private var userExercisesRegularly: Bool = true
    @State private var trainingForEvent: Bool = false
    
    private var userProfile: UserProfile? { profiles.first }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                
                StrengthAssessmentScreen(
                    benchPressMax: $benchPressMax,
                    squatMax: $squatMax,
                    deadliftMax: $deadliftMax,
                    pushupRange: $pushupRange,
                    canStandFromSitting: $canStandFromSitting,
                    deadHangRange: $deadHangRange,
                    userExercisesRegularly: $userExercisesRegularly,
                    trainingForEvent: $trainingForEvent,
                    onContinue: { saveAndDismiss() }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .onAppear { prefillFromProfile() }
        }
    }
    
    // MARK: - Pre-fill from Profile
    
    private func prefillFromProfile() {
        guard let profile = userProfile else { return }
        
        if let bench = profile.benchPressMax { benchPressMax = "\(Int(bench))" }
        if let squat = profile.squatMax { squatMax = "\(Int(squat))" }
        if let deadlift = profile.deadliftMax { deadliftMax = "\(Int(deadlift))" }
        
        // Map stored string back to enum
        if let range = profile.pushupRange {
            pushupRange = LongevityTierCalculation.PushupRange(rawValue: range)
        }
        canStandFromSitting = profile.canStandFromSitting
        if let range = profile.deadHangRange {
            deadHangRange = LongevityTierCalculation.DeadHangRange(rawValue: range)
        }
        
        userExercisesRegularly = profile.userExercisesRegularly
    }
    
    // MARK: - Save and Dismiss
    
    private func saveAndDismiss() {
        guard let profile = userProfile else { dismiss(); return }
        
        // Step 1: Save self-reported assessment data
        if let bench = Double(benchPressMax) { profile.benchPressMax = bench }
        if let squat = Double(squatMax) { profile.squatMax = squat }
        if let deadlift = Double(deadliftMax) { profile.deadliftMax = deadlift }
        
        profile.pushupRange = pushupRange?.rawValue
        profile.canStandFromSitting = canStandFromSitting
        profile.deadHangRange = deadHangRange?.rawValue
        profile.userExercisesRegularly = userExercisesRegularly
        profile.lastStrengthAssessmentDate = Date()
        
        try? modelContext.save()
        print("✅ Strength reassessment saved (self-reported)")
        
        // Step 2: Merge with workout-derived data (keeps higher value for each lift)
        // This scans the last 30 days of logged workouts for bench/squat/deadlift
        // and upgrades any lift where the workout e1RM exceeds the self-reported max.
        let result = StrengthDataMerger.mergeAndUpdate(
            profile: profile,
            modelContext: modelContext,
            daysBack: 30
        )
        
        if result.hasChanges {
            print("✅ Merged with workout data: \(result.summary)")
        }
        
        dismiss()
    }
}