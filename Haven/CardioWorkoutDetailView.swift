// New file: CardioWorkoutDetailView.swift
import SwiftUI
import SwiftData

struct CardioWorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    
    @Bindable var workoutDay: PlannedWorkoutDay
    
    @State private var editedDuration: String = ""
    @State private var editedModality: String = ""
    @State private var isEditing = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var isZone2: Bool {
        workoutDay.cardioType?.lowercased() == "zone2"
    }
    
    private var isVO2Max: Bool {
        workoutDay.cardioType?.lowercased() == "vo2max" || 
        workoutDay.cardioType?.lowercased() == "hiit"
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if isZone2 {
                        zone2Section
                    } else if isVO2Max {
                        vo2MaxSection
                    } else {
                        generalCardioSection
                    }
                    
                    if isEditing {
                        editingSection
                    } else {
                        editButton
                    }
                    
                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle(workoutDay.dayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editedDuration = String(workoutDay.cardioDuration ?? 30)
            editedModality = "" // No default, user chooses
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day label
            Text(dayFullName.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            // Workout name with zone pill
            HStack(spacing: 12) {
                Text(workoutDay.dayName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.atlasText)
                
                if let cardioType = workoutDay.cardioType {
                    zonePill(cardioType)
                }
            }
            
            // Duration
            if let duration = workoutDay.cardioDuration {
                Text("\(duration) minutes")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Zone 2 Section
    private var zone2Section: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Target HR Zone
            heartRateZoneCard
            
            // Modality Options
            modalityOptionsCard
            
            // Guidance
            if let notes = workoutDay.cardioNotes {
                guidanceCard(notes)
            }
        }
    }
    
    // MARK: - VO2 Max Section
    private var vo2MaxSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Interval Structure
            if let protocolText = workoutDay.cardioProtocol {
                intervalStructureCard(protocolText)
            }
            
            // Target HR Zone
            heartRateZoneCard
            
            // Workout Examples
            vo2MaxExamplesCard
            
            // Guidance
            if let notes = workoutDay.cardioNotes {
                guidanceCard(notes)
            }
        }
    }
    
    // MARK: - General Cardio Section
    private var generalCardioSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let notes = workoutDay.cardioNotes {
                guidanceCard(notes)
            }
            
            if workoutDay.targetHRMin != nil {
                heartRateZoneCard
            }
        }
    }
    
    // MARK: - Components
    
    private func zonePill(_ type: String) -> some View {
        Text(formatZoneType(type))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.atlasBackground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(colorForZone(type))
            .cornerRadius(6)
    }
    
    private var heartRateZoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("TARGET HEART RATE")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .tracking(1.5)
            }
            
            if let min = workoutDay.targetHRMin, let max = workoutDay.targetHRMax {
                HStack(spacing: 4) {
                    Text("\(min)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                    
                    Text("–")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text("\(max)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.atlasPrimary)
                    
                    Text("bpm")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.leading, 4)
                }
                
                if isZone2 {
                    Text("Conversational pace – you should be able to talk in full sentences")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.top, 4)
                } else if isVO2Max {
                    Text("Hard effort – you should feel breathless during intervals")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var modalityOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.atlasAccent)
                Text("MODALITY OPTIONS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .tracking(1.5)
            }
            
            Text("Choose any activity that keeps you in the target heart rate zone:")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .padding(.bottom, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                modalityOption("Running", icon: "figure.run")
                modalityOption("Cycling", icon: "figure.outdoor.cycle")
                modalityOption("Rowing", icon: "figure.rower")
                modalityOption("Swimming", icon: "figure.pool.swim")
                modalityOption("Elliptical", icon: "figure.elliptical")
                modalityOption("Walking", icon: "figure.walk")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func modalityOption(_ name: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.atlasAccent)
            
            Text(name)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
   private func intervalStructureCard(_ protocolText: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundColor(.orange)
            Text("INTERVAL STRUCTURE")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.atlasText)
                .tracking(1.5)
        }
        
        Text(protocolText)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.atlasPrimary)
        
        Text("After a 5-10 minute warmup, perform these intervals:")
            .font(.system(size: 14))
            .foregroundColor(.atlasTextMuted)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.1))
    .cornerRadius(12)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
    )
}
    
    private var vo2MaxExamplesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.atlasAccent)
                Text("EXAMPLE WORKOUTS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .tracking(1.5)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                exampleWorkout("Run: Track or treadmill intervals")
                exampleWorkout("Bike: Indoor trainer or outdoor hills")
                exampleWorkout("Row: Erg intervals with full recovery")
                exampleWorkout("Any modality where you can go hard and recover")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func exampleWorkout(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.atlasAccent)
                .frame(width: 6, height: 6)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
        }
    }
    
    private func guidanceCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("GUIDANCE")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasText)
                    .tracking(1.5)
            }
            
            Text(notes)
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Editing Section
    private var editingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            Text("EDIT WORKOUT")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(1.5)
            
            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration (minutes)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                TextField("Minutes", text: $editedDuration)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .foregroundColor(.atlasText)
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // Modality (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Modality (optional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                TextField("e.g., Running, Cycling, Rowing", text: $editedModality)
                    .font(.system(size: 16))
                    .foregroundColor(.atlasText)
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // Save/Cancel
            HStack(spacing: 12) {
                Button(action: {
                    isEditing = false
                    // Reset to original
                    editedDuration = String(workoutDay.cardioDuration ?? 30)
                    editedModality = ""
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: saveChanges) {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.atlasPrimary)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private var editButton: some View {
        Button(action: { isEditing = true }) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                
                Text("Edit Workout")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.atlasPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.atlasPrimary.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helpers
    
    private var dayFullName: String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard workoutDay.dayOfWeek >= 0 && workoutDay.dayOfWeek < days.count else { return "" }
        return days[workoutDay.dayOfWeek]
    }
    
    private func formatZoneType(_ type: String) -> String {
        switch type.lowercased() {
        case "zone2": return "ZONE 2"
        case "vo2max", "hiit": return "VO2 MAX"
        case "tempo": return "TEMPO"
        default: return type.uppercased()
        }
    }
    
    private func colorForZone(_ type: String) -> Color {
        switch type.lowercased() {
        case "zone2": return .atlasPrimary
        case "vo2max", "hiit": return .orange
        case "tempo": return .yellow
        default: return .atlasAccent
        }
    }
    
    private func saveChanges() {
        if let duration = Int(editedDuration) {
            workoutDay.cardioDuration = duration
        }
        
        // Optionally save modality preference in notes
        if !editedModality.isEmpty {
            let existingNotes = workoutDay.cardioNotes ?? ""
            workoutDay.cardioNotes = "Preferred: \(editedModality). " + existingNotes
        }
        
        do {
            try modelContext.save()
            print("✅ Saved cardio workout changes")
            isEditing = false
        } catch {
            print("❌ Failed to save: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PlannedWorkoutDay.self, configurations: config)
    
    let workout = PlannedWorkoutDay(
        dayType: "cardio",
        dayName: "30 min Cardio",
        dayOfWeek: 2
    )
    workout.cardioType = "zone2"
    workout.cardioDuration = 30
    workout.targetHRMin = 125
    workout.targetHRMax = 145
    workout.cardioNotes = "Stay conversational. You should be able to talk in full sentences throughout."
    
    container.mainContext.insert(workout)
    
    return NavigationStack {
        CardioWorkoutDetailView(workoutDay: workout)
            .modelContainer(container)
    }
}
