import SwiftUI
import SwiftData

struct EventCreationFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    /// Optional callback fired after event plan is successfully generated and saved.
    /// Called on MainActor before dismiss(). Use this in onboarding to advance steps.
    var onComplete: (() -> Void)? = nil
    
    @State private var currentStep: EventCreationStep = .selectEvent
    @State private var selectedEventType: String = ""
    @State private var eventName: String = ""
    @State private var eventDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var assessment: UserCapabilityAssessment?
    @State private var timelineStatus: TimelineStatus?
    @State private var isGeneratingPlan = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var profile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch currentStep {
                case .selectEvent:
                    SelectEventTypeView(
                        selectedEventType: $selectedEventType,
                        onContinue: {
                            withAnimation {
                                currentStep = .eventDetails
                            }
                        }
                    )
                    
                case .eventDetails:
                    EventDetailsView(
                        eventType: selectedEventType,
                        eventName: $eventName,
                        eventDate: $eventDate,
                        onContinue: {
                            createAssessmentAndContinue()
                        },
                        onBack: {
                            withAnimation {
                                currentStep = .selectEvent
                            }
                        }
                    )
                     
                case .assessment:
                    if let assessment = assessment {
                        AssessmentQuestionsView(
                            assessment: Binding(
                                get: { assessment },
                                set: { self.assessment = $0 }
                            ),
                            eventType: selectedEventType,
                            onComplete: {
                                calculateTimeline()
                            },
                            onBack: {
                                withAnimation {
                                    currentStep = .eventDetails
                                }
                            }
                        )
                    }

                case .timeline:
                    if let status = timelineStatus {
                        TimelineReviewView(
                            eventType: selectedEventType,
                            eventName: eventName,
                            eventDate: eventDate,
                            timelineStatus: status,
                            onConfirm: {
                                // ⭐ CHANGED: Go to strength preferences instead of generating
                                withAnimation {
                                    currentStep = .strengthPreference
                                }
                            },
                            onAdjust: {
                                withAnimation {
                                    currentStep = .eventDetails
                                }
                            }
                        )
                    }
                
                // ⭐ NEW STEP: Strength Training Preferences
                case .strengthPreference:
                    if let assessment = assessment {
                        StrengthPreferenceView(
                            strengthDaysPerWeek: Binding(
                                get: { assessment.strengthDaysPerWeek ?? 2 },
                                set: { assessment.strengthDaysPerWeek = $0 }
                            ),
                            strengthGoal: Binding(
                                get: { assessment.strengthGoal },
                                set: { assessment.strengthGoal = $0 }
                            ),
                            equipmentAccess: Binding(
                                get: { assessment.equipmentAccess },
                                set: { assessment.equipmentAccess = $0 }
                            ),
                            onContinue: {
                                try? modelContext.save()
                                generateEventPlan()
                            },
                            onBack: {
                                withAnimation {
                                    currentStep = .timeline
                                }
                            }
                        )
                    }
                    
                case .generating:
                    GeneratingPlanView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Create Assessment
    private func createAssessmentAndContinue() {
        // Clean up any existing assessments for this user
        let assessmentDescriptor = FetchDescriptor<UserCapabilityAssessment>()
        if let existingAssessments = try? modelContext.fetch(assessmentDescriptor) {
            for oldAssessment in existingAssessments.filter({ $0.userProfile?.id == profile?.id }) {
                print("🗑️ Deleting old assessment: \(oldAssessment.eventType)")
                modelContext.delete(oldAssessment)
            }
        }
        
        let newAssessment = UserCapabilityAssessment(eventType: selectedEventType)
        newAssessment.userProfile = profile
        modelContext.insert(newAssessment)
        
        // ⭐ CRITICAL: Save immediately to avoid "future backing data" error
        do {
            try modelContext.save()
            print("✅ Assessment saved successfully")
        } catch {
            print("❌ Failed to save assessment: \(error)")
            errorMessage = "Failed to create assessment: \(error.localizedDescription)"
            showError = true
            return
        }
        
        self.assessment = newAssessment
        
        withAnimation {
            currentStep = .assessment
        }
    }
    
    // MARK: - Calculate Timeline
    private func calculateTimeline() {
        guard let assessment = assessment else { return }
        
        // Calculate weeks available
        let calendar = Calendar.current
        let weeksAvailable = calendar.dateComponents([.weekOfYear], from: Date(), to: eventDate).weekOfYear ?? 12
        
        // Get requirements from CapabilityAssessor
        let (minimum, recommended, warnings) = CapabilityAssessor.calculateMinimumWeeks(
            eventType: selectedEventType,
            assessment: assessment
        )
        
        // Update assessment
        assessment.minimumWeeksRequired = minimum
        assessment.recommendedWeeks = recommended
        
        // Get timeline status
        let (status, successRate, message) = CapabilityAssessor.getTimelineStatus(
            weeksAvailable: weeksAvailable,
            minimumRequired: minimum,
            recommended: recommended
        )
        
        self.timelineStatus = TimelineStatus(
            weeksAvailable: weeksAvailable,
            minimumRequired: minimum,
            recommended: recommended,
            status: status,
            successRate: successRate,
            message: message,
            warnings: warnings
        )
        
        try? modelContext.save()
        
        withAnimation {
            currentStep = .timeline
        }
    }
    
    // MARK: - Generate Event Plan
    private func generateEventPlan() {
        guard let profile = profile,
              let assessment = assessment else {
            return
        }
        
        isGeneratingPlan = true
        currentStep = .generating
        
        Task {
            do {
                let weeksAvailable = Calendar.current.dateComponents([.weekOfYear], from: Date(), to: eventDate).weekOfYear ?? 12
                
                // Use the template-based generation
                let (masterPlan, program) = try await EventPlanGenerator.generateEventPlanWithTemplates(
                    profile: profile,
                    modelContext: modelContext,
                    assessment: assessment,
                    eventType: selectedEventType,
                    eventName: eventName.isEmpty ? nil : eventName,
                    eventDate: eventDate,
                    weeksUntilEvent: weeksAvailable
                )
                
                // Update profile
                profile.isTrainingForEvent = true
                profile.trainingMode = "event"
                profile.eventType = selectedEventType
                profile.eventName = eventName.isEmpty ? nil : eventName
                profile.eventDate = eventDate
                
                try? modelContext.save()
                
                await MainActor.run {
                    onComplete?()
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate plan: \(error.localizedDescription)"
                    showError = true
                    isGeneratingPlan = false
                    currentStep = .strengthPreference
                }
            }
        }
    }
}

// MARK: - Event Creation Steps
enum EventCreationStep {
    case selectEvent
    case eventDetails
    case assessment
    case timeline
    case strengthPreference  // ⭐ NEW STEP
    case generating
}

// MARK: - Timeline Status
struct TimelineStatus {
    let weeksAvailable: Int
    let minimumRequired: Int
    let recommended: Int
    let status: String // "insufficient", "minimum", "tight", "comfortable", "optimal"
    let successRate: Int?
    let message: String
    let warnings: [String]
}

// MARK: - Select Event Type View
struct SelectEventTypeView: View {
    @Binding var selectedEventType: String
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            // Subtle orange gradient background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.atlasPrimary.opacity(0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        // Orange accent icon
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 40))
                            .foregroundColor(.atlasPrimary)
                            .padding(.bottom, 8)
                        
                        Text("Train for an Event")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Choose your goal race")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        // Running Events
                        EventTypeSection(title: "Running") {
                            EventTypeButton(
                                title: "5K",
                                subtitle: "3.1 miles",
                                icon: "figure.run",
                                isSelected: selectedEventType == "5k"
                            ) {
                                selectedEventType = "5k"
                            }
                            
                            EventTypeButton(
                                title: "10K",
                                subtitle: "6.2 miles",
                                icon: "figure.run",
                                isSelected: selectedEventType == "10k"
                            ) {
                                selectedEventType = "10k"
                            }
                            
                            EventTypeButton(
                                title: "Half Marathon",
                                subtitle: "13.1 miles",
                                icon: "figure.run",
                                isSelected: selectedEventType == "half_marathon"
                            ) {
                                selectedEventType = "half_marathon"
                            }
                            
                            EventTypeButton(
                                title: "Marathon",
                                subtitle: "26.2 miles",
                                icon: "figure.run",
                                isSelected: selectedEventType == "marathon"
                            ) {
                                selectedEventType = "marathon"
                            }
                        }
                        
                        // Hybrid Fitness
                        EventTypeSection(title: "Hybrid Fitness") {
                            EventTypeButton(
                                title: "HYROX",
                                subtitle: "8K run + 8 stations",
                                icon: "figure.strengthtraining.functional",
                                isSelected: selectedEventType == "hyrox"
                            ) {
                                selectedEventType = "hyrox"
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if !selectedEventType.isEmpty {
                        Button(action: onContinue) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.orange)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Event Type Section
struct EventTypeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            content
        }
    }
}

// MARK: - Event Type Button
struct EventTypeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .orange : .white)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Event Details View
struct EventDetailsView: View {
    let eventType: String
    @Binding var eventName: String
    @Binding var eventDate: Date
    let onContinue: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Event Details")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Tell us about your \(eventTypeDisplay)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event Name (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextField("e.g., Chicago Marathon", text: $eventName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Race Date")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        DatePicker("", selection: $eventDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Show weeks available
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.orange)
                        Text("\(weeksUntilEvent) weeks until race day")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Continue to Assessment")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.orange)
                            .cornerRadius(16)
                    }
                    
                    Button(action: onBack) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .padding(.bottom, 40)
        }
    }
    
    private var eventTypeDisplay: String {
        switch eventType {
        case "5k": return "5K"
        case "10k": return "10K"
        case "half_marathon": return "Half Marathon"
        case "marathon": return "Marathon"
        case "hyrox": return "HYROX"
        default: return "event"
        }
    }
    
    private var weeksUntilEvent: Int {
        Calendar.current.dateComponents([.weekOfYear], from: Date(), to: eventDate).weekOfYear ?? 0
    }
}

// MARK: - Generating Plan View
struct GeneratingPlanView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
            
            Text("Creating Your Training Plan")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("This will take a few seconds...")
                .font(.body)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Assessment Questions View
struct AssessmentQuestionsView: View {
    @Binding var assessment: UserCapabilityAssessment
    let eventType: String
    let onComplete: () -> Void
    let onBack: () -> Void
    
    @State private var currentQuestion = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 4)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Question header
                    VStack(spacing: 8) {
                        Text("Assessment")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Question \(currentQuestion + 1) of \(totalQuestions)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // Current question
                    currentQuestionView
                        .padding(.horizontal)
                    
                    // Navigation buttons
                    VStack(spacing: 12) {
                        if canContinue {
                            Button(action: nextQuestion) {
                                Text(isLastQuestion ? "Complete Assessment" : "Continue")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.orange)
                                    .cornerRadius(16)
                            }
                        }
                        
                        if currentQuestion > 0 {
                            Button(action: previousQuestion) {
                                Text("Back")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        } else {
                            Button(action: onBack) {
                                Text("Back")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    @ViewBuilder
    private var currentQuestionView: some View {
        switch currentQuestion {
        case 0:
            RunningCapabilityQuestion(selection: Binding(
                get: { assessment.runningCapability },
                set: { assessment.runningCapability = $0 }
            ))
        case 1:
            RecentRacesQuestion(
                eventType: eventType,
                selections: Binding(
                    get: { Set(assessment.recentRaces) },
                    set: { assessment.recentRaces = Array($0) }
                )
            )
        case 2:
            StrengthFrequencyQuestion(selection: Binding(
                get: { assessment.strengthTrainingFrequency },
                set: { assessment.strengthTrainingFrequency = $0 }
            ))
        case 3:
            TimeAvailableQuestion(selection: Binding(
                get: { assessment.weeklyTimeAvailable },
                set: { assessment.weeklyTimeAvailable = $0 }
            ))
        default:
            // Event-specific questions
            eventSpecificQuestion
        }
    }
    
    @ViewBuilder
    private var eventSpecificQuestion: some View {
        switch eventType {
        case "hyrox":
            if currentQuestion == 4 {
                FunctionalFitnessQuestion(selections: Binding(
                    get: { Set(assessment.functionalFitnessBackground ?? []) },
                    set: { assessment.functionalFitnessBackground = Array($0) }
                ))
            } else if currentQuestion == 5 {
                HyroxEquipmentQuestion(
                    selections: Binding(
                        get: { Set(assessment.availableEquipment ?? []) },
                        set: { assessment.availableEquipment = Array($0) }
                    ),
                    trainsAtHyroxGym: Binding(
                        get: { assessment.trainsAtHyroxGym ?? false },
                        set: { assessment.trainsAtHyroxGym = $0 }
                    )
                )
            } else {
                EmptyView()
            }
        default:
            EmptyView()
        }
    }
    
    private var totalQuestions: Int {
        switch eventType {
        case "hyrox":
            return 6 // 4 universal + 2 HYROX-specific
        default:
            return 4 // Universal only
        }
    }
    
    private var progress: CGFloat {
        CGFloat(currentQuestion + 1) / CGFloat(totalQuestions)
    }
    
    private var canContinue: Bool {
        switch currentQuestion {
        case 0: return !assessment.runningCapability.isEmpty
        case 1: return true // Optional question
        case 2: return !assessment.strengthTrainingFrequency.isEmpty
        case 3: return !assessment.weeklyTimeAvailable.isEmpty
        case 4:
            if eventType == "hyrox" {
                return true // Optional
            }
            return true
        case 5:
            if eventType == "hyrox" {
                return true // Optional
            }
            return true
        default:
            return true
        }
    }
    
    private var isLastQuestion: Bool {
        currentQuestion == totalQuestions - 1
    }
    
    private func nextQuestion() {
        if isLastQuestion {
            onComplete()
        } else {
            withAnimation {
                currentQuestion += 1
            }
        }
    }
    
    private func previousQuestion() {
        withAnimation {
            currentQuestion = max(0, currentQuestion - 1)
        }
    }
}

// MARK: - Question 1: Running Capability
struct RunningCapabilityQuestion: View {
    @Binding var selection: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Running Ability")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Can you currently run continuously without stopping?")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                EventOptionButton(
                    title: "No, I can't run more than 1-2 minutes",
                    isSelected: selection == "cannot_run_10min"
                ) {
                    selection = "cannot_run_10min"
                }
                
                EventOptionButton(
                    title: "Yes, 10-15 minutes (1-1.5 miles)",
                    isSelected: selection == "10_15min"
                ) {
                    selection = "10_15min"
                }
                
                EventOptionButton(
                    title: "Yes, 20-30 minutes (2-3 miles)",
                    isSelected: selection == "20_30min"
                ) {
                    selection = "20_30min"
                }
                
                EventOptionButton(
                    title: "Yes, 30-45 minutes (3-5 miles)",
                    isSelected: selection == "30_45min"
                ) {
                    selection = "30_45min"
                }
                
                EventOptionButton(
                    title: "Yes, 45-60 minutes (5-8 miles)",
                    isSelected: selection == "45_60min"
                ) {
                    selection = "45_60min"
                }
                
                EventOptionButton(
                    title: "Yes, 60+ minutes (8+ miles)",
                    isSelected: selection == "60plus"
                ) {
                    selection = "60plus"
                }
            }
        }
    }
}

// MARK: - Question 2: Recent Races
struct RecentRacesQuestion: View {
    let eventType: String
    @Binding var selections: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Race Experience")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Have you completed any of these distances recently (past 6 months)?")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                EventMultiSelectButton(
                    title: "5K (3.1 miles)",
                    isSelected: selections.contains("5k")
                ) {
                    toggleSelection("5k")
                }
                
                EventMultiSelectButton(
                    title: "10K (6.2 miles)",
                    isSelected: selections.contains("10k")
                ) {
                    toggleSelection("10k")
                }
                
                EventMultiSelectButton(
                    title: "Half Marathon (13.1 miles)",
                    isSelected: selections.contains("half_marathon")
                ) {
                    toggleSelection("half_marathon")
                }
                
                EventMultiSelectButton(
                    title: "Marathon (26.2 miles)",
                    isSelected: selections.contains("marathon")
                ) {
                    toggleSelection("marathon")
                }
                
                EventMultiSelectButton(
                    title: "None of the above",
                    isSelected: selections.isEmpty
                ) {
                    selections.removeAll()
                }
            }
        }
    }
    
    private func toggleSelection(_ race: String) {
        if selections.contains(race) {
            selections.remove(race)
        } else {
            selections.insert(race)
        }
    }
}

// MARK: - Question 3: Strength Training Frequency
struct StrengthFrequencyQuestion: View {
    @Binding var selection: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Strength Training")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("How often do you currently strength train?")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                EventOptionButton(
                    title: "Never or rarely (0-1x per month)",
                    isSelected: selection == "never"
                ) {
                    selection = "never"
                }
                
                EventOptionButton(
                    title: "Occasionally (1-2x per month)",
                    isSelected: selection == "occasionally"
                ) {
                    selection = "occasionally"
                }
                
                EventOptionButton(
                    title: "Regularly (1-2x per week)",
                    isSelected: selection == "regularly"
                ) {
                    selection = "regularly"
                }
                
                EventOptionButton(
                    title: "Frequently (3-4x per week)",
                    isSelected: selection == "frequently"
                ) {
                    selection = "frequently"
                }
                
                EventOptionButton(
                    title: "Very frequently (5+ per week)",
                    isSelected: selection == "very_frequently"
                ) {
                    selection = "very_frequently"
                }
            }
        }
    }
}

// MARK: - Question 4: Weekly Time Available
struct TimeAvailableQuestion: View {
    @Binding var selection: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Commitment")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("How many hours per week can you REALISTICALLY commit to training?")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                EventOptionButton(
                    title: "3-5 hours (limited time)",
                    isSelected: selection == "3_5hrs"
                ) {
                    selection = "3_5hrs"
                }
                
                EventOptionButton(
                    title: "6-8 hours (moderate commitment)",
                    isSelected: selection == "6_8hrs"
                ) {
                    selection = "6_8hrs"
                }
                
                EventOptionButton(
                    title: "9-12 hours (serious commitment)",
                    isSelected: selection == "9_12hrs"
                ) {
                    selection = "9_12hrs"
                }
                
                EventOptionButton(
                    title: "13-16 hours (high commitment)",
                    isSelected: selection == "13_16hrs"
                ) {
                    selection = "13_16hrs"
                }
                
                EventOptionButton(
                    title: "17+ hours (all-in)",
                    isSelected: selection == "17plus"
                ) {
                    selection = "17plus"
                }
            }
        }
    }
}

// MARK: - Functional Fitness Question (HYROX)
struct FunctionalFitnessQuestion: View {
    @Binding var selections: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Functional Fitness Background")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Do you have experience with any of these?")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                EventMultiSelectButton(
                    title: "CrossFit or functional fitness training",
                    isSelected: selections.contains("crossfit")
                ) {
                    toggleSelection("crossfit")
                }
                
                EventMultiSelectButton(
                    title: "Obstacle course races (Spartan, Tough Mudder)",
                    isSelected: selections.contains("ocr")
                ) {
                    toggleSelection("ocr")
                }
                
                EventMultiSelectButton(
                    title: "Bootcamp-style classes",
                    isSelected: selections.contains("bootcamp")
                ) {
                    toggleSelection("bootcamp")
                }
                
                EventMultiSelectButton(
                    title: "HIIT or conditioning workouts",
                    isSelected: selections.contains("hiit")
                ) {
                    toggleSelection("hiit")
                }
                
                EventMultiSelectButton(
                    title: "None of the above",
                    isSelected: selections.isEmpty
                ) {
                    selections.removeAll()
                }
            }
        }
    }
    
    private func toggleSelection(_ item: String) {
        if selections.contains(item) {
            selections.remove(item)
        } else {
            selections.insert(item)
        }
    }
}

// MARK: - HYROX Equipment Question
struct HyroxEquipmentQuestion: View {
    @Binding var selections: Set<String>
    @Binding var trainsAtHyroxGym: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HYROX Equipment Access")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("What HYROX equipment do you have access to?")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                EventMultiSelectButton(
                    title: "SkiErg (Concept2)",
                    isSelected: selections.contains("skierg")
                ) {
                    toggleSelection("skierg")
                }
                
                EventMultiSelectButton(
                    title: "Prowler Sled or Push Sled",
                    isSelected: selections.contains("sled_push")
                ) {
                    toggleSelection("sled_push")
                }
                
                EventMultiSelectButton(
                    title: "Sled with Rope (for pulling)",
                    isSelected: selections.contains("sled_pull")
                ) {
                    toggleSelection("sled_pull")
                }
                
                EventMultiSelectButton(
                    title: "Rowing Machine (Concept2)",
                    isSelected: selections.contains("rower")
                ) {
                    toggleSelection("rower")
                }
                
                EventMultiSelectButton(
                    title: "Heavy Kettlebells/Dumbbells (50+ lbs)",
                    isSelected: selections.contains("heavy_weights")
                ) {
                    toggleSelection("heavy_weights")
                }
                
                EventMultiSelectButton(
                    title: "Sandbag (20kg/44lbs)",
                    isSelected: selections.contains("sandbag")
                ) {
                    toggleSelection("sandbag")
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.vertical, 8)
                
                Toggle(isOn: $trainsAtHyroxGym) {
                    Text("I train at a HYROX-certified gym")
                        .foregroundColor(.white)
                }
                .tint(.orange)
                .padding()
                .background(trainsAtHyroxGym ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func toggleSelection(_ item: String) {
        if selections.contains(item) {
            selections.remove(item)
        } else {
            selections.insert(item)
        }
    }
}

// MARK: - Timeline Review View
struct TimelineReviewView: View {
    let eventType: String
    let eventName: String
    let eventDate: Date
    let timelineStatus: TimelineStatus
    let onConfirm: () -> Void
    let onAdjust: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Training Timeline")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Based on your assessment")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Timeline status card
                timelineStatusCard
                    .padding(.horizontal)
                
                // Recommendations
                recommendationsCard
                    .padding(.horizontal)
                
                // Warnings (if any)
                if !timelineStatus.warnings.isEmpty {
                    warningsCard
                        .padding(.horizontal)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if timelineStatus.status != "insufficient" {
                        Button(action: onConfirm) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.orange)
                                .cornerRadius(16)
                        }
                    }
                    
                    Button(action: onAdjust) {
                        Text(timelineStatus.status == "insufficient" ? "Choose Different Date" : "Adjust Timeline")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .padding(.bottom, 40)
        }
    }
    
    private var timelineStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                statusIcon
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(timelineStatus.message)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Timeline details
            VStack(spacing: 12) {
                TimelineRow(
                    label: "Weeks Available",
                    value: "\(timelineStatus.weeksAvailable) weeks"
                )
                
                TimelineRow(
                    label: "Minimum Required",
                    value: "\(timelineStatus.minimumRequired) weeks"
                )
                
                TimelineRow(
                    label: "Recommended",
                    value: "\(timelineStatus.recommended) weeks"
                )
                
                if let successRate = timelineStatus.successRate {
                    TimelineRow(
                        label: "Success Rate",
                        value: "\(successRate)%",
                        valueColor: successRateColor(successRate)
                    )
                }
            }
        }
        .padding()
        .background(statusBackgroundColor)
        .cornerRadius(16)
    }
    
    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What This Means")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                switch timelineStatus.status {
                case "insufficient":
                    RecommendationPoint(
                        icon: "xmark.circle.fill",
                        text: "Not enough time to train safely for this event",
                        color: .red
                    )
                    RecommendationPoint(
                        icon: "calendar",
                        text: "Choose a race date at least \(timelineStatus.minimumRequired) weeks away",
                        color: .orange
                    )
                    RecommendationPoint(
                        icon: "figure.run",
                        text: "Or consider a shorter distance that fits your timeline",
                        color: .orange
                    )
                    
                case "minimum":
                    RecommendationPoint(
                        icon: "exclamationmark.triangle.fill",
                        text: "Zero room for setbacks (illness, injury, life events)",
                        color: .orange
                    )
                    RecommendationPoint(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Higher injury risk due to compressed timeline",
                        color: .orange
                    )
                    RecommendationPoint(
                        icon: "checkmark.circle.fill",
                        text: "Requires perfect adherence (90%+ workouts)",
                        color: .orange
                    )
                    
                case "tight":
                    RecommendationPoint(
                        icon: "checkmark.circle",
                        text: "Achievable with strong commitment",
                        color: .orange
                    )
                    RecommendationPoint(
                        icon: "calendar",
                        text: "Limited buffer for missed workouts",
                        color: .gray
                    )
                    
                case "comfortable":
                    RecommendationPoint(
                        icon: "checkmark.circle.fill",
                        text: "Good timeline with buffer for life happening",
                        color: .green
                    )
                    RecommendationPoint(
                        icon: "figure.run",
                        text: "Room for gradual progression and adaptation",
                        color: .green
                    )
                    
                case "optimal":
                    RecommendationPoint(
                        icon: "star.fill",
                        text: "Excellent timeline for proper preparation",
                        color: .green
                    )
                    RecommendationPoint(
                        icon: "trophy.fill",
                        text: "Time to develop speed and performance",
                        color: .green
                    )
                    
                default:
                    EmptyView()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var warningsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Important Considerations")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(timelineStatus.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text(warning)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(16)
    }
    
    private var statusIcon: Image {
        switch timelineStatus.status {
        case "insufficient":
            return Image(systemName: "xmark.circle.fill")
        case "minimum":
            return Image(systemName: "exclamationmark.triangle.fill")
        case "tight":
            return Image(systemName: "checkmark.circle")
        case "comfortable":
            return Image(systemName: "checkmark.circle.fill")
        case "optimal":
            return Image(systemName: "star.circle.fill")
        default:
            return Image(systemName: "circle")
        }
    }
    
    private var statusTitle: String {
        switch timelineStatus.status {
        case "insufficient":
            return "Not Enough Time"
        case "minimum":
            return "Minimum Timeline"
        case "tight":
            return "Tight But Doable"
        case "comfortable":
            return "Good Timeline"
        case "optimal":
            return "Excellent Timeline"
        default:
            return "Timeline Review"
        }
    }
    
    private var statusBackgroundColor: Color {
        switch timelineStatus.status {
        case "insufficient":
            return Color.red.opacity(0.15)
        case "minimum":
            return Color.orange.opacity(0.15)
        case "tight":
            return Color.orange.opacity(0.1)
        case "comfortable", "optimal":
            return Color.green.opacity(0.15)
        default:
            return Color.gray.opacity(0.1)
        }
    }
    
    private func successRateColor(_ rate: Int) -> Color {
        if rate >= 85 {
            return .green
        } else if rate >= 70 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimelineRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

struct RecommendationPoint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Reusable UI Components
struct EventOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : .gray)
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct EventMultiSelectButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .orange : .gray)
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
    }
}