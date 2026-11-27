import SwiftUI
import SwiftData

struct DayReassignmentView: View {
    let workout: PlannedWorkoutDay
    let allWorkouts: [PlannedWorkoutDay]
    let onSelect: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let daysOfWeek = [
        (0, "Sunday"),
        (1, "Monday"),
        (2, "Tuesday"),
        (3, "Wednesday"),
        (4, "Thursday"),
        (5, "Friday"),
        (6, "Saturday")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                List {
                    ForEach(daysOfWeek, id: \.0) { dayIndex, dayName in
                        let isCurrent = dayIndex == workout.dayOfWeek
                        let existingWorkout = allWorkouts.first(where: { $0.dayOfWeek == dayIndex && $0.id != workout.id })
                        
                        Button {
                            if !isCurrent {
                                onSelect(dayIndex)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(dayName)
                                    .font(.system(size: 16, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(isCurrent ? .atlasPrimary : .atlasText)
                                
                                Spacer()
                                
                                if isCurrent {
                                    Text("Current")
                                        .font(.system(size: 14))
                                        .foregroundColor(.atlasPrimary)
                                } else if let existing = existingWorkout {
                                    Text(existing.dayName)
                                        .font(.system(size: 14))
                                        .foregroundColor(.atlasTextMuted)
                                } else {
                                    Text("Rest Day")
                                        .font(.system(size: 14))
                                        .foregroundColor(.atlasTextMuted.opacity(0.6))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(isCurrent)
                        .listRowBackground(Color.atlasCardDark)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Move \(workout.dayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasPrimary)
                }
            }
        }
    }
}
