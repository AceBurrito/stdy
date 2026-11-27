// OnboardingSteps.swift
// Steady — onboarding screens (steps 1–8). Plan selection reuses
// PlanSelectionView / PlanPreviewView / CardioOnboardingStepView.
//
// Each step writes straight to the UserProfile so the flow can resume.

import SwiftUI
import SwiftData

// MARK: - Scaffold

/// Shared layout: progress ticks, title, content, pinned primary button.
struct OnboardingScaffold<Content: View>: View {
    let step: Int
    let totalSteps: Int
    let title: String
    var subtitle: String? = nil
    var primaryTitle: String = "Continue"
    var primaryEnabled: Bool = true
    let onPrimary: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    progressTicks
                        .padding(.top, 56)
                    Text(title)
                        .font(SteadyType.display(34))
                        .foregroundColor(.atlasText)
                        .padding(.top, 24)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(SteadyType.body)
                            .foregroundColor(.atlasTextMuted)
                            .padding(.top, 8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content()
                        .padding(.top, 28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                Button(primaryTitle, action: onPrimary)
                    .buttonStyle(SteadyPrimaryButtonStyle())
                    .disabled(!primaryEnabled)
                    .opacity(primaryEnabled ? 1 : 0.4)
                if let secondaryTitle, let onSecondary {
                    Button(secondaryTitle, action: onSecondary)
                        .font(SteadyType.body)
                        .foregroundColor(.atlasTextMuted)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color.atlasBackground)
        }
        .background(Color.atlasBackground.ignoresSafeArea())
    }

    private var progressTicks: some View {
        HStack(spacing: 4) {
            ForEach(1...totalSteps, id: \.self) { i in
                Rectangle()
                    .fill(i <= step ? Color.atlasPrimary : Color.steadyRaised)
                    .frame(height: 3)
            }
        }
    }
}

// MARK: - Step 0: Welcome

struct OnboardingWelcomeStep: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Get stronger.\nLose fat.\nRecover smart.")
                .font(SteadyType.display(48))
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Progressive overload, recovery from Apple Health, and body composition in one log.")
                .font(SteadyType.body)
                .foregroundColor(.atlasTextMuted)
                .padding(.top, 16)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Get Started", action: onStart)
                .buttonStyle(SteadyPrimaryButtonStyle())
            Text("One-time purchase. No subscription.")
                .font(SteadyType.caption)
                .foregroundColor(.steadyTextFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .background(Color.atlasBackground.ignoresSafeArea())
    }
}

// MARK: - Step 1: Apple Health

struct OnboardingHealthStep: View {
    let step: Int
    let totalSteps: Int
    let healthKitManager: HealthKitManager
    let onDone: () -> Void

    @State private var isConnecting = false

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "Connect Apple Health",
            subtitle: "Recovery is built from your own sleep, HRV and resting heart rate. Weight and body fat fill in your Body tab.",
            primaryTitle: isConnecting ? "Connecting…" : "Connect Apple Health",
            primaryEnabled: !isConnecting,
            onPrimary: connect,
            secondaryTitle: "Skip for now",
            onSecondary: onDone
        ) {
            VStack(alignment: .leading, spacing: 0) {
                readRow("Sleep", detail: "Hours and stages, last night")
                readRow("HRV", detail: "Overnight average vs your 30-day baseline")
                readRow("Resting heart rate", detail: "Morning value vs your 30-day baseline")
                readRow("Weight & body fat", detail: "Latest readings from scales and apps")
                readRow("Workouts", detail: "Import cardio, save lifts back to Health")
            }
            .steadyPanel(padding: 0)

            Text("Read only, except saving workouts you log. Nothing leaves your iCloud.")
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
                .padding(.top, 12)
        }
    }

    private func readRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(SteadyType.bodyEmphasis)
                .foregroundColor(.atlasText)
            Text(detail)
                .font(SteadyType.caption)
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.steadyHairline).frame(height: 1)
        }
    }

    private func connect() {
        isConnecting = true
        Task {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                print("❌ Apple Health connection failed: \(error)")
            }
            await MainActor.run {
                isConnecting = false
                onDone()
            }
        }
    }
}

// MARK: - Step 2: Basics

struct OnboardingBasicsStep: View {
    let step: Int
    let totalSteps: Int
    @Bindable var profile: UserProfile
    let healthData: HealthData
    let onDone: () -> Void

    @Environment(\.unitFormatter) private var unitFormatter
    @State private var age: Int = 30
    @State private var sex: String = ""
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 10
    @State private var heightCm: Int = 178

    private let sexOptions = ["Male", "Female"]

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "The basics",
            subtitle: "Used for metabolic age and heart rate zones.",
            primaryEnabled: !sex.isEmpty,
            onPrimary: save
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age").steadyLabel()
                    Stepper(value: $age, in: 16...90) {
                        Text("\(age)")
                            .font(SteadyType.metric(28))
                            .foregroundColor(.atlasText)
                    }
                    .steadyPanel(padding: 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sex").steadyLabel()
                    HStack(spacing: 10) {
                        ForEach(sexOptions, id: \.self) { option in
                            SteadyOptionRow(title: option, isSelected: sex == option) { sex = option }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Height").steadyLabel()
                    heightPicker
                        .steadyPanel(padding: 4)
                }
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var heightPicker: some View {
        if unitFormatter.system == .metric {
            Picker("Height", selection: $heightCm) {
                ForEach(140...215, id: \.self) { Text("\($0) cm").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
        } else {
            HStack(spacing: 0) {
                Picker("Feet", selection: $heightFeet) {
                    ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                }
                .pickerStyle(.wheel)
                Picker("Inches", selection: $heightInches) {
                    ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 140)
        }
    }

    private func load() {
        age = profile.age ?? healthData.age ?? 30
        sex = profile.gender ?? healthData.biologicalSex.flatMap { sexOptions.contains($0) ? $0 : nil } ?? ""
        if let inches = profile.height ?? healthData.height, inches > 0 {
            heightFeet = max(4, min(7, Int(inches) / 12))
            heightInches = Int(inches.rounded()) % 12
            heightCm = max(140, min(215, Int((inches * 2.54).rounded())))
        }
    }

    private func save() {
        profile.age = age
        profile.gender = sex
        profile.height = unitFormatter.system == .metric
            ? Double(heightCm) / 2.54
            : Double(heightFeet * 12 + heightInches)
        onDone()
    }
}

// MARK: - Step 3: Weight

struct OnboardingWeightStep: View {
    let step: Int
    let totalSteps: Int
    @Bindable var profile: UserProfile
    let healthData: HealthData
    let onDone: () -> Void

    @Environment(\.unitFormatter) private var unitFormatter
    @State private var weightText = ""
    @State private var fromHealth = false
    @FocusState private var focused: Bool

    private var weightValue: Double? {
        guard let v = Double(weightText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        return v
    }

    private var isPlausible: Bool {
        guard let v = weightValue else { return false }
        let lbs = unitFormatter.toLbs(v)
        return lbs >= 70 && lbs <= 600
    }

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "Current weight",
            subtitle: fromHealth ? "Pulled from Apple Health. Adjust if it's out of date." : "Your starting point. You can log weigh-ins on the Body tab.",
            primaryEnabled: isPlausible,
            onPrimary: save
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(SteadyType.metric(44))
                    .foregroundColor(.atlasText)
                    .focused($focused)
                    .frame(maxWidth: 180, alignment: .leading)
                Text(unitFormatter.weightUnit)
                    .font(SteadyType.title)
                    .foregroundColor(.atlasTextMuted)
                Spacer()
            }
            .steadyPanel(padding: 18)
        }
        .onAppear {
            if let lbs = profile.weight ?? healthData.weight {
                fromHealth = profile.weight == nil
                weightText = String(format: "%.1f", unitFormatter.fromLbs(lbs))
            } else {
                focused = true
            }
        }
    }

    private func save() {
        guard let v = weightValue else { return }
        profile.weight = unitFormatter.toLbs(v)
        focused = false
        onDone()
    }
}

// MARK: - Step 4: Body Fat

struct OnboardingBodyFatStep: View {
    let step: Int
    let totalSteps: Int
    @Bindable var profile: UserProfile
    let healthData: HealthData
    let onDone: () -> Void

    @State private var bodyFatText = ""
    @State private var fromHealth = false
    @FocusState private var focused: Bool

    private var percentValue: Double? {
        guard let v = Double(bodyFatText.replacingOccurrences(of: ",", with: ".")), v >= 3, v <= 60 else { return nil }
        return v
    }

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "Body fat",
            subtitle: fromHealth
                ? "Pulled from Apple Health. Adjust if it's out of date."
                : "From a smart scale, DEXA or calipers. A rough number is fine.",
            primaryEnabled: percentValue != nil,
            onPrimary: save,
            secondaryTitle: "I don't know",
            onSecondary: skip
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0", text: $bodyFatText)
                        .keyboardType(.decimalPad)
                        .font(SteadyType.metric(44))
                        .foregroundColor(.atlasText)
                        .focused($focused)
                        .frame(maxWidth: 180, alignment: .leading)
                    Text("%")
                        .font(SteadyType.title)
                        .foregroundColor(.atlasTextMuted)
                    Spacer()
                }
                .steadyPanel(padding: 18)

                Text("With body fat, Steady tracks lean mass separately from weight, so you can see muscle holding while fat drops.")
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            if let fraction = profile.bodyFatPercent ?? healthData.bodyFatPercentage {
                fromHealth = profile.bodyFatPercent == nil
                bodyFatText = String(format: "%.1f", fraction * 100)
            }
        }
    }

    private func save() {
        guard let v = percentValue else { return }
        profile.bodyFatPercent = v / 100
        focused = false
        onDone()
    }

    private func skip() {
        profile.bodyFatPercent = nil
        focused = false
        onDone()
    }
}

// MARK: - Steps 5–7: Single-choice pickers

struct OnboardingGoalStep: View {
    let step: Int
    let totalSteps: Int
    @Bindable var profile: UserProfile
    let onDone: () -> Void

    @State private var selection: SteadyGoal? = nil

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "What's the goal?",
            subtitle: "Shapes your plan recommendations and how the Body tab reads your progress.",
            primaryEnabled: selection != nil,
            onPrimary: {
                profile.primaryGoal = selection?.rawValue
                profile.secondaryGoal = nil
                onDone()
            }
        ) {
            VStack(spacing: 10) {
                ForEach(SteadyGoal.allCases) { goal in
                    SteadyOptionRow(title: goal.title, subtitle: goal.subtitle, icon: goal.icon, isSelected: selection == goal) {
                        selection = goal
                    }
                }
            }
        }
        .onAppear { selection = profile.primaryGoal.flatMap(SteadyGoal.init(rawValue:)) }
    }
}

struct OnboardingExperienceStep: View {
    let step: Int
    let totalSteps: Int
    @Bindable var profile: UserProfile
    let onDone: () -> Void

    @State private var selection: SteadyExperience? = nil

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "Training experience",
            primaryEnabled: selection != nil,
            onPrimary: {
                profile.experienceLevel = selection?.rawValue
                onDone()
            }
        ) {
            VStack(spacing: 10) {
                ForEach(SteadyExperience.allCases) { level in
                    SteadyOptionRow(title: level.title, subtitle: level.subtitle, isSelected: selection == level) {
                        selection = level
                    }
                }
            }
        }
        .onAppear { selection = profile.experienceLevel.flatMap(SteadyExperience.init(rawValue:)) }
    }
}

struct OnboardingEquipmentStep: View {
    let step: Int
    let totalSteps: Int
    @Bindable var profile: UserProfile
    let onDone: () -> Void

    @State private var selection: SteadyEquipment? = nil

    var body: some View {
        OnboardingScaffold(
            step: step, totalSteps: totalSteps,
            title: "Equipment",
            subtitle: "Plans only use what you have.",
            primaryEnabled: selection != nil,
            onPrimary: {
                profile.availableEquipment = selection?.title
                onDone()
            }
        ) {
            VStack(spacing: 10) {
                ForEach(SteadyEquipment.allCases) { option in
                    SteadyOptionRow(title: option.title, subtitle: option.subtitle, icon: option.icon, isSelected: selection == option) {
                        selection = option
                    }
                }
            }
        }
        .onAppear {
            if profile.availableEquipment != nil {
                selection = SteadyEquipment.from(profile.availableEquipment)
            }
        }
    }
}
