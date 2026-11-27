import SwiftUI

struct RegressionInterventionView: View {
    let alert: RegressionAlert
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 24) {
                // Warning Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 12) {
                    Text("Pattern Alert")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.atlasText)
                    
                    Text(alert.message)
                        .font(.system(size: 16))
                        .foregroundColor(.atlasText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("This isn't about motivation")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasAccent)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        CheckItem(text: "Did something change? (travel, illness, work stress)")
                        CheckItem(text: "Is sleep disrupted? (this cascades to everything)")
                        CheckItem(text: "Are you trying to do too much?")
                    }
                    
                    Text("Let's identify the root cause and adjust your protocol accordingly.")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                Button(action: onDismiss) {
                    Text("Continue to Analysis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            .padding(32)
            .background(Color.atlasBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

struct CheckItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    RegressionInterventionView(
        alert: RegressionAlert(
            type: .suddenDrop,
            message: "You were crushing it at 85% for 2 weeks, now at 45%. What changed?"
        ),
        onDismiss: {}
    )
}
