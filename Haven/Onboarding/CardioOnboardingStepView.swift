import SwiftUI

// MARK: - Cardio Onboarding Step View
// Full-screen step that appears after the plan preview is confirmed.
// Pre-fills a smart cardio recommendation based on rest days,
// and lets users customize type, duration, or remove/add days.

struct CardioOnboardingStepView: View {
    let restDays: [Int]                               // All rest days from the strength plan
    let onContinue: ([PlanCommitter.CardioDayConfig]) -> Void
    let onSkip: () -> Void

    @State private var cardioDays: [EditableCardioDay] = []
    @State private var editingDay: EditableCardioDay? = nil

    // MARK: - Editable Model

    struct EditableCardioDay: Identifiable {
        var id: Int { dayOfWeek }
        let dayOfWeek: Int
        var cardioType: String
        var durationMinutes: Int
        var isActive: Bool              // false = rest day (no cardio assigned)
    }

    // MARK: - Computed

    private var activeCardioDays: [EditableCardioDay] {
        cardioDays.filter { $0.isActive }
    }

    private var zone2Count: Int {
        activeCardioDays.filter { $0.cardioType == "Zone 2" }.count
    }

    private var intervalCount: Int {
        activeCardioDays.filter { $0.cardioType == "VO2 Max" }.count
    }

    private var summaryText: String {
        let total = activeCardioDays.count
        if total == 0 { return "No cardio days selected" }

        var parts: [String] = []
        parts.append("\(total) cardio day\(total == 1 ? "" : "s")")
        if zone2Count > 0 { parts.append("\(zone2Count) Zone 2") }
        if intervalCount > 0 { parts.append("\(intervalCount) Interval") }

        let otherCount = total - zone2Count - intervalCount
        if otherCount > 0 { parts.append("\(otherCount) Other") }

        return parts.joined(separator: " · ")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    headerSection

                    // Day list
                    dayListSection

                    // Summary
                    if !activeCardioDays.isEmpty {
                        summaryBadge
                    }

                    // Instructions
                    instructionsText

                    // Continue button
                    continueButton

                    // Skip
                    skipText

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .onAppear(perform: buildInitialState)
        .sheet(item: $editingDay) { day in
            CardioEditorSheet(
                day: day,
                onSave: { updated in
                    updateDay(updated)
                    editingDay = nil
                },
                onRemove: {
                    deactivateDay(day.dayOfWeek)
                    editingDay = nil
                },
                onCancel: {
                    editingDay = nil
                }
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CARDIO")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)

            Text("Now let's add cardio.")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)

            Text("VO₂ Max is the single strongest predictor of longevity. Here's what the research recommends.")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(4)
        }
        .padding(.top, 8)
    }

    // MARK: - Day List

    private var dayListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR CARDIO PLAN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)

            VStack(spacing: 4) {
                ForEach(cardioDays.indices, id: \.self) { index in
                    let day = cardioDays[index]
                    cardioRowView(day: day)
                }
            }
        }
    }

    private func cardioRowView(day: EditableCardioDay) -> some View {
        Button(action: { editingDay = day }) {
            HStack(spacing: 14) {
                // Day name
                Text(dayName(for: day.dayOfWeek))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .frame(width: 36, alignment: .leading)

                if day.isActive {
                    // Cardio info
                    Text("\(day.cardioType) · \(day.durationMinutes) min")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.atlasText)

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasPrimary)
                } else {
                    // Rest day
                    Text("—— Rest ——")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted.opacity(0.4))

                    Spacer()

                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted.opacity(0.3))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(day.isActive ? Color.atlasPrimary.opacity(0.06) : Color.white.opacity(0.02))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Summary Badge

    private var summaryBadge: some View {
        Text(summaryText)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.atlasPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.atlasPrimary.opacity(0.08))
            .cornerRadius(8)
    }

    // MARK: - Instructions

    private var instructionsText: some View {
        Text("Tap any day to change type, duration, or remove it.\nTap a rest day to add cardio.")
            .font(.system(size: 13))
            .foregroundColor(.atlasTextMuted)
            .lineSpacing(4)
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.atlasBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.atlasPrimary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }

    private var skipText: some View {
        Button(action: onSkip) {
            Text("Skip for now")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted.opacity(0.6))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Logic

    private func buildInitialState() {
        let recommendations = CardioRecommendation.recommend(restDays: restDays)
        let recommendedDays = Set(recommendations.map { $0.dayOfWeek })

        cardioDays = restDays.sorted().map { dow in
            if let rec = recommendations.first(where: { $0.dayOfWeek == dow }) {
                return EditableCardioDay(
                    dayOfWeek: dow,
                    cardioType: rec.cardioType,
                    durationMinutes: rec.durationMinutes,
                    isActive: true
                )
            } else {
                return EditableCardioDay(
                    dayOfWeek: dow,
                    cardioType: "Zone 2",
                    durationMinutes: 30,
                    isActive: false
                )
            }
        }
    }

    private func updateDay(_ updated: EditableCardioDay) {
        if let index = cardioDays.firstIndex(where: { $0.dayOfWeek == updated.dayOfWeek }) {
            cardioDays[index] = updated
        }
    }

    private func deactivateDay(_ dayOfWeek: Int) {
        if let index = cardioDays.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
            cardioDays[index] = EditableCardioDay(
                dayOfWeek: dayOfWeek,
                cardioType: cardioDays[index].cardioType,
                durationMinutes: cardioDays[index].durationMinutes,
                isActive: false
            )
        }
    }

    private func handleContinue() {
        let configs = activeCardioDays.map { day in
            PlanCommitter.CardioDayConfig(
                dayOfWeek: day.dayOfWeek,
                cardioType: day.cardioType,
                durationMinutes: day.durationMinutes
            )
        }
        onContinue(configs)
    }

    private func dayName(for dayOfWeek: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard dayOfWeek >= 0 && dayOfWeek < 7 else { return "???" }
        return names[dayOfWeek]
    }
}

// MARK: - Cardio Editor Sheet

struct CardioEditorSheet: View {
    let day: CardioOnboardingStepView.EditableCardioDay
    let onSave: (CardioOnboardingStepView.EditableCardioDay) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    @State private var selectedType: String
    @State private var selectedDuration: Int

    init(
        day: CardioOnboardingStepView.EditableCardioDay,
        onSave: @escaping (CardioOnboardingStepView.EditableCardioDay) -> Void,
        onRemove: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.day = day
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
        _selectedType = State(initialValue: day.cardioType)
        _selectedDuration = State(initialValue: day.durationMinutes)
    }

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var dayDisplayName: String {
        guard day.dayOfWeek >= 0 && day.dayOfWeek < 7 else { return "Day" }
        return dayNames[day.dayOfWeek]
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    // Type picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TYPE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.5)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(CardioRecommendation.CardioTypeOption.allOptions) { option in
                                Button(action: {
                                    selectedType = option.name
                                    selectedDuration = option.defaultDuration
                                }) {
                                    Text(option.name)
                                        .font(.system(size: 14, weight: selectedType == option.name ? .semibold : .regular))
                                        .foregroundColor(selectedType == option.name ? .atlasBackground : .atlasText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(selectedType == option.name ? Color.atlasPrimary : Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Duration picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1.5)

                        HStack(spacing: 8) {
                            ForEach(CardioRecommendation.durationOptions, id: \.self) { mins in
                                Button(action: { selectedDuration = mins }) {
                                    Text("\(mins) min")
                                        .font(.system(size: 14, weight: selectedDuration == mins ? .semibold : .regular))
                                        .foregroundColor(selectedDuration == mins ? .atlasBackground : .atlasText)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(selectedDuration == mins ? Color.atlasPrimary : Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    Spacer()

                    // Save button
                    Button(action: {
                        let updated = CardioOnboardingStepView.EditableCardioDay(
                            dayOfWeek: day.dayOfWeek,
                            cardioType: selectedType,
                            durationMinutes: selectedDuration,
                            isActive: true
                        )
                        onSave(updated)
                    }) {
                        Text("Save")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(12)
                    }

                    // Remove button (only if day currently has cardio)
                    if day.isActive {
                        Button(action: onRemove) {
                            Text("Remove Cardio")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(24)
            }
            .navigationTitle(dayDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
    }
}