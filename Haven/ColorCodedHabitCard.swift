// ColorCodedHabitCard.swift
// Shared habit card component with color-coded left borders
// Coral for AI-assigned, Teal for Personal

import SwiftUI
import SwiftData

struct ColorCodedHabitCard: View {
    let habit: Habit
    var selectedDate: Date = Date()
    var allHabitsComplete: Bool = false
    
    @Environment(\.modelContext) private var modelContext
    @State private var isCompleted = false
    @State private var showingCardioLog = false
    @State private var showingWorkoutLog = false
    @State private var showingDetail = false
    @State private var isAnimating = false
    @State private var breathingOpacity: Double = 1.0
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    // Border color: coral when all habits done, otherwise type-based teal/amber
    private var borderColor: Color {
        if allHabitsComplete {
            return Color.atlasAccent
        }
        return habit.habitType == "custom" ? Color.atlasAmber : Color.atlasPrimary
    }
    
    // Badge text
    private var badgeText: String {
        habit.habitType == "custom" ? "Personal" : "AI"
    }
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 12) {
                // Left check circle
                ZStack {
                    if !isCompleted && isToday {
                        Circle()
                            .fill(borderColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .blur(radius: 6)
                            .opacity(breathingOpacity * 0.3)
                    }
                    
                    Circle()
                        .strokeBorder(borderColor.opacity(0.5), lineWidth: 2)
                        .background(
                            Circle()
                                .fill(isCompleted ? borderColor.opacity(0.25) : borderColor.opacity(0.08))
                        )
                        .frame(width: 38, height: 38)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(borderColor)
                    } else {
                        Image(systemName: iconForHabit)
                            .font(.system(size: 14))
                            .foregroundColor(borderColor.opacity(0.5))
                    }
                }
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                
                // Title + subtitle + badge
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        emphasizedTitle
                        
                        Spacer()
                        
                        // Badge - only for Personal habits
                        if habit.habitType == "custom" {
                            Text("Personal")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(borderColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(borderColor.opacity(0.15))
                                .cornerRadius(3)
                        }
                    }
                    
                    if !habit.details.isEmpty {
                        Text(habit.details)
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    if isToday && streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.atlasAccent)
                            Text("\(streak) day streak")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.atlasAccent)
                        }
                        .padding(.top, 1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isCompleted ? 0.02 : 0.04))
            )
            .overlay(
                // SHARP LEFT BORDER - like mockup
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: borderColor, location: 0.0),
                                .init(color: borderColor.opacity(0.8), location: 0.02),
                                .init(color: borderColor.opacity(0.5), location: 0.06),
                                .init(color: borderColor.opacity(0.2), location: 0.12),
                                .init(color: Color.clear, location: 0.18)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                    .animation(.easeInOut(duration: 0.5), value: allHabitsComplete)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(isCompleted ? 0.2 : 0.35),
                radius: isCompleted ? 5 : 7,
                x: 0,
                y: isCompleted ? 2 : 3
            )
            .opacity(isCompleted ? 0.75 : (isToday ? breathingOpacity : 0.7))
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Long press opens detail view (works anytime, even for past dates)
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showingDetail = true
                }
        )
        .onAppear {
            checkCompletionStatus()
            if !isCompleted && isToday {
                startBreathingAnimation()
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                stopBreathingAnimation()
            } else if isToday {
                startBreathingAnimation()
            }
        }
        .sheet(isPresented: $showingDetail) {
            HabitDetailView(habit: habit)
        }
        .sheet(isPresented: $showingCardioLog) {
            ManualCardioLogView(
                habit: habit,
                onComplete: {
                    checkCompletionStatus()
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                }
            )
        }
        .sheet(isPresented: $showingWorkoutLog) {
            WorkoutLogView(
                habit: habit,
                onComplete: {
                    checkCompletionStatus()
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                }
            )
        }
    }
    
    private var emphasizedTitle: some View {
        let components = parseHabitTitle(habit.title)
        return HStack(spacing: 0) {
            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                Text(component.text)
                    .font(.system(size: 16, weight: component.emphasized ? .bold : .medium))
                    .foregroundColor(component.emphasized ? .white : .atlasText)
            }
        }
    }
    
    private func parseHabitTitle(_ title: String) -> [(text: String, emphasized: Bool)] {
        var result: [(text: String, emphasized: Bool)] = []
        
        let words = title.split(separator: " ")
        for word in words {
            let wordStr = String(word)
            
            let shouldEmphasize = wordStr.contains(":") ||
                                  wordStr.last?.isLetter == false && wordStr.first?.isNumber == true ||
                                  (wordStr.first?.isNumber == true && wordStr.count <= 3)
            
            if result.isEmpty {
                result.append((text: wordStr, emphasized: shouldEmphasize))
            } else {
                result.append((text: " " + wordStr, emphasized: shouldEmphasize))
            }
        }
        
        return result
    }
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathingOpacity = 0.95
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            breathingOpacity = 1.0
        }
    }
    
    private func triggerCompletionAnimation() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = false
            }
        }
    }
    
    private var iconForHabit: String {
        if habit.isTrainingHabit {
            switch habit.trainingDayType {
            case "cardio": return "figure.run"
            case "strength": return "figure.strengthtraining.traditional"
            case "rest": return "moon.fill"
            default: return "circle"
            }
        }
        return "circle"
    }
    
    private var streak: Int {
        let dataController = DataController(modelContext: modelContext)
        return dataController.getHabitStreak(habit: habit)
    }
    
    private func checkCompletionStatus() {
        let dataController = DataController(modelContext: modelContext)
        isCompleted = dataController.isHabitComplete(habit: habit, on: selectedDate)
    }
    
    private func handleTap() {
        // Only allow tap completion for today (long press works anytime)
        guard isToday else { return }
        
        if isCompleted {
            let dataController = DataController(modelContext: modelContext)
            dataController.toggleHabitCompletion(habit: habit, date: selectedDate)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted = false
            }
            NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            return
        }
        
        if habit.isTrainingHabit {
            switch habit.trainingDayType {
            case "cardio":
                showingCardioLog = true
            case "strength":
                showingWorkoutLog = true
            case "rest":
                triggerCompletionAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let dataController = DataController(modelContext: modelContext)
                    dataController.markHabitComplete(habit, date: selectedDate)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isCompleted = true
                    }
                    NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
                }
            default:
                toggleCompletion()
            }
        } else {
            toggleCompletion()
        }
    }
    
    private func toggleCompletion() {
        triggerCompletionAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let dataController = DataController(modelContext: modelContext)
            dataController.toggleHabitCompletion(habit: habit, date: selectedDate)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted.toggle()
            }
            
            if isToday {
                NotificationCenter.default.post(name: Notification.Name("HabitStatusChanged"), object: nil)
            }
        }
    }
}