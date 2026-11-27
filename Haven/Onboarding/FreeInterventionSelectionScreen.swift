import SwiftUI
import SwiftData

// MARK: - Free Intervention Selection Screen
// Onboarding Step 7: Assess deficiencies -> Select up to 3 habits
// No AI, no tier dependency, deterministic selection

struct FreeInterventionSelectionScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \BiologicalPaceScore.date, order: .reverse) private var paceScores: [BiologicalPaceScore]
    
    let onContinue: ([Intervention]) -> Void
    
    @State private var recommendations: InterventionRecommendationResponse?
    @State private var isLoading = true
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let recs = recommendations {
                FreeInterventionSelectionView(
                    recommendations: recs,
                    onContinue: onContinue
                )
            } else {
                errorFallback
            }
        }
        .task {
            loadRecommendations()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(.atlasPrimary)
                .scaleEffect(1.2)
            
            Text("Building your starting habits...")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
        }
    }
    
    // MARK: - Error Fallback
    
    private var errorFallback: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.atlasAmber)
            
            Text("Couldn't generate recommendations")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text("You can add habits later from the app")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
            
            Button(action: { onContinue([]) }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.atlasPrimary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Load Recommendations
    
    private func loadRecommendations() {
        guard let profile = userProfile else {
            isLoading = false
            return
        }
        
        // Get latest health metrics
        let metricsDescriptor = FetchDescriptor<HealthMetrics>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let latestMetrics = try? modelContext.fetch(metricsDescriptor).first
        
        // Build deficiency assessment
        let age = profile.age ?? 40
        let isMale = profile.gender?.lowercased() == "male"
        let primaryGoal = profile.primaryGoal ?? "live_longer"
        
    let sleepValue: Double?
        if let sleep = latestMetrics?.sleepDuration {
            sleepValue = sleep
        } else if let reported = profile.selfReportedSleepHours, reported > 0 {
        sleepValue = reported
        } else {
            sleepValue = nil
        }

        let deficiencies = DeficiencyAssessment.determinePriorities(
            sleepHours: sleepValue,
            proteinGrams: profile.currentProteinIntake,
            bodyWeight: profile.weight,
            vo2Max: latestMetrics?.vo2Max,
            hrv: latestMetrics?.heartRateVariability,
            rhr: latestMetrics?.restingHeartRate,
            steps: latestMetrics?.stepCount,
            activityLevel: profile.activityLevel,
            age: age,
            isMale: isMale,
            primaryGoal: primaryGoal
        )
        
        print("📊 Deficiency Assessment: \(deficiencies.count) priorities")
        for d in deficiencies {
            print("   \(d.level.emoji) \(d.metric): \(d.level.rawValue)")
        }
        
        // Build minimal user info for selector
        let userInfo = PaceInterventionSelector.UserInfo(
            name: profile.name ?? "Friend",
            age: age,
            isMale: isMale,
            primaryGoal: primaryGoal,
            sleepHours: sleepValue,
            hrv: latestMetrics?.heartRateVariability,
            rhr: latestMetrics?.restingHeartRate,
            vo2Max: latestMetrics?.vo2Max,
            steps: latestMetrics?.stepCount,
            bodyweight: profile.weight,
            proteinGrams: profile.currentProteinIntake,
            activityLevel: profile.activityLevel
        )
        
        // Run deterministic selector
        let recs = PaceInterventionSelector.selectInterventions(
            deficiencies: deficiencies,
            userInfo: userInfo
        )
        
        recommendations = recs
        isLoading = false
    }
}
