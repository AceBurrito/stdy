import SwiftUI
import SwiftData

struct SwapInterventionView: View {
    let currentHabit: Habit
    let onSwap: (InterventionTemplate) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { $0.isActive == true }) private var activeHabits: [Habit]
    
    @State private var selectedCategory: InterventionCategory? = nil
    @State private var confirmIntervention: InterventionTemplate? = nil
    
    // All interventions minus what's already active
    private var availableInterventions: [InterventionTemplate] {
        let activeIds = Set(activeHabits.compactMap { $0.interventionId })
        return InterventionLibrary.allInterventions.filter { intervention in
            !activeIds.contains(intervention.id) &&
            intervention.id != currentHabit.interventionId
        }
    }
    
    // Same-pillar recommendations (most relevant swaps)
    private var recommendedInterventions: [InterventionTemplate] {
        let currentPillar = currentHabit.pillar
        return availableInterventions
            .filter { $0.category.rawValue == currentPillar }
            .sorted { $0.baseImpactScore > $1.baseImpactScore }
    }
    
    // Filtered by selected category
    private var filteredInterventions: [InterventionTemplate] {
        guard let category = selectedCategory else {
            return availableInterventions.sorted { $0.baseImpactScore > $1.baseImpactScore }
        }
        return availableInterventions
            .filter { $0.category == category }
            .sorted { $0.baseImpactScore > $1.baseImpactScore }
    }
    
    private let categories: [InterventionCategory] = [
        .sleep, .nutrition, .recovery, .movement, .lifestyle
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Current habit being replaced
                        currentHabitCard
                        
                        // Recommended swaps (same pillar)
                        if !recommendedInterventions.isEmpty {
                            recommendedSection
                        }
                        
                        // Category filter
                        categoryFilter
                        
                        // Full library
                        librarySection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
                ToolbarItem(placement: .principal) {
                    Text("Swap Habit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.atlasText)
                }
            }
            .alert("Swap Habit?", isPresented: Binding(
                get: { confirmIntervention != nil },
                set: { if !$0 { confirmIntervention = nil } }
            )) {
                Button("Cancel", role: .cancel) { confirmIntervention = nil }
                Button("Swap") {
                    if let intervention = confirmIntervention {
                        onSwap(intervention)
                    }
                }
            } message: {
                if let intervention = confirmIntervention {
                    Text("Replace \"\(currentHabit.title)\" with \"\(intervention.title)\"? Your history for the old habit will be preserved.")
                }
            }
        }
    }
    
    // MARK: - Current Habit Card
    
    private var currentHabitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REPLACING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)
            
            HStack(spacing: 12) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasAccent.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentHabit.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(currentHabit.pillar)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
            }
            .padding(14)
            .background(Color.atlasAccent.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasAccent.opacity(0.15), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Recommended Section
    
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasPrimary)
                .tracking(1.5)
            
            ForEach(Array(recommendedInterventions.prefix(3))) { intervention in
                InterventionSwapRow(intervention: intervention) {
                    confirmIntervention = intervention
                }
            }
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL HABITS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryPill(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )
                    
                    ForEach(categories, id: \.self) { category in
                        CategoryPill(
                            title: category.rawValue,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Library Section
    
    private var librarySection: some View {
        VStack(spacing: 8) {
            ForEach(filteredInterventions) { intervention in
                InterventionSwapRow(intervention: intervention) {
                    confirmIntervention = intervention
                }
            }
            
            if filteredInterventions.isEmpty {
                Text("No additional habits available in this category.")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }
}

// MARK: - Intervention Swap Row

struct InterventionSwapRow: View {
    let intervention: InterventionTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: intervention.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.atlasPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.atlasPrimary.opacity(0.12))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(intervention.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(intervention.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Impact indicator
                Text("\(intervention.baseImpactScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.atlasPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .atlasBackground : .atlasTextMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.atlasPrimary : Color.white.opacity(0.06))
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
