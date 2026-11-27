import SwiftUI
import SwiftData

// MARK: - Strength Percentile Card
// Shows the same strength percentile that feeds the Pace score's strength component.
// Includes progress bar, last assessment date, and reassess button.

struct StrengthPercentileCard: View {
    let percentile: Int?
    let lastAssessmentDate: Date?
    let dataSource: String?
    let onReassess: () -> Void
    
    private var isDueForReassessment: Bool {
        guard let date = lastAssessmentDate else { return false }
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince >= 30
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STRENGTH PERCENTILE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            if let pct = percentile {
                // Percentile bar + value
                HStack(spacing: 14) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tierColor(for: pct))
                                .frame(width: geo.size.width * CGFloat(pct) / 100)
                        }
                    }
                    .frame(height: 8)
                    
                    // Percentile label
                    Text(ordinal(pct))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.atlasText)
                        .frame(minWidth: 50, alignment: .trailing)
                }
                
                // Source note
                VStack(alignment: .leading, spacing: 4) {
                    if dataSource == "workoutDerived" {
                        Text("Estimated from your workout data")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    } else {
                        Text("Based on your strength assessment")
                            .font(.system(size: 12))
                            .foregroundColor(.atlasTextMuted)
                    }
                    
                    if let date = lastAssessmentDate {
                        HStack(spacing: 4) {
                            Text("Last assessed: \(date.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(.system(size: 12))
                                .foregroundColor(.atlasTextMuted.opacity(0.7))
                            
                            if isDueForReassessment {
                                Text("· Due for reassessment")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.atlasAmber)
                            }
                        }
                    }
                }
                
                // Reassess button
                Button(action: onReassess) {
                    Text(isDueForReassessment ? "Reassess" : "Retake Assessment")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.atlasPrimary.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
                
            } else {
                // No assessment data — empty state
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete a strength assessment to see your percentile and improve your Pace score.")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                    
                    Button(action: onReassess) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 14))
                            Text("Take Assessment")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.atlasBackground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.atlasPrimary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func tierColor(for percentile: Int) -> Color {
        switch percentile {
        case 0..<25: return .atlasAccent      // Coral — below average
        case 25..<50: return .atlasAmber       // Amber — average
        case 50..<75: return .atlasPrimary     // Teal — above average
        default: return Color(hex: "#4ECDC4")  // Bright teal — excellent
        }
    }
    
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        VStack(spacing: 16) {
            StrengthPercentileCard(
                percentile: 62,
                lastAssessmentDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()),
                dataSource: "workoutDerived",
                onReassess: {}
            )
            
            StrengthPercentileCard(
                percentile: nil,
                lastAssessmentDate: nil,
                dataSource: nil,
                onReassess: {}
            )
        }
        .padding(24)
    }
}