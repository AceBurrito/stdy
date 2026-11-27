import SwiftUI
import SwiftData

struct CoachingResultsHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklyCoachingResult.weekStartDate, order: .reverse) private var results: [WeeklyCoachingResult]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            if results.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(results) { result in
                            NavigationLink(destination: CoachingResultDetailView(result: result)) {
                                resultRow(result)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Weekly Reviews")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundColor(.atlasTextMuted.opacity(0.4))
            
            Text("No Reviews Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text("Complete your first weekly check-in to see your coaching analysis here.")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Result Row
    
    private func resultRow(_ result: WeeklyCoachingResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date range
            HStack {
                Text(weekRangeString(start: result.weekStartDate, end: result.weekEndDate))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                // Pace delta
                if let start = result.paceStart, let end = result.paceEnd {
                    let delta = end - start
                    HStack(spacing: 4) {
                        Image(systemName: delta <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(format: "%+.1f", delta))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(delta <= 0 ? .atlasPrimary : .atlasAccent)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
            }
            
            // Weekly focus preview
            if let focus = result.weeklyFocusText, !focus.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasAmber)
                    
                    Text(focus)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(2)
                }
            }
            
            // Biggest win preview
            if let win = result.biggestWinText, !win.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasPrimary)
                    
                    Text(win)
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func weekRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        
        return "\(startStr) – \(endStr)"
    }
}

// MARK: - Detail View (shows full coaching cards)

struct CoachingResultDetailView: View {
    let result: WeeklyCoachingResult
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 4) {
                        Text(weekRangeString(start: result.weekStartDate, end: result.weekEndDate))
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(.atlasText)
                        
                        if let start = result.paceStart, let end = result.paceEnd {
                            Text("Pace: \(String(format: "%.1f", start)) → \(String(format: "%.1f", end))")
                                .font(.system(size: 14))
                                .foregroundColor(.atlasTextMuted)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Coaching cards
                    let sections = result.decodeSections()
                    ForEach(sections) { section in
                        CoachingSectionCard(section: section)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Week Review")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func weekRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}