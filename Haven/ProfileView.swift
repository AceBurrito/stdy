import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    
    private var profile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Personal Info
                            personalInfoSection(profile: profile)
                            
                            // Training Preferences
                            trainingPreferencesSection(profile: profile)
                            
                            // Goals
                            goalsSection(profile: profile)
                            
                            // App Settings
                            appSettingsSection
                            
                            Spacer().frame(height: 40)
                        }
                        .padding(24)
                    }
                } else {
                    Text("No profile found")
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }    
    
    // MARK: - Personal Info Section
    
    private func personalInfoSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Personal Info")
            
            VStack(spacing: 0) {
                NavigationLink(destination: EditPersonalInfoView(profile: profile)) {
                    profileRow(label: "Name", value: profile.name ?? "Not set")
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditPersonalInfoView(profile: profile)) {
                    profileRow(label: "Age", value: profile.age != nil ? "\(profile.age!)" : "Not set")
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditPersonalInfoView(profile: profile)) {
                    profileRow(label: "Gender", value: profile.gender?.capitalized ?? "Not set")
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditPersonalInfoView(profile: profile)) {
                    profileRow(label: "Height", value: formatHeight(profile.height))
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditPersonalInfoView(profile: profile)) {
                    profileRow(label: "Weight", value: profile.weight != nil ? unitFormatter.displayWeightInt(profile.weight!) : "Not set")
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Training Preferences Section
    
    private func trainingPreferencesSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Training Preferences")
            
            VStack(spacing: 0) {
                NavigationLink(destination: EditTrainingPreferencesView(profile: profile)) {
                    profileRow(label: "Days per Week", value: profile.trainingDaysPerWeek != nil ? "\(profile.trainingDaysPerWeek!) days" : "Not set")
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditTrainingPreferencesView(profile: profile)) {
                    profileRow(label: "Session Length", value: profile.trainingMinutesPerSession != nil ? "\(profile.trainingMinutesPerSession!) min" : "Not set")
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditTrainingPreferencesView(profile: profile)) {
                    profileRow(label: "Experience", value: profile.experienceLevel?.capitalized ?? "Not set")
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditTrainingPreferencesView(profile: profile)) {
                    profileRow(label: "Equipment", value: truncate(profile.availableEquipment, length: 25))
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditTrainingPreferencesView(profile: profile)) {
                    profileRow(label: "Constraints", value: truncate(profile.trainingConstraints, length: 25))
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            Text("Changes will be applied at your next weekly check-in")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
                .padding(.horizontal, 4)
        }
    }

   
    
// MARK: - Goals Section

private func goalsSection(profile: UserProfile) -> some View {
    VStack(alignment: .leading, spacing: 16) {
        sectionHeader("Goals")
        
        VStack(spacing: 0) {
            NavigationLink(destination: EditGoalsView(profile: profile)) {
                profileRow(label: "Primary Goal", value: formatGoal(profile.primaryGoal))
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            NavigationLink(destination: EditGoalsView(profile: profile)) {
                profileRow(label: "Secondary Goal", value: formatGoal(profile.secondaryGoal))
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            NavigationLink(destination: EditGoalsView(profile: profile)) {
                profileRow(label: "Goal Weight", value: profile.goalWeight != nil ? unitFormatter.displayWeightInt(profile.goalWeight!) : "Not set")
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
    


private var appSettingsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
        sectionHeader("App")
        
        VStack(spacing: 0) {
            NavigationLink(destination: HealthPermissionsView()) {
                profileRow(label: "Health Permissions", value: "Manage")
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            unitSystemRow
            
            Divider().background(Color.white.opacity(0.1))
            
            // Sprint 5: Morning Brief Notification Toggle
            morningBriefToggleRow
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                Text("Version")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Text(appVersion)
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(16)
            
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
    
    
    // MARK: - Unit System Row

    private var unitSystemRow: some View {
        HStack {
            Text("Units")
                .font(.system(size: 16))
                .foregroundColor(.atlasText)

            Spacer()

            Picker("Units", selection: unitPreferenceBinding) {
                Text("Auto").tag("")
                Text("Imperial").tag("imperial")
                Text("Metric").tag("metric")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(16)
    }

    private var unitPreferenceBinding: Binding<String> {
        Binding(
            get: { profile?.unitPreference ?? "" },
            set: { newValue in
                if let p = profile {
                    p.unitPreference = newValue
                    try? modelContext.save()
                }
            }
        )
    }

    // MARK: - Morning Brief Toggle (Sprint 5)

    private var morningBriefToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Morning Brief")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasText)

                Text("Daily reminder at 7:00 AM")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasTextMuted)
            }

            Spacer()

            Toggle("", isOn: morningBriefBinding)
                .tint(.atlasPrimary)
                .labelsHidden()
        }
        .padding(16)
    }

    private var morningBriefBinding: Binding<Bool> {
        Binding(
            get: { profile?.morningBriefNotificationEnabled ?? false },
            set: { newValue in
                if let p = profile {
                    p.morningBriefNotificationEnabled = newValue
                    try? modelContext.save()
                    NotificationManager.shared.scheduleMorningBriefReminder(enabled: newValue)
                }
            }
        )
    }

    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.atlasAccent)
            .tracking(1.5)
    }
    
    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.atlasText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted.opacity(0.5))
        }
        .padding(16)
    }
    
    // MARK: - Helpers
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func formatHeight(_ height: Double?) -> String {
        guard let inches = height else { return "Not set" }
        let feet = Int(inches) / 12
        let remainingInches = Int(inches) % 12
        return "\(feet)'\(remainingInches)\""
    }
    
    private func formatGoal(_ goal: String?) -> String {
        guard let goal = goal else { return "Not set" }
        return goal.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private func truncate(_ text: String?, length: Int) -> String {
        guard let text = text, !text.isEmpty else { return "Not set" }
        if text.count <= length {
            return text
        }
        return String(text.prefix(length)) + "..."
    }
}

// MARK: - Edit Personal Info View

struct EditPersonalInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    @Environment(\.unitFormatter) private var unitFormatter
    
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""
    @State private var weight: String = ""
    
    private let genderOptions = ["male", "female", "other", "prefer not to say"]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        TextField("Your name", text: $name)
                            .textFieldStyle(atlasTextFieldStyle())
                    }
                    
                    // Age
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Age")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        TextField("Age", text: $age)
                            .keyboardType(.numberPad)
                            .textFieldStyle(atlasTextFieldStyle())
                    }
                    
                    // Gender
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        Picker("Gender", selection: $gender) {
                            Text("Select...").tag("")
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option.capitalized).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .tint(.atlasText)
                    }
                    
                    // Height
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Height")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack(spacing: 12) {
                            HStack {
                                TextField("5", text: $heightFeet)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 50)
                                Text("ft")
                                    .foregroundColor(.atlasTextMuted)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            
                            HStack {
                                TextField("10", text: $heightInches)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 50)
                                Text("in")
                                    .foregroundColor(.atlasTextMuted)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack {
                            TextField("175", text: $weight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(atlasTextFieldStyle())
                            
                            Text(unitFormatter.weightUnit)
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    
                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle("Personal Info")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.atlasTextMuted)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .foregroundColor(.atlasPrimary)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        name = profile.name ?? ""
        age = profile.age != nil ? "\(profile.age!)" : ""
        gender = profile.gender ?? ""
        
        if let height = profile.height {
            let feet = Int(height) / 12
            let inches = Int(height) % 12
            heightFeet = "\(feet)"
            heightInches = "\(inches)"
        }
        
        weight = profile.weight != nil ? "\(Int(profile.weight!))" : ""
    }
    
    private func saveChanges() {
        profile.name = name.isEmpty ? nil : name
        profile.age = Int(age)
        profile.gender = gender.isEmpty ? nil : gender
        
        if let feet = Int(heightFeet), let inches = Int(heightInches) {
            profile.height = Double(feet * 12 + inches)
        }
        
        profile.weight = Double(weight)
    }
}

// MARK: - Edit Training Preferences View

struct EditTrainingPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    
    @State private var daysPerWeek: Int = 4
    @State private var minutesPerSession: Int = 45
    @State private var experienceLevel: String = ""
    @State private var equipment: String = ""
    @State private var constraints: String = ""
    
    private let daysOptions = [2, 3, 4, 5, 6]
    private let minutesOptions = [20, 30, 45, 60, 90]
    private let experienceOptions = ["beginner", "intermediate", "advanced"]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Days per week
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Training Days per Week")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack(spacing: 8) {
                            ForEach(daysOptions, id: \.self) { days in
                                Button(action: { daysPerWeek = days }) {
                                    Text("\(days)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(daysPerWeek == days ? .atlasBackground : .atlasText)
                                        .frame(width: 50, height: 44)
                                        .background(daysPerWeek == days ? Color.atlasPrimary : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Minutes per session
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Length")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack(spacing: 8) {
                            ForEach(minutesOptions, id: \.self) { mins in
                                Button(action: { minutesPerSession = mins }) {
                                    Text("\(mins)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(minutesPerSession == mins ? .atlasBackground : .atlasText)
                                        .frame(width: 50, height: 44)
                                        .background(minutesPerSession == mins ? Color.atlasPrimary : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Text("minutes")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    // Experience level
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Experience Level")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack(spacing: 8) {
                            ForEach(experienceOptions, id: \.self) { level in
                                Button(action: { experienceLevel = level }) {
                                    Text(level.capitalized)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(experienceLevel == level ? .atlasBackground : .atlasText)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(experienceLevel == level ? Color.atlasPrimary : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Equipment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Equipment")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        TextEditor(text: $equipment)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            .foregroundColor(.atlasText)
                            .scrollContentBackground(.hidden)
                        
                        Text("e.g., Full gym, dumbbells only, home gym with rack")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    // Constraints
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Constraints / Injuries")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        TextEditor(text: $constraints)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            .foregroundColor(.atlasText)
                            .scrollContentBackground(.hidden)
                        
                        Text("e.g., Lower back issues, recovering from shoulder surgery")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    // Note about changes
                    Text("Changes will be applied at your next weekly check-in")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAccent)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.atlasAccent.opacity(0.1))
                        .cornerRadius(10)
                    
                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle("Training Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.atlasTextMuted)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .foregroundColor(.atlasPrimary)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        daysPerWeek = profile.trainingDaysPerWeek ?? 4
        minutesPerSession = profile.trainingMinutesPerSession ?? 45
        experienceLevel = profile.experienceLevel ?? ""
        equipment = profile.availableEquipment ?? ""
        constraints = profile.trainingConstraints ?? ""
    }
    
    private func saveChanges() {
        profile.trainingDaysPerWeek = daysPerWeek
        profile.trainingMinutesPerSession = minutesPerSession
        profile.experienceLevel = experienceLevel.isEmpty ? nil : experienceLevel
        profile.availableEquipment = equipment.isEmpty ? nil : equipment
        profile.trainingConstraints = constraints.isEmpty ? nil : constraints
    }
}

// MARK: - Edit Goals View

struct EditGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    @Environment(\.unitFormatter) private var unitFormatter
    
    @State private var primaryGoal: String = ""
    @State private var secondaryGoal: String = ""
    @State private var goalWeight: String = ""
    
    let goalOptions: [(id: String, title: String, subtitle: String, icon: String)] = [
        ("live_longer", "Live Longer", "Maximize healthspan and lifespan", "heart.fill"),
        ("look_better", "Look Better", "Improve body composition and aesthetics", "figure.stand"),
        ("feel_better", "Feel Better", "Boost energy, mood, and recovery", "bolt.fill"),
        ("get_stronger", "Get Stronger", "Build strength and muscle", "figure.strengthtraining.traditional"),
        ("sport_performance", "Sport/Performance", "Train for specific sport or event", "trophy.fill")
    ]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Primary Goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Primary Goal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        ForEach(goalOptions, id: \.id) { goal in
                            GoalOptionRow(
                                title: goal.title,
                                subtitle: goal.subtitle,
                                icon: goal.icon,
                                isSelected: primaryGoal == goal.id,
                                isDisabled: secondaryGoal == goal.id
                            ) {
                                primaryGoal = goal.id
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                    
                    // Secondary Goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Secondary Goal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        ForEach(goalOptions, id: \.id) { goal in
                            GoalOptionRow(
                                title: goal.title,
                                subtitle: goal.subtitle,
                                icon: goal.icon,
                                isSelected: secondaryGoal == goal.id,
                                isDisabled: primaryGoal == goal.id
                            ) {
                                secondaryGoal = goal.id
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                    
                    // Goal Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Weight (optional)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        HStack {
                            TextField("175", text: $goalWeight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(atlasTextFieldStyle())
                            
                            Text(unitFormatter.weightUnit)
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    
                    // Note about changes
                    Text("Goal changes will be reflected at your next weekly check-in")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasAccent)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.atlasAccent.opacity(0.1))
                        .cornerRadius(10)
                    
                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.atlasTextMuted)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .foregroundColor(.atlasPrimary)
                .fontWeight(.semibold)
                .disabled(primaryGoal.isEmpty || secondaryGoal.isEmpty)
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        primaryGoal = profile.primaryGoal ?? ""
        secondaryGoal = profile.secondaryGoal ?? ""
        goalWeight = profile.goalWeight != nil ? "\(Int(profile.goalWeight!))" : ""
    }
    
    private func saveChanges() {
        profile.primaryGoal = primaryGoal.isEmpty ? nil : primaryGoal
        profile.secondaryGoal = secondaryGoal.isEmpty ? nil : secondaryGoal
        profile.goalWeight = Double(goalWeight)
    }
}

// MARK: - Goal Option Row

struct GoalOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.atlasPrimary.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasTextMuted)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasText)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.atlasPrimary)
                }
            }
            .padding(14)
            .background(isSelected ? Color.atlasPrimary.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.atlasPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}
// MARK: - Health Permissions View

struct HealthPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.atlasPrimary)
                
                Text("Apple Health")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text("atlas uses Apple Health to track your sleep, heart rate, and activity data.")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Button(action: openHealthSettings) {
                    Text("Open Health Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .background(Color.atlasPrimary)
                        .cornerRadius(12)
                }
                .padding(.top, 16)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationTitle("Health Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func openHealthSettings() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }

    
}


#Preview {
    ProfileView()
}