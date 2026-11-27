// MARK: - TrainingDayPanel
// Rich training preview for today's workout. Lives in a swipeable TabView alongside habits.
// Shows exercise list with last-session data for strength days, zone targets for cardio days,
// and recovery messaging for rest days. Includes a direct action button to start logging.

import SwiftUI
import SwiftData

struct TrainingDayPanel: View {
    let todaysWorkout: PlannedWorkoutDay?
    let trainingHabit: Habit?
    let isCompleted: Bool
    
    // Last session context
    let lastSessionVolume: Double?
    let lastSessionDate: Date?
    let lastCardioSession: CardioSession?
    
    // Actions
    let onStartWorkout: () -> Void
    let onStartCardio: () -> Void
    let onMarkRestComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    private var dayType: String {
        todaysWorkout?.dayType ?? trainingHabit?.trainingDayType ?? "rest"
    }
    
    private var dayName: String {
        todaysWorkout?.dayName ?? trainingHabit?.title ?? "Rest Day"
    }
    
    private var exercises: [PlannedExercise] {
        todaysWorkout?.exercises.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
            
            // Content varies by day type
            switch dayType {
            case "strength":
                strengthContent
            case "cardio":
                cardioContent
            default:
                restContent
            }
            
            // Action button
            if !isCompleted {
                actionButton
            } else {
                completedBanner
            }
        }
        .background(Color.atlasCardDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isCompleted
                        ? Color.atlasPrimary.opacity(0.2)
                        : Color.atlasPrimary.opacity(0.12),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.atlasPrimary.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForDayType)
                    .font(.system(size: 17))
                    .foregroundColor(.atlasPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S TRAINING")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)
                
                Text(dayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.atlasText)
            }
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.atlasPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
    
    // MARK: - Strength Day Content
    
    private var strengthContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Exercise list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(exercises.prefix(5).enumerated()), id: \.element.id) { index, exercise in
                    HStack(spacing: 0) {
                        Text(exercise.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText.opacity(0.85))
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        // Target sets × reps
                        if let reps = exercise.targetReps {
                            Text("\(exercise.targetSets) × \(reps)")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                }
                
                if exercises.count > 5 {
                    Text("+ \(exercises.count - 5) more")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            // Last session context
            if let volume = lastSessionVolume, volume > 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                    
                    Text("Last session: \(formatVolume(volume)) total volume")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.atlasTextMuted.opacity(0.6))
                    
                    if let date = lastSessionDate {
                        Text("· \(relativeDate(date))")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }
    
    // MARK: - Cardio Day Content
    
    private var cardioContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 12) {
                // Zone target
                if let workout = todaysWorkout {
                    if let hrMin = workout.targetHRMin, let hrMax = workout.targetHRMax {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TARGET HR")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.atlasTextMuted)
                                    .tracking(1)
                                
                                Text("\(hrMin)–\(hrMax) bpm")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.atlasPrimary)
                            }
                            
                            Spacer()
                            
                            if let duration = workout.cardioDuration {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("DURATION")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.atlasTextMuted)
                                        .tracking(1)
                                    
                                    Text("\(duration) min")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.atlasText)
                                }
                            }
                        }
                    }
                    
                    // Cardio protocol or notes
                    if let proto = workout.cardioProtocol, !proto.isEmpty {
                        Text(proto)
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                            .lineSpacing(2)
                    }
                    
                    if let notes = workout.cardioNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                
                // Last cardio session
                if let lastCardio = lastCardioSession {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted.opacity(0.5))
                        
                        var parts: [String] {
                            var p: [String] = []
                            p.append("\(lastCardio.duration) min")
                            if let hr = lastCardio.avgHeartRate {
                                p.append("\(Int(hr)) bpm avg")
                            }
                            if let dist = lastCardio.distance, dist > 0 {
                                p.append(String(format: "%.1f mi", dist))
                            }
                            return p
                        }
                        
                        Text("Last: " + parts.joined(separator: " · "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.atlasTextMuted.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
    
    // MARK: - Rest Day Content
    
    private var restContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery is when you actually get stronger. Trust the process.")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(3)
                
                HStack(spacing: 16) {
                    restSuggestion(icon: "figure.walk", text: "Light walk")
                    restSuggestion(icon: "figure.flexibility", text: "Stretch")
                    restSuggestion(icon: "bed.double.fill", text: "Sleep early")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
    
    private func restSuggestion(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.atlasPrimary.opacity(0.5))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.atlasTextMuted.opacity(0.6))
        }
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        Button(action: {
            switch dayType {
            case "strength": onStartWorkout()
            case "cardio": onStartCardio()
            default: onMarkRestComplete()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: dayType == "rest" ? "checkmark" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(actionLabel)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.atlasBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.atlasPrimary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }
    
    private var completedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.atlasPrimary)
            
            Text(dayType == "rest" ? "Rest day logged" : "Workout complete")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
    
    private var actionLabel: String {
        switch dayType {
        case "strength": return "Start Workout"
        case "cardio": return "Log Cardio"
        default: return "Mark Rest Day Complete"
        }
    }
    
    private var iconForDayType: String {
        switch dayType {
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio": return "figure.run"
        default: return "moon.fill"
        }
    }
    
    // MARK: - Helpers
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }
    
    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days) days ago" }
        return "\(days / 7)w ago"
    }
}

// MARK: - No Training Panel (shown when no training today)

struct NoTrainingPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.atlasTextMuted.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "moon.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S TRAINING")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1.5)
                    
                    Text("No workout scheduled")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                }
                
                Spacer()
            }
            
            Text("Focus on your habits today. Recovery matters.")
                .font(.system(size: 13))
                .foregroundColor(.atlasTextMuted.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.atlasCardDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.atlasTextMuted.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        TrainingDayPanel(
            todaysWorkout: nil,
            trainingHabit: nil,
            isCompleted: false,
            lastSessionVolume: 12400,
            lastSessionDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            lastCardioSession: nil,
            onStartWorkout: {},
            onStartCardio: {},
            onMarkRestComplete: {}
        )
        .padding(.horizontal, 20)
    }
}