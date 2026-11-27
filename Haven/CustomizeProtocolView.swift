// PERSONAL HABITS VIEW
// Simple add/delete for personal habits
// AI protocol changes now handled via Coaching Chat

import SwiftUI
import SwiftData

struct CustomizeProtocolView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<Habit> { $0.isActive == true && $0.habitType == "custom" }) private var personalHabits: [Habit]
    
    @State private var showingAddHabit = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PERSONAL HABITS")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.atlasPrimary.opacity(0.8))
                                .tracking(2)
                            
                            Text("Track habits outside your AI protocol. These won't affect your Pace score.")
                                .font(.system(size: 13))
                                .foregroundColor(.atlasTextMuted)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        
                        if personalHabits.isEmpty {
                            emptyState
                        } else {
                            habitsList
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Personal Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if personalHabits.count < 5 {
                        Button(action: { showingAddHabit = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.atlasPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddCustomHabitView()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        Button(action: { showingAddHabit = true }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.atlasPrimary.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add a personal habit")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    Text("Meditation, journaling, reading, etc.")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
    
    // MARK: - Habits List
    
    private var habitsList: some View {
        VStack(spacing: 12) {
            ForEach(personalHabits) { habit in
                PersonalHabitCard(habit: habit)
            }
            
            // Add more button
            if personalHabits.count < 5 {
                Button(action: { showingAddHabit = true }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Personal Habit")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.atlasPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.atlasPrimary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Personal Habit Card
struct PersonalHabitCard: View {
    let habit: Habit
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                if !habit.details.isEmpty {
                    Text(habit.details)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            Spacer()
            
            Button(action: { showingDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 1)
        )
        .alert("Remove Habit?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                habit.isActive = false
                try? modelContext.save()
            }
        } message: {
            Text("This will remove \"\(habit.title)\" from your personal habits.")
        }
    }
}

#Preview {
    CustomizeProtocolView()
}
