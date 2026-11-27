import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @State private var showingBodyGoal = false
    
    private var profile: UserProfile? {
        profiles.first
    }
    
    /// "15% · 172 lbs" or "Not set"
    private func bodyGoalText(_ profile: UserProfile) -> String {
        guard let target = profile.targetBodyFatPercent else { return "Not set" }
        let percent = String(format: "%.1f%%", target * 100)
        guard let weight = profile.goalWeight else { return percent }
        return percent + " · " + unitFormatter.displayWeightInt(weight)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Training setup (moved here from its own tab)
                            trainingSetupSection
                            
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
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingBodyGoal) { BodyGoalView() }
        }
    }    
    
    // MARK: - Training Setup Section
    
    private var trainingSetupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Training")
            
            VStack(spacing: 0) {
                NavigationLink(destination: TrainingProgramView()) {
                    profileRow(label: "Training Plan", value: "Schedule & routines")
                }
            }
            .background(Color.atlasCardDark)
            .cornerRadius(10)
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
                    profileRow(label: "Equipment", value: profile.availableEquipment == nil ? "Not set" : SteadyEquipment.from(profile.availableEquipment).title)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                NavigationLink(destination: EditTrainingPreferencesView(profile: profile)) {
                    profileRow(label: "Constraints", value: truncate(profile.trainingConstraints, length: 25))
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

   
    
// MARK: - Goals Section

private func goalsSection(profile: UserProfile) -> some View {
    VStack(alignment: .leading, spacing: 16) {
        sectionHeader("Goals")
        
        VStack(spacing: 0) {
            NavigationLink(destination: EditGoalsView(profile: profile)) {
                profileRow(label: "Goal", value: formatGoal(profile.primaryGoal))
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Button { showingBodyGoal = true } label: {
                profileRow(label: "Body Fat Goal", value: bodyGoalText(profile))
            }
            .buttonStyle(.plain)
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
            
            Toggle(isOn: weeklySummaryBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly summary")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasText)
                    Text("Sunday 6 PM: sessions, sets per muscle, new bests, weight trend")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .tint(.atlasPrimary)
            .padding(16)
            
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
    
    
    // MARK: - Weekly Summary Toggle

    @AppStorage(WeeklySummary.enabledKey) private var weeklySummaryEnabled = true

    private var weeklySummaryBinding: Binding<Bool> {
        Binding(
            get: { weeklySummaryEnabled },
            set: { enabled in
                weeklySummaryEnabled = enabled
                if enabled {
                    NotificationManager.shared.requestPermission { _ in
                        WeeklySummary.refresh(modelContext: modelContext, unitFormatter: unitFormatter)
                    }
                } else {
                    WeeklySummary.disable()
                }
            }
        )
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
        SteadyGoal.displayName(for: goal)
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
                        
                        ForEach(SteadyEquipment.allCases) { option in
                            SteadyOptionRow(
                                title: option.title,
                                subtitle: option.subtitle,
                                icon: option.icon,
                                isSelected: equipment == option.title
                            ) {
                                equipment = option.title
                            }
                        }
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
                    
                    Text("Plan recommendations use these. Your current plan stays until you change it.")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
        equipment = profile.availableEquipment.map { SteadyEquipment.from($0).title } ?? ""
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
    
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Goal
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Goal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                        
                        ForEach(SteadyGoal.allCases) { goal in
                            SteadyOptionRow(
                                title: goal.title,
                                subtitle: goal.subtitle,
                                icon: goal.icon,
                                isSelected: primaryGoal == goal.rawValue
                            ) {
                                primaryGoal = goal.rawValue
                            }
                        }
                    }
                    
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
                .disabled(primaryGoal.isEmpty)
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        primaryGoal = profile.primaryGoal ?? ""
        secondaryGoal = profile.secondaryGoal ?? ""
    }
    
    private func saveChanges() {
        profile.primaryGoal = primaryGoal.isEmpty ? nil : primaryGoal
        profile.secondaryGoal = nil
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
                
                Text("Recovery reads your sleep, HRV and resting heart rate from Apple Health. Weight, body fat and workouts come from there too.")
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