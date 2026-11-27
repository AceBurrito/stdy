import SwiftUI

struct NonNegotiableCard: View {
    let habit: NonNegotiable
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: habit.icon)
                .font(.system(size: 24))
                .foregroundColor(.atlasPrimary)
                .frame(width: 44, height: 44)
                .background(Color.atlasPrimary.opacity(0.15))
                .cornerRadius(10)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasText)
                
                Text(habit.reason)
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        
        NonNegotiableCard(habit: NonNegotiable(
            title: "In bed by 10:30 PM",
            icon: "bed.double.fill",
            reason: "Your 6.2hr sleep average is limiting recovery"
        ))
        .padding()
    }
}
