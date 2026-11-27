import SwiftUI
import SwiftData

struct HabitTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { $0.isActive == true }) private var habits: [Habit]
    @Query private var profiles: [UserProfile]
    
    @State private var showingAddCustomHabit = false
    
    // Accept selected date from TodayView
    var selectedDate: Date = Date()
    
    // Binding for collapsible focus context
    @Binding var showingFocusContext: Bool
    
    // Filter habits by type AND date
    private var nonNegotiableHabits: [Habit] {
        habits.filter { habit in
            habit.habitType == "non_negotiable" && habit.appliesTo(date: selectedDate)
        }
    }
    
    private var customHabits: [Habit] {
        habits.filter { habit in
            habit.habitType == "custom" && habit.isActive
        }
    }
    
    // Check if selected date is today
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    // Custom habit limit
    private var canAddCustomHabit: Bool {
        customHabits.count < 5
    }
    
    // MARK: - Smart Completion Counter Text
    private var completionCounterText: AttributedString {
        let hour = Calendar.current.component(.hour, from: Date())
        let completed = completedNonNegotiableCount
        let total = nonNegotiableHabits.count
        
        var text: AttributedString
        
        // Before 10am: Show "X for today" unless user has started
        if isToday && hour < 10 && completed == 0 {
            text = AttributedString("\(total) for today")
        } else {
            // After 10am or if user has started: Show "X of Y complete"
            text = AttributedString("\(completed) of \(total) complete")
            
            // Make numbers bold and primary color
            if let completedRange = text.range(of: "\(completed)") {
                text[completedRange].foregroundColor = .atlasPrimary
                text[completedRange].font = .system(size: 15, weight: .bold)
            }
            if let totalRange = text.range(of: "\(total)") {
                text[totalRange].foregroundColor = .atlasPrimary
                text[totalRange].font = .system(size: 15, weight: .bold)
            }
        }
        
        return text
    }
    
    // MARK: - "Why These Three?" Context
    private var whyTheseThreeContext: String? {
        guard let profile = profiles.first else { return nil }
        
        if let weekStart = profile.currentWeekStartDate {
            let calendar = Calendar.current
            let weekNumber = calendar.dateComponents([.weekOfYear], from: weekStart, to: Date()).weekOfYear ?? 0
            
            if weekNumber < 2 {
                return "Focus: Sleep Foundation • Building your baseline"
            } else if weekNumber < 4 {
                return "Focus: Building consistency • 80%+ adherence unlocks next tier"
            } else {
                return "Focus: Maintaining foundation • Ready to add strength soon"
            }
        }
        
        return "Focus: Building your foundation • Small actions, big impact"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with Info Button
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("YOUR NON-NEGOTIABLES")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.atlasAccent)
                        .tracking(2)
                    
                    Spacer()
                    
                    // Info button for context (only show on today)
                    if isToday && whyTheseThreeContext != nil {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showingFocusContext.toggle()
                            }
                        }) {
                            Image(systemName: showingFocusContext ? "info.circle.fill" : "info.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.atlasPrimary.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if !nonNegotiableHabits.isEmpty {
                    Text(completionCounterText)
                        .font(.system(size: 15))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            if nonNegotiableHabits.isEmpty {
                emptyStateView
            } else {
                // MARK: - Progress Bar (ENHANCED)
                VStack(spacing: 12) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)
                            
                            // Progress fill with gradient
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.atlasPrimary,
                                            Color.atlasPrimary.opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progressPercentage, height: 6)
                                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progressPercentage)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, showingFocusContext ? 12 : 20)
                
                // MARK: - Collapsible "Why These Three?" Context
                if showingFocusContext, let context = whyTheseThreeContext, isToday {
                    HStack(spacing: 10) {
                        Image(systemName: "target")
                            .font(.system(size: 14))
                            .foregroundColor(.atlasPrimary)
                        
                        Text(context)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.atlasPrimary.opacity(0.9))
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.atlasPrimary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                // MARK: - Non-Negotiable Habits List (TIGHT 16PT SPACING)
                VStack(spacing: 16) {
                    ForEach(nonNegotiableHabits) { habit in
                        PremiumHabitCard(habit: habit, selectedDate: selectedDate)
                    }
                }
                .padding(.horizontal, 20)
                
                // MARK: - Custom Habits Section
                customHabitsSection
                    .padding(.top, 40)
            }
            
            Spacer()
                .frame(height: 40)
        }
        .sheet(isPresented: $showingAddCustomHabit) {
            AddCustomHabitView()
        }
    }
    
    // MARK: - Custom Habits Section
    private var customHabitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PERSONAL HABITS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.atlasAccent.opacity(0.7))
                    .tracking(2)
                
                Spacer()
                
                if canAddCustomHabit && isToday {
                    Button(action: { showingAddCustomHabit = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.atlasPrimary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if customHabits.isEmpty {
                Button(action: { showingAddCustomHabit = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.atlasPrimary.opacity(0.6))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Track your own habits")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.atlasTextMuted)
                            
                            Text("Meditation, journaling, reading, etc.")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                .opacity(isToday ? 1.0 : 0.5)
                .disabled(!isToday)
            } else {
                VStack(spacing: 16) {
                    ForEach(customHabits) { habit in
                        CustomHabitCard(habit: habit, selectedDate: selectedDate)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var completedNonNegotiableCount: Int {
        let dataController = DataController(modelContext: modelContext)
        return nonNegotiableHabits.filter { dataController.isHabitComplete(habit: $0, on: selectedDate) }.count
    }
    
    private var progressPercentage: Double {
        guard !nonNegotiableHabits.isEmpty else { return 0 }
        return Double(completedNonNegotiableCount) / Double(nonNegotiableHabits.count)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.atlasTextMuted)
            
            Text("No habits for this day")
                .font(.system(size: 17))
                .foregroundColor(.atlasTextMuted)
            
            Text("Complete onboarding to unlock your personalized protocol")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
}

// MARK: - Custom Habit Card (MATCHING BEAUTIFUL DESIGN)
struct CustomHabitCard: View {
    let habit: Habit
    var selectedDate: Date = Date()
    
    @Environment(\.modelContext) private var modelContext
    @State private var isCompleted = false
    @State private var showingDeleteConfirm = false
    @State private var breathingOpacity: Double = 1.0
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    private var streak: Int {
        let dataController = DataController(modelContext: modelContext)
        return dataController.getHabitStreak(habit: habit)
    }
    
    var body: some View {
        Button(action: toggleCompletion) {
            HStack(spacing: 16) {
                // SMALL CHECKMARK CIRCLE (40pt)
                ZStack {
                    if !isCompleted && isToday {
                        Circle()
                            .fill(Color.atlasPrimary.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .blur(radius: 8)
                            .opacity(breathingOpacity * 0.4)
                    }
                    
                    Circle()
                        .strokeBorder(Color.atlasPrimary.opacity(0.5), lineWidth: 2)
                        .background(
                            Circle()
                                .fill(isCompleted ? Color.atlasPrimary.opacity(0.3) : Color.atlasPrimary.opacity(0.1))
                        )
                        .frame(width: 40, height: 40)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.atlasPrimary)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasPrimary.opacity(0.6))
                    }
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    // ALWAYS allocate space for streak to maintain height
                    HStack(spacing: 4) {
                        if isToday && streak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.atlasAccent)
                            Text("\(streak) day streak")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.atlasAccent)
                        } else {
                            Text(" ")
                                .font(.system(size: 12))
                                .opacity(0)
                        }
                    }
                    .frame(height: 16) // Fixed height for streak
                }
                
                Spacer()
                
                if isToday {
                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.atlasTextMuted.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Completion indicator (ALWAYS same size)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isCompleted ? .atlasPrimary.opacity(0.5) : .clear)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 72) // FIXED HEIGHT for custom habits (no details line)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isCompleted ? 0.02 : 0.05))
            )
            .overlay(
                // Glowing left edge ALWAYS BRIGHT - the anchor
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.atlasPrimary.opacity(0.8), location: 0.0),
                                .init(color: Color.atlasPrimary.opacity(0.6), location: 0.05),
                                .init(color: Color.clear, location: 0.2),
                                .init(color: Color.clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
            )
            .overlay(
                // Subtle border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.atlasTextMuted.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(isCompleted ? 0.15 : 0.3),
                radius: isCompleted ? 6 : 8,
                x: 0,
                y: isCompleted ? 2 : 3
            )
            .opacity(isCompleted ? 0.5 : (isToday ? breathingOpacity : 0.7))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isToday)
        .onAppear {
            checkCompletionStatus()
            if !isCompleted && isToday {
                startBreathingAnimation()
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                stopBreathingAnimation()
            } else if isToday {
                startBreathingAnimation()
            }
        }
        .alert("Remove Habit?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                deleteHabit()
            }
        } message: {
            Text("This will remove \"\(habit.title)\" from your personal habits.")
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathingOpacity = 0.95
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            breathingOpacity = 1.0
        }
    }
    
    private func checkCompletionStatus() {
        let dataController = DataController(modelContext: modelContext)
        isCompleted = dataController.isHabitComplete(habit: habit, on: selectedDate)
    }
    
    private func toggleCompletion() {
        guard isToday else { return }
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let dataController = DataController(modelContext: modelContext)
        dataController.toggleHabitCompletion(habit: habit, date: selectedDate)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isCompleted.toggle()
        }
        
        NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
    }
    
    private func deleteHabit() {
        habit.isActive = false
        try? modelContext.save()
    }
}

// MARK: - Add Custom Habit View
struct AddCustomHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    @State private var habitTitle = ""
    @FocusState private var isFocused: Bool
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    let suggestions = [
        "Meditate",
        "Journal",
        "Read",
        "Cold shower",
        "Stretch",
        "Gratitude practice",
        "No phone before bed",
        "Walk outside"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isFocused = false
                    }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Habit Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.atlasText)
                            
                            TextField("What do you want to track?", text: $habitTitle)
                                .font(.system(size: 16))
                                .foregroundColor(.atlasText)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .focused($isFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    isFocused = false
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUGGESTIONS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.atlasTextMuted)
                                .tracking(1.5)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        habitTitle = suggestion
                                        isFocused = false
                                    }) {
                                        Text(suggestion)
                                            .font(.system(size: 14))
                                            .foregroundColor(habitTitle == suggestion ? .atlasBackground : .atlasText)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(habitTitle == suggestion ? Color.atlasPrimary : Color.white.opacity(0.08))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        Spacer()
                            .frame(height: 20)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.atlasTextMuted.opacity(0.6))
                            
                            Text("Personal habits are for your own tracking. They won't affect your streak or adherence scores.")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted.opacity(0.6))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                        
                        Button(action: {
                            isFocused = false
                            addHabit()
                        }) {
                            Text("Add Habit")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.atlasBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(habitTitle.isEmpty ? Color.atlasTextMuted.opacity(0.3) : Color.atlasPrimary)
                                .cornerRadius(12)
                        }
                        .disabled(habitTitle.isEmpty)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Add Personal Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
    
    private func addHabit() {
        let trimmedTitle = habitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let newHabit = Habit(
            title: trimmedTitle,
            details: "",
            pillar: "Personal",
            habitType: "custom",
            isTrainingHabit: false,
            isUnlocked: true
        )
        newHabit.userProfile = userProfile
        
        modelContext.insert(newHabit)
        try? modelContext.save()
        
        dismiss()
    }
}

// MARK: - PREMIUM HABIT CARD (GLOWING LEFT EDGE)
struct PremiumHabitCard: View {
    let habit: Habit
    var selectedDate: Date = Date()
    
    @Environment(\.modelContext) private var modelContext
    @State private var isCompleted = false
    @State private var showingCardioLog = false
    @State private var showingWorkoutLog = false
    @State private var isAnimating = false
    @State private var breathingOpacity: Double = 1.0
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 16) {
                // SMALL CHECKMARK CIRCLE (40pt - consistent size)
                ZStack {
                    // Subtle outer glow for incomplete
                    if !isCompleted && isToday {
                        Circle()
                            .fill(Color.atlasPrimary.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .blur(radius: 8)
                            .opacity(breathingOpacity * 0.4)
                    }
                    
                    // Main circle
                    Circle()
                        .strokeBorder(Color.atlasPrimary.opacity(0.5), lineWidth: 2)
                        .background(
                            Circle()
                                .fill(isCompleted ? Color.atlasPrimary.opacity(0.3) : Color.atlasPrimary.opacity(0.1))
                        )
                        .frame(width: 40, height: 40)
                    
                    // Icon or checkmark
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.atlasPrimary)
                    } else {
                        Image(systemName: iconForHabit)
                            .font(.system(size: 16))
                            .foregroundColor(.atlasPrimary.opacity(0.6))
                    }
                }
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                
                // Text Content with BOLD NUMBERS
                VStack(alignment: .leading, spacing: 6) {
                    emphasizedTitle
                    
                    // Details line (ALWAYS show to maintain height)
                    Text(habit.details.isEmpty ? " " : habit.details)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(1)
                        .opacity(habit.details.isEmpty ? 0 : 1)
                    
                    // Streak (ALWAYS allocate space to maintain height)
                    HStack(spacing: 4) {
                        if isToday && streak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.atlasAccent)
                            Text("\(streak) day streak")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.atlasAccent)
                        } else {
                            Text(" ")
                                .font(.system(size: 12))
                                .opacity(0)
                        }
                    }
                    .frame(height: 16) // Fixed height for streak
                }
                
                Spacer()
                
                // Completion indicator on right (subtle, ALWAYS same size)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isCompleted ? .atlasPrimary.opacity(0.5) : .clear)
                    .frame(width: 20, height: 20) // Fixed size
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 88) // FIXED HEIGHT - never changes
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isCompleted ? 0.02 : 0.05))
            )
            .overlay(
                // THE KEY: Glowing left edge ALWAYS BRIGHT - this is the anchor
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.atlasPrimary.opacity(0.8), location: 0.0),
                                .init(color: Color.atlasPrimary.opacity(0.6), location: 0.05),
                                .init(color: Color.clear, location: 0.2),
                                .init(color: Color.clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
            )
            .overlay(
                // Subtle border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.atlasTextMuted.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(isCompleted ? 0.15 : 0.3),
                radius: isCompleted ? 6 : 8,
                x: 0,
                y: isCompleted ? 2 : 3
            )
            .opacity(isCompleted ? 0.5 : (isToday ? breathingOpacity : 0.7))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isToday)
        .onAppear {
            checkCompletionStatus()
            if !isCompleted && isToday {
                startBreathingAnimation()
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                stopBreathingAnimation()
            } else if isToday {
                startBreathingAnimation()
            }
        }
        .sheet(isPresented: $showingCardioLog) {
            ManualCardioLogView(
                habit: habit,
                onComplete: {
                    checkCompletionStatus()
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                }
            )
        }
        .sheet(isPresented: $showingWorkoutLog) {
            WorkoutLogView(
                habit: habit,
                onComplete: {
                    checkCompletionStatus()
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                }
            )
        }
    }
    
    // MARK: - Emphasized Title with Bold Numbers/Times
    private var emphasizedTitle: some View {
        let components = parseHabitTitle(habit.title)
        return HStack(spacing: 0) {
            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                Text(component.text)
                    .font(.system(size: 17, weight: component.emphasized ? .bold : .medium))
                    .foregroundColor(component.emphasized ? .white : .atlasText)
            }
        }
    }
    
    private func parseHabitTitle(_ title: String) -> [(text: String, emphasized: Bool)] {
        var result: [(text: String, emphasized: Bool)] = []
        
        let words = title.split(separator: " ")
        for word in words {
            let wordStr = String(word)
            
            let shouldEmphasize = wordStr.contains(":") ||
                                  wordStr.last?.isLetter == false && wordStr.first?.isNumber == true ||
                                  (wordStr.first?.isNumber == true && wordStr.count <= 3)
            
            if result.isEmpty {
                result.append((text: wordStr, emphasized: shouldEmphasize))
            } else {
                result.append((text: " " + wordStr, emphasized: shouldEmphasize))
            }
        }
        
        return result
    }
    
    // MARK: - Subtle Breathing Animation
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathingOpacity = 0.95
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            breathingOpacity = 1.0
        }
    }
    
    // MARK: - Simple Completion Animation (NO PARTICLES)
    private func triggerCompletionAnimation() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Just a simple scale bounce
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private var iconForHabit: String {
        if habit.isTrainingHabit {
            switch habit.trainingDayType {
            case "cardio": return "figure.run"
            case "strength": return "figure.strengthtraining.traditional"
            case "rest": return "moon.fill"
            default: return "circle"
            }
        }
        return "circle"
    }
    
    private var streak: Int {
        let dataController = DataController(modelContext: modelContext)
        return dataController.getHabitStreak(habit: habit)
    }
    
    private func checkCompletionStatus() {
        let dataController = DataController(modelContext: modelContext)
        isCompleted = dataController.isHabitComplete(habit: habit, on: selectedDate)
    }
    
    private func handleTap() {
        guard isToday else { return }
        
        if isCompleted {
            let dataController = DataController(modelContext: modelContext)
            dataController.toggleHabitCompletion(habit: habit, date: selectedDate)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted = false
            }
            NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            return
        }
        
        if habit.isTrainingHabit {
            switch habit.trainingDayType {
            case "cardio":
                showingCardioLog = true
            case "strength":
                showingWorkoutLog = true
            case "rest":
                triggerCompletionAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let dataController = DataController(modelContext: modelContext)
                    dataController.markHabitComplete(habit, date: selectedDate)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isCompleted = true
                    }
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                }
            default:
                toggleCompletion()
            }
        } else {
            toggleCompletion()
        }
    }
    
    private func toggleCompletion() {
        triggerCompletionAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let dataController = DataController(modelContext: modelContext)
            dataController.toggleHabitCompletion(habit: habit, date: selectedDate)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted.toggle()
            }
            
            if isToday {
                NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            }
        }
    }
}

#Preview {
    HabitTrackerView(showingFocusContext: .constant(false))
}
