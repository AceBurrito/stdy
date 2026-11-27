import SwiftUI
import SwiftData

// MARK: - User Input for Personalized Interventions
// Shown as a sheet when user selects an intervention that requires custom input
// (e.g., Daily Skill Practice, Creative Flow Time)

struct InterventionUserInputSheet: View {
    let intervention: Intervention
    let template: InterventionTemplate
    let onSave: (String, Int) -> Void  // (customName, durationMinutes)
    @Environment(\.dismiss) private var dismiss
    
    @State private var customName: String = ""
    @State private var selectedDuration: Int
    @FocusState private var isNameFocused: Bool
    
    init(intervention: Intervention, template: InterventionTemplate, onSave: @escaping (String, Int) -> Void) {
        self.intervention = intervention
        self.template = template
        self.onSave = onSave
        // Default to middle option
        let options = template.userInputDurationOptions ?? [15, 20, 30]
        _selectedDuration = State(initialValue: options[options.count / 2])
    }
    
    private var canSave: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.atlasPrimary.opacity(0.15))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: intervention.icon)
                            .font(.system(size: 28))
                            .foregroundColor(.atlasPrimary)
                    }
                    
                    Text("Make it yours")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.atlasText)
                    
                    Text(template.userInputPrompt ?? "What will you commit to?")
                        .font(.system(size: 16))
                        .foregroundColor(.atlasTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR ACTIVITY")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.atlasTextMuted)
                        .tracking(1)
                    
                    TextField(
                        template.userInputPlaceholder ?? "Enter activity...",
                        text: $customName
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundColor(.atlasText)
                    .focused($isNameFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isNameFocused ? Color.atlasPrimary : Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                
                // Duration picker
                if let options = template.userInputDurationOptions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DAILY COMMITMENT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1)
                        
                        HStack(spacing: 10) {
                            ForEach(options, id: \.self) { minutes in
                                Button(action: { selectedDuration = minutes }) {
                                    Text("\(minutes) min")
                                        .font(.system(size: 15, weight: selectedDuration == minutes ? .semibold : .regular))
                                        .foregroundColor(selectedDuration == minutes ? .atlasBackground : .atlasText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedDuration == minutes ?
                                            Color.atlasPrimary : Color.white.opacity(0.05)
                                        )
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    selectedDuration == minutes ? Color.clear : Color.white.opacity(0.1),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Preview of what the habit card will look like
                if canSave {
                    VStack(spacing: 8) {
                        Text("YOUR HABIT CARD")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                            .tracking(1)
                        
                        HStack(spacing: 12) {
                            Image(systemName: intervention.icon)
                                .font(.system(size: 20))
                                .foregroundColor(.atlasPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.atlasPrimary.opacity(0.15))
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(customName.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.atlasText)
                                
                                Text("\(selectedDuration) minutes daily")
                                    .font(.system(size: 13))
                                    .foregroundColor(.atlasTextMuted)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeOut(duration: 0.2), value: canSave)
                }
                
                // Save button
                Button(action: {
                    let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(name, selectedDuration)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canSave ? .atlasBackground : .atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canSave ? Color.atlasPrimary : Color.white.opacity(0.1))
                        .cornerRadius(14)
                }
                .disabled(!canSave)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isNameFocused = true
        }
    }
}

// MARK: - User Input Data
// Stored per-intervention when user provides custom name/duration

struct InterventionUserInput {
    let interventionId: String
    var customName: String
    var durationMinutes: Int
}
