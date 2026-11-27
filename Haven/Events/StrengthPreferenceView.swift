import SwiftUI

// MARK: - Strength Training Preference View
// Shows AFTER timeline review, BEFORE plan generation
// Asks: How many days? What goal? What equipment?

struct StrengthPreferenceView: View {
    @Binding var strengthDaysPerWeek: Int
    @Binding var strengthGoal: String?
    @Binding var equipmentAccess: String?
    let onContinue: () -> Void
    let onBack: () -> Void
    
    @State private var showEquipmentQuestion = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.atlasPrimary)
                        .padding(.bottom, 8)
                    
                    Text("Strength Training")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("This plan includes strength work to prevent injuries and improve running performance")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Question 1: How many days per week?
                VStack(alignment: .leading, spacing: 16) {
                    Text("How many days per week do you want to strength train?")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        StrengthDaysButton(
                            days: 2,
                            title: "2 days - As designed",
                            subtitle: "Injury prevention focus (Recommended)",
                            isSelected: strengthDaysPerWeek == 2
                        ) {
                            strengthDaysPerWeek = 2
                            strengthGoal = "injury_prevention"
                            showEquipmentQuestion = false
                        }
                        
                        StrengthDaysButton(
                            days: 2,
                            title: "2 days - Build serious strength",
                            subtitle: "Heavy compound lifts, progressive overload",
                            isSelected: strengthDaysPerWeek == 2 && strengthGoal == "build_strength"
                        ) {
                            strengthDaysPerWeek = 2
                            strengthGoal = "build_strength"
                            showEquipmentQuestion = true
                        }
                        
                        StrengthDaysButton(
                            days: 3,
                            title: "3 days - Maximum strength focus",
                            subtitle: "Serious about getting stronger",
                            isSelected: strengthDaysPerWeek == 3
                        ) {
                            strengthDaysPerWeek = 3
                            strengthGoal = "build_strength"
                            showEquipmentQuestion = true
                        }
                        
                        StrengthDaysButton(
                            days: 1,
                            title: "1 day - Minimal maintenance",
                            subtitle: "Time-constrained, bare minimum",
                            isSelected: strengthDaysPerWeek == 1
                        ) {
                            strengthDaysPerWeek = 1
                            strengthGoal = "injury_prevention"
                            showEquipmentQuestion = false
                        }
                        
                        StrengthDaysButton(
                            days: 0,
                            title: "0 days - Running only",
                            subtitle: "Not recommended (higher injury risk)",
                            isSelected: strengthDaysPerWeek == 0
                        ) {
                            strengthDaysPerWeek = 0
                            strengthGoal = nil
                            equipmentAccess = nil
                            showEquipmentQuestion = false
                        }
                    }
                }
                .padding(.horizontal)
                
                // Question 2: Equipment access (conditional)
                if showEquipmentQuestion {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What equipment do you have access to?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 12) {
                            EquipmentButton(
                                equipment: "full_gym",
                                title: "Full Gym Access",
                                subtitle: "Barbells, racks, benches, machines",
                                icon: "building.2.fill",
                                isSelected: equipmentAccess == "full_gym"
                            ) {
                                equipmentAccess = "full_gym"
                            }
                            
                            EquipmentButton(
                                equipment: "home_gym",
                                title: "Home Gym",
                                subtitle: "Barbell, rack, bench, dumbbells",
                                icon: "house.fill",
                                isSelected: equipmentAccess == "home_gym"
                            ) {
                                equipmentAccess = "home_gym"
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Preview of what they're getting
                if strengthDaysPerWeek > 0 {
                    strengthPreviewCard
                        .padding(.horizontal)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Generate Training Plan")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(canContinue ? Color.atlasPrimary : Color.gray)
                            .cornerRadius(16)
                    }
                    .disabled(!canContinue)
                    
                    Button(action: onBack) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.atlasPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .padding(.bottom, 40)
        }
        .animation(.easeInOut, value: showEquipmentQuestion)
    }
    
    private var canContinue: Bool {
        if strengthDaysPerWeek == 0 {
            return true // No strength = no equipment needed
        }
        if strengthGoal == "build_strength" {
            return equipmentAccess != nil // Need equipment selection
        }
        return true // Injury prevention = bodyweight/dumbbells (always available)
    }
    
    @ViewBuilder
    private var strengthPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.atlasPrimary)
                Text("What You'll Get")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            if strengthDaysPerWeek == 0 {
                PreviewPoint(
                    icon: "exclamationmark.triangle.fill",
                    text: "Pure running plan with no strength work",
                    color: .orange
                )
                PreviewPoint(
                    icon: "info.circle.fill",
                    text: "Higher injury risk without strength training",
                    color: .orange
                )
            } else if strengthGoal == "injury_prevention" {
                PreviewPoint(
                    icon: "figure.strengthtraining.traditional",
                    text: "\(strengthDaysPerWeek)x per week, 40 min sessions",
                    color: .atlasPrimary
                )
                PreviewPoint(
                    icon: "cross.case.fill",
                    text: "Focus: Injury prevention, stability, mobility",
                    color: .atlasPrimary
                )
                PreviewPoint(
                    icon: "dumbbell.fill",
                    text: "Equipment: Bodyweight + light dumbbells",
                    color: .atlasPrimary
                )
            } else if strengthGoal == "build_strength" {
                PreviewPoint(
                    icon: "figure.strengthtraining.traditional",
                    text: "\(strengthDaysPerWeek)x per week, 50 min sessions",
                    color: .atlasPrimary
                )
                PreviewPoint(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Focus: Build serious strength, progressive overload",
                    color: .atlasPrimary
                )
                PreviewPoint(
                    icon: "dumbbell.fill",
                    text: "Exercises: Squats, deadlifts, bench press, rows",
                    color: .atlasPrimary
                )
            }
        }
        .padding()
        .background(Color.atlasPrimary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Strength Days Button
struct StrengthDaysButton: View {
    let days: Int
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(.white)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .atlasPrimary : .gray)
                }
            }
            .padding()
            .background(isSelected ? Color.atlasPrimary.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.atlasPrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Equipment Button
struct EquipmentButton: View {
    let equipment: String
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .atlasPrimary : .white)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .atlasPrimary : .gray)
            }
            .padding()
            .background(isSelected ? Color.atlasPrimary.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.atlasPrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview Point
struct PreviewPoint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}
