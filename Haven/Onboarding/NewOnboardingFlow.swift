import SwiftUI
import SwiftData

struct NewOnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitManager = HealthKitManager.shared
    @Query private var profiles: [UserProfile]

    @State private var currentStep = 0
    @State private var showingApp = false

    // Pace calculation state
    @State private var calculatedPaceResult: PaceResult?

    // Exercise status (from strength assessment)
    @State private var userExercisesRegularly = false

    // Plan selection state (step 8)
    @State private var selectedTemplate: TrainingPlanTemplate? = nil
    @State private var showPlanPreview = false
    @State private var showCustomBuilder = false
    @State private var showEventCreationFlow = false

    // ✅ NEW: Cardio step state (step 9)
    @State private var showCardioStep = false
    @State private var pendingDayAssignments: [DayAssigner.DayAssignment] = []

    private var userProfile: UserProfile? {
        profiles.first
    }

    // MARK: - Onboarding Flow
    //
    // ✅ UPDATED FLOW (Training Preferences removed, Cardio step added):
    //
    // Act 1: Who are you? (Steps 0-5)
    //   Step 0: Welcome + Name
    //   Step 1: Explainer Sequence (5 swipeable cards)
    //   Step 2: Goal Selection
    //   Step 3: Apple Health Connection
    //   Step 4: Quick Profile (Baseline Data)
    //   Step 5: Strength Assessment + Equipment (combined)
    //
    // Act 2: Here's where you stand. (Steps 6-7)
    //   Step 6: Pace Calculating
    //   Step 7: Pace Reveal
    //
    // Act 3: Let's build your plan. (Steps 8-10)
    //   Step 8: Plan Selection → Plan Preview → Cardio Step
    //   Step 9: Habit Selection
    //   → TodayView
    //

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            if showingApp {
                ContentView()
            } else {
                ZStack(alignment: .topLeading) {
                    Group {
                        switch currentStep {
                        case 0:
                            WelcomeView {
                                print("✅ Step 0 complete: Welcome")
                                currentStep = 1
                            }

                        case 1:
                            OnboardingExplainerView {
                                print("✅ Step 1 complete: Explainer")
                                currentStep = 2
                            }

                        case 2:
                            GoalSelectionView {
                                print("✅ Step 2 complete: Goals")
                                currentStep = 3
                            }

                        case 3:
                            AppleHealthConnectionScreen(
                                healthKitManager: healthKitManager,
                                onConnect: {
                                    print("✅ Step 3 complete: Apple Health connected")
                                    currentStep = 4
                                },
                                onSkip: {
                                    print("✅ Step 3 complete: Apple Health skipped")
                                    currentStep = 4
                                }
                            )

                        case 4:
                            BaselineDataView(healthKitManager: healthKitManager) {
                                print("✅ Step 4 complete: Baseline data")
                                currentStep = 5
                            }

                        case 5:
                            // ✅ Strength Assessment now includes Equipment (step 5 of 6 inside)
                            StrengthAssessmentScreen(
                                benchPressMax: Binding(
                                    get: {
                                        if let val = userProfile?.benchPressMax {
                                            return String(Int(val))
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        userProfile?.benchPressMax = Double(newValue)
                                    }
                                ),
                                squatMax: Binding(
                                    get: {
                                        if let val = userProfile?.squatMax {
                                            return String(Int(val))
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        userProfile?.squatMax = Double(newValue)
                                    }
                                ),
                                deadliftMax: Binding(
                                    get: {
                                        if let val = userProfile?.deadliftMax {
                                            return String(Int(val))
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        userProfile?.deadliftMax = Double(newValue)
                                    }
                                ),
                                pushupRange: Binding(
                                    get: {
                                        if let raw = userProfile?.pushupRange {
                                            return LongevityTierCalculation.PushupRange(rawValue: raw)
                                        }
                                        return nil
                                    },
                                    set: { userProfile?.pushupRange = $0?.rawValue }
                                ),
                                canStandFromSitting: Binding(
                                    get: { userProfile?.canStandFromSitting },
                                    set: { userProfile?.canStandFromSitting = $0 }
                                ),
                                deadHangRange: Binding(
                                    get: {
                                        if let raw = userProfile?.deadHangRange {
                                            return LongevityTierCalculation.DeadHangRange(rawValue: raw)
                                        }
                                        return nil
                                    },
                                    set: { userProfile?.deadHangRange = $0?.rawValue }
                                ),
                                userExercisesRegularly: $userExercisesRegularly,
                                trainingForEvent: .constant(false),
                                onContinue: {
                                    print("✅ Step 5 complete: Strength assessment + equipment")
                                    userProfile?.lastStrengthAssessmentDate = Date()
                                    try? modelContext.save()
                                    currentStep = 6
                                }
                            )

                        case 6:
                            PaceCalculatingScreen(
                                healthKitManager: healthKitManager,
                                onCalculationComplete: { result in
                                    print("✅ Step 6 complete: Pace = \(String(format: "%.2f", result.paceValue))")
                                    calculatedPaceResult = result
                                    currentStep = 7
                                }
                            )

                        case 7:
                            if let result = calculatedPaceResult {
                                PaceRevealScreen(
                                    result: result,
                                    userName: userProfile?.name ?? "there",
                                    onComplete: {
                                        // ✅ SKIP step 8 (old Training Preferences) → go straight to plan selection
                                        print("✅ Step 7 complete: Pace reveal -> plan selection")
                                        currentStep = 8
                                    }
                                )
                            } else {
                                VStack(spacing: 20) {
                                    Text("Unable to calculate Pace")
                                        .foregroundColor(.atlasText)
                                    Button("Continue Anyway") {
                                        currentStep = 8
                                    }
                                    .foregroundColor(.atlasPrimary)
                                }
                            }

                        // =============================================
                        // Step 8: Plan Selection → Preview → Cardio → Commit
                        // =============================================
                        case 8:
                            planSelectionStep

                        // =============================================
                        // Step 9: Habit Selection
                        // =============================================
                        case 9:
                            FreeInterventionSelectionScreen(
                                onContinue: { selectedInterventions in
                                    print("✅ Step 9 complete: Selected \(selectedInterventions.count) habits")
                                    completeOnboardingWithHabits(selectedInterventions)
                                }
                            )

                        default:
                            EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    
                    // BUG-001: Back button — visible on all steps except 0 (Welcome)
                    // Steps 6+ (Pace calculating/reveal) and 8+ (plan flow) are intentionally
                    // excluded from back nav since they're post-assessment and involve async work.
                    if currentStep > 0 && currentStep < 6 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.atlasTextMuted)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .sheet(isPresented: $showEventCreationFlow) {
            EventCreationFlow(onComplete: {
                print("✅ Step 8 complete: Event plan created")
                createTrainingHabitsFromActivePlan()
                currentStep = 9
            })
        }
    }

    // MARK: - Step 8: Plan Selection → Preview → Cardio

    @ViewBuilder
    private var planSelectionStep: some View {
        if showCustomBuilder {
            // Build Your Own flow
            CustomPlanBuilderView(
                onComplete: {
                    print("✅ Step 8 complete: Custom plan committed")
                    createTrainingHabitsFromActivePlan()
                    showCustomBuilder = false
                    currentStep = 9
                },
                onBack: {
                    showCustomBuilder = false
                    selectedTemplate = nil
                    showPlanPreview = false
                    showCardioStep = false
                }
            )
        } else if showCardioStep, let template = selectedTemplate {
            // ✅ NEW: Cardio step (after plan preview, before commit)
            let restDays = pendingDayAssignments
                .filter { $0.workoutType == "rest" }
                .map { $0.dayOfWeek }

            CardioOnboardingStepView(
                restDays: restDays,
                onContinue: { cardioDays in
                    print("✅ Step 8 complete: \(template.name) + \(cardioDays.count) cardio days committed")
                    commitPlanWithCardio(template: template, cardioDays: cardioDays)
                    createTrainingHabitsFromActivePlan()
                    resetPlanState()
                    currentStep = 9
                },
                onSkip: {
                    print("✅ Step 8 complete: \(template.name) committed (cardio skipped)")
                    commitPlanWithCardio(template: template, cardioDays: [])
                    createTrainingHabitsFromActivePlan()
                    resetPlanState()
                    currentStep = 9
                }
            )
        } else if showPlanPreview, let template = selectedTemplate {
            // Plan Preview — "Continue" now advances to cardio step instead of committing
            PlanPreviewView(
                template: template,
                onConfirm: {
                    // Capture day assignments before moving to cardio step
                    let previewAssignments = DayAssigner.assignDays(for: template)
                    pendingDayAssignments = previewAssignments
                    showCardioStep = true
                },
                onBack: {
                    showPlanPreview = false
                    selectedTemplate = nil
                    showCardioStep = false
                }
            )
        } else {
            // Plan Selection (3-4 recommendations)
            PlanSelectionView(
                onPlanSelected: { template in
                    selectedTemplate = template
                    showPlanPreview = true
                },
                onBuildYourOwn: {
                    showCustomBuilder = true
                },
                onEventTraining: {
                    print("✅ Step 8: Event training — opening EventCreationFlow")
                    showEventCreationFlow = true
                }
            )
        }
    }

    // MARK: - Commit Plan with Cardio

    /// Commits the strength plan + cardio days together via PlanCommitter.
    private func commitPlanWithCardio(
        template: TrainingPlanTemplate,
        cardioDays: [PlanCommitter.CardioDayConfig]
    ) {
        guard let profile = userProfile else { return }

        PlanCommitter.commitTemplatePlan(
            template: template,
            dayAssignments: pendingDayAssignments,
            cardioDays: cardioDays,
            userProfile: profile,
            modelContext: modelContext
        )
    }

    /// Resets all plan selection state variables.
    private func resetPlanState() {
        showPlanPreview = false
        showCardioStep = false
        selectedTemplate = nil
        pendingDayAssignments = []
    }

    // MARK: - Create Training Habits from Active Plan

    private func createTrainingHabitsFromActivePlan() {
        guard let profile = userProfile else { return }
        TrainingHabitManager.createTrainingHabits(
            profile: profile,
            modelContext: modelContext
        )
    }

    // MARK: - Complete Onboarding with Habits

    private func completeOnboardingWithHabits(_ selectedInterventions: [Intervention]) {
        guard let profile = userProfile else { return }

        print("🚀 Completing onboarding with \(selectedInterventions.count) habits...")

        profile.onboardingComplete = true
        profile.onboardingCompletedDate = Date()  // BUG-003: Start 7-day grace period
        profile.currentWeek = 1
        profile.planActivationDate = Date()
        profile.userExercisesRegularly = userExercisesRegularly

        // Save intervention selections to profile
        do {
            try InterventionRecommendationEngine.saveSelections(
                profile: profile,
                selectedInterventions: selectedInterventions,
                modelContext: modelContext
            )
        } catch {
            print("⚠️ Failed to save selections: \(error)")
        }

        // Create habits from selected interventions
        let dataController = DataController(modelContext: modelContext)
        for intervention in selectedInterventions {
            let habitTitle = intervention.customTitle ?? intervention.title
            let habitDetails: String
            if let duration = intervention.customDuration {
                habitDetails = "\(duration) minutes daily"
            } else {
                habitDetails = intervention.whyThisMatters
            }

            dataController.createHabit(
                title: habitTitle,
                details: habitDetails,
                pillar: mapCategoryToPillar(intervention.category),
                habitType: "non_negotiable",
                isTrainingHabit: false,
                trainingDayType: nil,
                isUnlocked: true,
                dayOfWeek: nil,
                howToGuide: intervention.howToGuide,
                researchCitation: intervention.researchCitation,
                interventionId: intervention.id
            )
        }

        // Save onboarding Pace score to database
        if let paceResult = calculatedPaceResult {
            let paceScore = BiologicalPaceScore(
                date: Date(),
                paceValue: paceResult.paceValue,
                compositePercentile: paceResult.compositePercentile,
                confidenceLevel: paceResult.confidenceLevel,
                componentsAvailable: paceResult.componentsAvailable
            )
            paceScore.populate(from: paceResult)
            modelContext.insert(paceScore)

            profile.latestPaceValue = paceResult.paceValue
            profile.latestPaceConfidence = paceResult.confidenceLevel

            print("✅ Saved onboarding Pace: \(paceResult.paceValue)")
        }

        // NOTE: Training plan is already committed in Step 8 (PlanCommitter).
        // No need to call TemplateTrainingPlanGenerator here.

        try? modelContext.save()

        print("✅ Onboarding complete — \(selectedInterventions.count) habits created")
        for h in selectedInterventions {
            let displayName = h.customTitle ?? h.title
            let durationNote = h.customDuration != nil ? " (\(h.customDuration!) min)" : ""
            print("   - \(displayName)\(durationNote) [\(h.category)]")
        }

        showingApp = true
    }

    private func mapCategoryToPillar(_ category: String) -> String {
        switch category.lowercased() {
        case "sleep": return "sleep"
        case "nutrition": return "nutrition"
        case "recovery": return "recovery"
        case "movement": return "movement"
        case "lifestyle": return "lifestyle"
        case "longevity fundamentals": return "longevity"
        default: return "lifestyle"
        }
    }
}  // end of struct


#Preview {
    NewOnboardingFlow()
}