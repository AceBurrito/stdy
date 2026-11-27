import SwiftUI
import SwiftData

// MARK: - Onboarding Flow (Steady)
//
//   0  Welcome
//   1  Apple Health permissions
//   2  Basics: age, sex, height
//   3  Current weight (Apple Health or manual)
//   4  Body fat % (Apple Health, manual, or "I don't know")
//   5  Goal: Lose Fat / Build Muscle / Recomp / Maintain
//   6  Experience: Beginner / Intermediate / Advanced
//   7  Equipment: Bodyweight / Dumbbells / Full Gym
//   8  Plan selection → preview → cardio days (or Build Your Own)
//   → Today tab
//
// No habits, no nutrition, no Pace. Every step writes to UserProfile directly.

struct NewOnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitManager = HealthKitManager.shared
    @Query private var profiles: [UserProfile]

    @State private var currentStep = 0

    // Plan selection state (step 8)
    @State private var selectedTemplate: TrainingPlanTemplate? = nil
    @State private var showPlanPreview = false
    @State private var showCustomBuilder = false
    @State private var showCardioStep = false
    @State private var pendingDayAssignments: [DayAssigner.DayAssignment] = []

    /// Steps 1–8 show progress ticks
    private let totalSteps = 8

    private var userProfile: UserProfile? {
        profiles.first
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.atlasBackground
                .ignoresSafeArea()

            Group {
                if currentStep == 0 {
                    OnboardingWelcomeStep {
                        ensureProfile()
                        advance()
                    }
                } else if let profile = userProfile {
                    step(for: profile)
                } else {
                    // Profile is created on the welcome step; this covers a relaunch mid-flow.
                    ProgressView()
                        .tint(.atlasPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear { ensureProfile() }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
            .id(currentStep)

            // Back button on steps 2–7 (data entry). Step 1 is permissions; step 8 has its own navigation.
            if currentStep >= 2 && currentStep <= 7 {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStep)
        .preferredColorScheme(.dark)
    }

    // MARK: - Steps

    @ViewBuilder
    private func step(for profile: UserProfile) -> some View {
        switch currentStep {
        case 1:
            OnboardingHealthStep(step: 1, totalSteps: totalSteps, healthKitManager: healthKitManager, onDone: advance)
        case 2:
            OnboardingBasicsStep(step: 2, totalSteps: totalSteps, profile: profile, healthData: healthKitManager.healthData, onDone: saveAndAdvance)
        case 3:
            OnboardingWeightStep(step: 3, totalSteps: totalSteps, profile: profile, healthData: healthKitManager.healthData, onDone: saveAndAdvance)
        case 4:
            OnboardingBodyFatStep(step: 4, totalSteps: totalSteps, profile: profile, healthData: healthKitManager.healthData, onDone: saveAndAdvance)
        case 5:
            OnboardingGoalStep(step: 5, totalSteps: totalSteps, profile: profile, onDone: saveAndAdvance)
        case 6:
            OnboardingExperienceStep(step: 6, totalSteps: totalSteps, profile: profile, onDone: saveAndAdvance)
        case 7:
            OnboardingEquipmentStep(step: 7, totalSteps: totalSteps, profile: profile, onDone: saveAndAdvance)
        default:
            planSelectionStep
        }
    }

    // MARK: - Step 8: Plan Selection → Preview → Cardio

    @ViewBuilder
    private var planSelectionStep: some View {
        if showCustomBuilder {
            CustomPlanBuilderView(
                onComplete: {
                    print("✅ Onboarding: custom plan committed")
                    completeOnboarding()
                },
                onBack: {
                    showCustomBuilder = false
                    resetPlanState()
                }
            )
        } else if showCardioStep, let template = selectedTemplate {
            let restDays = pendingDayAssignments
                .filter { $0.workoutType == "rest" }
                .map { $0.dayOfWeek }

            CardioOnboardingStepView(
                restDays: restDays,
                onContinue: { cardioDays in
                    print("✅ Onboarding: \(template.name) + \(cardioDays.count) cardio days committed")
                    commitPlan(template: template, cardioDays: cardioDays)
                    completeOnboarding()
                },
                onSkip: {
                    print("✅ Onboarding: \(template.name) committed (cardio skipped)")
                    commitPlan(template: template, cardioDays: [])
                    completeOnboarding()
                }
            )
        } else if showPlanPreview, let template = selectedTemplate {
            PlanPreviewView(
                template: template,
                onConfirm: {
                    pendingDayAssignments = DayAssigner.assignDays(for: template)
                    showCardioStep = true
                },
                onBack: {
                    resetPlanState()
                }
            )
        } else {
            PlanSelectionView(
                onPlanSelected: { template in
                    selectedTemplate = template
                    showPlanPreview = true
                },
                onBuildYourOwn: {
                    showCustomBuilder = true
                }
            )
        }
    }

    // MARK: - Navigation

    private func advance() {
        currentStep += 1
    }

    private func saveAndAdvance() {
        try? modelContext.save()
        advance()
    }

    private func goBack() {
        guard currentStep > 1 else { return }
        currentStep -= 1
    }

    private func ensureProfile() {
        let profile = DataController(modelContext: modelContext).getOrCreateUserProfile()
        profile.onboardingComplete = false
        try? modelContext.save()
    }

    // MARK: - Plan Commit

    private func commitPlan(template: TrainingPlanTemplate, cardioDays: [PlanCommitter.CardioDayConfig]) {
        guard let profile = userProfile else { return }
        PlanCommitter.commitTemplatePlan(
            template: template,
            dayAssignments: pendingDayAssignments,
            cardioDays: cardioDays,
            userProfile: profile,
            modelContext: modelContext
        )
    }

    private func resetPlanState() {
        showPlanPreview = false
        showCardioStep = false
        selectedTemplate = nil
        pendingDayAssignments = []
    }

    // MARK: - Finish

    private func completeOnboarding() {
        guard let profile = userProfile else { return }

        // Starting weigh-in, so the Body tab and Today snapshot have a first point
        if let weight = profile.weight {
            let entry = BodyCompEntry(date: Date(), weight: weight)
            entry.bodyFat = profile.bodyFatPercent
            entry.notes = "Starting point"
            entry.userProfile = profile
            modelContext.insert(entry)
        }

        profile.onboardingComplete = true
        profile.onboardingCompletedDate = Date()
        profile.currentWeek = 1
        profile.planActivationDate = Date()

        // Weekly summary is on by default; ask once, as the user lands in the app
        NotificationManager.shared.requestPermission { _ in }

        do {
            try modelContext.save()
            print("✅ Onboarding complete — goal: \(profile.primaryGoal ?? "none"), experience: \(profile.experienceLevel ?? "none"), equipment: \(profile.availableEquipment ?? "none")")
        } catch {
            print("❌ Failed to save onboarding: \(error)")
        }
        // RootView swaps to the main app when onboardingComplete flips.
    }
}

#Preview {
    NewOnboardingFlow()
}
