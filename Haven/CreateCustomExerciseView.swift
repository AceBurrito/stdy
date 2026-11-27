import SwiftUI
import SwiftData

// MARK: - Create Custom Exercise View
// Full-featured form for creating user exercises.
// Presented as a sheet from either ExercisePickerView or PlanExercisePickerView.
// After creation, the exercise is immediately returned via the onCreated callback
// so it can be added to the current workout/routine without requiring a second search.

struct CreateCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    /// Called with the new ExerciseDefinition after successful creation.
    let onCreated: (ExerciseDefinition) -> Void
    
    /// Pre-filled name from search text (if user searched for something not in library).
    var prefillName: String = ""
    
    @State private var name: String = ""
    @State private var selectedMuscleGroup: MuscleGroup = .chest
    @State private var selectedEquipment: Equipment = .dumbbell
    @State private var selectedCategory: ExerciseCategory = .compound
    @State private var isUnilateral: Bool = false
    @State private var isTimed: Bool = false
    @State private var defaultSets: Int = 3
    @State private var defaultReps: Int = 10
    @State private var showNameError: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Name
                        nameSection
                        
                        // Muscle Group
                        muscleGroupSection
                        
                        // Equipment
                        equipmentSection
                        
                        // Type (Compound / Isolation)
                        typeSection
                        
                        // Options
                        optionsSection
                        
                        // Defaults
                        defaultsSection
                        
                        // Create Button
                        createButton
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CREATE EXERCISE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1.5)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
            }
            .onAppear {
                if !prefillName.isEmpty {
                    name = prefillName
                }
            }
        }
    }
    
    // MARK: - Name Section
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXERCISE NAME")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            TextField("e.g. Nordic Curl", text: $name)
                .font(.system(size: 16))
                .foregroundColor(.atlasText)
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .onChange(of: name) { _, _ in
                    showNameError = false
                }
            
            if showNameError {
                Text("Exercise name is required")
                    .font(.system(size: 12))
                    .foregroundColor(.atlasAccent)
            }
        }
    }
    
    // MARK: - Muscle Group Section
    
    private var muscleGroupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLE GROUP")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MuscleGroup.allCases.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        Button {
                            selectedMuscleGroup = group
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: group.icon)
                                    .font(.system(size: 12))
                                Text(group.shortName)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(selectedMuscleGroup == group ? .atlasBackground : .atlasText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedMuscleGroup == group ? Color.atlasPrimary : Color.white.opacity(0.08))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Equipment Section
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EQUIPMENT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Equipment.allCases, id: \.self) { equip in
                        Button {
                            selectedEquipment = equip
                            // Auto-set bodyweight flag
                            if equip == .bodyweight {
                                isUnilateral = false
                            }
                        } label: {
                            Text(equip.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(selectedEquipment == equip ? .atlasBackground : .atlasText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedEquipment == equip ? Color.atlasPrimary : Color.white.opacity(0.08))
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Type Section
    
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            HStack(spacing: 0) {
                ForEach([ExerciseCategory.compound, ExerciseCategory.isolation], id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedCategory == cat ? .atlasBackground : .atlasTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedCategory == cat ? Color.atlasPrimary : Color.clear)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPTIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Toggle(isOn: $isUnilateral) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unilateral (per side)")
                        .font(.system(size: 15))
                        .foregroundColor(.atlasText)
                    Text("Tracks left and right sides separately")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .tint(.atlasPrimary)
            
            Toggle(isOn: $isTimed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timed (seconds instead of reps)")
                        .font(.system(size: 15))
                        .foregroundColor(.atlasText)
                    Text("For holds, carries, and timed exercises")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            .tint(.atlasPrimary)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Defaults Section
    
    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEFAULTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sets")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    HStack(spacing: 12) {
                        Button {
                            if defaultSets > 1 { defaultSets -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.atlasPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("\(defaultSets)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(.atlasText)
                            .frame(width: 36, alignment: .center)
                        
                        Button {
                            if defaultSets < 10 { defaultSets += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.atlasPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(isTimed ? "Seconds" : "Reps")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    HStack(spacing: 12) {
                        Button {
                            let step = isTimed ? 5 : 1
                            let min = isTimed ? 5 : 1
                            if defaultReps > min { defaultReps -= step }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.atlasPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("\(defaultReps)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(.atlasText)
                            .frame(width: 36, alignment: .center)
                        
                        Button {
                            let step = isTimed ? 5 : 1
                            let max = isTimed ? 120 : 30
                            if defaultReps < max { defaultReps += step }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.atlasPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        Button {
            createExercise()
        } label: {
            Text("Create Exercise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.atlasBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.atlasPrimary.opacity(0.4) : Color.atlasPrimary)
                .cornerRadius(12)
        }
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Create
    
    private func createExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            showNameError = true
            return
        }
        
        let custom = CustomExercise(
            name: trimmedName,
            muscleGroup: selectedMuscleGroup,
            category: selectedCategory,
            equipment: selectedEquipment,
            isBodyweight: selectedEquipment == .bodyweight,
            isUnilateral: isUnilateral,
            isTimed: isTimed,
            defaultSets: defaultSets,
            defaultReps: defaultReps
        )
        
        modelContext.insert(custom)
        
        do {
            try modelContext.save()
            print("✅ Custom exercise created: \(trimmedName)")
        } catch {
            print("❌ Failed to save custom exercise: \(error)")
        }
        
        // Return the ExerciseDefinition so the caller can immediately add it
        let definition = custom.toDefinition()
        onCreated(definition)
        dismiss()
    }
}