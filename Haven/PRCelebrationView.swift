import SwiftUI

struct PRCelebrationView: View {
    let prs: [(exercise: String, prs: [PersonalRecord])]
    let onDismiss: () -> Void
    
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Trophy icon with animation
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.steadyRaised)
                        .frame(width: 120, height: 120)
                        .scaleEffect(showConfetti ? 1.0 : 0.8)
                    
                    Image(systemName: "trophy")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundColor(.atlasAmber)
                        .scaleEffect(showConfetti ? 1.0 : 0.5)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showConfetti)
                
                // Title
                VStack(spacing: 8) {
                    Text("New best")
                        .font(SteadyType.display(34))
                        .foregroundColor(.atlasText)
                    
                    Text("You just set \(totalPRCount) new PR\(totalPRCount == 1 ? "" : "s")")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                }
                
                // PR Details
                VStack(spacing: 16) {
                    ForEach(Array(prs.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.exercise)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.atlasText)
                            
                            ForEach(Array(item.prs.enumerated()), id: \.offset) { prIndex, pr in
                                PRBadge(pr: pr)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.atlasPrimary.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.atlasPrimary.opacity(0.3), lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.atlasPrimary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                showConfetti = true
            }
        }
    }
    
    private var totalPRCount: Int {
        prs.reduce(0) { $0 + $1.prs.count }
    }
}

struct PRBadge: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let pr: PersonalRecord
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: prIcon)
                .font(.system(size: 20))
                .foregroundColor(.atlasPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(prTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                HStack(spacing: 4) {
                    if let previous = pr.previousRecord {
                        Text("\(formatValue(previous))")
                            .font(.system(size: 13))
                            .foregroundColor(.atlasTextMuted)
                            .strikethrough()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    Text(formatValue(pr.value))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
    }
    
    private var prIcon: String {
        switch pr.recordType {
        case "weight": return "scalemass.fill"
        case "reps": return "repeat"
        case "volume": return "chart.bar.fill"
        default: return "star.fill"
        }
    }
    
    private var prTitle: String {
        switch pr.recordType {
        case "weight": return "Max Weight"
        case "reps": return "Max Reps"
        case "volume": return "Total Volume"
        default: return "Personal Record"
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch pr.recordType {
        case "weight": return unitFormatter.displayWeightInt(value)
        case "reps": return "\(Int(value)) reps"
        case "volume": return unitFormatter.displayVolume(value)
        default: return "\(Int(value))"
        }
    }
}

#Preview {
    PRCelebrationView(
        prs: [(
            exercise: "Bench Press",
            prs: [
                PersonalRecord(exerciseName: "Bench Press", recordType: "weight", value: 225, date: Date())
            ]
        )],
        onDismiss: {}
    )
}