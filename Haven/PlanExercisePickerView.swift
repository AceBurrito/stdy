import SwiftUI
import SwiftData

// MARK: - Plan Exercise Picker View
// Lets users browse and select exercises from ExerciseLibrary + custom exercises.
// Used in the Build Your Own flow and routine builder.
//
// Features:
// - Search by name (library + custom)
// - Browse by muscle group
// - Browse by equipment
// - Create custom exercises via full form sheet
// - Custom exercises visually distinguished with "Custom" badge

struct PlanExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called when an exercise is selected
    let onSelect: (ExerciseDefinition) -> Void

    /// Optional: equipment filter based on user's gear
    var equipmentFilter: String?

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup? = nil
    @State private var selectedEquipment: Equipment? = nil
    @State private var browseMode: BrowseMode = .muscleGroup
    @State private var showCreateCustom = false

    enum BrowseMode: String, CaseIterable {
        case muscleGroup = "Muscle"
        case equipment = "Equipment"
    }

    private var filteredExercises: [ExerciseDefinition] {
        let all = ExerciseLibrary.allIncludingCustom(modelContext: modelContext)

        // Apply search
        if !searchText.isEmpty {
            return all.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply muscle group filter
        if browseMode == .muscleGroup, let group = selectedMuscleGroup {
            return all.filter { $0.muscleGroup == group }
        }

        // Apply equipment filter
        if browseMode == .equipment, let equip = selectedEquipment {
            return all.filter { $0.equipment == equip }
        }

        return all
    }
    
    /// Show the "Create Custom" option when search has no results,
    /// or always show it at the top of the list as an easy access point.
    private var showCreateCustomOption: Bool {
        !searchText.isEmpty && filteredExercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    browseToggle
                    categoryChips
                    exerciseList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ADD EXERCISE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1.5)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
            }
            .sheet(isPresented: $showCreateCustom) {
                CreateCustomExerciseView(
                    onCreated: { definition in
                        onSelect(definition)
                        dismiss()
                    },
                    prefillName: searchText
                )
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)

            TextField("Search exercises...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Browse Toggle

    private var browseToggle: some View {
        HStack(spacing: 0) {
            ForEach(BrowseMode.allCases, id: \.self) { mode in
                Button(action: {
                    browseMode = mode
                    selectedMuscleGroup = nil
                    selectedEquipment = nil
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(browseMode == mode ? .atlasBackground : .atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(browseMode == mode ? Color.atlasPrimary : Color.clear)
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if browseMode == .muscleGroup {
                    CategoryChip(
                        title: "All",
                        isSelected: selectedMuscleGroup == nil,
                        action: { selectedMuscleGroup = nil }
                    )

                    ForEach(MuscleGroup.allCases.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        CategoryChip(
                            title: group.rawValue,
                            isSelected: selectedMuscleGroup == group,
                            action: { selectedMuscleGroup = group }
                        )
                    }
                } else {
                    CategoryChip(
                        title: "All",
                        isSelected: selectedEquipment == nil,
                        action: { selectedEquipment = nil }
                    )

                    ForEach(Equipment.allCases, id: \.self) { equip in
                        CategoryChip(
                            title: equip.rawValue,
                            isSelected: selectedEquipment == equip,
                            action: { selectedEquipment = equip }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                // Create Custom button — always visible at top
                createCustomButton
                
                if filteredExercises.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.atlasTextMuted.opacity(0.3))
                        Text("No exercises found")
                            .font(.system(size: 15))
                            .foregroundColor(.atlasTextMuted)
                        Text("Create a custom exercise instead")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted.opacity(0.7))
                    }
                    .padding(.top, 40)
                } else if filteredExercises.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.atlasTextMuted.opacity(0.3))
                        Text("No exercises found")
                            .font(.system(size: 15))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(filteredExercises) { exercise in
                        PlanExercisePickerRow(exercise: exercise, isCustom: ExerciseLibrary.isCustomExercise(id: exercise.id)) {
                            onSelect(exercise)
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Create Custom Button
    
    private var createCustomButton: some View {
        Button {
            showCreateCustom = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Custom Exercise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                    Text("Add an exercise not in the library")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.atlasPrimary.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.bottom, 4)
    }
}

// MARK: - Plan Exercise Picker Row (with custom badge)

struct PlanExercisePickerRow: View {
    let exercise: ExerciseDefinition
    let isCustom: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Compound/isolation indicator
                Circle()
                    .fill(exercise.isCompound ? Color.atlasPrimary : Color.atlasAmber)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.atlasText)
                        
                        if isCustom {
                            Text("Custom")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.atlasAmber)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.atlasAmber.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(exercise.muscleGroup.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)

                        Text("·")
                            .foregroundColor(.atlasTextMuted.opacity(0.3))

                        Text(exercise.equipment.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.atlasPrimary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .atlasBackground : .atlasTextMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.atlasPrimary : Color.white.opacity(0.06))
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}