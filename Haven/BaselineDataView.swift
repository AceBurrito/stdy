import SwiftUI
import SwiftData
import HealthKit

struct BaselineDataView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var healthKitManager: HealthKitManager
    
    @State private var name = ""
    @State private var age: String = ""
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 10
    @State private var weight: String = ""
    @State private var gender: String = "Male"
    @State private var wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 6, minute: 30))!
    @State private var activityLevel: String = "moderately_active"
    @State private var proteinGrams: String = ""
    
    @State private var dataLoaded = false
    @State private var selfReportedSleepHours: Double? = nil
    @State private var showSleepSelfReport: Bool = false
    
    let onComplete: () -> Void
    
    let activityLevels = [
        ("sedentary", "Sedentary", "Little to no exercise"),
        ("lightly_active", "Lightly Active", "1-2 days/week"),
        ("moderately_active", "Moderately Active", "3-5 days/week"),
        ("very_active", "Very Active", "6-7 days/week")
    ]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    headerSection
                    
                    // Personal Info
                    personalInfoSection
                    
                    // Body Metrics
                    bodyMetricsSection
                    
                    // Sleep Schedule
                    sleepScheduleSection
                    
                    // Activity & Nutrition
                    activityNutritionSection
                    
                    // Continue Button
                    continueButton
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            loadHealthData()
            
            // Check if we need to ask for sleep self-report
            Task {
                let hasRecentSleep = await healthKitManager.hasRecentSleepData()
                showSleepSelfReport = !hasRecentSleep
                
                if !hasRecentSleep {
                    selfReportedSleepHours = 7.0 // Default
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BASELINE DATA")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)
            
            Text("Let's gather your starting point")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
            
            if dataLoaded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Data loaded from Apple Health")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.top, 40)
    }
    
    // MARK: - Personal Info Section
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Personal Info")
            
            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                TextField("Your name", text: $name)
                    .textFieldStyle(atlasTextFieldStyle())
            }
            
            // Age
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Age")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    if !age.isEmpty && dataLoaded {
                        Text("from Apple Health")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasAccent)
                    }
                }
                
                TextField("Age", text: $age)
                    .keyboardType(.numberPad)
                    .textFieldStyle(atlasTextFieldStyle())
            }
            
            // Gender
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gender")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    if dataLoaded && healthKitManager.healthData.biologicalSex != nil {
                        Text("from Apple Health")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasAccent)
                    }
                }
                
                Picker("Gender", selection: $gender) {
                    Text("Male").tag("Male")
                    Text("Female").tag("Female")
                    Text("Other").tag("Other")
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - Body Metrics Section
    private var bodyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Body Metrics")
            
            // Height
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Height")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    if dataLoaded && healthKitManager.healthData.height != nil {
                        Text("from Apple Health")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasAccent)
                    }
                }
                
                HStack(spacing: 16) {
                    HeightPicker(selection: $heightFeet, range: 3...7, suffix: "'", label: "Feet")
                    HeightPicker(selection: $heightInches, range: 0...11, suffix: "\"", label: "Inches")
                }
            }
            
            // Weight
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weight (lbs)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    if !weight.isEmpty && dataLoaded {
                        Text("from Apple Health")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasAccent)
                    }
                }
                
                TextField("Weight", text: $weight)
                    .keyboardType(.numberPad)
                    .textFieldStyle(atlasTextFieldStyle())
            }
        }
    }
    
    // MARK: - Sleep Schedule Section
    private var sleepScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Sleep Schedule")
            
            Text("What time do you typically wake up on weekdays?")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
            
            HStack {
                Text("Wake time:")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                Spacer()
                DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            Text("We'll use this to calculate your ideal bedtime if needed")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted.opacity(0.7))
        }
    }
    
    // MARK: - Activity & Nutrition Section
    private var activityNutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Activity & Nutrition")
            
            // Activity Level
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity Level")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                VStack(spacing: 8) {
                    ForEach(activityLevels, id: \.0) { level in
                        ActivityLevelCard(
                            title: level.1,
                            subtitle: level.2,
                            isSelected: activityLevel == level.0,
                            action: {
                                activityLevel = level.0
                            }
                        )
                    }
                }
            }

            // Sleep Self-Report (if Apple Health unavailable)
            if showSleepSelfReport {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(text: "Sleep Duration")
                    
                    Text("We couldn't detect sleep data from Apple Health")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How many hours do you typically sleep per night?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.atlasText)
                        
                        HStack {
                            Text("Hours per night:")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button(action: {
                                    if let hours = selfReportedSleepHours {
                                        selfReportedSleepHours = max(4, hours - 0.5)
                                    } else {
                                        selfReportedSleepHours = 7.0
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.atlasPrimary)
                                }
                                
                                Text(String(format: "%.1f hrs", selfReportedSleepHours ?? 7.0))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.atlasText)
                                    .frame(width: 80)
                                
                                Button(action: {
                                    if let hours = selfReportedSleepHours {
                                        selfReportedSleepHours = min(12, hours + 0.5)
                                    } else {
                                        selfReportedSleepHours = 7.0
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.atlasPrimary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        
                        Text("💡 This helps us estimate your baseline until we get actual sleep data")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted.opacity(0.7))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            // Protein Intake
            VStack(alignment: .leading, spacing: 12) {
                Text("How much protein do you typically eat per day?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                TextField("e.g., 140", text: $proteinGrams)
                    .keyboardType(.numberPad)
                    .textFieldStyle(atlasTextFieldStyle())
                
                // Quick estimate guide
                VStack(alignment: .leading, spacing: 6) {
                    Text("💡 Quick estimate guide:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text("• Chicken breast (palm-sized): 25g")
                    Text("• Greek yogurt (1 cup): 20g")
                    Text("• 2 eggs: 12g")
                    Text("• Protein shake: 25g")
                }
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted.opacity(0.8))
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                Button(action: { proteinGrams = "" }) {
                    Text("Skip - I have no idea")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAccent)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Continue Button
    private var continueButton: some View {
        Button(action: saveAndContinue) {
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canContinue ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                .cornerRadius(12)
        }
        .disabled(!canContinue)
    }
    
    // MARK: - Computed Properties
    private var canContinue: Bool {
        !name.isEmpty && !age.isEmpty && !weight.isEmpty
    }
    
    // MARK: - Functions
    private func loadHealthData() {
        let data = healthKitManager.healthData
        
        // Calculate exact age from birthday
        if let dateOfBirth = try? healthKitManager.healthStore.dateOfBirthComponents() {
            let calendar = Calendar.current
            let now = Date()
            
            if let birthDate = calendar.date(from: dateOfBirth) {
                let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
                if let calculatedAge = ageComponents.year {
                    age = String(calculatedAge)
                }
            }
        }
        
        // Gender
        gender = data.biologicalSex ?? "Male"
        
        // Height
        if let heightInches = data.height {
            let totalInches = Int(heightInches)
            heightFeet = totalInches / 12
            self.heightInches = totalInches % 12
        }
        
        // Weight
        if let weightLbs = data.weight {
            weight = String(format: "%.0f", weightLbs)
        }
        
        dataLoaded = (data.age != nil || data.height != nil || data.weight != nil)
    }
    
    private func saveAndContinue() {
        let dataController = DataController(modelContext: modelContext)
        let profile = dataController.getOrCreateUserProfile()
        
        profile.name = name
        profile.age = Int(age)
        profile.height = Double(heightFeet * 12 + heightInches)
        profile.weight = Double(weight)
        profile.gender = gender
        profile.activityLevel = activityLevel
        
        // Save wake time
        profile.targetWakeTime = wakeTime

        // Save self-reported sleep if needed
        if showSleepSelfReport, let hours = selfReportedSleepHours {
            profile.selfReportedSleepHours = hours
        } else {
            profile.selfReportedSleepHours = nil
        }
        
        // Save protein intake (with estimated flag)
        if let grams = Double(proteinGrams), grams > 0 {
            profile.currentProteinIntake = grams
            profile.proteinIsEstimated = true
        } else {
            profile.currentProteinIntake = nil
            profile.proteinIsEstimated = false
        }
        
        // Create initial weight entry
        if let weightValue = Double(weight) {
            let initialWeightEntry = BodyCompEntry(date: Date(), weight: weightValue)
            initialWeightEntry.notes = "Starting weight"
            initialWeightEntry.userProfile = profile
            modelContext.insert(initialWeightEntry)
        }
        
        // Set default experience level
        if profile.activityLevel == "sedentary" || profile.activityLevel == "lightly_active" {
            profile.experienceLevel = "beginner"
        } else if profile.activityLevel == "moderately_active" {
            profile.experienceLevel = "intermediate"
        } else {
            profile.experienceLevel = "advanced"
        }
        
        // Sync last 7 days of health data for tier calculation
        // This ensures consistent 7-day averaging between onboarding and ongoing tier calcs
        Task {
            print("🔄 Syncing 7-day health metrics for tier calculation...")
            await healthKitManager.syncMetricsWithSmartRefresh(modelContext: modelContext)
            
            do {
                try modelContext.save()
                print("✅ Baseline data saved + 7-day metrics synced")
                print("   Age: \(profile.age ?? 0)")
                print("   Activity Level: \(profile.activityLevel ?? "nil")")
                print("   Protein Intake: \(profile.currentProteinIntake ?? 0)g (estimated: \(profile.proteinIsEstimated))")
                print("   Wake Time: \(wakeTime.formatted(date: .omitted, time: .shortened))")
                
                // Verify sync worked
                let descriptor = FetchDescriptor<HealthMetrics>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let metrics = (try? modelContext.fetch(descriptor)) ?? []
                print("   Health Metrics Entries: \(metrics.count)")
                if let latest = metrics.first {
                    print("   Latest: Sleep: \(latest.sleepDuration ?? 0)h, HRV: \(latest.heartRateVariability ?? 0)ms, RHR: \(latest.restingHeartRate ?? 0)bpm")
                }
                
                await MainActor.run {
                    onComplete()
                }
            } catch {
                print("❌ Failed to save: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionLabel: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.atlasText)
    }
}

struct atlasTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.atlasText)
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
    }
}

struct ActivityLevelCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasText)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasPrimary)
                }
            }
            .padding(14)
            .background(isSelected ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.atlasPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HeightPicker: View {
    @Binding var selection: Int
    let range: ClosedRange<Int>
    let suffix: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
            
            Picker(label, selection: $selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text("\(value)\(suffix)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
        }
    }
}


#Preview {
    BaselineDataView(healthKitManager: HealthKitManager(), onComplete: {})
}
