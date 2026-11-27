import SwiftUI
import SwiftData

struct ProteinHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProteinEntry.date, order: .reverse) private var entries: [ProteinEntry]
    @Query private var profiles: [UserProfile]
    
    @State private var showingLogSheet = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private var proteinGoal: Int? {
        userProfile?.proteinGoal
    }
    
    private var sevenDayAverage: Int {
        let recentEntries = entries.prefix(7)
        guard !recentEntries.isEmpty else { return 0 }
        let total = recentEntries.reduce(0) { $0 + $1.grams }
        return total / recentEntries.count
    }
    
    private var daysHitGoal: Int {
        guard let goal = proteinGoal else { return 0 }
        let threshold = Double(goal) * 0.85
        return entries.prefix(7).filter { Double($0.grams) >= threshold }.count
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Summary cards
                    summarySection
                    
                    // History list
                    historySection
                }
                .padding(24)
            }
        }
        .navigationTitle("Protein Intake")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingLogSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .sheet(isPresented: $showingLogSheet) {
            ProteinLogSheet()
        }
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 7-day average
                SummaryCard(
                    title: "7-Day Avg",
                    value: "\(sevenDayAverage)g",
                    subtitle: proteinGoal != nil ? "Goal: \(proteinGoal!)g" : nil,
                    color: .atlasPrimary
                )
                
                // Days hit goal
                if proteinGoal != nil {
                    SummaryCard(
                        title: "Days on Target",
                        value: "\(daysHitGoal)/7",
                        subtitle: "Last 7 days",
                        color: daysHitGoal >= 5 ? .green : .orange
                    )
                }
            }
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HISTORY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            if entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        ProteinEntryRow(entry: entry, goal: proteinGoal)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundColor(.atlasTextMuted.opacity(0.5))
            
            Text("No protein entries yet")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)
            
            Button(action: { showingLogSheet = true }) {
                Text("Log Your First Entry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(1.5)
            
            Text(value)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.atlasText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Protein Entry Row
struct ProteinEntryRow: View {
    let entry: ProteinEntry
    let goal: Int?
    
    private var hitGoal: Bool {
        guard let goal = goal else { return false }
        return Double(entry.grams) >= Double(goal) * 0.85
    }
    
    private var percentage: Int {
        guard let goal = goal, goal > 0 else { return 0 }
        return Int((Double(entry.grams) / Double(goal)) * 100)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                if entry.isEstimated {
                    Text("Estimated")
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Text("\(entry.grams)g")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.atlasText)
                
                if goal != nil {
                    HStack(spacing: 4) {
                        Text("\(percentage)%")
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: hitGoal ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(hitGoal ? .green : .atlasTextMuted)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationView {
        ProteinHistoryView()
    }
}
