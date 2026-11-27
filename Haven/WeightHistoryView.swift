import SwiftUI
import SwiftData

struct WeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var entries: [BodyCompEntry]
    @Query private var profiles: [UserProfile]

    @State private var showingAddWeight = false

    private var userProfile: UserProfile? { profiles.first }

    private var sevenDayAverage: Double {
        let recent = Array(entries.prefix(7))
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0.0) { $0 + $1.weight } / Double(recent.count)
    }

    private var thirtyDayChange: Double {
        guard entries.count >= 2 else { return 0 }
        let recent = entries[0].weight
        let older = entries[min(29, entries.count - 1)].weight
        return recent - older
    }

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    summarySection
                    historySection
                }
                .padding(24)
            }
        }
        .navigationTitle("Weight History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddWeight = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAddWeight) {
            AddWeightView()
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("7-DAY AVG")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)

                Text(unitFormatter.displayWeight(sevenDayAverage))
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.atlasText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.atlasPrimary.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("30-DAY CHANGE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasTextMuted)
                    .tracking(1.5)

                HStack(spacing: 4) {
                    Image(systemName: thirtyDayChange > 0 ? "arrow.up.right" : thirtyDayChange < 0 ? "arrow.down.right" : "minus")
                        .font(.system(size: 16))

                    Text(unitFormatter.displayWeight(abs(thirtyDayChange)))
                        .font(.system(size: 28, weight: .light))
                }
                .foregroundColor(thirtyDayChange > 0 ? .red : thirtyDayChange < 0 ? .green : .atlasText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
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
                        WeightEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scalemass")
                .font(.system(size: 40))
                .foregroundColor(.atlasTextMuted.opacity(0.5))

            Text("No weight entries yet")
                .font(.system(size: 16))
                .foregroundColor(.atlasTextMuted)

            Button(action: { showingAddWeight = true }) {
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

#Preview {
    NavigationStack {
        WeightHistoryView()
    }
}