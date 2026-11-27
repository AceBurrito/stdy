// WeightHistoryView.swift
// Steady — every body comp entry, newest first. Tap to edit, swipe to delete.

import SwiftUI
import SwiftData

struct WeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.unitFormatter) private var unitFormatter
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var entries: [BodyCompEntry]

    @State private var showingAdd = false
    @State private var editing: BodyCompEntry? = nil

    /// Entries grouped by month, newest month first
    private var sections: [(title: String, entries: [BodyCompEntry])] {
        let calendar = Calendar.current
        var result: [(String, [BodyCompEntry])] = []
        var currentKey: DateComponents? = nil
        for entry in entries {
            let key = calendar.dateComponents([.year, .month], from: entry.date)
            if key != currentKey {
                result.append((entry.date.formatted(.dateTime.month(.wide).year()), []))
                currentKey = key
            }
            result[result.count - 1].1.append(entry)
        }
        return result
    }

    var body: some View {
        List {
            if entries.isEmpty {
                Text("No entries yet.")
                    .font(SteadyType.body)
                    .foregroundColor(.atlasTextMuted)
                    .listRowBackground(Color.atlasCardDark)
            }
            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.entries) { entry in
                        Button { editing = entry } label: {
                            WeightEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.atlasCardDark)
                        .listRowSeparatorTint(Color.steadyHairline)
                    }
                    .onDelete { offsets in
                        delete(offsets.map { section.entries[$0] })
                    }
                } header: {
                    Text(section.title).steadyLabel()
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddWeightView() }
        .sheet(item: $editing) { entry in AddWeightView(entry: entry) }
    }

    private func delete(_ toDelete: [BodyCompEntry]) {
        toDelete.forEach { modelContext.delete($0) }
        try? modelContext.save()
        BodyProfileSync.apply(modelContext: modelContext)
        WidgetSync.refresh(modelContext: modelContext, unitFormatter: unitFormatter)
    }
}

#Preview {
    NavigationStack {
        WeightHistoryView()
    }
}
