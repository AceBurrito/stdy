import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    @State private var showSwapSheet = false
    
    private var borderColor: Color {
        habit.habitType == "custom" ? Color.atlasAmber : Color.atlasPrimary
    }
    
    private var badgeText: String {
        habit.habitType == "custom" ? "Personal" : "AI"
    }
    
    // Don't show swap for training habits or custom/personal habits
    private var canSwap: Bool {
        habit.habitType == "non_negotiable" && !habit.isTrainingHabit
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with habit info
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                    
                    // Tab selector
                    tabSelector
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    
                    // Tab content
                    TabView(selection: $selectedTab) {
                        HabitGuideTab(habit: habit)
                            .tag(0)
                        
                        HabitHistoryTab(habit: habit)
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Swap button at bottom (AI habits only)
                    if canSwap {
                        swapButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.atlasPrimary)
                }
            }
            .sheet(isPresented: $showSwapSheet) {
                SwapInterventionView(
                    currentHabit: habit,
                    onSwap: { newIntervention in
                        performSwap(with: newIntervention)
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(habit.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Text(badgeText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(borderColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(borderColor.opacity(0.15))
                    .cornerRadius(6)
            }
            
            if !habit.details.isEmpty {
                Text(habit.details)
                    .font(.system(size: 15))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(4)
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "Guide", isSelected: selectedTab == 0) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            }
            
            TabButton(title: "History", isSelected: selectedTab == 1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Swap Button
    
    private var swapButton: some View {
        Button(action: { showSwapSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Swap Habit")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.atlasAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.atlasAmber.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasAmber.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Perform Swap
    
    private func performSwap(with intervention: InterventionTemplate) {
        // Deactivate old habit
        habit.isActive = false
        
        // Create new habit from intervention
        let newHabit = Habit(
            title: intervention.title,
            details: intervention.whyTemplate,
            pillar: intervention.category.rawValue,
            habitType: "non_negotiable",
            howToGuide: intervention.howToGuide,
            researchCitation: intervention.researchCitation,
            interventionId: intervention.id
        )
        newHabit.userProfile = habit.userProfile
        modelContext.insert(newHabit)
        
        do {
            try modelContext.save()
            print("✅ Swapped habit: \(habit.title) → \(intervention.title)")
            NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
        } catch {
            print("❌ Failed to swap habit: \(error)")
        }
    }
}

// MARK: - Tab Button (keep existing if already defined elsewhere, otherwise include here)
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .atlasBackground : .atlasTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.atlasPrimary : Color.clear
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, configurations: config)
    let context = container.mainContext
    
    let habit = Habit(
        title: "Morning Sunlight",
        details: "Morning sunlight exposure anchors your circadian rhythm.",
        pillar: "Sleep",
        howToGuide: "Step outside for 10 minutes within 1 hour of waking.",
        researchCitation: "Zeitzer et al. (2000): PMID 10742677",
        interventionId: "morning_sunlight_exposure"
    )
    context.insert(habit)
    
    return HabitDetailView(habit: habit)
        .modelContainer(container)
        .environmentObject(PurchaseManager.shared)
}
